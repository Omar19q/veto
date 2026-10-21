import '../../l10n/strings.dart';
import '../../services/captain_market_backend.dart';
import '../../services/map_provider_policy.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/app_sound_service.dart';
import '../../services/market_support_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../vito_market/widgets/market_order_chat_sheet.dart';

class CaptainMarketOrderScreen extends StatefulWidget {
  final CaptainMarketBackend? backend;
  const CaptainMarketOrderScreen({
    super.key,
    required this.orderId,
    this.backend,
  });

  final String orderId;

  @override
  State<CaptainMarketOrderScreen> createState() =>
      _CaptainMarketOrderScreenState();
}

class _CaptainMarketOrderScreenState extends State<CaptainMarketOrderScreen> {
  Map<String, dynamic>? _context;
  bool _loading = true;
  bool _busy = false;
  String Function()? _error;
  Timer? _timer;
  late final CaptainMarketBackend _backend =
      widget.backend ?? CaptainMarketBackend();
  List<RealtimeChannel> _channels = [];
  StreamSubscription<String?>? _auth;
  String? _uid;
  int _readRevision = 0;
  BuildContext? _confirmationContext;
  bool get _owns => mounted && _uid != null && _backend.accountId == _uid;

  Map<String, dynamic> get _order => _map(_context?['order']);
  Map<String, dynamic> get _store => _map(_context?['store']);
  Map<String, dynamic> get _customer => _map(_context?['customer']);
  List<Map<String, dynamic>> get _items => _list(_context?['items']);
  String get _status => _order['order_status']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _uid = _backend.accountId;
    _load();
    if (_uid != null)
      _channels = _backend.subscribe(widget.orderId, () {
        if (_owns) _load(silent: true);
      });
    _auth = _backend.accountChanges.listen((uid) {
      if (!mounted || uid == _uid) return;
      _readRevision++;
      _timer?.cancel();
      for (final channel in _channels) {
        channel.unsubscribe();
      }
      _channels = [];
      final modal = _confirmationContext;
      if (modal != null &&
          modal.mounted &&
          ModalRoute.of(modal)?.isCurrent == true)
        Navigator.of(modal).pop(false);
      setState(() {
        _context = null;
        _loading = false;
        _busy = false;
        _error = () => context.strings.captainMarketLoadFailed;
      });
    });
    _timer = Timer.periodic(Duration(seconds: 10), (_) {
      if (_owns) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _auth?.cancel();
    for (final channel in _channels) {
      channel.unsubscribe();
    }
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!_owns) {
      if (mounted)
        setState(() {
          _loading = false;
          _context = null;
          _error = () => context.strings.captainMarketLoadFailed;
        });
      return;
    }
    final revision = ++_readRevision;
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final value = await _backend.getContext(widget.orderId);
      if (!_owns || revision != _readRevision) return;
      setState(() {
        _context = value;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!_owns || revision != _readRevision) return;
      setState(() {
        _loading = false;
        _context = null;
        _error = () => context.strings.captainMarketLoadFailed;
      });
    }
  }

