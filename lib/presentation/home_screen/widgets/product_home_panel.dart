import 'package:flutter/services.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../../../l10n/strings.dart';
import '../../../services/booking_address_seed.dart';
import '../../../services/booking_performance.dart';
import '../../../services/supabase_service.dart';

class ProductHomePanel extends StatefulWidget {
  const ProductHomePanel({
    super.key,
    required this.customerId,
    required this.pickupCaption,
    required this.onStart,
    required this.onMarket,
    this.loadAddresses,
    this.loadRecentTrips,
    this.suggestedPickup,
  });
  final String? customerId;
  final String pickupCaption;
  final void Function(BookingAddressSelection selection, String? service)
  onStart;
  final VoidCallback onMarket;
  final BookingAddressSeed? suggestedPickup;
  final Future<List<Map<String, dynamic>>> Function(
    String customerId,
  )? loadAddresses,
      loadRecentTrips;
  @override
  State<ProductHomePanel> createState() => _ProductHomePanelState();
}

class _ProductHomePanelState extends State<ProductHomePanel> {
  BookingAddressSeed? _pickup;
  List<BookingAddressSeed> _quickDestinations = [];
  String? _service;
  bool _loading = true;
  bool _failed = false;
  bool _pickupChosen = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ProductHomePanel old) {
    super.didUpdateWidget(old);
    if (old.customerId != widget.customerId) {
      _pickup = null;
      _quickDestinations = [];
      _pickupChosen = false;
      _loading = widget.customerId != null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    final id = widget.customerId;
    if (id == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        widget.loadAddresses?.call(id) ??
            SupabaseService.instance.getCustomerAddresses(id),
        widget.loadRecentTrips?.call(id) ??
            SupabaseService.instance.getCustomerTrips(id, limit: 12),
      ]).timeout(const Duration(seconds: 8));
      if (!mounted || id != widget.customerId) return;
      final saved = results[0]
          .map(BookingAddressSeed.saved)
          .whereType<BookingAddressSeed>()
          .toList();
      if (!mounted || id != widget.customerId) return;
      final savedDestinations = saved.where((a) => !a.defaultPickup).toList();
      final seen = <String>{};
      for (final s in savedDestinations) {
        seen.add('\,');
      }
      final recent = results[1]
          .map(BookingAddressSeed.recent)
          .whereType<BookingAddressSeed>()
          .where((r) => seen.add('\,'))
          .toList();
      final quick = [...savedDestinations, ...recent].take(3).toList();
      setState(() {
        _pickup = saved.where((a) => a.defaultPickup).firstOrNull;
        _quickDestinations = quick;
        _loading = false;
        _failed = false;
      });
      // A local platform read must never hold the booking UI in loading state.
      unawaited(_restorePickup(id, saved));
    } catch (_) {
      if (mounted && id == widget.customerId) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _restorePickup(
    String account,
    List<BookingAddressSeed> saved,
  ) async {
    try {
      final choice = (await SharedPreferences.getInstance()).getString(
        'veto_pickup_$account',
      );
      if (!mounted || account != widget.customerId || _pickupChosen) return;
      final stored = saved
          .where((a) => '${a.latitude},${a.longitude}' == choice)
          .firstOrNull;
      if (stored != null) setState(() => _pickup = stored);
    } catch (_) {
      /* Optional convenience only. */
    }
  }

  void _start([BookingAddressSeed? destination]) => widget.onStart(
    BookingAddressSelection(
      pickup: _pickup ?? (_pickupChosen ? null : widget.suggestedPickup),
      destination: destination,
      attempt: BookingPerformanceAttempt(),
    ),
    _service,
  );
  @override
  Widget build(BuildContext context) {
    final l = context.strings;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final scale = MediaQuery.textScalerOf(context).scale(14);
    final isDark = theme.brightness == Brightness.dark;
    final compactLabels = scale <= 19;
    final pickupName = _pickup?.label ?? widget.pickupCaption;
    final isEnglish = l.localeName.startsWith('en');
    final services = <({String id, String label})>[
      (id: 'car', label: l.car),
      (id: 'motorcycle', label: l.motorcycle),
      (id: 'ladies', label: isEnglish ? 'Ladies' : 'سيدات وأطفال'),
      (id: 'package', label: l.delivery),
      (id: 'market', label: l.market),
    ];

    // Only the primary unified route action and categories are permanently visible.
    // Destinations and saved places are accessible inside the booking flow.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Unified Uber-style Route Search Card (Where to + Pickup in one card)
        Material(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colors.outlineVariant.withAlpha(isDark ? 100 : 70),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Primary "Where to?" action (Hero bar)
                Semantics(
                  button: true,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _start();
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 11),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFFFFC107).withAlpha(35)
                                  : const Color(0xFFFFC107).withAlpha(45),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.search_rounded,
                              size: 21,
                              color: isDark
                                  ? const Color(0xFFFFC107)
                                  : const Color(0xFFD97706),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l.whereTo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 16.5,
                              ),
                            ),
                          ),
                          ExcludeSemantics(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E2540)
                                    : colors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colors.outlineVariant.withAlpha(80),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.near_me_rounded,
                                    size: 13,
                                    color: isDark
                                        ? const Color(0xFFFFC107)
                                        : const Color(0xFFD97706),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isEnglish ? 'Now' : 'طلب الآن',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Subtle internal divider
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 14,
                  endIndent: 14,
                  color: colors.outlineVariant.withAlpha(isDark ? 80 : 50),
                ),

                // Pickup location info row (compact, clear, editable)
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _start();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Text(
                          isEnglish ? 'From: ' : 'من: ',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            pickupName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isEnglish ? 'Change' : 'تغيير',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? const Color(0xFFFFC107)
                                : const Color(0xFFD97706),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_left_rounded,
                          size: 16,
                          color: isDark
                              ? const Color(0xFFFFC107)
                              : const Color(0xFFD97706),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_quickDestinations.isNotEmpty) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final dest in _quickDestinations) ...[
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ActionChip(
                      avatar: Icon(
                        dest.label.contains('منزل') || dest.label.toLowerCase().contains('home')
                            ? Icons.home_rounded
                            : dest.label.contains('عمل') || dest.label.toLowerCase().contains('work')
                                ? Icons.work_rounded
                                : Icons.history_rounded,
                        size: 15,
                        color: colors.primary,
                      ),
                      label: Text(
                        dest.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      backgroundColor: colors.surfaceContainerHighest.withAlpha(isDark ? 120 : 90),
                      side: BorderSide(color: colors.outlineVariant.withAlpha(90)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _start(dest);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          height: 64 + MediaQuery.textScalerOf(context).scale(14) * 2.2,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < services.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: services[i].label,
                    child: Material(
                      color: _service == services[i].id
                          ? (isDark
                              ? const Color(0xFFFFC107).withAlpha(35)
                              : colors.primaryContainer)
                          : colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          if (services[i].id == 'market') {
                            widget.onMarket();
                          } else {
                            setState(() => _service = services[i].id);
                            _start();
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _service == services[i].id
                                  ? (isDark
                                      ? const Color(0xFFFFC107)
                                      : const Color(0xFFD97706))
                                  : colors.outlineVariant.withAlpha(isDark ? 60 : 40),
                              width: _service == services[i].id ? 1.5 : 1,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 8,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Center(
                                  child: Image.asset(
                                    'assets/vehicles/${const {'car': 'veto_economy', 'motorcycle': 'veto_moto', 'ladies': 'veto_ladies', 'package': 'veto_parcel', 'market': 'veto_market'}[services[i].id]}.webp',
                                    fit: BoxFit.contain,
                                    cacheWidth: 128,
                                    semanticLabel: services[i].label,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  services[i].label,
                                  maxLines: 1,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: compactLabels ? 11.5 : null,
                                    fontWeight: _service == services[i].id
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: _service == services[i].id && isDark
                                        ? const Color(0xFFFFC107)
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_failed)
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(l.retry),
          ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
      ],
    );
  }
}
