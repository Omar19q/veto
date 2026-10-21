import 'package:flutter/material.dart';

import '../../services/supabase_service.dart';
import '../../theme/admin_theme.dart';

class AdminMarketPromosPanel extends StatefulWidget {
  const AdminMarketPromosPanel({super.key});

  @override
  State<AdminMarketPromosPanel> createState() => _AdminMarketPromosPanelState();
}

class _AdminMarketPromosPanelState extends State<AdminMarketPromosPanel> {
  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _promos = [];
  String? _storeId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final service = SupabaseService.instance;
      final stores = await service.getAllSupermarkets();
      final promos = await service.getAdminMarketPromos(
        supermarketId: _storeId,
      );
      if (!mounted) return;
      setState(() {
        _stores = stores;
        _promos = promos;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                value: _storeId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'عرض أكواد متجر محدد',
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('كل المتاجر'),
                  ),
                  ..._stores.map(
                    (store) => DropdownMenuItem<String?>(
                      value: store['id'].toString(),
                      child: Text(store['name']?.toString() ?? 'متجر'),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _storeId = value);
                  _load();
                },
              ),
            ),
            SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _stores.isEmpty ? null : () => _edit(),
              icon: Icon(Icons.add_rounded),
              label: Text('كود جديد'),
            ),
          ],
        ),
      ),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          'أكواد خصم فيتو ماركت ينشئها الأدمن فقط. قيمة الخصم تتحملها المنصة وتظهر في تسوية المتجر.',
          style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.muted),
        ),
      ),
      SizedBox(height: 8),
      Expanded(
        child: _loading
            ? Center(
                child: CircularProgressIndicator(color: AdminTheme.goldDark),
              )
            : _promos.isEmpty
            ? Center(
                child: Text(
                  'لا توجد أكواد خصم للمتاجر.',
                  style: TextStyle(color: AdminTheme.muted),
                ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  padding: EdgeInsets.all(14),
                  itemCount: _promos.length,
                  separatorBuilder: (_, __) => SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final promo = _promos[index];
                    final type = promo['discount_type']?.toString();
                    final value =
                        (promo['discount_value'] as num?)?.toDouble() ?? 0;
                    return ListTile(
                      tileColor: AdminTheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: AdminTheme.borderSoft),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: AdminTheme.goldDark.withValues(alpha: .15),
                        child: Icon(
                          Icons.local_offer_rounded,
                          color: AdminTheme.goldDark,
                        ),
                      ),
                      title: Text(
                        '${promo['code']} — ${promo['supermarket_name'] ?? ''}',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: AdminTheme.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        type == 'percent'
                            ? 'خصم ${value.toStringAsFixed(0)}% • استُخدم ${promo['used_count'] ?? 0} مرة'
                            : 'خصم ${value.toStringAsFixed(2)} ج • استُخدم ${promo['used_count'] ?? 0} مرة',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: AdminTheme.muted,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            promo['is_active'] == true
                                ? Icons.check_circle
                                : Icons.pause_circle,
                            color: promo['is_active'] == true
                                ? Colors.greenAccent
                                : Colors.orange,
                          ),
                          IconButton(
                            onPressed: () => _edit(promo),
                            icon: Icon(Icons.edit_rounded),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
    ],
  );

  Future<void> _edit([Map<String, dynamic>? promo]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _MarketPromoDialog(stores: _stores, promo: promo),
    );
    if (saved == true) await _load();
  }
}

class _MarketPromoDialog extends StatefulWidget {
  const _MarketPromoDialog({required this.stores, this.promo});
  final List<Map<String, dynamic>> stores;
  final Map<String, dynamic>? promo;

  @override
  State<_MarketPromoDialog> createState() => _MarketPromoDialogState();
}

class _MarketPromoDialogState extends State<_MarketPromoDialog> {
  late final TextEditingController _code;
  late final TextEditingController _value;
  late final TextEditingController _minimum;
  late final TextEditingController _maximum;
  late final TextEditingController _maxUses;
  late String _storeId;
  late String _type;
  late bool _active;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final promo = widget.promo;
    _storeId =
        promo?['supermarket_id']?.toString() ??
        widget.stores.first['id'].toString();
    _type = promo?['discount_type']?.toString() ?? 'fixed';
    _active = promo?['is_active'] != false;
    _code = TextEditingController(text: promo?['code']?.toString() ?? '');
    _value = TextEditingController(
      text: promo?['discount_value']?.toString() ?? '',
    );
    _minimum = TextEditingController(
      text: promo?['minimum_subtotal']?.toString() ?? '0',
    );
    _maximum = TextEditingController(
      text: promo?['maximum_discount']?.toString() ?? '',
    );
    _maxUses = TextEditingController(
      text: promo?['max_uses']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _code.dispose();
    _value.dispose();
    _minimum.dispose();
    _maximum.dispose();
    _maxUses.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = double.tryParse(_value.text.trim());
    final minimum = double.tryParse(_minimum.text.trim()) ?? 0;
    final maximum = _maximum.text.trim().isEmpty
        ? null
        : double.tryParse(_maximum.text.trim());
    final maxUses = _maxUses.text.trim().isEmpty
        ? null
        : int.tryParse(_maxUses.text.trim());
    if (_code.text.trim().length < 3 || value == null || value <= 0) {
      setState(() => _error = 'اكتب كودًا صحيحًا وقيمة خصم أكبر من صفر.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await SupabaseService.instance.saveAdminMarketPromo(
        id: widget.promo?['id']?.toString(),
        supermarketId: _storeId,
        code: _code.text,
        discountType: _type,
        discountValue: value,
        minimumSubtotal: minimum,
        maximumDiscount: maximum,
        maxUses: maxUses,
        active: _active,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'تعذر حفظ الكود. تأكد أنه غير مستخدم من قبل.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.promo == null ? 'إضافة كود خصم متجر' : 'تعديل كود الخصم',
    ),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _storeId,
              decoration: InputDecoration(labelText: 'المتجر'),
              items: widget.stores
                  .map(
                    (store) => DropdownMenuItem<String>(
                      value: store['id'].toString(),
                      child: Text(store['name']?.toString() ?? 'متجر'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _storeId = value!),
            ),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: 'الكود'),
            ),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: InputDecoration(labelText: 'نوع الخصم'),
              items: [
                DropdownMenuItem(value: 'fixed', child: Text('مبلغ بالجنيه')),
                DropdownMenuItem(value: 'percent', child: Text('نسبة مئوية')),
              ],
              onChanged: (value) => setState(() => _type = value!),
            ),
            TextField(
              controller: _value,
              keyboardType: TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: 'قيمة الخصم'),
            ),
            TextField(
              controller: _minimum,
              keyboardType: TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: 'أقل قيمة للطلب'),
            ),
            TextField(
              controller: _maximum,
              keyboardType: TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'أقصى خصم — اختياري',
              ),
            ),
            TextField(
              controller: _maxUses,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'عدد مرات الاستخدام — اختياري',
              ),
            ),
            SwitchListTile(
              value: _active,
              onChanged: (value) => setState(() => _active = value),
              title: Text('الكود نشط'),
            ),
            if (_error != null)
              Text(_error!, style: TextStyle(color: AdminTheme.error)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: Text('إلغاء'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: _saving
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text('حفظ'),
      ),
    ],
  );
}
