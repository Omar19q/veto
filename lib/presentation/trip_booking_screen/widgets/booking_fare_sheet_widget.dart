import '../../../l10n/strings.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../services/growth_service.dart';
import '../../../services/customer_payment_preference.dart';
import '../../../services/supabase_service.dart';
import 'extra_requests_field.dart';
import '../../../widgets/extra_purchase_limit.dart';

class BookingFareSheetWidget extends StatefulWidget {
  final String serviceId;
  final String pickupLabel;
  final String destinationLabel;
  final double distance;
  final double duration;
  final double fare;
  final double growthDiscount;
  final double availableGrowthDiscount;
  final bool useEarnedDiscount;
  final ValueChanged<bool>? onEarnedDiscountChanged;
  final bool growthPreviewReady;
  final int incentiveAmount;
  final int passengerCount;
  final double? packageWeightKg;
  final double walletBalance;
  final String previousDueReason;
  final ValueChanged<int> onPassengerCountChanged;
  final ValueChanged<double> onPackageWeightChanged;
  final void Function(String method, double walletAmount, double cashAmount)
  onPaymentMethodChanged;
  final VoidCallback onConfirm;
  final Future<Map<String, dynamic>> Function(String code, double amount)?
  onApplyPromo;
  final VoidCallback? onClearPromo;
  final String initialCustomerNote;
  final ValueChanged<String> onCustomerNoteChanged;
  final double? initialExtraExpectedAmount;
  final ValueChanged<double?>? onExtraExpectedAmountChanged;
  final String initialExtraRequests;
  final ValueChanged<String>? onExtraRequestsChanged;

  const BookingFareSheetWidget({
    super.key,
    required this.serviceId,
    required this.pickupLabel,
    required this.destinationLabel,
    required this.distance,
    required this.duration,
    required this.fare,
    this.growthDiscount = 0,
    this.availableGrowthDiscount = 0,
    this.useEarnedDiscount = true,
    this.onEarnedDiscountChanged,
    this.growthPreviewReady = true,
    required this.incentiveAmount,
    required this.passengerCount,
    required this.walletBalance,
    this.previousDueReason = '',
    required this.onPassengerCountChanged,
    required this.onPackageWeightChanged,
    required this.onPaymentMethodChanged,
    required this.onConfirm,
    this.packageWeightKg,
    this.onApplyPromo,
    this.onClearPromo,
    this.initialCustomerNote = '',
    required this.onCustomerNoteChanged,
    this.initialExtraExpectedAmount,
    this.onExtraExpectedAmountChanged,
    this.initialExtraRequests = '',
    this.onExtraRequestsChanged,
  });

  @override
  State<BookingFareSheetWidget> createState() => _BookingFareSheetWidgetState();
}

class _BookingFareSheetWidgetState extends State<BookingFareSheetWidget> {
  late String _paymentMethod;
  late double _walletAmount;
  late double _cashAmount;
  late double _packageWeight;
  final _scrollController = ScrollController();
  final _promoController = TextEditingController();
  late final TextEditingController _noteController;
  late final TextEditingController _extraController;
  late final TextEditingController _extraAmountController;
  final _extraAmountKey = GlobalKey<FormFieldState<String>>();
  int _promoRevision = 0;
  bool _paymentChosen = false;
  String? _paymentOwner;
  double _promoDiscount = 0;
  bool _promoLoading = false;
  String? _promoMessage;

