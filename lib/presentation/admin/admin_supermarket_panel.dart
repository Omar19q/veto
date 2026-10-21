import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/admin_theme.dart';
import 'admin_market_promos_panel.dart';

class AdminSupermarketPanel extends StatefulWidget {
  const AdminSupermarketPanel({super.key});
  @override
  State<AdminSupermarketPanel> createState() => _AdminSupermarketPanelState();
}

class _AdminSupermarketPanelState extends State<AdminSupermarketPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<Map<String, dynamic>> shops = [];
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> deliveryPrices = [];
  List<Map<String, dynamic>> settlements = [];
  bool _assigningCaptain = false;
  bool loadingShops = true,
      loadingOrders = true,
      loadingPrices = true,
      loadingSettlements = true;
  TripRealtimeLease? _ordersChannel;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _loadAll();
    _ordersChannel = SupabaseService.instance.subscribeToScaleAdminPulse(
      _loadOrders,
    );
  }

  @override
  void dispose() {
    _ordersChannel?.unsubscribe();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadShops(),
      _loadOrders(),
      _loadPrices(),
      _loadSettlements(),
    ]);
  }

  Future<void> _loadShops() async {
    try {
      final x = await SupabaseService.instance.getAllSupermarkets();
      if (mounted) setState(() => shops = x);
    } catch (_) {}
    if (mounted) setState(() => loadingShops = false);
  }

  Future<void> _loadOrders() async {
    try {
      final x = await SupabaseService.instance.getAdminMarketOrders(limit: 200);
      if (mounted) setState(() => orders = x);
    } catch (_) {}
    if (mounted) setState(() => loadingOrders = false);
  }

  Future<void> _loadPrices() async {
    try {
      final x = await SupabaseService.instance.getVitoMarketDeliveryPricing();
      if (mounted) setState(() => deliveryPrices = x);
    } catch (_) {}
    if (mounted) setState(() => loadingPrices = false);
  }

  Future<void> _loadSettlements() async {
    try {
      final rows = await SupabaseService.instance.getAdminMarketSettlements();
      if (mounted) setState(() => settlements = rows);
    } catch (_) {}
    if (mounted) setState(() => loadingSettlements = false);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Row(
              children: [
                Text(
                  'فيتو ماركت',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AdminTheme.ink,
                  ),
                ),
                Spacer(),
                IconButton(
                  tooltip: 'تحديث',
                  onPressed: _loadAll,
                  icon: Icon(Icons.refresh, color: AdminTheme.goldDark),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabs,
            labelColor: AdminTheme.goldDark,
            unselectedLabelColor: AdminTheme.muted,
            indicatorColor: AdminTheme.goldDark,
            tabs: [
              Tab(text: 'المتاجر والمنتجات', icon: Icon(Icons.storefront)),
              Tab(text: 'طلبات فيتو ماركت', icon: Icon(Icons.shopping_bag)),
              Tab(text: 'أسعار التوصيل', icon: Icon(Icons.local_shipping)),
              Tab(text: 'أكواد الخصم', icon: Icon(Icons.local_offer_rounded)),
              Tab(text: 'التسويات', icon: Icon(Icons.account_balance)),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _shopsTab(),
                _ordersTab(),
                _pricingTab(),
                AdminMarketPromosPanel(),
                _settlementsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shopsTab() => Column(
    children: [
      Padding(
        padding: EdgeInsets.fromLTRB(18, 14, 18, 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            onPressed: () async {
              await showDialog(context: context, builder: (_) => _ShopDialog());
              _loadShops();
            },
            icon: Icon(Icons.add),
            label: Text('إضافة متجر', style: TextStyle(fontFamily: 'Cairo')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.goldDark,
              foregroundColor: AppTheme.primary,
            ),
          ),
        ),
      ),
      Expanded(
        child: loadingShops
            ? Center(
                child: CircularProgressIndicator(color: AdminTheme.goldDark),
              )
            : ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                itemCount: shops.length,
                separatorBuilder: (_, __) => SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final s = shops[i];
                  return Container(
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AdminTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AdminTheme.borderSoft),
                    ),
                    child: Row(
                      children: [
                        if (s['logo_url'] != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              s['logo_url'].toString(),
                              width: 58,
                              height: 58,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Icon(
                            Icons.store_rounded,
                            color: AdminTheme.goldDark,
                            size: 50,
                          ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s['name']?.toString() ?? '',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  color: AdminTheme.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                s['address']?.toString() ?? '',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  color: AdminTheme.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: s['is_active'] == true,
                          onChanged: (v) async {
                            await SupabaseService.instance.setSupermarketActive(
                              s['id'].toString(),
                              v,
                            );
                            _loadShops();
                          },
                          activeThumbColor: AdminTheme.goldDark,
                        ),
                        IconButton(
                          onPressed: () async {
                            await showDialog(
                              context: context,
                              builder: (_) => _ShopDialog(existing: s),
                            );
                            _loadShops();
                          },
                          icon: Icon(
                            Icons.edit_rounded,
                            color: AdminTheme.goldDark,
                          ),
                        ),
                        IconButton(
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor: AdminTheme.surface,
                              content: _ProductManager(shop: s),
                            ),
                          ),
                          icon: Icon(
                            Icons.inventory_2_rounded,
                            color: AdminTheme.goldDark,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    ],
  );

  Widget _ordersTab() {
    if (loadingOrders) {
      return Center(
        child: CircularProgressIndicator(color: AdminTheme.goldDark),
      );
    }
    if (orders.isEmpty) {
      return Center(
        child: Text(
          'لا توجد طلبات فيتو ماركت',
          style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.muted),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.all(18),
      itemCount: orders.length,
      separatorBuilder: (_, __) => SizedBox(height: 10),
      itemBuilder: (_, i) => _orderCard(orders[i]),
    );
  }

  Widget _orderCard(Map<String, dynamic> o) {
    final status = o['order_status']?.toString() ?? 'pending';
    final items = (o['items'] is List)
        ? List<Map<String, dynamic>>.from(o['items'])
        : <Map<String, dynamic>>[];
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (o['store_order_number'] as num?) != null
                      ? 'شباك ${(o['store_order_number'] as num).toInt().toString().padLeft(2, '0')}'
                      : 'طلب #${o['id'].toString().substring(0, 8).toUpperCase()}',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w800,
                    color: AdminTheme.ink,
                  ),
                ),
              ),
              Text(
                _marketStatusLabel(status),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: AdminTheme.goldDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'العميل: ${o['customer_name'] ?? 'غير معروف'}',
            style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
          ),
          Text(
            'رقم العميل: ${o['customer_phone'] ?? 'غير متوفر'}',
            style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.muted),
          ),
          Text(
            'المتجر: ${o['supermarket_name'] ?? ''}',
            style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.muted),
          ),
          Text(
            'التاريخ: ${_date(o['created_at'])}',
            style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.muted),
          ),
          Text(
            'العنوان: ${o['delivery_address'] ?? ''}',
            style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.muted),
          ),
          Divider(color: AdminTheme.borderSoft),
          ...items.map(
            (it) => Padding(
              padding: EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${it['product_name']} × ${it['quantity']}',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: AdminTheme.ink,
                      ),
                    ),
                  ),
                  Text(
                    '${it['subtotal'] ?? 0} ج',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: AdminTheme.goldDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(color: AdminTheme.borderSoft),
          _moneyRow('المجموع الفرعي', o['subtotal']),
          _moneyRow('التوصيل', o['delivery_fee']),
          _moneyRow('الإجمالي', o['total_amount'], strong: true),
          SizedBox(height: 12),
          if ({
            'confirmed',
            'preparing',
            'ready_for_pickup',
            'captain_assigned',
          }.contains(status))
            Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: ElevatedButton.icon(
                onPressed: () => _assignCaptain(o),
                icon: Icon(Icons.delivery_dining_rounded),
                label: Text(
                  'اختيار كابتن مؤهل',
                  style: TextStyle(fontFamily: 'Cairo'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.goldDark,
                  foregroundColor: AppTheme.primary,
                ),
              ),
            ),
          Row(
            children: [
              Text(
                'الحالة:',
                style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.muted),
              ),
              SizedBox(width: 10),
              DropdownButton<String>(
                value: _validMarketStatus(status),
                dropdownColor: AdminTheme.surface,
                items:
                    [
                          'pending',
                          'confirmed',
                          'preparing',
                          'ready_for_pickup',
                          'captain_assigned',
                          'picked_up',
                          'on_the_way',
                          'delivered',
                          'cancelled',
                        ]
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(
                              _marketStatusLabel(s),
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                color: AdminTheme.ink,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (v) async {
                  if (v == null || v == status) return;
                  try {
                    await SupabaseService.instance.adminUpdateMarketOrderStatus(
                      orderId: o['id'].toString(),
                      status: v,
                    );
                    await _loadOrders();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'تعذر تغيير الحالة: $e',
                          style: TextStyle(fontFamily: 'Cairo'),
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _assignCaptain(Map<String, dynamic> order) async {
    if (_assigningCaptain) return;
    _assigningCaptain = true;
    try {
      final captains = await SupabaseService.instance.getEligibleMarketCaptains(
        order['id'].toString(),
      );
      if (!mounted) return;
      if (captains.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('لا يوجد كابتن متصل ومفعّل لفيتو ماركت الآن.'),
          ),
        );
        return;
      }
      final selected = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AdminTheme.surface,
          title: Text(
            'اختر كابتن',
            style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
          ),
          content: SizedBox(
            width: 480,
            height: 560,
            child: Column(
              children: [
                _captainsMap(
                  captains,
                  onSelect: (captain) => Navigator.pop(context, captain),
                ),
                SizedBox(height: 10),
                Text(
                  'اضغط رقم الكابتن على الخريطة أو اسمه بالقائمة. الأخضر متاح، والذهبي موقع المتجر. التعيين مباشر.',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: AdminTheme.muted,
                    fontSize: 11,
                  ),
                ),
                SizedBox(height: 4),
                Expanded(
                  child: ListView.separated(
                    itemCount: captains.length,
                    separatorBuilder: (_, __) =>
                        Divider(color: AdminTheme.borderSoft),
                    itemBuilder: (_, i) {
                      final c = captains[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: c['is_assignable'] == true
                              ? Color(0xFF16A34A)
                              : AdminTheme.surfaceSoft,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: AdminTheme.ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        title: Text(
                          c['full_name']?.toString() ?? '',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: AdminTheme.ink,
                          ),
                        ),
                        subtitle: Text(
                          '${c['phone'] ?? ''} • ${c['distance_km'] == null ? 'الموقع غير متاح على الخريطة' : '${(c['distance_km'] as num).toStringAsFixed(1)} كم من المتجر'}\n'
                          '${_captainAvailabilityLabel(c)}',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: AdminTheme.muted,
                          ),
                        ),
                        enabled: c['is_assignable'] == true,
                        onTap: c['is_assignable'] == true
                            ? () => Navigator.pop(context, c)
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (selected == null) return;
      await SupabaseService.instance.assignMarketCaptain(
        orderId: order['id'].toString(),
        captainId: selected['id'].toString(),
      );
      await _loadOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_assignmentErrorLabel(e))));
      }
    } finally {
      _assigningCaptain = false;
    }
  }

  String _captainAvailabilityLabel(Map<String, dynamic> c) {
    if (c['is_assignable'] == true) {
      return c['location_is_fresh'] == true
          ? 'متصل ومتاح — اضغط للتعيين'
          : 'متصل ومتاح — الموقع المعروض آخر موقع معروف';
    }
    return switch (c['unavailable_reason']?.toString()) {
      'active_trip' => 'غير متاح — لديه رحلة شغالة',
      'active_market_order' => 'غير متاح — لديه طلب فيتو ماركت',
      'pending_assignment' => 'غير متاح — محجوز لطلب آخر',
      'debt_limit_reached' => 'غير متاح — وصل لحد الدين المحدد',
      _ => 'غير متاح حاليًا — حدّث القائمة',
    };
  }

  String _assignmentErrorLabel(Object error) {
    final message = error.toString();
    if (message.contains('order_already_assigned') ||
        message.contains('assignment_conflict')) {
      return 'الطلب أو الكابتن تم تعيينه بالفعل. حدّث قائمة الطلبات.';
    }
    if (message.contains('order_not_assignable')) {
      return 'المتجر لازم يقبل الطلب أولًا، وبعدها يمكنك تعيين الكابتن.';
    }
    if (message.contains('captain_not_available')) {
      return 'حالة الكابتن اتغيّرت أو أصبح مشغولًا. افتح الاختيار مرة أخرى.';
    }
    if (message.contains('debt_limit_reached')) {
      return 'الكابتن وصل لحد الدين. راجع حسابه من إدارة الكباتن.';
    }
    if (message.contains('PGRST202') || message.contains('PGRST203')) {
      return 'شغّل SQL المرفق لإصلاح خدمة تعيين الكابتن ثم حاول مرة أخرى.';
    }
    return 'تعذر حفظ التعيين الآن. تحقق من الإنترنت وحدّث قائمة الطلبات.';
  }

  Widget _captainsMap(
    List<Map<String, dynamic>> captains, {
    required ValueChanged<Map<String, dynamic>> onSelect,
  }) {
    double? number(dynamic value) =>
        (value as num?)?.toDouble() ?? double.tryParse('$value');
    final first = captains.first;
    final storeLat = number(first['store_latitude']);
    final storeLon = number(first['store_longitude']);
    final center = storeLat != null && storeLon != null
        ? LatLng(storeLat, storeLon)
        : LatLng(
            number(first['current_latitude']) ?? 30.0131,
            number(first['current_longitude']) ?? 31.2089,
          );
    final markers = <Marker>[
      if (storeLat != null && storeLon != null)
        Marker(
          point: LatLng(storeLat, storeLon),
          width: 46,
          height: 46,
          child: CircleAvatar(
            backgroundColor: Colors.orange,
            child: Icon(Icons.store, color: Colors.white),
          ),
        ),
      ...captains.indexed.expand((entry) {
        final lat = number(entry.$2['current_latitude']);
        final lon = number(entry.$2['current_longitude']);
        if (lat == null || lon == null) return <Marker>[];
        return [
          Marker(
            point: LatLng(lat, lon),
            width: 42,
            height: 42,
            child: Tooltip(
              message:
                  '${entry.$2['full_name'] ?? 'كابتن'} — ${_captainAvailabilityLabel(entry.$2)}',
              child: GestureDetector(
                onTap: entry.$2['is_assignable'] == true
                    ? () => onSelect(entry.$2)
                    : null,
                child: CircleAvatar(
                  backgroundColor: entry.$2['is_assignable'] == true
                      ? Color(0xFF16A34A)
                      : AdminTheme.surfaceSoft,
                  child: Text(
                    '${entry.$1 + 1}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ];
      }),
    ];
    return SizedBox(
      height: 215,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          options: MapOptions(initialCenter: center, initialZoom: 13.5),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.vetosanya.app',
            ),
            MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }

  Widget _pricingTab() {
    if (loadingPrices) {
      return Center(
        child: CircularProgressIndicator(color: AdminTheme.goldDark),
      );
    }
    return ListView(
      padding: EdgeInsets.all(18),
      children: [
        Text(
          'سعر توصيل فيتو ماركت حسب حرف المنطقة',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AdminTheme.ink,
          ),
        ),
        SizedBox(height: 10),
        Text(
          'يمكن تحديد سعر توصيل مستقل لكل حرف. عند عدم وجود سعر للحرف يستخدم السعر العام من الإعدادات.',
          style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.muted),
        ),
        SizedBox(height: 16),
        ...deliveryPrices.map((p) => _deliveryPriceRow(p)),
        SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () async {
            await _editDeliveryPrice();
          },
          icon: Icon(Icons.add),
          label: Text(
            'إضافة / تعديل حرف',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminTheme.goldDark,
            foregroundColor: AppTheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _settlementsTab() {
    if (loadingSettlements) {
      return Center(
        child: CircularProgressIndicator(color: AdminTheme.goldDark),
      );
    }
    if (settlements.isEmpty) {
      return Center(
        child: Text(
          'لا توجد تسويات محسوبة حتى الآن',
          style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.muted),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.all(18),
      itemCount: settlements.length,
      separatorBuilder: (_, __) => SizedBox(height: 10),
      itemBuilder: (_, index) {
        final settlement = settlements[index];
        final store = settlement['supermarkets'] is Map
            ? Map<String, dynamic>.from(settlement['supermarkets'] as Map)
            : <String, dynamic>{};
        final direction = settlement['direction']?.toString();
        final calculated = settlement['status'] == 'calculated';
        final balance = ((settlement['balance'] as num?)?.toDouble() ?? 0)
            .abs();
        return Container(
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AdminTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AdminTheme.borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                store['name']?.toString() ?? '',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: AdminTheme.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${settlement['business_date']} • ${direction == 'pay_store'
                    ? 'مستحق للصرف'
                    : direction == 'collect_from_store'
                    ? 'مطلوب للتحصيل'
                    : 'الحساب متعادل'}',
                style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.muted),
              ),
              _moneyRow('إجمالي المبيعات', settlement['gross_sales']),
              _moneyRow('عمولة فيتو', settlement['store_commission']),
              _moneyRow('الصافي', balance, strong: true),
              Text(
                'طريقة المتجر: ${store['settlement_payout_method'] ?? 'غير محددة'} — ${store['settlement_payout_details'] ?? ''}',
                style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.muted),
              ),
              if (calculated && direction != 'balanced')
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton(
                    onPressed: () => _completeSettlement(settlement),
                    child: Text(
                      direction == 'collect_from_store'
                          ? 'تسجيل التحصيل'
                          : 'تسجيل الصرف',
                    ),
                  ),
                )
              else
                Text(
                  'الحالة: ${settlement['status']}',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: AdminTheme.goldDark,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _completeSettlement(Map<String, dynamic> settlement) async {
    final reference = TextEditingController();
    final notes = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد العملية المالية اليدوية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: reference,
              decoration: InputDecoration(labelText: 'رقم المرجع *'),
            ),
            TextField(
              controller: notes,
              decoration: InputDecoration(labelText: 'ملاحظات'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reference.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: Text('تسجيل'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await SupabaseService.instance.completeMarketSettlement(
        settlementId: settlement['id'].toString(),
        reference: reference.text.trim(),
        notes: notes.text.trim(),
      );
      await _loadSettlements();
    }
    reference.dispose();
    notes.dispose();
  }

  Widget _deliveryPriceRow(Map<String, dynamic> p) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AdminTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTheme.borderSoft),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'منطقة ${p['area_letter']}',
              style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
            ),
          ),
          Text(
            '${p['delivery_fee']} ج',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: AdminTheme.goldDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          IconButton(
            onPressed: () => _editDeliveryPrice(existing: p),
            icon: Icon(Icons.edit, color: AdminTheme.goldDark),
          ),
        ],
      ),
    );
  }

  Future<void> _editDeliveryPrice({Map<String, dynamic>? existing}) async {
    final area = TextEditingController(
      text: existing?['area_letter']?.toString() ?? '',
    );
    final fee = TextEditingController(
      text: existing?['delivery_fee']?.toString() ?? '',
    );
    try {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AdminTheme.surface,
          title: Text(
            'سعر توصيل المنطقة',
            style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: area,
                style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
                decoration: InputDecoration(labelText: 'حرف المنطقة'),
              ),
              TextField(
                controller: fee,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
                decoration: InputDecoration(labelText: 'سعر التوصيل'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
            ),
            ElevatedButton(
              onPressed: () async {
                final f = double.tryParse(fee.text.trim());
                final a = area.text.trim();
                if (a.isEmpty || f == null || f < 0) return;
                try {
                  await SupabaseService.instance
                      .upsertVitoMarketDeliveryPricing(
                        areaLetter: a,
                        deliveryFee: f,
                      );
                  if (context.mounted) Navigator.pop(context);
                } catch (_) {}
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.goldDark,
                foregroundColor: AppTheme.primary,
              ),
              child: Text('حفظ', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      );
    } finally {
      area.dispose();
      fee.dispose();
      await _loadPrices();
    }
  }

  double _num(Object? v) =>
      (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
  Widget _moneyRow(String label, Object? v, {bool strong = false}) => Padding(
    padding: EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.muted),
          ),
        ),
        Text(
          '${_num(v).toStringAsFixed(2)} ج',
          style: TextStyle(
            fontFamily: 'Cairo',
            color: strong ? AdminTheme.goldDark : AdminTheme.ink,
            fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  String _date(Object? v) {
    final d = DateTime.tryParse(v?.toString() ?? '');
    return d == null ? '-' : d.toLocal().toString().substring(0, 16);
  }

  String _validMarketStatus(String s) {
    final all = {
      'pending',
      'confirmed',
      'preparing',
      'ready_for_pickup',
      'captain_assigned',
      'picked_up',
      'on_the_way',
      'delivered',
      'cancelled',
    };
    return all.contains(s) ? s : 'pending';
  }

  static String _marketStatusLabel(String s) =>
      {
        'pending': 'جديد',
        'confirmed': 'مؤكد',
        'preparing': 'جاري التجهيز',
        'ready_for_pickup': 'جاهز',
        'captain_assigned': 'تم التعيين',
        'picked_up': 'تم الاستلام',
        'on_the_way': 'في الطريق',
        'delivered': 'تم التسليم',
        'cancelled': 'ملغي',
      }[s] ??
      s;
}

class _ShopDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _ShopDialog({this.existing});
  @override
  State<_ShopDialog> createState() => _ShopDialogState();
}

class _ShopDialogState extends State<_ShopDialog> {
  final name = TextEditingController();
  final address = TextEditingController();
  final phone = TextEditingController();
  final hours = TextEditingController();
  final delivery = TextEditingController();
  final ownerPhone = TextEditingController();
  final ownerName = TextEditingController();
  final commission = TextEditingController();
  final latitude = TextEditingController();
  final longitude = TextEditingController();
  XFile? image, coverImage;
  bool active = true, open = true, saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    name.text = e?['name']?.toString() ?? '';
    address.text = e?['address']?.toString() ?? '';
    phone.text = e?['phone']?.toString() ?? '';
    hours.text = e?['opening_hours']?.toString() ?? '';
    delivery.text = e?['delivery_estimate_minutes']?.toString() ?? '30';
    commission.text = e?['commission_percent']?.toString() ?? '10';
    latitude.text = e?['latitude']?.toString() ?? '';
    longitude.text = e?['longitude']?.toString() ?? '';
    active = e?['is_active'] != false;
    open = e?['is_open'] != false;
    if (e != null) _loadOwner(e['id'].toString());
  }

  Future<void> _loadOwner(String storeId) async {
    final owner = await SupabaseService.instance.getMerchantOwner(storeId);
    if (!mounted || owner == null) return;
    setState(() {
      ownerPhone.text = owner['phone']?.toString() ?? '';
      ownerName.text = owner['full_name']?.toString() ?? '';
    });
  }

  @override
  void dispose() {
    for (final c in [
      name,
      address,
      phone,
      hours,
      delivery,
      ownerPhone,
      ownerName,
      commission,
      latitude,
      longitude,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final pct = double.tryParse(commission.text.trim());
    final lat = double.tryParse(latitude.text.trim());
    final lon = double.tryParse(longitude.text.trim());
    if (name.text.trim().isEmpty ||
        !RegExp(r'^01\d{9}$').hasMatch(ownerPhone.text.trim()) ||
        pct == null ||
        pct < 0 ||
        pct > 100) {
      setState(
        () => error = 'أدخل اسم المتجر ورقم مسؤول صحيحًا وعمولة من 0 إلى 100.',
      );
      return;
    }
    if (lat == null ||
        lon == null ||
        lat < -90 ||
        lat > 90 ||
        lon < -180 ||
        lon > 180) {
      setState(() => error = 'حدد موقع المتجر الصحيح قبل الحفظ.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      String? logo = widget.existing?['logo_url']?.toString();
      String? cover = widget.existing?['cover_url']?.toString();
      if (image != null)
        logo = await SupabaseService.instance.uploadPublicImage(
          path: 'supermarkets/${DateTime.now().millisecondsSinceEpoch}.jpg',
          bytes: await image!.readAsBytes(),
          contentType: 'image/jpeg',
        );
      if (coverImage != null)
        cover = await SupabaseService.instance.uploadPublicImage(
          path:
              'supermarkets/covers/${DateTime.now().millisecondsSinceEpoch}.jpg',
          bytes: await coverImage!.readAsBytes(),
          contentType: 'image/jpeg',
        );
      await SupabaseService.instance.upsertSupermarketWithOwner(
        supermarketId: widget.existing?['id']?.toString(),
        name: name.text.trim(),
        phone: phone.text.trim(),
        address: address.text.trim(),
        latitude: lat,
        longitude: lon,
        ownerPhone: ownerPhone.text.trim(),
        ownerName: ownerName.text.trim(),
        commissionPercent: pct,
        active: active,
        open: open,
        deliveryEstimateMinutes: int.tryParse(delivery.text.trim()) ?? 30,
        logoUrl: logo,
        coverUrl: cover,
        openingHours: hours.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        setState(
          () => error = 'تعذر حفظ المتجر. تأكد من عدم ربط الرقم بمتجر آخر.',
        );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AdminTheme.surface,
    title: Text(
      widget.existing == null
          ? 'إضافة متجر وربط المسؤول'
          : 'تعديل المتجر والمسؤول',
      style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
    ),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          children: [
            _field(name, 'اسم المتجر'),
            _field(address, 'العنوان'),
            Row(
              children: [
                Expanded(child: _field(latitude, 'خط العرض *', number: true)),
                SizedBox(width: 8),
                Expanded(child: _field(longitude, 'خط الطول *', number: true)),
              ],
            ),
            OutlinedButton.icon(
              onPressed: _captureStoreLocation,
              icon: Icon(Icons.my_location_rounded),
              label: Text('استخدام موقعي الحالي كموقع المتجر'),
            ),
            _field(phone, 'هاتف المتجر', phoneInput: true),
            Divider(color: AdminTheme.borderSoft),
            _field(ownerPhone, 'رقم دخول مسؤول المتجر *', phoneInput: true),
            _field(ownerName, 'اسم مسؤول المتجر'),
            _field(commission, 'عمولة فيتو على المتجر % *', number: true),
            _field(hours, 'ساعات العمل'),
            _field(delivery, 'مدة التوصيل بالدقائق', number: true),
            OutlinedButton.icon(
              onPressed: () async {
                image = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 82,
                  maxWidth: 1400,
                );
                setState(() {});
              },
              icon: Icon(Icons.image, color: AdminTheme.goldDark),
              label: Text(
                image == null ? 'إضافة شعار المتجر' : 'تم اختيار الشعار',
              ),
            ),
            SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                coverImage = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 82,
                  maxWidth: 1600,
                );
                setState(() {});
              },
              icon: Icon(
                Icons.photo_library_rounded,
                color: AdminTheme.goldDark,
              ),
              label: Text(
                coverImage == null ? 'إضافة صورة الغلاف' : 'تم اختيار الغلاف',
              ),
            ),
            SwitchListTile(
              value: active,
              onChanged: (v) => setState(() => active = v),
              title: Text(
                'المتجر ظاهر للعملاء',
                style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
              ),
              activeThumbColor: AdminTheme.goldDark,
            ),
            SwitchListTile(
              value: open,
              onChanged: (v) => setState(() => open = v),
              title: Text(
                'المتجر مفتوح',
                style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
              ),
              activeThumbColor: AdminTheme.goldDark,
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(fontFamily: 'Cairo', color: Colors.redAccent),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
      ElevatedButton(
        onPressed: saving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: AdminTheme.goldDark,
          foregroundColor: AppTheme.primary,
        ),
        child: saving
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text('حفظ', style: TextStyle(fontFamily: 'Cairo')),
      ),
    ],
  );

  Future<void> _captureStoreLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted)
          setState(
            () => error = 'اسمح بالوصول للموقع أو اكتب الإحداثيات يدويًا.',
          );
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        latitude.text = position.latitude.toStringAsFixed(7);
        longitude.text = position.longitude.toStringAsFixed(7);
        error = null;
      });
    } catch (_) {
      if (mounted)
        setState(() => error = 'تعذر تحديد الموقع. اكتب الإحداثيات يدويًا.');
    }
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool number = false,
    bool phoneInput = false,
  }) => Padding(
    padding: EdgeInsets.only(bottom: 9),
    child: TextField(
      controller: c,
      keyboardType: phoneInput
          ? TextInputType.phone
          : number
          ? TextInputType.numberWithOptions(decimal: true)
          : null,
      style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontFamily: 'Cairo', color: AdminTheme.muted),
        filled: true,
        fillColor: AdminTheme.surfaceSoft,
        border: OutlineInputBorder(),
      ),
    ),
  );
}

class _ProductManager extends StatefulWidget {
  final Map<String, dynamic> shop;
  const _ProductManager({required this.shop});
  @override
  State<_ProductManager> createState() => _ProductManagerState();
}

class _ProductManagerState extends State<_ProductManager> {
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> cats = [];
  bool loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sid = widget.shop['id'].toString();
      final p = await SupabaseService.instance.getProducts(sid);
      final c = await SupabaseService.instance.getAllProductCategories(sid);
      if (mounted)
        setState(() {
          products = p;
          cats = c;
        });
    } catch (_) {
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _add() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ProductDialog(shop: widget.shop, categories: cats),
    );
    await _load();
  }

  Future<void> _addCategory() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _CategoryDialog(shop: widget.shop),
    );
    await _load();
  }

  Widget _productTile(Map<String, dynamic> p) => Container(
    padding: EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AdminTheme.surfaceSoft,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        if (p['image_url'] != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              p['image_url'].toString(),
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          )
        else
          Icon(Icons.inventory_2_rounded, color: AdminTheme.goldDark, size: 42),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            p['name']?.toString() ?? '',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: AdminTheme.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          '${p['price'] ?? 0} ج',
          style: TextStyle(
            fontFamily: 'Cairo',
            color: AdminTheme.goldDark,
            fontWeight: FontWeight.w800,
          ),
        ),
        Switch(
          value: p['is_available'] != false,
          onChanged: (v) async {
            await SupabaseService.instance.client
                .from('products')
                .update({'is_available': v})
                .eq('id', p['id']);
            await _load();
          },
          activeThumbColor: AdminTheme.goldDark,
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 600,
    height: 560,
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'منتجات ${widget.shop['name']}',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AdminTheme.ink,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _addCategory,
              icon: Icon(Icons.category_outlined),
              label: Text('تصنيف'),
            ),
            SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _add,
              icon: Icon(Icons.add),
              label: Text('منتج'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.goldDark,
                foregroundColor: AppTheme.primary,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Expanded(
          child: loading
              ? Center(
                  child: CircularProgressIndicator(color: AdminTheme.goldDark),
                )
              : ListView.separated(
                  itemCount: products.length,
                  separatorBuilder: (_, __) => SizedBox(height: 8),
                  itemBuilder: (_, i) => _productTile(products[i]),
                ),
        ),
      ],
    ),
  );
}

