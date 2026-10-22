import '../../l10n/strings.dart';
import '../../services/map_provider_policy.dart';
import '../../services/market_tracking_backend.dart';
import 'package:vetosanya/widgets/captain_photo_v16.dart';
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
import 'widgets/market_order_chat_sheet.dart';

class VitoMarketOrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final MarketTrackingBackend? backend;
  const VitoMarketOrderTrackingScreen({
    super.key,
    required this.orderId,
    this.backend,
  });
  @override
  State<VitoMarketOrderTrackingScreen> createState() =>
      _VitoMarketOrderTrackingScreenState();
}

class _VitoMarketOrderTrackingScreenState
    extends State<VitoMarketOrderTrackingScreen> {
  Map<String, dynamic>? data;
  bool loading = true;
  late final MarketTrackingBackend _backend =
      widget.backend ?? MarketTrackingBackend();
  List<RealtimeChannel> _channels = [];
  StreamSubscription<String?>? _auth;
  String? _uid;
  int _readRevision = 0;
  bool failed = false;
  bool get _owns => mounted && _uid != null && _backend.accountId == _uid;
  Timer? timer;
  Map<String, dynamic> get order => _map(data?['order']);
  Map<String, dynamic> get store => _map(data?['store']);
  Map<String, dynamic> get captain => _map(data?['captain']);
  List<Map<String, dynamic>> get items => _list(data?['items']);
  @override
  void initState() {
    super.initState();
    _uid = _backend.accountId;
    _load();
    if (_uid != null)
      _channels = _backend.subscribe(widget.orderId, () {
        if (_owns) _load();
      });
    _auth = _backend.accountChanges.listen((uid) {
      if (!mounted || uid == _uid) return;
      _readRevision++;
      timer?.cancel();
      for (final channel in _channels) {
        channel.unsubscribe();
      }
      _channels = [];
      setState(() {
        data = null;
        loading = false;
        failed = true;
      });
    });
    timer = Timer.periodic(Duration(seconds: 12), (_) {
      if (_owns) _load();
    });
  }

  @override
  void dispose() {
    _auth?.cancel();
    for (final channel in _channels) {
      channel.unsubscribe();
    }
    timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_owns) {
      if (mounted)
        setState(() {
          data = null;
          loading = false;
          failed = true;
        });
      return;
    }
    final revision = ++_readRevision;
    try {
      final value = await _backend.getContext(widget.orderId);
      if (!_owns || revision != _readRevision) return;
      setState(() {
        data = value;
        loading = false;
        failed = false;
      });
    } catch (_) {
      if (!_owns || revision != _readRevision) return;
      setState(() {
        data = null;
        loading = false;
        failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Directionality(
      textDirection: Directionality.of(context),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          context.strings.marketTracking2335b680,
          style: TextStyle( fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          onPressed: () => context.go('/home-screen'),
          icon: Icon(Icons.arrow_back_ios_new_rounded),
        ),
        actions: [
          IconButton(
            tooltip: context.strings.marketTrackingd8fd5c0d,
            onPressed: data == null ? null : _openSupport,
            icon: Icon(Icons.support_agent_rounded, color: AppTheme.whatsapp),
          ),
        ],
      ),
      body: loading
          ? Center(
              child: CircularProgressIndicator(
                color: isDark ? AppTheme.gold : Theme.of(context).colorScheme.primary,
              ),
            )
          : data == null
          ? Center(child: Text(context.strings.marketTracking7a653e5a))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.all(14),
                children: [
                  _hero(),
                  SizedBox(height: 12),
                  _progress(),
                  if (captain.isNotEmpty) ...[
                    SizedBox(height: 12),
                    _captainCard(),
                    SizedBox(height: 12),
                    _mapCard(),
                  ],
                  SizedBox(height: 12),
                  _orderCard(),
                  SizedBox(height: 12),
                  _storeCard(),
                  SizedBox(height: 30),
                ],
              ),
            ),
    ),
  );
  }

  Widget _hero() {
    final s = order['order_status']?.toString() ?? 'pending';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryAccent = isDark ? AppTheme.gold : Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF25200B), Color(0xFF12182A)]
              : [
                  Theme.of(context).colorScheme.surfaceContainerHighest,
                  Theme.of(context).colorScheme.surface,
                ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppTheme.gold.withValues(alpha: .45) : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: primaryAccent,
              shape: BoxShape.circle,
            ),
            child: Icon(_icon(s), color: isDark ? AppTheme.primary : Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _status(s),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _hint(s),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _orderLabel,
            style: TextStyle(color: primaryAccent, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _progress() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progressDoneColor = isDark ? AppTheme.gold : const Color(0xFF10B981);

    final flow = [
      ('pending', context.strings.marketTrackingd51f9d8d),
      ('confirmed', context.strings.marketTrackingf5fde9cb),
      ('preparing', context.strings.marketTrackingbf6cf358),
      ('captain_assigned', context.strings.marketTracking9643e947),
      ('picked_up', context.strings.marketTracking69ca2e6b),
      ('on_the_way', context.strings.marketTracking4452951b),
      ('delivered', context.strings.marketTracking3ef541b9),
    ];
    final current = _rank(order['order_status']?.toString() ?? 'pending');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: _decoration(),
      child: Row(
        children: flow.map((x) {
          final done = current >= _rank(x.$1);
          return Expanded(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: done
                      ? progressDoneColor
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Icon(
                    done ? Icons.check : Icons.circle_outlined,
                    size: 14,
                    color: done
                        ? (isDark ? AppTheme.primary : Colors.white)
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  x.$2,
                  style: TextStyle(
                    fontSize: 9,
                    color: done
                        ? progressDoneColor
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _captainCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(14),
      decoration: _decoration(gold: true),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: colorScheme.surfaceContainerHighest,
                backgroundImage:
                    (captain['profile_photo']?.toString() ?? '').isNotEmpty
                    ? captainPhotoV16(captain['profile_photo'].toString())
                    : null,
                child: (captain['profile_photo']?.toString() ?? '').isEmpty
                    ? Icon(
                        Icons.delivery_dining,
                        color: isDark ? AppTheme.gold : colorScheme.primary,
                      )
                    : null,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.strings.marketTracking3b315330,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      captain['full_name']?.toString() ??
                          context.strings.marketTrackinga6b2ea4b,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      context.strings.marketTrackingPhone(
                        '${captain['phone'] ?? '-'}',
                      ),
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      context.strings.marketTrackingVehicle(
                        '${captain['vehicle_brand'] ?? ''} ${captain['vehicle_model'] ?? ''}',
                        '${captain['vehicle_color'] ?? ''}',
                        '${captain['vehicle_plate'] ?? '-'}',
                      ),
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                    if (_eta() != null)
                      Text(
                        _eta()!,
                        style: TextStyle(
                          color: isDark ? AppTheme.gold : colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _call,
                  icon: Icon(Icons.call),
                  label: Text(context.strings.marketTracking606af07c),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _chatOpen ? _openChat : null,
                  icon: Icon(Icons.chat_bubble),
                  label: Text(context.strings.marketTracking3150a947),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppTheme.gold : colorScheme.primary,
                    foregroundColor: isDark ? AppTheme.primary : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mapCard() {
    final markers = <Marker>[];
    final s = _point(store['latitude'], store['longitude']),
        c = _point(captain['latitude'], captain['longitude']),
        d = _point(order['delivery_latitude'], order['delivery_longitude']);
    if (s != null) markers.add(_marker(s, Icons.store, Colors.orange));
    if (c != null)
      markers.add(_marker(c, Icons.delivery_dining, AppTheme.gold));
    if (d != null) markers.add(_marker(d, Icons.home, Colors.green));
    if (markers.isEmpty) return SizedBox.shrink();
    return Container(
      height: 240,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: FlutterMap(
        options: MapOptions(initialCenter: c ?? s ?? d!, initialZoom: 14),
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

  Widget _orderCard() => Container(
    padding: EdgeInsets.all(15),
    decoration: _decoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.strings.marketTrackinge9ffcc97,
          style: TextStyle(
            
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 8),
        ...items.map(
          (i) =>
              _line('${i['quantity']} × ${i['product_name']}', i['subtotal']),
        ),
        Divider(color: Theme.of(context).colorScheme.outlineVariant),
        _line(context.strings.marketTracking771e11be, order['subtotal']),
        _line(context.strings.marketTracking78415ee3, order['delivery_fee']),
        _line(context.strings.marketTracking48c3380c, order['wallet_amount']),
        _line(context.strings.marketTrackingdbf303cb, order['cash_amount']),
        _line(
          context.strings.marketTrackingbaed6e99,
          order['total_amount'],
          strong: true,
        ),
      ],
    ),
  );
  Widget _storeCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(15),
      decoration: _decoration(),
      child: Row(
        children: [
          Icon(
            Icons.storefront,
            color: isDark ? AppTheme.gold : Theme.of(context).colorScheme.primary,
            size: 32,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store['name']?.toString() ??
                      context.strings.marketTracking4c5cf17e,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  store['address']?.toString() ?? '',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, dynamic value, {bool strong = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: strong
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: strong ? FontWeight.w800 : null,
              ),
            ),
          ),
          Text(
            _amountLabel(value),
            style: TextStyle(
              color: strong
                  ? (isDark ? AppTheme.gold : const Color(0xFF10B981))
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
  bool get _chatOpen => {
    'captain_assigned',
    'ready_for_pickup',
    'picked_up',
    'on_the_way',
    'delivered',
  }.contains(order['order_status']);
  Future<void> _call() async {
    final p = captain['phone']?.toString() ?? '';
    if (p.isNotEmpty) await launchUrl(Uri(scheme: 'tel', path: p));
  }

  Future<void> _openChat() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => MarketOrderChatSheet(
        orderId: widget.orderId,
        storeOrderNumber: order['store_order_number'],
        actorLabel: 'عميل',
      ),
    );
  }

  Future<void> _openSupport() async {
    final opened = await MarketSupportService.openWhatsApp(
      orderId: widget.orderId,
      storeOrderNumber: order['store_order_number'],
      actorLabel: 'عميل',
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.marketTrackingae881876)),
      );
    }
  }

  String get _orderLabel {
    final value =
        (order['store_order_number'] as num?)?.toInt() ??
        int.tryParse('${order['store_order_number']}');
    if (value != null)
      return context.strings.marketTrackingCounter(
        value.toString().padLeft(2, '0'),
      );
    final end = widget.orderId.length < 8 ? widget.orderId.length : 8;
    return '#${widget.orderId.substring(0, end).toUpperCase()}';
  }

  // No verified routing ETA is present in the current context RPC. A fixed
  // speed and straight-line distance cannot justify an arrival promise.
  String? _eta() => null;

  String _amountLabel(dynamic value) {
    final amount = value is num ? value.toDouble() : double.tryParse('$value');
    return amount == null || !amount.isFinite
        ? context.strings.historyAmountUnavailable
        : context.strings.moneyValue(amount.toStringAsFixed(2));
  }

  Marker _marker(LatLng p, IconData i, Color c) => Marker(
    point: p,
    width: 45,
    height: 45,
    child: Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: c, width: 2),
      ),
      child: Icon(i, color: c),
    ),
  );
  LatLng? _point(dynamic a, dynamic b) {
    final x = (a is num ? a.toDouble() : null) ?? double.tryParse('$a'),
        y = (b is num ? b.toDouble() : null) ?? double.tryParse('$b');
    return x == null ||
            y == null ||
            !x.isFinite ||
            !y.isFinite ||
            x.abs() > 90 ||
            y.abs() > 180
        ? null
        : LatLng(x, y);
  }

  BoxDecoration _decoration({bool gold = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: gold
            ? (isDark
                ? AppTheme.gold.withValues(alpha: .35)
                : Theme.of(context).colorScheme.primary.withValues(alpha: .35))
            : Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
  Map<String, dynamic> _map(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : {};
  List<Map<String, dynamic>> _list(dynamic v) => v is List
      ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : [];
  int _rank(String s) =>
      {
        'pending': 0,
        'confirmed': 1,
        'preparing': 2,
        'ready_for_pickup': 3,
        'captain_assigned': 3,
        'picked_up': 4,
        'on_the_way': 5,
        'delivered': 6,
        'cancelled': -1,
      }[s] ??
      0;
  String _status(String s) =>
      {
        'pending': context.strings.marketTracking376012df,
        'confirmed': context.strings.marketTracking333cc412,
        'preparing': context.strings.marketTracking58837987,
        'ready_for_pickup': context.strings.marketTracking07554e17,
        'captain_assigned': context.strings.marketTrackingb7d72a98,
        'picked_up': context.strings.marketTrackingff3274e0,
        'on_the_way': context.strings.marketTracking2f7a3366,
        'delivered': context.strings.marketTracking3a648805,
        'cancelled': context.strings.marketTracking46c5b2fc,
      }[s] ??
      s;
  String _hint(String s) =>
      {
        'pending': context.strings.marketTracking7430827b,
        'confirmed': context.strings.marketTracking3a216b91,
        'preparing': context.strings.marketTracking80c40038,
        'ready_for_pickup': context.strings.marketTracking0f39c3d0,
        'captain_assigned': context.strings.marketTracking7451a3a0,
        'picked_up': context.strings.marketTracking8877e2b1,
        'on_the_way': context.strings.marketTracking55635fa8,
        'delivered': context.strings.marketTrackingc0e8e2e6,
        'cancelled': context.strings.marketTrackinga952b3bf,
      }[s] ??
      '';
  IconData _icon(String s) =>
      {
        'pending': Icons.hourglass_top,
        'confirmed': Icons.check_circle,
        'preparing': Icons.inventory_2,
        'ready_for_pickup': Icons.shopping_bag,
        'captain_assigned': Icons.delivery_dining,
        'picked_up': Icons.inventory,
        'on_the_way': Icons.route,
        'delivered': Icons.home,
        'cancelled': Icons.cancel,
      }[s] ??
      Icons.receipt;
}

class _MarketChatSheet extends StatefulWidget {
  final String orderId;
  const _MarketChatSheet({required this.orderId});
  @override
  State<_MarketChatSheet> createState() => _MarketChatSheetState();
}

class _MarketChatSheetState extends State<_MarketChatSheet> {
  final input = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  RealtimeChannel? channel;
  bool sending = false;
  @override
  void initState() {
    super.initState();
    _load();
    channel = SupabaseService.instance.subscribeToMarketMessages(
      widget.orderId,
      () async {
        await AppSoundService.instance.playChat();
        _load();
      },
    );
  }

  @override
  void dispose() {
    channel?.unsubscribe();
    input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final x = await SupabaseService.instance.getMarketMessages(widget.orderId);
    if (mounted) setState(() => messages = x);
  }

  Future<void> _send() async {
    final t = input.text.trim();
    if (t.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await SupabaseService.instance.sendMarketMessage(widget.orderId, t);
      input.clear();
      await _load();
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return Directionality(
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
                  context.strings.marketTrackingaed070ad,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final m = messages[i],
                        mine =
                            m['sender_user_id'] ==
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
                              ? (isDark ? AppTheme.gold : colorScheme.primary)
                              : (isDark
                                  ? const Color(0xFF1E2638)
                                  : colorScheme.surfaceContainerHighest),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          m['message_text']?.toString() ?? '',
                          style: TextStyle(
                            color: mine
                                ? (isDark ? AppTheme.primary : Colors.white)
                                : colorScheme.onSurface,
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
                        controller: input,
                        maxLength: 1000,
                        decoration: InputDecoration(
                          hintText: context.strings.marketTrackingcb7741fc,
                          counterText: '',
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: sending ? null : _send,
                      icon: Icon(
                        Icons.send,
                        color: isDark ? AppTheme.gold : colorScheme.primary,
                      ),
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
}