  double get _grossTotal => math.max(0, widget.fare + widget.incentiveAmount);
  double get _debtRollover => math.max(0, -widget.walletBalance);
  double get _total => math.max(
    0,
    _grossTotal -
        (_promoDiscount > 0 ? _promoDiscount : widget.growthDiscount) +
        _debtRollover,
  );

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.initialCustomerNote);
    _extraController = TextEditingController(text: widget.initialExtraRequests);
    _extraAmountController = TextEditingController(
      text: widget.initialExtraExpectedAmount?.toStringAsFixed(2) ?? '',
    );

    _packageWeight = widget.packageWeightKg ?? 1;

    // Never force the customer to pay cash when a partial wallet + cash
    // combination is possible. For a wallet balance below the total,
    // Combined is the correct default.
    if (widget.walletBalance > 0 && widget.walletBalance < _total) {
      _paymentMethod = 'combined';
    } else {
      _paymentMethod = 'cash';
    }
    _recalculatePayment(notify: false);
    _restorePayment();

    // Keep the parent booking model in sync with the default shown to the
    // customer. Without this, the UI could show "محفظة + كاش" while the
    // booking model still contains the old default "cash" until the customer
    // manually taps a payment option.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onPaymentMethodChanged(_paymentMethod, _walletAmount, _cashAmount);
    });
  }

  @override
  void didUpdateWidget(covariant BookingFareSheetWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fare != widget.fare ||
        oldWidget.incentiveAmount != widget.incentiveAmount ||
        oldWidget.walletBalance != widget.walletBalance) {
      _promoRevision++;
      _promoLoading = false;
      _promoDiscount = 0;
      _promoMessage = null;
      if (_paymentMethod == 'wallet' && widget.walletBalance < _total) {
        _paymentMethod = 'combined';
      }
      _recalculatePayment(notify: true);
    } else if (oldWidget.growthDiscount != widget.growthDiscount ||
        oldWidget.useEarnedDiscount != widget.useEarnedDiscount) {
      _recalculatePayment(notify: true);
    }
  }

  void _recalculatePayment({required bool notify}) {
    final total = _total;
    double wallet = 0;
    double cash = total;

    switch (_paymentMethod) {
      case 'wallet':
        if (widget.walletBalance >= total) {
          wallet = total;
          cash = 0;
        } else {
          _paymentMethod = total > 0 ? 'combined' : 'cash';
          wallet = math.max(0, math.min(widget.walletBalance, total));
          cash = math.max(0, total - wallet);
        }
        break;
      case 'combined':
        wallet = math.max(0, math.min(widget.walletBalance, total));
        cash = math.max(0, total - wallet);
        break;
      default:
        _paymentMethod = 'cash';
        break;
    }

    _walletAmount = double.parse(wallet.toStringAsFixed(2));
    _cashAmount = double.parse(cash.toStringAsFixed(2));

    if (notify) {
      widget.onPaymentMethodChanged(_paymentMethod, _walletAmount, _cashAmount);
    }
  }

  Future<void> _restorePayment() async {
    try {
      final account = SupabaseService.instance.currentUser?.id;
      _paymentOwner = account;
      if (account == null) return;
      final method = await CustomerPaymentPreference().load(account);
      if (!mounted ||
          _paymentChosen ||
          method == null ||
          SupabaseService.instance.currentUser?.id != account)
        return;
      setState(() {
        _paymentMethod = method;
        _recalculatePayment(notify: false);
      });
      widget.onPaymentMethodChanged(_paymentMethod, _walletAmount, _cashAmount);
    } catch (_) {
      /* Optional preference cannot block booking. */
    }
  }

  void _setPaymentMethod(String method) {
    _paymentChosen = true;
    setState(() => _paymentMethod = method);
    _recalculatePayment(notify: true);
    final account = _paymentOwner;
    if (account != null) {
      CustomerPaymentPreference()
          .save(account, method)
          .catchError((Object _) {});
    }
  }

  String get _paymentLabel => switch (_paymentMethod) {
    'wallet' => context.strings.uidf1727d8,
    'combined' => context.strings.ui92215af2,
    _ => context.strings.ui1881ccb3,
  };

  Future<void> _choosePayment() async {
    final l = context.strings;
    final method = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .8,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.changePayment,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                for (final option in [
                  (
                    id: 'cash',
                    label: l.ui1881ccb3,
                    icon: Icons.payments_outlined,
                    enabled: true,
                    help: l.ui898cec70,
                  ),
                  (
                    id: 'wallet',
                    label: l.uidf1727d8,
                    icon: Icons.account_balance_wallet_outlined,
                    enabled: widget.walletBalance >= _total && _total > 0,
                    help: l.moneyValue(widget.walletBalance.toStringAsFixed(2)),
                  ),
                  (
                    id: 'combined',
                    label: l.ui92215af2,
                    icon: Icons.call_split_rounded,
                    enabled: widget.walletBalance > 0 && _total > 0,
                    help: l.ui5dbd6c30,
                  ),
                ])
                  ListTile(
                    enabled: option.enabled,
                    minVerticalPadding: 16,
                    leading: Icon(option.icon),
                    title: Text(option.label),
                    subtitle: Text(option.help),
                    selected: _paymentMethod == option.id,
                    trailing: _paymentMethod == option.id
                        ? const Icon(Icons.check_circle)
                        : null,
                    onTap: option.enabled
                        ? () => Navigator.pop(sheetContext, option.id)
                        : null,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || method == null) return;
    _setPaymentMethod(method);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _promoController.dispose();
    _noteController.dispose();
    _extraController.dispose();
    _extraAmountController.dispose();
    super.dispose();
  }

  String _promoError(String? error) {
    switch (error) {
      case 'promo_expired':
        return context.strings.uibc40c997;
      case 'promo_not_started':
        return context.strings.ui327c8f24;
      case 'promo_inactive':
        return context.strings.uif628612e;
      case 'promo_total_limit':
        return context.strings.ui9b548771;
      case 'promo_people_limit':
        return context.strings.uiab945993;
      case 'promo_user_limit':
        return context.strings.ui312fca54;
      case 'promo_legacy_people_unknown':
        return context.strings.uidf40e49a;
      case 'promo_zero_discount':
        return context.strings.ui3b3d074b;
      case 'login_required':
        return context.strings.ui2dcb22b8;
      case 'promo_network_error':
        return context.strings.ui28fd5fd3;
      default:
        return context.strings.uia73828a5;
    }
  }

  void _clearPromoOnEdit(String _) {
    _promoRevision++;
    widget.onClearPromo?.call();
    setState(() {
      _promoDiscount = 0;
      _promoMessage = null;
      _promoLoading = false;
    });
    _recalculatePayment(notify: true);
  }

  Future<void> _applyPromo() async {
    final code = _promoController.text.trim();
    if (code.isEmpty || widget.onApplyPromo == null || _promoLoading) return;
    setState(() {
      _promoLoading = true;
      _promoMessage = null;
    });
    final revision = ++_promoRevision;
    Map<String, dynamic> result;
    try {
      result = await widget.onApplyPromo!(code, _grossTotal);
    } catch (_) {
      result = {'success': false, 'error': 'promo_network_error'};
      if (revision == _promoRevision) widget.onClearPromo?.call();
    }
    if (!mounted) return;
    if (revision != _promoRevision) return;
    // A late network response must not reapply a code the customer has edited.
    if (_promoController.text.trim() != code) {
      widget.onClearPromo?.call();
      setState(() => _promoLoading = false);
      return;
    }
    final applied = result['success'] == true;
    if (!applied) GrowthService().observe('promo_code_rejected');
    final amount = applied
        ? (num.tryParse(result['discount']?.toString() ?? '')?.toDouble() ?? 0)
        : 0.0;
    setState(() {
      _promoLoading = false;
      _promoDiscount = math.max(0, amount);
      _promoMessage = applied
          ? context.strings.promoAppliedValue(_promoDiscount.toStringAsFixed(2))
          : _promoError(result['error']?.toString());
    });
    _recalculatePayment(notify: true);
  }

  @override
  Widget build(BuildContext context) {
    final isPackage =
        widget.serviceId == 'package' || widget.serviceId == 'package_delivery';

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 30,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                interactive: true,
                radius: const Radius.circular(8),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.outline,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _RouteCard(
                        pickup: widget.pickupLabel,
                        destination: widget.destinationLabel,
                      ),
                      const SizedBox(height: 6),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(Localizations.localeOf(context).languageCode=='ar'?(_promoDiscount>0||widget.growthDiscount>0?'الإجمالي بعد الخصم':'الأجرة التقديرية'):(_promoDiscount>0||widget.growthDiscount>0?'Total after discount':'Estimated fare')),
                              if(_promoDiscount>0||widget.growthDiscount>0)
                              Text(
                                context.strings.moneyValue(
                                  _grossTotal.toStringAsFixed(2),
                                ),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      decoration:
                                          _promoDiscount > 0 ||
                                              widget.growthDiscount > 0
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                              ),
                              if (_promoDiscount > 0 ||
                                  widget.growthDiscount > 0)
                                Text(
                                  context.strings.promoAppliedValue(
                                    (_promoDiscount > 0
                                            ? _promoDiscount
                                            : widget.growthDiscount)
                                        .toStringAsFixed(2),
                                  ),
                                ),
                              Text(
                                context.strings.moneyValue(
                                  _total.toStringAsFixed(2),
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoBox(
                              icon: Icons.route_rounded,
                              label: context.strings.uidd00b654,
                              value: context.strings.distanceValue(
                                widget.distance.toStringAsFixed(1),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _InfoBox(
                              icon: Icons.schedule_rounded,
                              label: context.strings.uia7947509,
                              value: context.strings.durationValue(
                                widget.duration.ceil().toString(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _InfoBox(
                              icon: Icons.payments_rounded,
                              label: context.strings.ui45a9a436,
                              value: context.strings.moneyValue(
                                widget.fare.toStringAsFixed(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // V39: passenger count remains 1 in the existing payload.
                      // The redundant selector is hidden, without changing accounting.
                      if (isPackage) ...[
                        const SizedBox(height: 12),
                        _sectionTitle(context.strings.ui8a440ee4),
                        const SizedBox(height: 8),
                        Slider(
                          value: _packageWeight.clamp(1, 30),
                          min: 1,
                          max: 30,
                          divisions: 29,
                          activeColor: AppTheme.gold,
                          inactiveColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          label: _packageWeight.toStringAsFixed(0),
                          onChanged: (v) {
                            setState(() => _packageWeight = v);
                            widget.onPackageWeightChanged(v);
                          },
                        ),
                      ],
                      if (widget.availableGrowthDiscount > 0) ...[
                        const SizedBox(height: 12),
                        Material(
                          color: AppTheme.gold.withAlpha(20),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.card_giftcard_rounded,
                                  color: AppTheme.gold,
                                  size: 27,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.strings.earnedRideDiscount,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        context.strings.earnedRideSaving(
                                          context.strings.moneyValue(
                                            widget.availableGrowthDiscount
                                                .toStringAsFixed(2),
                                          ),
                                        ),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        context.strings.earnedRideTerms,
                                        style: TextStyle(fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: widget.useEarnedDiscount,
                                  onChanged: widget.onEarnedDiscountChanged,
                                  activeTrackColor: AppTheme.gold,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (!widget.useEarnedDiscount)
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                              context.strings.earnedRideSkipped,
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                      ],
                      if (widget.onApplyPromo != null) ...[
                        const SizedBox(height: 12),
                        _sectionTitle(context.strings.uif11b8c52),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _promoController,
                                onChanged: _clearPromoOnEdit,
                                textDirection: TextDirection.ltr,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                                decoration: InputDecoration(
                                  hintText: context.strings.uid219bc19,
                                  hintStyle: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outline,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _promoLoading ? null : _applyPromo,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.gold,
                                foregroundColor: AppTheme.primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 15,
                                ),
                              ),
                              child: _promoLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      context.strings.ui268974da,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                        if (_promoMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                _promoMessage!,
                                style: TextStyle(
                                  color: _promoDiscount > 0
                                      ? AppTheme.successLight
                                      : AppTheme.errorLight,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                      ],
                      if (_debtRollover > 0) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.errorLight.withAlpha(18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.errorLight.withAlpha(70),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: AppTheme.errorLight,
                                size: 19,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  context.strings.previousDueNotice(
                                    widget.previousDueReason.isEmpty
                                        ? context.strings.uif28e3f71
                                        : widget.previousDueReason,
                                    _debtRollover.toStringAsFixed(2),
                                  ),
                                  textDirection: Directionality.of(context),
                                  style: const TextStyle(
                                    color: AppTheme.errorLight,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Material(
                        color: Colors.transparent,
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text(
                            context.strings.ui18a707e2,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          initiallyExpanded:
                              widget.initialCustomerNote.trim().isNotEmpty ||
                              widget.initialExtraRequests.trim().isNotEmpty,
                          children: [
                            const SizedBox(height: 8),
                            TextField(
                              controller: _noteController,
                              maxLines: 3,
                              textDirection: Directionality.of(context),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              onChanged: widget.onCustomerNoteChanged,
                              decoration: InputDecoration(
                                hintText: context.strings.ui49acfce8,
                                hintStyle: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                filled: true,
                                fillColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ExtraRequestsField(
                              controller: _extraController,
                              onChanged: (value) {
                                widget.onExtraRequestsChanged?.call(value);
                                if (value.trim().isEmpty) {
                                  _extraAmountController.clear();
                                  widget.onExtraExpectedAmountChanged?.call(
                                    null,
                                  );
                                }
                                setState(() {});
                              },
                            ),
                            if (_extraController.text.trim().isNotEmpty)
                              const ExtraPurchaseLimitBanner(),
                            if (_extraController.text.trim().isNotEmpty)
                              TextFormField(
                                key: _extraAmountKey,
                                controller: _extraAmountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                validator: (value) =>
                                    validateExtraPurchaseAmount(
                                      value,
                                      strings: context.strings,
                                    ),
                                decoration: InputDecoration(
                                  labelText: context.strings.ui84c7eeb2,
                                  suffixText: context.strings.currency,
                                  filled: true,
                                ),
                                onChanged: (value) =>
                                    widget.onExtraExpectedAmountChanged?.call(
                                      double.tryParse(
                                        normalizePurchaseAmount(value),
                                      ),
                                    ),
                              ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                      _sectionTitle(context.strings.uiae2d6005),
                      const SizedBox(height: 8),
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          tileColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          leading: const Icon(
                            Icons.account_balance_wallet_outlined,
                          ),
                          title: Text(_paymentLabel),
                          subtitle: Text(context.strings.changePayment),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: _choosePayment,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _FinalFareSummary(
                        rideFare: widget.fare,
                        incentive: widget.incentiveAmount.toDouble(),
                        previousDue: _debtRollover,
                        discount: _promoDiscount > 0
                            ? _promoDiscount
                            : widget.growthDiscount,
                        totalAfterDiscount: _total,
                        walletAmount: _walletAmount,
                        cashAmount: _cashAmount,
                        paymentMethod: _paymentMethod,
                        walletBalance: widget.walletBalance,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ), // Expanded: the long review scrolls independently
            Container(
              padding: const EdgeInsets.fromLTRB(13, 9, 13, 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(color: Theme.of(context).colorScheme.outline),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.strings.bookingTotal,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        context.strings.moneyValue(_total.toStringAsFixed(2)),
                        key: const ValueKey('booking-total'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed:
                        _total > 0 &&
                            widget.growthPreviewReady &&
                            !_promoLoading
                        ? () {
                            if (_extraAmountKey.currentState?.validate() ==
                                false)
                              return;
                            widget.onConfirm();
                          }
                        : null,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(context.strings.uia39f7a83),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.gold,
                      foregroundColor: AppTheme.primary,
                      minimumSize: const Size(48, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        text,
        textDirection: Directionality.of(context),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final String pickup;
  final String destination;

  const _RouteCard({required this.pickup, required this.destination});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        children: [
          _routeLine(
            context,
            Icons.radio_button_checked_rounded,
            AppTheme.successLight,
            context.strings.uiae7ae56d,
            pickup,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 1,
                height: 10,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          _routeLine(
            context,
            Icons.location_on_rounded,
            AppTheme.errorLight,
            context.strings.ui8b068efc,
            destination,
          ),
        ],
      ),
    );
  }

  Widget _routeLine(
    BuildContext context,
    IconData icon,
    Color color,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                label,
                textDirection: Directionality.of(context),
                style: TextStyle(
                  fontSize: 9,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: Directionality.of(context),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoBox({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        children: [
          Icon(icon, size: 17, color: AppTheme.gold),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinalFareSummary extends StatelessWidget {
  final double rideFare;
  final double incentive;
  final double previousDue;
  final double discount;
  final double totalAfterDiscount;
  final double walletAmount;
  final double cashAmount;
  final String paymentMethod;
  final double walletBalance;

  const _FinalFareSummary({
    required this.rideFare,
    required this.incentive,
    required this.previousDue,
    required this.discount,
    required this.totalAfterDiscount,
    required this.walletAmount,
    required this.cashAmount,
    required this.paymentMethod,
    required this.walletBalance,
  });

  String _paymentLabel(BuildContext context) {
    switch (paymentMethod) {
      case 'wallet':
        return context.strings.ui69cb4d81;
      case 'combined':
        return context.strings.uid1588f9b;
      default:
        return context.strings.ui1881ccb3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final paidFullyByWallet = totalAfterDiscount > 0 && cashAmount <= 0.004;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.gold.withAlpha(90), width: 1.2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.gold.withAlpha(28),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.calculate_rounded,
                  color: AppTheme.gold,
                  size: 26,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      context.strings.ui5164d8be,
                      textAlign: TextAlign.right,
                      textDirection: Directionality.of(context),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      context.strings.ui68881282,
                      textAlign: TextAlign.right,
                      textDirection: Directionality.of(context),
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _line(
            context,
            icon: Icons.local_taxi_rounded,
            label: context.strings.uiff8a5dd1,
            value: rideFare,
          ),
          if (incentive > 0)
            _line(
              context,
              icon: Icons.add_circle_rounded,
              label: context.strings.ui87369f01,
              value: incentive,
            ),
          if (previousDue > 0)
            _line(
              context,
              icon: Icons.warning_amber_rounded,
              label: context.strings.uif28e3f71,
              value: previousDue,
              color: AppTheme.errorLight,
            ),
          if (discount > 0)
            _line(
              context,
              icon: Icons.discount_rounded,
              label: context.strings.uib593a645,
              value: -discount,
              color: AppTheme.successLight,
            ),
          Divider(height: 18, color: Theme.of(context).colorScheme.outline),
          _line(
            context,
            icon: Icons.receipt_long_rounded,
            label: context.strings.uif918ebca,
            value: totalAfterDiscount,
            strong: true,
            color: AppTheme.gold,
          ),
          if (walletAmount > 0)
            _line(
              context,
              icon: Icons.account_balance_wallet_rounded,
              label: context.strings.ui70cc122a,
              value: -walletAmount,
              color: AppTheme.gold,
            ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            decoration: BoxDecoration(
              color: paidFullyByWallet
                  ? AppTheme.successLight.withAlpha(18)
                  : AppTheme.gold.withAlpha(18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: paidFullyByWallet
                    ? AppTheme.successLight.withAlpha(90)
                    : AppTheme.gold.withAlpha(90),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  paidFullyByWallet
                      ? Icons.verified_rounded
                      : Icons.payments_rounded,
                  color: paidFullyByWallet
                      ? AppTheme.successLight
                      : AppTheme.gold,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        paidFullyByWallet
                            ? context.strings.uid6c3b867
                            : context.strings.ui8fb9853e,
                        textAlign: TextAlign.right,
                        textDirection: Directionality.of(context),
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        context.strings.moneyValue(
                          cashAmount.toStringAsFixed(2),
                        ),
                        textAlign: TextAlign.right,
                        textDirection: Directionality.of(context),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: paidFullyByWallet
                              ? AppTheme.successLight
                              : AppTheme.gold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.credit_card_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  paidFullyByWallet
                      ? context.strings.ui032bb56d
                      : walletAmount > 0
                      ? context.strings.walletPaymentSummary(
                          _paymentLabel(context),
                          walletAmount.toStringAsFixed(2),
                        )
                      : context.strings.paymentSummary(_paymentLabel(context)),
                  textAlign: TextAlign.right,
                  textDirection: Directionality.of(context),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (walletBalance > 0 &&
              walletAmount > 0 &&
              walletBalance > walletAmount) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                context.strings.walletRemaining(
                  (walletBalance - walletAmount).toStringAsFixed(2),
                ),
                textAlign: TextAlign.right,
                textDirection: Directionality.of(context),
                style: TextStyle(
                  fontSize: 9,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(
    BuildContext context, {
    required IconData icon,
    required String label,
    required double value,
    bool strong = false,
    Color? color,
  }) {
    final isNegative = value < 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: strong ? 20 : 18,
            color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.right,
              textDirection: Directionality.of(context),
              style: TextStyle(
                color: strong
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: strong ? 12 : 11,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            context.strings.moneyValue(
              '${isNegative ? '- ' : ''}${value.abs().toStringAsFixed(2)}',
            ),
            textDirection: Directionality.of(context),
            style: TextStyle(
              color:
                  color ??
                  (strong
                      ? AppTheme.gold
                      : Theme.of(context).colorScheme.onSurface),
              fontWeight: strong ? FontWeight.w900 : FontWeight.w800,
              fontSize: strong ? 14 : 11,
            ),
          ),
        ],
      ),
    );
  }
}