  Future<void> _moveTo(String next) async {
    if (_busy || !_owns) return;
    setState(() => _busy = true);
    try {
      await _backend.transition(widget.orderId, next);
      if (!mounted || !_owns) return;
      await AppSoundService.instance.playSuccess();
      await _load(silent: true);
      if (!mounted || !_owns) return;
      final message = switch (next) {
        'picked_up' => context.strings.captainMarketd7768428,
        'on_the_way' => context.strings.captainMarket14dc5df9,
        'delivered' => context.strings.captainMarket53dcbe87,
        _ => context.strings.captainMarket6eae6542,
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      if (next == 'delivered') context.go('/captain-dashboard');
    } catch (error) {
      if (_owns) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.captainMarket6de2e125)),
        );
      }
    } finally {
      if (_owns) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: Directionality.of(context),
    child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          context.strings.captainMarketJobTitle(_orderLabel),
          style: TextStyle( fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: context.strings.captainMarketd8fd5c0d,
            onPressed: _openSupport,
            icon: Icon(Icons.support_agent_rounded, color: AppTheme.whatsapp),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : _error != null
          ? _errorView()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.all(14),
                children: [
                  _hero(),
                  SizedBox(height: 12),
                  _invoiceCard(),
                  SizedBox(height: 12),
                  _mapCard(),
                  SizedBox(height: 12),
                  _destinationCard(),
                  if (_customer.isNotEmpty) ...[
                    SizedBox(height: 12),
                    _customerCard(),
                  ],
                  SizedBox(height: 12),
                  _itemsCard(),
                  if (_status == 'captain_assigned' ||
                      _status == 'ready_for_pickup') ...[
                    SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _confirmCancel,
                      icon: Icon(Icons.cancel_outlined),
                      label: Text(context.strings.captainMarkete8449fb2),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorLight,
                      ),
                    ),
                  ],
                  SizedBox(height: 18),
                  _actionButton(),
                  SizedBox(height: 32),
                ],
              ),
            ),
    ),
  );

  Widget _errorView() => Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: AppTheme.errorLight, size: 48),
          SizedBox(height: 12),
          Text(_error!(), textAlign: TextAlign.center),
          SizedBox(height: 12),
          ElevatedButton(
            onPressed: _load,
            child: Text(context.strings.captainMarket14d5786f),
          ),
        ],
      ),
    ),
  );

  Widget _hero() => Container(
    padding: EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [Color(0xFF2B2307), Color(0xFF12182A)]),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppTheme.gold.withValues(alpha: .5)),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 27,
          backgroundColor: AppTheme.gold,
          child: Icon(Icons.delivery_dining, color: AppTheme.primary, size: 31),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _statusText(_status),
                style: TextStyle(
                  
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                _status == 'captain_assigned' || _status == 'ready_for_pickup'
                    ? context.strings.captainMarketd5d536cd
                    : context.strings.captainMarketd8f14d9b,
                style: TextStyle(
                  
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _mapCard() {
    final storePoint = _point(_store['latitude'], _store['longitude']);
    final customerPoint = _point(
      _order['delivery_latitude'],
      _order['delivery_longitude'],
    );
    final target = _customer.isEmpty ? storePoint : customerPoint ?? storePoint;
    if (target == null) return SizedBox.shrink();
    final markers = <Marker>[
      if (storePoint != null) _marker(storePoint, Icons.store, Colors.orange),
      if (_customer.isNotEmpty && customerPoint != null)
        _marker(customerPoint, Icons.home, Colors.green),
    ];
    return Container(
      height: 245,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: FlutterMap(
        options: MapOptions(initialCenter: target, initialZoom: 15),
        children: [
          TileLayer(
            urlTemplate: MapProviderPolicy.legacyRasterTemplate,
            userAgentPackageName: 'com.vetosanya.app',
          ),
          MarkerLayer(markers: markers),
          RichAttributionWidget(
            attributions: [TextSourceAttribution('OpenStreetMap contributors')],
          ),
        ],
      ),
    );
  }

  Widget _destinationCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _customer.isEmpty
              ? context.strings.captainMarketdaf5d487
              : context.strings.captainMarket97432797,
          style: _titleStyle,
        ),
        SizedBox(height: 6),
        Text(
          _store['name']?.toString() ?? context.strings.captainMarket4c5cf17e,
          style: _bodyStrong,
        ),
        Text(_store['address']?.toString() ?? '', style: _secondaryStyle),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _call(_store['phone']),
                icon: Icon(Icons.call),
                label: Text(context.strings.captainMarketd33daf8e),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () =>
                    _navigate(_store['latitude'], _store['longitude']),
                icon: Icon(Icons.navigation_rounded),
                label: Text(context.strings.captainMarketc76b2601),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _customerCard() => _card(
    gold: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.strings.captainMarket8cc3de69, style: _titleStyle),
        SizedBox(height: 6),
        Text(
          _customer['full_name']?.toString() ??
              context.strings.captainMarketa042411e,
          style: _bodyStrong,
        ),
        Text(
          _order['delivery_address']?.toString() ?? '',
          style: _secondaryStyle,
        ),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _call(_customer['phone']),
                icon: Icon(Icons.call),
                label: Text(context.strings.captainMarket606af07c),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openChat,
                icon: Icon(Icons.chat_bubble_outline),
                label: Text(context.strings.captainMarket3150a947),
              ),
            ),
            SizedBox(width: 8),
            IconButton.filled(
              onPressed: () => _navigate(
                _order['delivery_latitude'],
                _order['delivery_longitude'],
              ),
              icon: Icon(Icons.navigation_rounded),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _itemsCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.strings.captainMarket467e6137, style: _titleStyle),
        SizedBox(height: 8),
        ..._items.map(
          (item) => Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '${item['quantity'] ?? 1}×',
                    style: TextStyle(
                      color: AppTheme.gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    item['product_name']?.toString() ??
                        context.strings.captainMarketf8720c74,
                    style: _secondaryStyle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _actionButton() {
    final (label, icon, action) = switch (_status) {
      'captain_assigned' || 'ready_for_pickup' => (
        context.strings.captainMarketc2b2b3af,
        Icons.inventory_2_rounded,
        () => _moveTo('picked_up'),
      ),
      'picked_up' => (
        context.strings.captainMarket58ed2a34,
        Icons.route_rounded,
        () => _moveTo('on_the_way'),
      ),
      'on_the_way' => (
        context.strings.captainMarket25cb347d,
        Icons.check_circle_rounded,
        _confirmDelivery,
      ),
      _ => (
        context.strings.captainMarket310ca3cd,
        Icons.done_all_rounded,
        null,
      ),
    };
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _busy ? null : action,
        icon: _busy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.gold,
          foregroundColor: AppTheme.primary,
          textStyle: TextStyle(
            
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _invoiceCard() {
    final fee = _number(_order['delivery_fee']);
    final earning = _number(_order['captain_earning']);
    final commission = fee == null || earning == null
        ? null
        : (fee - earning).clamp(0, double.infinity);
    final share = _number(_order['captain_delivery_share_percent']);
    final percent = share == null ? null : 100 - share;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: AppTheme.gold),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.strings.captainMarket973ed905,
                  style: _titleStyle,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _invoiceLine(
            context.strings.captainMarket95b5d1f4,
            _order['cash_amount'],
            prominent: true,
          ),
          if (_number(_order['cash_amount']) == 0)
            Text(context.strings.captainMarketdf06bb32, style: _secondaryStyle),
          _invoiceLine(
            context.strings.captainMarket75d406d4,
            _order['store_cash_due'],
          ),
          _invoiceLine(
            context.strings.captainMarket02f77b39,
            _order['wallet_amount'],
          ),
          if ((_number(_order['market_promo_discount']) ?? 0) > 0)
            _invoiceLine(
              context.strings.captainMarket25d3f39d,
              _order['market_promo_discount'],
            ),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          _invoiceLine(context.strings.captainMarketaa63ea8f, fee),
          _invoiceLine(
            context.strings.captainMarketCommission(
              percent == null ? '—' : percent.toStringAsFixed(1),
            ),
            commission,
          ),
          _invoiceLine(
            context.strings.captainMarket78163c16,
            earning,
            prominent: true,
          ),
          SizedBox(height: 8),
          Text(context.strings.captainMarket15c48cd1, style: _secondaryStyle),
        ],
      ),
    );
  }

  Widget _invoiceLine(String label, dynamic amount, {bool prominent = false}) =>
      Padding(
        padding: EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: prominent ? _bodyStrong : _secondaryStyle,
              ),
            ),
            SizedBox(width: 8),
            Text(
              _number(amount) == null
                  ? context.strings.historyAmountUnavailable
                  : context.strings.moneyValue(_money(amount)),
              style: TextStyle(
                
                color: prominent
                    ? AppTheme.gold
                    : Theme.of(context).colorScheme.onSurface,
                fontSize: prominent ? 19 : 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );

  Future<void> _confirmDelivery() async {
    if (_busy || !_owns) return;
    setState(() => _busy = true);
    try {
      await _load(silent: true);
      if (!mounted || !_owns || _error != null || _status != 'on_the_way')
        return;
      final cash = _number(_order['cash_amount']);
      if (cash == null || !cash.isFinite || cash < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.captainMarket456e5cc8)),
        );
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          _confirmationContext = ctx;
          return AlertDialog(
            title: Text(context.strings.captainMarket981e9393),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cash == 0
                        ? context.strings.captainMarketcce08954
                        : context.strings.captainMarketConfirmCash(
                            cash.toStringAsFixed(2),
                          ),
                  ),
                  SizedBox(height: 12),
                  _invoiceCard(),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(context.strings.captainMarketcb822418),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  cash == 0
                      ? context.strings.captainMarket25deb8cf
                      : context.strings.captainMarket8b4ef63a,
                ),
              ),
            ],
          );
        },
      );
      if (confirmed == true && _owns) {
        setState(() => _busy = false);
        await _moveTo('delivered');
      }
    } finally {
      if (_owns) setState(() => _busy = false);
    }
  }

  Widget _card({required Widget child, bool gold = false}) => Container(
    padding: EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: gold
            ? AppTheme.gold.withValues(alpha: .4)
            : Theme.of(context).colorScheme.outlineVariant,
      ),
    ),
    child: child,
  );

  Future<void> _call(dynamic raw) async {
    final phone = raw?.toString() ?? '';
    if (phone.isNotEmpty) await launchUrl(Uri(scheme: 'tel', path: phone));
  }

  Future<void> _navigate(dynamic lat, dynamic lon) async {
    final point = _point(lat, lon);
    if (point == null) return;
    await launchUrl(
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${point.latitude},${point.longitude}',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _openChat() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => MarketOrderChatSheet(
        orderId: widget.orderId,
        storeOrderNumber: _order['store_order_number'],
        actorLabel: 'كابتن',
      ),
    );
  }

  Future<void> _openSupport() async {
    final opened = await MarketSupportService.openWhatsApp(
      orderId: widget.orderId,
      storeOrderNumber: _order['store_order_number'],
      actorLabel: 'كابتن',
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.captainMarketae881876)),
      );
    }
  }

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        _confirmationContext = context;
        return AlertDialog(
          title: Text(context.strings.captainMarket3b88cefe),
          content: Text(context.strings.captainMarket0ea97780),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.strings.captainMarketcb822418),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.strings.captainMarket2e57d50e),
            ),
          ],
        );
      },
    );
    if (confirmed != true || _busy || !_owns) return;
    setState(() => _busy = true);
    try {
      await _backend.cancel(widget.orderId);
      if (!mounted || !_owns) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.captainMarket206a9708)),
      );
      context.go('/captain-dashboard');
    } catch (_) {
      if (_owns) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.captainMarketff44f761)),
        );
      }
    } finally {
      if (_owns) setState(() => _busy = false);
    }
  }

  Marker _marker(LatLng point, IconData icon, Color color) => Marker(
    point: point,
    width: 46,
    height: 46,
    child: Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(icon, color: color),
    ),
  );

  LatLng? _point(dynamic a, dynamic b) {
    final lat = (a is num ? a.toDouble() : null) ?? double.tryParse('$a');
    final lon = (b is num ? b.toDouble() : null) ?? double.tryParse('$b');
    return lat == null ||
            lon == null ||
            !lat.isFinite ||
            !lon.isFinite ||
            lat.abs() > 90 ||
            lon.abs() > 180
        ? null
        : LatLng(lat, lon);
  }

  double? _number(dynamic value) {
    final n = value is num ? value.toDouble() : double.tryParse('$value');
    return n != null && n.isFinite ? n : null;
  }

  String _money(dynamic value) => (_number(value) ?? 0).toStringAsFixed(2);
  String get _orderLabel {
    final value =
        (_order['store_order_number'] as num?)?.toInt() ??
        int.tryParse('${_order['store_order_number']}');
    if (value != null)
      return context.strings.marketTrackingCounter(
        value.toString().padLeft(2, '0'),
      );
    final end = widget.orderId.length < 8 ? widget.orderId.length : 8;
    return '#${widget.orderId.substring(0, end).toUpperCase()}';
  }

  String _statusText(String value) =>
      {
        'captain_assigned': context.strings.captainMarket3ba053db,
        'ready_for_pickup': context.strings.captainMarket0b98ede2,
        'picked_up': context.strings.captainMarket0bbfeacc,
        'on_the_way': context.strings.captainMarketaf0ea2c8,
        'delivered': context.strings.captainMarketf711d592,
      }[value] ??
      context.strings.captainMarket97b675e6;

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : {};
  List<Map<String, dynamic>> _list(dynamic value) => value is List
      ? value
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList()
      : [];

  static const _titleStyle = TextStyle(
    
    color: AppTheme.gold,
    fontWeight: FontWeight.w800,
  );
  TextStyle get _bodyStrong => TextStyle(
    
    color: Theme.of(context).colorScheme.onSurface,
    fontWeight: FontWeight.w800,
  );
  TextStyle get _secondaryStyle => TextStyle(
    
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}

