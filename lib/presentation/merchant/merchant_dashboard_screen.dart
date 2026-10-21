import 'package:vetosanya/widgets/captain_photo_v16.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../routes/app_routes.dart';
import '../../services/app_sound_service.dart';
import '../../services/market_support_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

class MerchantDashboardScreen extends StatefulWidget {
  const MerchantDashboardScreen({super.key});

  @override
  State<MerchantDashboardScreen> createState() =>
      _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState extends State<MerchantDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  RealtimeChannel? _channel;
  Map<String, dynamic>? _store;
  Map<String, dynamic>? _membership;
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _staff = [];
  List<Map<String, dynamic>> _settlements = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      final data = await SupabaseService.instance.getMerchantDashboard();
      final store = Map<String, dynamic>.from(data['store'] as Map);
      final products = await SupabaseService.instance.getMerchantProducts(
        store['id'].toString(),
      );
      final categories = await SupabaseService.instance.getAllProductCategories(
        store['id'].toString(),
      );
      List<Map<String, dynamic>> staff = const [];
      try {
        staff = await SupabaseService.instance.getMerchantStaff();
      } catch (_) {
        // Staff without team-management permission still uses the other tabs.
      }
      if (!mounted) return;
      setState(() {
        _store = store;
        _membership = data['membership'] is Map
            ? Map<String, dynamic>.from(data['membership'] as Map)
            : null;
        _orders = _mapList(data['orders']);
        _settlements = _mapList(data['settlements']);
        _products = products;
        _categories = categories;
        _staff = staff;
        _loading = false;
      });
      _channel ??= SupabaseService.instance.client
          .channel('merchant_orders_${store['id']}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'market_orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'supermarket_id',
              value: store['id'].toString(),
            ),
            callback: (payload) async {
              if (payload.eventType == PostgresChangeEvent.insert) {
                await AppSoundService.instance.playMarketOrder();
              }
              await _load();
            },
          )
          .subscribe();
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = 'تعذر تحميل لوحة المتجر. تأكد من ربط الرقم بالمتجر.';
        });
    }
  }

  List<Map<String, dynamic>> _mapList(dynamic value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1220),
        title: Text(
          _store?['name']?.toString() ?? 'إدارة متجر فيتو ماركت',
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: () async {
              await SupabaseService.instance.signOut();
              if (context.mounted) context.go(AppRoutes.signUpLoginScreen);
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.gold,
          indicatorColor: AppTheme.gold,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long_rounded), text: 'الطلبات'),
            Tab(icon: Icon(Icons.inventory_2_rounded), text: 'المنتجات'),
            Tab(icon: Icon(Icons.groups_2_rounded), text: 'الفريق'),
            Tab(
              icon: Icon(Icons.account_balance_wallet_rounded),
              text: 'الحسابات',
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : _error != null
          ? _message(_error!, Icons.error_outline_rounded)
          : TabBarView(
              controller: _tabs,
              children: [
                _ordersTab(),
                _productsTab(),
                _staffTab(),
                _financeTab(),
              ],
            ),
    ),
  );

  Widget _ordersTab() {
    if (_orders.isEmpty)
      return _message('لا توجد طلبات حتى الآن', Icons.shopping_bag_outlined);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: _orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _orderCard(_orders[i]),
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final status = order['order_status']?.toString() ?? 'pending';
    final items = _mapList(order['items']);
    final actions = switch (status) {
      'pending' => [('قبول الطلب', 'confirmed'), ('رفض بسبب', 'cancelled')],
      'confirmed' => [('بدء التجهيز', 'preparing')],
      'preparing' => [('جاهز للاستلام', 'ready_for_pickup')],
      'captain_assigned' when order['ready_at'] == null => [
        ('الطلب جاهز لاستلام الكابتن', 'ready_for_pickup'),
      ],
      _ => <(String, String)>[],
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _orderLabel(order),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _status(status),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Text(
              '${item['quantity']} × ${item['product_name']} — ${_money(item['subtotal'])}',
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const Divider(color: AppTheme.cardBorder),
          _line('قيمة السلة', order['subtotal']),
          if (((order['market_promo_discount'] as num?)?.toDouble() ?? 0) > 0)
            _line('خصم برومو ممول من فيتو', order['market_promo_discount']),
          _line('عمولة فيتو', order['store_commission_amount']),
          _line(
            'صافي حق المتجر بعد العمولة',
            order['store_net_amount'],
            strong: true,
          ),
          _line(
            'المبلغ الذي تستلمه من الكابتن',
            order['store_cash_due'],
            strong: true,
          ),
          if (order['captain'] is Map) ...[
            const SizedBox(height: 12),
            _captainCard(Map<String, dynamic>.from(order['captain'] as Map)),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openSupport(order),
              icon: const Icon(Icons.support_agent_rounded),
              label: const Text('خدمة عملاء واتساب'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.whatsapp,
              ),
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actions
                  .map(
                    (a) => ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: a.$2 == 'cancelled'
                            ? Colors.red.shade700
                            : AppTheme.gold,
                        foregroundColor: a.$2 == 'cancelled'
                            ? Colors.white
                            : AppTheme.primary,
                      ),
                      onPressed: () =>
                          _transition(order['id'].toString(), a.$2),
                      child: Text(
                        a.$1,
                        style: const TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _captainCard(Map<String, dynamic> captain) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.backgroundDark,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.gold.withValues(alpha: .28)),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: AppTheme.surfaceVariant,
          backgroundImage:
              (captain['profile_photo']?.toString() ?? '').isNotEmpty
              ? captainPhotoV16(captain['profile_photo'].toString())
              : null,
          child: (captain['profile_photo']?.toString() ?? '').isEmpty
              ? const Icon(Icons.delivery_dining, color: AppTheme.gold)
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                captain['full_name']?.toString() ?? 'الكابتن',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'الهاتف: ${captain['phone'] ?? '-'}',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                'المركبة: ${captain['vehicle_brand'] ?? ''} ${captain['vehicle_model'] ?? ''} • اللوحة ${captain['vehicle_plate'] ?? '-'}',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              if (captain['vehicle_year'] != null)
                Text(
                  'سنة الصنع: ${captain['vehicle_year']} • اللون: ${captain['vehicle_color'] ?? '-'}',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _transition(String orderId, String status) async {
    String? reason;
    if (status == 'cancelled') {
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('سبب رفض الطلب'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'اكتب السبب ليظهر للعميل والإدارة',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty)
                  Navigator.pop(context, controller.text.trim());
              },
              child: const Text('تأكيد الرفض'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (reason == null) return;
    }
    try {
      await SupabaseService.instance.transitionMarketOrder(
        orderId: orderId,
        status: status,
        reason: reason,
      );
      await _load();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لم يتم تغيير الحالة. حدّث الطلب وحاول مرة أخرى.'),
          ),
        );
    }
  }

  Future<void> _openSupport(Map<String, dynamic> order) async {
    final opened = await MarketSupportService.openWhatsApp(
      orderId: order['id'].toString(),
      storeOrderNumber: order['store_order_number'],
      actorLabel: 'متجر',
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح واتساب الآن.')));
    }
  }

  String _orderLabel(Map<String, dynamic> order) {
    final value =
        (order['store_order_number'] as num?)?.toInt() ??
        int.tryParse('${order['store_order_number']}');
    if (value != null) return 'شباك ${value.toString().padLeft(2, '0')}';
    final id = order['id'].toString();
    final end = id.length < 8 ? id.length : 8;
    return 'طلب #${id.substring(0, end).toUpperCase()}';
  }

  Widget _productsTab() {
    final canManage =
        _membership?['merchant_role'] == 'owner' ||
        _membership?['can_manage_products'] == true;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A2541), Color(0xFF11182A)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.gold.withValues(alpha: .35)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppTheme.gold,
                  child: Icon(
                    Icons.storefront_rounded,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'إدارة كتالوج المتجر',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${_products.where((p) => p['is_active'] == true).length} منتج نشط • اضغط على أي منتج لتعديله',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canManage)
                  FilledButton.icon(
                    onPressed: () => _editProduct(null),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('منتج'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_products.isEmpty)
            _message(
              'ابدأ بإضافة أول منتج في متجرك',
              Icons.inventory_2_outlined,
            )
          else
            ..._products.map((p) {
              final available =
                  p['is_available'] == true && p['is_active'] == true;
              final discounted = p['has_active_discount'] == true;
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: ListTile(
                  tileColor: AppTheme.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppTheme.cardBorder),
                  ),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: (p['image_url']?.toString() ?? '').isEmpty
                        ? Container(
                            width: 52,
                            height: 52,
                            color: AppTheme.surfaceVariant,
                            child: const Icon(
                              Icons.inventory_2,
                              color: AppTheme.gold,
                            ),
                          )
                        : Image.network(
                            p['image_url'].toString(),
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 52,
                              height: 52,
                              color: AppTheme.surfaceVariant,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          p['name']?.toString() ?? '',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (discounted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: .16),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'خصم',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.greenAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _money(p['effective_price'] ?? p['price']),
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              color: AppTheme.gold,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (discounted) ...[
                            const SizedBox(width: 6),
                            Text(
                              _money(p['price']),
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                color: AppTheme.textSecondary,
                                decoration: TextDecoration.lineThrough,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        'المخزون: ${p['track_stock'] == true ? p['stock_quantity'] ?? 0 : 'غير محدود'}',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  trailing: Switch(
                    value: available,
                    activeThumbColor: AppTheme.gold,
                    onChanged: canManage
                        ? (v) async {
                            await SupabaseService.instance
                                .updateMerchantProduct(
                                  productId: p['id'].toString(),
                                  available: v,
                                );
                            await _load();
                          }
                        : null,
                  ),
                  onTap: canManage ? () => _editProduct(p) : null,
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _editProduct(Map<String, dynamic>? product) async {
    final name = TextEditingController(
      text: product?['name']?.toString() ?? '',
    );
    final description = TextEditingController(
      text: product?['description']?.toString() ?? '',
    );
    final image = TextEditingController(
      text: product?['image_url']?.toString() ?? '',
    );
    XFile? selectedImage;
    final price = TextEditingController(
      text: product?['price']?.toString() ?? '',
    );
    final stock = TextEditingController(
      text: product?['stock_quantity']?.toString() ?? '',
    );
    final unit = TextEditingController(
      text: product?['unit']?.toString() ?? 'قطعة',
    );
    final discountPercent = TextEditingController(
      text: product?['discount_percent']?.toString() ?? '',
    );
    final discountPrice = TextEditingController(
      text: product?['discount_price']?.toString() ?? '',
    );
    String? categoryId = product?['category_id']?.toString();
    if (categoryId == null && _categories.isNotEmpty) {
      categoryId = _categories.first['id']?.toString();
    }
    bool trackStock = product?['track_stock'] == true;
    bool available = product?['is_available'] != false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(product == null ? 'إضافة منتج جديد' : 'تعديل المنتج'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'اسم المنتج *',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                  ),
                  TextField(
                    controller: description,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'وصف مختصر'),
                  ),
                  if (_categories.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: categoryId,
                      items: _categories
                          .map(
                            (category) => DropdownMenuItem<String>(
                              value: category['id']?.toString(),
                              child: Text(
                                category['name']?.toString() ?? 'قسم',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => categoryId = value),
                      decoration: const InputDecoration(
                        labelText: 'قسم المنتج',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 82,
                        maxWidth: 1200,
                      );
                      if (picked != null) {
                        setDialogState(() => selectedImage = picked);
                      }
                    },
                    icon: const Icon(Icons.photo_library_rounded),
                    label: Text(
                      selectedImage != null
                          ? 'تم اختيار صورة جديدة'
                          : image.text.isNotEmpty
                          ? 'تغيير صورة المنتج من المعرض'
                          : 'اختيار صورة المنتج من المعرض',
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: price,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'السعر الأساسي *',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: unit,
                          decoration: const InputDecoration(
                            labelText: 'الوحدة',
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: discountPercent,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'نسبة الخصم %',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: discountPrice,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'أو سعر بعد الخصم',
                          ),
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    value: trackStock,
                    onChanged: (v) => setDialogState(() => trackStock = v),
                    title: const Text('تتبّع المخزون'),
                    subtitle: const Text('يمنع الطلب عند نفاد الكمية'),
                  ),
                  if (trackStock)
                    TextField(
                      controller: stock,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'الكمية المتاحة',
                      ),
                    ),
                  SwitchListTile(
                    value: available,
                    onChanged: (v) => setDialogState(() => available = v),
                    title: const Text('متاح للعميل الآن'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (product != null)
              TextButton(
                onPressed: () async {
                  Navigator.pop(context, false);
                  await _archiveProduct(product);
                },
                child: const Text(
                  'إخفاء المنتج',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حفظ المنتج'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      final parsedPrice = double.tryParse(price.text.trim());
      if (name.text.trim().isEmpty || parsedPrice == null || parsedPrice <= 0) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('اكتب اسم المنتج وسعرًا صحيحًا')),
          );
      } else {
        try {
          var imageUrl = image.text.trim();
          if (selectedImage != null) {
            imageUrl = await SupabaseService.instance.uploadPublicImage(
              path:
                  'products/${_store!['id']}/${DateTime.now().millisecondsSinceEpoch}.jpg',
              bytes: await selectedImage!.readAsBytes(),
            );
          }
          await SupabaseService.instance.saveMerchantProduct(
            productId: product?['id']?.toString(),
            name: name.text,
            description: description.text,
            categoryId: categoryId,
            imageUrl: imageUrl,
            price: parsedPrice,
            unit: unit.text,
            trackStock: trackStock,
            stock: double.tryParse(stock.text),
            available: available,
            active: true,
            discountPercent: double.tryParse(discountPercent.text),
            discountPrice: double.tryParse(discountPrice.text),
          );
          await _load();
        } catch (e) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تعذر حفظ المنتج. راجع السعر والخصم والصلاحيات.'),
              ),
            );
        }
      }
    }
    name.dispose();
    description.dispose();
    image.dispose();
    price.dispose();
    stock.dispose();
    unit.dispose();
    discountPercent.dispose();
    discountPrice.dispose();
  }

  Future<void> _archiveProduct(Map<String, dynamic> product) async {
    try {
      await SupabaseService.instance.archiveMerchantProduct(
        product['id'].toString(),
      );
      await _load();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر إخفاء المنتج')));
    }
  }

  Widget _staffTab() {
    final role = _membership?['merchant_role']?.toString();
    final canManage = role == 'owner' || role == 'manager';
    if (!canManage)
      return _message(
        'ليس لديك صلاحية إدارة فريق المتجر',
        Icons.lock_outline_rounded,
      );
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.gold.withValues(alpha: .32)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: AppTheme.gold,
                  size: 34,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'فريق وصلاحيات المتجر',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'أضف الموظف برقم هاتفه وحدد ما يمكنه إدارته',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _editStaff(null),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('إضافة'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_staff.isEmpty)
            _message('لا يوجد موظفون مضافون', Icons.groups_outlined)
          else
            ..._staff.map(
              (m) => Card(
                color: AppTheme.surface,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: m['is_active'] == true
                        ? AppTheme.gold.withValues(alpha: .18)
                        : Colors.grey.withValues(alpha: .15),
                    child: Icon(
                      m['merchant_role'] == 'owner'
                          ? Icons.workspace_premium_rounded
                          : Icons.badge_outlined,
                      color: m['is_active'] == true
                          ? AppTheme.gold
                          : Colors.grey,
                    ),
                  ),
                  title: Text(
                    m['full_name']?.toString() ?? 'موظف',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '${m['phone'] ?? ''} • ${_merchantRole(m['merchant_role'])}\n${_permissionText(m)}',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  isThreeLine: true,
                  trailing: m['merchant_role'] == 'owner'
                      ? const Icon(Icons.lock_rounded, color: AppTheme.gold)
                      : const Icon(
                          Icons.edit_outlined,
                          color: AppTheme.textSecondary,
                        ),
                  onTap: m['merchant_role'] == 'owner'
                      ? null
                      : () => _editStaff(m),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _editStaff(Map<String, dynamic>? member) async {
    final name = TextEditingController(
      text: member?['full_name']?.toString() ?? '',
    );
    final phone = TextEditingController(
      text: member?['phone']?.toString() ?? '',
    );
    String role = member?['merchant_role']?.toString() ?? 'staff';
    bool products = member?['can_manage_products'] == true,
        orders = member?['can_manage_orders'] != false,
        finance = member?['can_view_finance'] == true,
        active = member?['is_active'] != false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          title: Text(member == null ? 'إضافة موظف' : 'تعديل صلاحيات الموظف'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'اسم الموظف *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف *',
                      hintText: '01xxxxxxxxx',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    items: const [
                      DropdownMenuItem(value: 'staff', child: Text('موظف')),
                      DropdownMenuItem(
                        value: 'manager',
                        child: Text('مدير متجر'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setD(() => role = v);
                    },
                    decoration: const InputDecoration(labelText: 'الدور'),
                  ),
                  CheckboxListTile(
                    value: orders,
                    onChanged: (v) => setD(() => orders = v ?? false),
                    title: const Text('إدارة الطلبات'),
                  ),
                  CheckboxListTile(
                    value: products,
                    onChanged: (v) => setD(() => products = v ?? false),
                    title: const Text('إدارة المنتجات والأسعار'),
                  ),
                  CheckboxListTile(
                    value: finance,
                    onChanged: (v) => setD(() => finance = v ?? false),
                    title: const Text('عرض الحسابات والتسويات'),
                  ),
                  SwitchListTile(
                    value: active,
                    onChanged: (v) => setD(() => active = v),
                    title: const Text('الحساب مفعل'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حفظ الصلاحيات'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      try {
        await SupabaseService.instance.saveMerchantStaff(
          membershipId: member?['id']?.toString(),
          phone: phone.text,
          fullName: name.text,
          role: role,
          canManageProducts: products,
          canManageOrders: orders,
          canViewFinance: finance,
          active: active,
        );
        await _load();
      } catch (_) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تعذر حفظ الموظف. تأكد من الرقم والصلاحيات.'),
            ),
          );
      }
    }
    name.dispose();
    phone.dispose();
  }

  String _merchantRole(dynamic role) => role == 'owner'
      ? 'مالك المتجر'
      : role == 'manager'
      ? 'مدير'
      : 'موظف';
  String _permissionText(Map<String, dynamic> m) {
    final p = <String>[];
    if (m['can_manage_orders'] == true) p.add('الطلبات');
    if (m['can_manage_products'] == true) p.add('المنتجات');
    if (m['can_view_finance'] == true) p.add('الحسابات');
    return p.isEmpty ? 'بدون صلاحيات' : p.join(' • ');
  }

  Widget _financeTab() {
    final canView =
        _membership?['merchant_role'] == 'owner' ||
        _membership?['can_view_finance'] == true;
    if (!canView) {
      return _message(
        'ليس لديك صلاحية عرض الحسابات والتسويات',
        Icons.lock_outline_rounded,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _summaryCard(),
        const SizedBox(height: 12),
        const Text(
          'كشوف التسوية اليومية',
          style: TextStyle(
            fontFamily: 'Cairo',
            color: AppTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        if (_settlements.isEmpty)
          _message('لا توجد تسويات محسوبة بعد', Icons.account_balance_outlined)
        else
          ..._settlements.map(
            (s) => Card(
              color: AppTheme.surface,
              child: ListTile(
                title: Text(
                  s['business_date']?.toString() ?? '',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  '${_direction(s['direction'])} • ${_statusText(s['status'])}',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: AppTheme.textSecondary,
                  ),
                ),
                trailing: Text(
                  _money((s['balance'] as num?)?.abs()),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: AppTheme.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _summaryCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.gold.withValues(alpha: .35)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'قواعد حساب متجرك',
          style: TextStyle(
            fontFamily: 'Cairo',
            color: AppTheme.gold,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'عمولة فيتو: ${_store?['commission_percent'] ?? 0}%',
          style: const TextStyle(
            fontFamily: 'Cairo',
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          'طريقة الصرف: ${_store?['settlement_payout_method'] ?? 'لم تُحدد'}',
          style: const TextStyle(
            fontFamily: 'Cairo',
            color: AppTheme.textPrimary,
          ),
        ),
        if ((_store?['settlement_payout_details']?.toString() ?? '').isNotEmpty)
          Text(
            _store!['settlement_payout_details'].toString(),
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: AppTheme.textSecondary,
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _editPayout,
          icon: const Icon(Icons.edit_rounded),
          label: const Text('تحديد طريقة استلام المستحقات'),
        ),
        const Text(
          'التسوية تُحسب آليًا بعد منتصف الليل. الصرف أو التحصيل لا يُعتبر منفذًا إلا بعد تسجيل الإدارة لمرجع العملية.',
          style: TextStyle(fontFamily: 'Cairo', color: AppTheme.textSecondary),
        ),
      ],
    ),
  );

  Future<void> _editPayout() async {
    String method =
        _store?['settlement_payout_method']?.toString() ?? 'instapay';
    final details = TextEditingController(
      text: _store?['settlement_payout_details']?.toString() ?? '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('طريقة استلام مستحقات المتجر'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: method,
                items: const [
                  DropdownMenuItem(value: 'instapay', child: Text('InstaPay')),
                  DropdownMenuItem(
                    value: 'mobile_wallet',
                    child: Text('محفظة موبايل'),
                  ),
                  DropdownMenuItem(
                    value: 'bank_account',
                    child: Text('حساب بنكي'),
                  ),
                  DropdownMenuItem(value: 'manual', child: Text('تسوية يدوية')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => method = value);
                  }
                },
              ),
              TextField(
                controller: details,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'الرقم أو بيانات الحساب',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && details.text.trim().isNotEmpty) {
      await SupabaseService.instance.updateMerchantPayout(
        method: method,
        details: details.text.trim(),
      );
      await _load();
    }
    details.dispose();
  }

  Widget _message(String text, IconData icon) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 46),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
  Widget _line(String label, dynamic value, {bool strong = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: strong ? AppTheme.textPrimary : AppTheme.textSecondary,
              fontWeight: strong ? FontWeight.w800 : FontWeight.normal,
            ),
          ),
        ),
        Text(
          _money(value),
          style: TextStyle(
            fontFamily: 'Cairo',
            color: strong ? AppTheme.gold : AppTheme.textPrimary,
            fontWeight: strong ? FontWeight.w800 : FontWeight.normal,
          ),
        ),
      ],
    ),
  );
  Widget _status(String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: AppTheme.gold.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      _statusText(value),
      style: const TextStyle(
        fontFamily: 'Cairo',
        color: AppTheme.gold,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
  String _money(dynamic value) =>
      '${((value as num?)?.toDouble() ?? double.tryParse(value?.toString() ?? '') ?? 0).toStringAsFixed(2)} ج';
  String _statusText(dynamic s) =>
      const {
        'pending': 'جديد',
        'confirmed': 'مقبول',
        'preparing': 'قيد التجهيز',
        'ready_for_pickup': 'جاهز للاستلام',
        'captain_assigned': 'تم تعيين كابتن',
        'picked_up': 'استلمه الكابتن',
        'on_the_way': 'في الطريق',
        'delivered': 'تم التسليم',
        'cancelled': 'ملغي',
        'calculated': 'محسوبة',
        'paid': 'تم الصرف',
        'collected': 'تم التحصيل',
      }[s?.toString()] ??
      s?.toString() ??
      '';
  String _direction(dynamic d) => d == 'pay_store'
      ? 'مستحق للصرف'
      : d == 'collect_from_store'
      ? 'مطلوب للتحصيل'
      : 'الحساب متعادل';
}

