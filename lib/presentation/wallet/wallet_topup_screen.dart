import '../../l10n/strings.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/wallet_topup_service.dart';


class WalletTopupScreen extends StatefulWidget {
  final String? initialOfferId;
  const WalletTopupScreen({super.key, this.initialOfferId});
  @override
  State<WalletTopupScreen> createState() => _WalletTopupScreenState();
}

class _WalletTopupScreenState extends State<WalletTopupScreen> {
  Color get _navy => Theme.of(context).scaffoldBackgroundColor;
  Color get _panel => Theme.of(context).colorScheme.surfaceContainerHighest;
  Color get _gold => Theme.of(context).colorScheme.primary;
  Color get _muted => Theme.of(context).colorScheme.onSurfaceVariant;

  final _svc = WalletTopupService.instance;
  final _amount = TextEditingController();
  final _sender = TextEditingController();
  final _operation = TextEditingController();
  List<Map<String, dynamic>> _offers = [], _methods = [], _requests = [];
  Map<String, dynamic>? _offer, _method, _current;
  bool _loading = true, _sending = false;
  int _step = 0;
  String? _error;
  bool _initialSelectionConsumed = false;
  Timer? _refreshTimer;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _load();
    _subscription = _svc.watchRequests(() => _refreshRequests());
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refreshRequests(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _subscription?.unsubscribe();
    _amount.dispose();
    _sender.dispose();
    _operation.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final offers = await _svc.offers();
      final methods = await _svc.methods();
      final requests = await _svc.requests();
      if (!mounted) return;
      setState(() {
        _offers = offers;
        _methods = methods;
        _requests = requests;
        _loading = false;
        _error = null;
        if (!_initialSelectionConsumed && widget.initialOfferId != null) {
          _initialSelectionConsumed = true;
          for (final offer in offers) {
            if (offer['id'] == widget.initialOfferId) {
              _offer = offer;
              _amount.text = '${offer['paid_amount']}';
              _step = 1;
              break;
            }
          }
        }
        if (_method != null && !methods.any((m) => m['id'] == _method!['id']))
          _method = null;
        if (_current != null) {
          for (final request in requests) {
            if (request['id'] == _current!['id']) {
              _current = request;
              break;
            }
          }
        }
      });
    } catch (e) {
      debugPrint('Wallet top-up load failed: $e');
      if (mounted)
        setState(() {
          _loading = false;
          _error =
              context.strings.topupfb743f85;
        });
    }
  }

  Future<void> _refreshRequests() async {
    try {
      final requests = await _svc.requests();
      if (!mounted) return;
      setState(() {
        _requests = requests;
        if (_current != null) {
          for (final r in requests) {
            if (r['id'] == _current!['id']) {
              _current = r;
              break;
            }
          }
        }
      });
    } catch (_) {} // Preserve last known status and allow manual retry.
  }

  void _snack(String message) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle()),
        ),
      );
  }

  double get _paid => double.tryParse(_amount.text.trim()) ?? 0;
  double get _bonus => (_offer?['bonus_amount'] as num?)?.toDouble() ?? 0;
  bool get _validAmount =>
      _paid > 0 &&
      _paid <= 1000000 &&
      ((_paid * 100) - (_paid * 100).round()).abs() < 0.000001 &&
      (_offer == null || (_offer!['paid_amount'] as num).toDouble() == _paid);
  void _selectOffer(Map<String, dynamic>? offer) {
    setState(() {
      _offer = offer;
      _step = 1;
      if (offer != null) {
        _amount.text = '${offer['paid_amount']}';
      } else {
        _amount.clear();
      }
    });
  }

  void _continueToTransfer() {
    if (!_validAmount) {
      _snack(context.strings.topup120e8520);
      return;
    }
    if (_method == null) {
      _snack(context.strings.topup85a2d105);
      return;
    }
    setState(() => _step = 2);
  }

  Future<void> _submit() async {
    if (_sending || !_validAmount || _method == null) return;
    if (_sender.text.trim().length < 5) {
      _snack(context.strings.topup42c2949d);
      return;
    }
    setState(() => _sending = true);
    try {
      final request = await _svc.submit(
        methodId: _method!['id'].toString(),
        amount: _paid,
        offerId: _offer?['id']?.toString(),
        sender: _sender.text,
        operation: _operation.text,
      );
      if (!mounted) return;
      setState(() {
        _current = request;
        _step = 3;
        _sending = false;
      });
      await _refreshRequests();
      _snack(context.strings.topup8c6dd9dd);
    } catch (e) {
      debugPrint('Wallet top-up request failed: $e');
      if (mounted) {
        setState(() => _sending = false);
        _snack(
          context.strings.topupf5d7c7d6,
        );
      }
    }
  }

  Widget _card(Widget child, {bool glow = false}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: glow ? _gold : const Color(0xFF30435F),
        width: glow ? 1.4 : 1,
      ),
      boxShadow: glow
          ? [BoxShadow(color: _gold.withAlpha(35), blurRadius: 25)]
          : null,
    ),
    child: child,
  );
  Widget _txt(
    String text, {
    double size = 14,
    Color? color,
    bool bold = false,
  }) => Text(
    text,
    style: TextStyle(
      
      color: color ?? Theme.of(context).colorScheme.onSurface,
      fontSize: size,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
    ),
  );
  Widget _button(
    String title,
    VoidCallback? action, {
    bool secondary = false,
  }) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: action,
      style: ElevatedButton.styleFrom(
        backgroundColor: secondary ? _panel : _gold,
        foregroundColor: secondary ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        side: secondary ?  BorderSide(color: _gold) : null,
      ),
      child: Text(
        title,
        style: const TextStyle(
          
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
  Widget _field(
    TextEditingController ctrl,
    String label, {
    TextInputType type = TextInputType.text,
    String? hint,
    bool readOnly = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: ctrl,
      keyboardType: type,
      readOnly: readOnly,
      onChanged: (_) {
        if (mounted) setState(() {});
      },
      style: const TextStyle(color: Colors.white, ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle:  TextStyle(color: _muted, ),
        hintStyle:  TextStyle(color: _muted, ),
        filled: true,
        fillColor: _navy,
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF405373)),
          borderRadius: BorderRadius.circular(14),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide:  BorderSide(color: _gold),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
  );
  Widget _hero() => Container(
    height: 202,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      image: DecorationImage(
        // Decode at a useful banner resolution instead of the full 1672px asset.
        image: ResizeImage(
          const AssetImage('assets/images/wallet_topup_cairo.webp'),
          width: 1024,
        ),
        fit: BoxFit.cover,
        alignment: Alignment.centerLeft,
      ),
    ),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xF2081428), Color(0xD9081428), Color(0x33081428)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _txt(context.strings.topup4d96fe71, size: 13, color: _gold, bold: true),
          _txt(context.strings.topup6a50382f, size: 25, bold: true),
          _txt(
            context.strings.topup78775dc3,
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(height: 11),
          _txt(
            context.strings.topup1eb95ad4,
            size: 11,
            color: _gold,
          ),
        ],
      ),
    ),
  );
  Widget _offerCard(Map<String, dynamic> offer) {
    final paid = (offer['paid_amount'] as num).toDouble(),
        bonus = (offer['bonus_amount'] as num).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _txt(context.strings.topupd2016477, size: 12, color: _gold, bold: true),
            const SizedBox(height: 5),
            _txt(offer['title'].toString(), size: 20, bold: true),
            _txt(
              'ادفع ${paid.toStringAsFixed(0)} جنيه • مكافأة ${bonus.toStringAsFixed(0)} جنيه • الإجمالي ${(paid + bonus).toStringAsFixed(0)} جنيه',
              color: _gold,
              size: 12,
            ),
            if (offer['ends_at'] != null)
              _txt(
                'العرض متاح حتى ${offer['ends_at'].toString().split('T').first}',
                color: _muted,
                size: 11,
              ),
            const SizedBox(height: 12),
            _button(context.strings.topup292f3529, () => _selectOffer(offer)),
          ],
        ),
        glow: true,
      ),
    );
  }

  Widget _offersStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _txt(context.strings.topupf5e67eb7, size: 21, bold: true),
      const SizedBox(height: 8),
      _txt(
        context.strings.topupd27033c9,
        color: _muted,
        size: 12,
      ),
      const SizedBox(height: 16),
      ..._offers.map(_offerCard),
      _button(
        context.strings.topupc2ef5692,
        () => _selectOffer(null),
        secondary: true,
      ),
      if (_methods.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _txt(
            context.strings.topupe0607388,
            color: _gold,
            size: 12,
          ),
        ),
    ],
  );
  Widget _amountStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _txt(context.strings.topup1768325b, size: 20, bold: true),
      const SizedBox(height: 14),
      if (_offer != null)
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _txt(context.strings.topupb7231cbd, size: 12, color: _gold),
              _txt(_offer!['title'].toString(), size: 18, bold: true),
              _txt(
                context.strings.topup1223dbd6,
                size: 11,
                color: _muted,
              ),
            ],
          ),
          glow: true,
        ),
      const SizedBox(height: 12),
      if (_offer == null)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [50, 100, 200, 500, 1000]
              .map(
                (n) => ChoiceChip(
                  label: Text(
                    '$n جنيه',
                    style: TextStyle(
                      color: _paid == n ? _navy : Colors.white,
                      
                    ),
                  ),
                  selected: _paid == n,
                  selectedColor: _gold,
                  backgroundColor: _panel,
                  onSelected: (_) {
                    setState(() => _amount.text = '$n');
                  },
                ),
              )
              .toList(),
        ),
      const SizedBox(height: 12),
      _field(
        _amount,
        context.strings.topupac3d43ad,
        type: const TextInputType.numberWithOptions(decimal: true),
        readOnly: _offer != null,
      ),
      _card(
        Column(
          children: [
            _line(context.strings.topup29bc32d5, '${_paid.toStringAsFixed(2)} جنيه'),
            _line(context.strings.topup346be366, '+ ${_bonus.toStringAsFixed(2)} جنيه'),
            const Divider(color: Color(0xFF405373)),
            _line(
              context.strings.topup663ba8dc,
              '${(_paid + _bonus).toStringAsFixed(2)} جنيه',
              important: true,
            ),
          ],
        ),
        glow: true,
      ),
      const SizedBox(height: 20),
      _txt(context.strings.topup43f4b708, size: 20, bold: true),
      const SizedBox(height: 12),
      if (_methods.isEmpty)
        _txt(
          context.strings.topupb14b98c9,
          color: _gold,
          size: 12,
        ),
      ..._methods.map(
        (method) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _card(
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              activeColor: _gold,
              secondary:
                  (method['image_url'] ?? '').toString().startsWith('https://')
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Image.network(
                        method['image_url'].toString(),
                        height: 40,
                        width: 40,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>  Icon(
                          Icons.account_balance_wallet_rounded,
                          color: _gold,
                        ),
                      ),
                    )
                  :  Icon(
                      Icons.account_balance_wallet_rounded,
                      color: _gold,
                    ),
              title: _txt(method['name'].toString(), bold: true),
              subtitle: _txt(
                context.strings.topupd85df9ec,
                size: 11,
                color: _muted,
              ),
              value: method['id'].toString(),
              groupValue: _method?['id']?.toString(),
              onChanged: (_) {
                setState(() => _method = method);
              },
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      _button(
        context.strings.topup1d09cf88,
        _methods.isEmpty ? null : _continueToTransfer,
      ),
    ],
  );
  Widget _line(String label, String value, {bool important = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: _txt(
            label,
            size: important ? 12 : 11,
            color: important ? _gold : _muted,
            bold: important,
          ),
        ),
        _txt(
          value,
          size: important ? 15 : 13,
          color: important ? _gold : Colors.white,
          bold: true,
        ),
      ],
    ),
  );
  Widget _transferStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _txt(context.strings.topup114df589, size: 20, bold: true),
      const SizedBox(height: 12),
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _txt(
              'وسيلة الدفع: ${_method?['name'] ?? ''}',
              size: 16,
              bold: true,
            ),
            _txt(
              'حوّل ${_paid.toStringAsFixed(2)} جنيه إلى الرقم أو الحساب التالي:',
              color: _muted,
              size: 12,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    '${_method?['transfer_number'] ?? ''}',
                    style:  TextStyle(
                      
                      fontSize: 22,
                      color: _gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.strings.topup08e262ba,
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(
                        text: '${_method?['transfer_number'] ?? ''}',
                      ),
                    );
                    _snack(context.strings.topupa914d518);
                  },
                  icon:  Icon(Icons.copy_rounded, color: _gold),
                ),
              ],
            ),
            const Divider(color: Color(0xFF405373)),
            _txt(context.strings.topup58890d41, color: _gold, bold: true),
            _txt(
              (_method?['instructions'] ??
                      context.strings.topup9f05f6f1)
                  .toString(),
              size: 12,
              color: Colors.white,
            ),
          ],
        ),
        glow: true,
      ),
      const SizedBox(height: 16),
      _field(
        _sender,
        context.strings.topup9296abef,
        type: TextInputType.phone,
        hint: context.strings.topup9895aa5d,
      ),
      _field(
        _operation,
        context.strings.topup18f7532a,
        hint: context.strings.topupceedefc4,
      ),
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _txt(context.strings.topup218b7624, color: _gold, bold: true),
            const SizedBox(height: 5),
            _txt(
              context.strings.topupd6c8e2d2,
              size: 12,
              color: _muted,
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _button(
        _sending ? context.strings.topup838c527e : context.strings.topup2bc6aebc,
        _sending ? null : _submit,
      ),
    ],
  );
  String _status(String? status) => switch (status) {
    'approved' => context.strings.topup4a807954,
    'rejected' => context.strings.topup5d969a71,
    'pending' => context.strings.topup8aac5fac,
    _ => context.strings.topupd44d4435,
  };
  Color _statusColor(String? s) => s == 'approved'
      ? const Color(0xFF72E6AB)
      : s == 'rejected'
      ? const Color(0xFFFF9393)
      : _gold;
  Widget _statusStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _txt(context.strings.topup90aa4d47, size: 20, bold: true),
      const SizedBox(height: 14),
      if (_current != null)
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _current!['status'] == 'approved'
                    ? Icons.check_circle
                    : _current!['status'] == 'rejected'
                    ? Icons.cancel
                    : Icons.hourglass_top,
                color: _statusColor(_current!['status']?.toString()),
                size: 44,
              ),
              _txt(
                _status(_current!['status']?.toString()),
                size: 21,
                color: _statusColor(_current!['status']?.toString()),
                bold: true,
              ),
              _txt(
                _current!['status'] == 'pending'
                    ? context.strings.topup007c4718
                    : _current!['status'] == 'approved'
                    ? context.strings.topupc769438a
                    : context.strings.topupca711e4a,
                size: 12,
                color: _muted,
              ),
              const Divider(color: Color(0xFF405373)),
              _line(context.strings.topupd84c4984, _current!['reference'].toString()),
              _line(context.strings.topup558ab445, '${_current!['paid_amount']} جنيه'),
              _line(context.strings.topup36bba20f, '${_current!['bonus_amount']} جنيه'),
              _line(context.strings.topupf3471840, _current!['method_name'].toString()),
              _line(
                context.strings.topup82e926cb,
                _current!['created_at']
                    .toString()
                    .replaceFirst('T', ' ')
                    .split('.')
                    .first,
              ),
              if (_current!['review_note'] != null)
                _txt(
                  'ملاحظات المراجع: ${_current!['review_note']}',
                  color: _muted,
                  size: 12,
                ),
            ],
          ),
        ),
      const SizedBox(height: 14),
      _button(context.strings.topupc875c278, () => _refreshRequests(), secondary: true),
      const SizedBox(height: 10),
      _button(context.strings.topup066febb5, () {
        setState(() => _step = 4);
      }),
    ],
  );
  Widget _history() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _txt(context.strings.topupe5f00560, size: 20, bold: true),
      const SizedBox(height: 14),
      if (_requests.isEmpty)
        _txt(context.strings.topup102df0aa, color: _muted),
      ..._requests.map(
        (r) => Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: InkWell(
            onTap: () {
              setState(() {
                _current = r;
                _step = 3;
              });
            },
            child: _card(
              Row(
                children: [
                  Icon(
                    Icons.receipt_long,
                    color: _statusColor(r['status']?.toString()),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _txt(r['reference'].toString(), bold: true),
                        _txt(
                          '${r['paid_amount']} جنيه + ${r['bonus_amount']} مكافأة',
                          size: 11,
                          color: _muted,
                        ),
                      ],
                    ),
                  ),
                  _txt(
                    _status(r['status']?.toString()),
                    color: _statusColor(r['status']?.toString()),
                    size: 11,
                    bold: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: Directionality.of(context),
    child: Scaffold(
      backgroundColor: _navy,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title:  Text(
          context.strings.topup152d5282,
          style: TextStyle( fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: context.strings.topup45513074,
            onPressed: () {
              _refreshRequests();
              setState(() => _step = 4);
            },
            icon: const Icon(Icons.history_rounded),
          ),
        ],
      ),
      body: _loading
          ?  Center(child: CircularProgressIndicator(color: _gold))
          : RefreshIndicator(
              onRefresh: _load,
              color: _gold,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _hero(),
                  const SizedBox(height: 18),
                  if (_error != null)
                    _card(
                      _txt(_error!, size: 12, color: const Color(0xFFFF9393)),
                    ),
                  if (_error == null) ...[
                    if (_step < 4)
                      Row(
                        children: [
                          for (var i = 0; i < 4; i++)
                            Expanded(
                              child: Container(
                                height: 4,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: i <= _step ? _gold : _panel,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 17),
                    if (_step == 0) _offersStep(),
                    if (_step == 1) _amountStep(),
                    if (_step == 2) _transferStep(),
                    if (_step == 3) _statusStep(),
                    if (_step == 4) _history(),
                    if (_step > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 17),
                        child: _button(
                          _step == 4 || _step == 3 ? context.strings.topupf3b40143 : context.strings.topupcb822418,
                          () => setState(
                            () => _step = (_step == 4 || _step == 3)
                                ? 0
                                : _step - 1,
                          ),
                          secondary: true,
                        ),
                      ),
                  ],
                  const SizedBox(height: 90),
                ],
              ),
            ),
    ),
  );
}