class _CaptainMarketChat extends StatefulWidget {
  const _CaptainMarketChat({required this.orderId});
  final String orderId;

  @override
  State<_CaptainMarketChat> createState() => _CaptainMarketChatState();
}

class _CaptainMarketChatState extends State<_CaptainMarketChat> {
  final _input = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  RealtimeChannel? _channel;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = SupabaseService.instance.subscribeToMarketMessages(
      widget.orderId,
      () async {
        await AppSoundService.instance.playChat();
        _load();
      },
    );
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final value = await SupabaseService.instance.getMarketMessages(
      widget.orderId,
    );
    if (mounted) setState(() => _messages = value);
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await SupabaseService.instance.sendMarketMessage(widget.orderId, text);
      _input.clear();
      await _load();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: Directionality.of(context),
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                context.strings.captainMarket67cf4a3e,
                style: _CaptainMarketOrderScreenState._titleStyle,
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(12),
                itemCount: _messages.length,
                itemBuilder: (_, index) {
                  final message = _messages[index];
                  final mine =
                      message['sender_user_id'] ==
                      SupabaseService.instance.currentUser?.id;
                  return Align(
                    alignment: mine
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: EdgeInsets.only(bottom: 7),
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: mine
                            ? AppTheme.gold
                            : Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        message['message_text']?.toString() ?? '',
                        style: TextStyle(
                          
                          color: mine
                              ? AppTheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      maxLength: 1000,
                      decoration: InputDecoration(
                        hintText: context.strings.captainMarketcb7741fc,
                        counterText: '',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: Icon(Icons.send, color: AppTheme.gold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