class _ProductDialog extends StatefulWidget {
  final Map<String, dynamic> shop;
  final List<Map<String, dynamic>> categories;
  const _ProductDialog({required this.shop, required this.categories});
  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  final name = TextEditingController(),
      price = TextEditingController(),
      unit = TextEditingController();
  String? cat;
  XFile? img;
  bool saving = false;
  @override
  void dispose() {
    name.dispose();
    price.dispose();
    unit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pr = double.tryParse(price.text.trim());
    if (name.text.trim().isEmpty || pr == null) return;
    setState(() => saving = true);
    try {
      String? url;
      if (img != null)
        url = await SupabaseService.instance.uploadPublicImage(
          path: 'products/${DateTime.now().millisecondsSinceEpoch}.jpg',
          bytes: await img!.readAsBytes(),
          contentType: 'image/jpeg',
        );
      await SupabaseService.instance.saveProduct(
        supermarketId: widget.shop['id'].toString(),
        categoryId: cat,
        name: name.text.trim(),
        price: pr,
        unit: unit.text.trim().isEmpty ? null : unit.text.trim(),
        imageUrl: url,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AdminTheme.surface,
    title: Text(
      'إضافة منتج',
      style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
    ),
    content: SingleChildScrollView(
      child: Column(
        children: [
          _f(name, 'اسم المنتج'),
          _f(price, 'السعر', num: true),
          _f(unit, 'الوحدة'),
          DropdownButton<String?>(
            value: cat,
            hint: Text('التصنيف'),
            items: [
              DropdownMenuItem<String?>(value: null, child: Text('بدون تصنيف')),
              ...widget.categories.map(
                (x) => DropdownMenuItem<String?>(
                  value: x['id'].toString(),
                  child: Text(x['name'].toString()),
                ),
              ),
            ],
            onChanged: (v) => setState(() => cat = v),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final f = await ImagePicker().pickImage(
                source: ImageSource.gallery,
                imageQuality: 82,
                maxWidth: 1200,
              );
              if (f != null) setState(() => img = f);
            },
            icon: Icon(Icons.image, color: AdminTheme.goldDark),
            label: Text(img == null ? 'إضافة صورة المنتج' : 'تم اختيار الصورة'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
      ElevatedButton(
        onPressed: saving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: AdminTheme.goldDark,
          foregroundColor: AppTheme.primary,
        ),
        child: saving
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text('حفظ'),
      ),
    ],
  );
  Widget _f(TextEditingController c, String l, {bool num = false}) => Padding(
    padding: EdgeInsets.only(bottom: 9),
    child: TextField(
      controller: c,
      keyboardType: num ? TextInputType.numberWithOptions(decimal: true) : null,
      style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
      decoration: InputDecoration(
        labelText: l,
        filled: true,
        fillColor: AdminTheme.surfaceSoft,
        border: OutlineInputBorder(),
      ),
    ),
  );
}

class _CategoryDialog extends StatefulWidget {
  final Map<String, dynamic> shop;
  const _CategoryDialog({required this.shop});
  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final c = TextEditingController();
  XFile? img;
  bool saving = false;
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (c.text.trim().isEmpty) return;
    setState(() => saving = true);
    try {
      String? imageUrl;
      if (img != null)
        imageUrl = await SupabaseService.instance.uploadPublicImage(
          path:
              'product-categories/${widget.shop['id']}/${DateTime.now().millisecondsSinceEpoch}.jpg',
          bytes: await img!.readAsBytes(),
          contentType: 'image/jpeg',
        );
      await SupabaseService.instance.saveProductCategory(
        supermarketId: widget.shop['id'].toString(),
        name: c.text.trim(),
        imageUrl: imageUrl,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AdminTheme.surface,
    title: Text(
      'إضافة تصنيف',
      style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: c,
          style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
          decoration: InputDecoration(labelText: 'اسم التصنيف'),
        ),
        SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () async {
            img = await ImagePicker().pickImage(
              source: ImageSource.gallery,
              imageQuality: 82,
              maxWidth: 1000,
            );
            setState(() {});
          },
          icon: Icon(Icons.image, color: AdminTheme.goldDark),
          label: Text(
            img == null ? 'إضافة أيقونة التصنيف' : 'تم اختيار الأيقونة',
          ),
        ),
      ],
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
      ElevatedButton(onPressed: saving ? null : _save, child: Text('حفظ')),
    ],
  );
}
