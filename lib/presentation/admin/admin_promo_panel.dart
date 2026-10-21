import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/admin_theme.dart';

/// V17: real usage totals and customer details come from admin-only database RPCs.
/// Old used_count has a separate unattributed baseline; never fabricate customer names.
class AdminPromoPanel extends StatefulWidget {
  const AdminPromoPanel({super.key});

  @override
  State<AdminPromoPanel> createState() => _AdminPromoPanelState();
}

class _AdminPromoPanelState extends State<AdminPromoPanel> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final raw = await SupabaseService.instance.client.rpc('admin_promo_list_v17');
      if (raw is! List) throw StateError('Unexpected promo list response');
      if (mounted) setState(() {
        _items = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = 'تعذر تحميل البروموكود: $e'; _loading = false; });
    }
  }

  void _message(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg,
      style: TextStyle(fontFamily: 'Cairo'))));
  }

  static String _date(dynamic input) {
    final d = DateTime.tryParse(input?.toString() ?? '')?.toLocal();
    if (d == null) return 'بلا تاريخ';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  static String _saveError(String? error) => switch (error) {
    'admin_required' => 'هذه العملية للأدمن فقط',
    'invalid_code_format' => 'الكود من 3 إلى 32 حرفًا إنجليزيًا أو رقمًا أو - أو _',
    'promo_code_exists' => 'الكود مستخدم بالفعل',
    'invalid_discount' => 'حدد قيمة خصم صحيحة (جنيه أو نسبة فقط)',
    'invalid_limits' => 'الحدود لازم تكون أعدادًا صحيحة أكبر من صفر',
    'invalid_expiry' => 'الانتهاء لازم يكون بعد بداية العرض',
    'limit_below_existing_uses' => 'الحد الإجمالي أقل من عدد الاستخدامات الحالية',
    'limit_below_existing_customers' => 'حد الأشخاص أقل من عدد الأشخاص الحالي',
    'promo_legacy_people_unknown' => 'الكود القديم له استخدامات غير منسوبة؛ أنشئ كودًا جديدًا لحد الأشخاص',
    'code_cannot_change' => 'لا يمكن تغيير اسم كود مستخدم؛ أنشئ كودًا جديدًا',
    'promo_not_found' => 'الكود لم يعد موجودًا',
    _ => 'لم يتم الحفظ: ${error ?? 'خطأ غير معروف'}',
  };

  Future<void> _edit([Map<String, dynamic>? current]) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PromoEditor(initial: current),
    );
    if (changed == true) _load();
  }

  Future<void> _toggle(Map<String, dynamic> p, bool active) async {
    try {
      final raw = await SupabaseService.instance.client.rpc('admin_promo_save_v17', params: {
        'p_id': p['id'], 'p_code': p['code'],
        'p_discount_amount': p['discount_amount'],
        'p_discount_percent': p['discount_percent'],
        'p_max_uses': p['max_uses'], 'p_per_user_limit': p['per_user_limit'],
        'p_max_customers': p['max_customers'],
        'p_valid_from': p['valid_from'], 'p_valid_until': p['valid_until'],
        'p_is_active': active,
      });
      final result = Map<String, dynamic>.from(raw as Map);
      if (result['success'] != true) throw StateError(_saveError(result['error']?.toString()));
      _load();
    } catch (e) {
      _message('تعذر تغيير حالة الكود: $e');
    }
  }

  Future<void> _uses(Map<String, dynamic> p) async {
    await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      backgroundColor: AdminTheme.surface,
      title: Text('مَن استخدم ${p['code']}؟',
        style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.goldDark)),
      content: SizedBox(
        width: 620,
        height: MediaQuery.sizeOf(dialogContext).height * .60,
        child: FutureBuilder<dynamic>(
          future: SupabaseService.instance.client.rpc('admin_promo_uses_v17',
            params: {'p_promo_id': p['id'], 'p_limit': 500}),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text('تعذر عرض السجل: ${snapshot.error}',
              style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.error));
            if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
            final raw = snapshot.data;
            if (raw is! List) return Text('استجابة غير متوقعة');
            final rows = raw.map((r) => Map<String, dynamic>.from(r as Map)).toList();
            if (rows.isEmpty) return Center(child: Text(
              (p['v17_legacy_count'] as num? ?? 0) > 0
                ? 'لا توجد أسماء مؤكدة للاستخدامات القديمة. السجل التفصيلي يبدأ من V17.'
                : 'لم يُستخدم هذا الكود حتى الآن.',
              style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.muted),
              textAlign: TextAlign.center,
            ));
            return Column(children: [
              if ((p['v17_legacy_count'] as num? ?? 0) > 0)
                Padding(padding: EdgeInsets.only(bottom: 10), child: Text(
                  'ملاحظة: الاستخدامات السابقة على V17 غير مرتبطة بأسماء مؤكدة.',
                  style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.goldDark, fontSize: 12))),
              Expanded(child: ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) => Divider(color: AdminTheme.borderSoft),
                itemBuilder: (_, i) {
                  final r = rows[i];
                  return ListTile(
                    title: Text(r['customer_name']?.toString() ?? 'عميل',
                      style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink)),
                    subtitle: Text('${r['customer_phone'] ?? ''}  |  ${_date(r['redeemed_at'])}\n'
                      'الرحلة: ${r['trip_id']} (${r['trip_status']})',
                      style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.muted, fontSize: 11)),
                    trailing: Text('- ${r['discount']} ج', style: TextStyle(
                      fontFamily: 'Cairo', color: AdminTheme.goldDark, fontWeight: FontWeight.bold)),
                  );
                },
              )),
              if (rows.length == 500) Text('يُعرض أحدث 500 استخدام فقط',
                style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.muted)),
            ]);
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext),
        child: Text('إغلاق', style: TextStyle(fontFamily: 'Cairo')))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(padding: EdgeInsets.all(14), child: Row(children: [
        Expanded(child: Text('إدارة البروموكود', style: TextStyle(fontFamily: 'Cairo',
          fontSize: 18, fontWeight: FontWeight.bold, color: AdminTheme.ink))),
        IconButton(onPressed: _load, icon: Icon(Icons.refresh, color: AdminTheme.goldDark),
          tooltip: 'تحديث'),
        ElevatedButton.icon(onPressed: () => _edit(),
          icon: Icon(Icons.add), label: Text('كود جديد', style: TextStyle(fontFamily: 'Cairo')),
          style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.goldDark,
            foregroundColor: AppTheme.primary)),
      ])),
      Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text(
        'عدد الأشخاص = حسابات مختلفة، وعدد الاستخدامات = إجمالي الرحلات التي حجزت بالكود. '
        'الاستخدام يُحسب عند إنشاء الرحلة، حتى لو أُلغيت لاحقًا.',
        style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AdminTheme.muted))),
      SizedBox(height: 8),
      Expanded(child: _loading ? Center(child: CircularProgressIndicator(color: AdminTheme.goldDark))
        : _error != null ? Center(child: SelectableText(_error!,
            style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.error)))
        : _items.isEmpty ? Center(child: Text('لا توجد أكواد. اضغط كود جديد.',
            style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.muted)))
        : ListView.builder(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: _items.length, itemBuilder: (context, index) {
              final p = _items[index];
              final used = (p['used_count'] as num?)?.toInt() ?? 0;
              final people = (p['tracked_customers'] as num?)?.toInt() ?? 0;
              final legacy = (p['v17_legacy_count'] as num?)?.toInt() ?? 0;
              final expiry = DateTime.tryParse(p['valid_until']?.toString() ?? '');
              final expired = expiry != null && !expiry.isAfter(DateTime.now());
              final active = p['is_active'] == true;
              final discount = p['discount_percent'] != null
                ? '${p['discount_percent']}%' : '${p['discount_amount']} ج';
              return Card(color: AdminTheme.surface, margin: EdgeInsets.only(bottom: 10),
                child: Padding(padding: EdgeInsets.all(12), child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('${p['code']}  •  $discount', style: TextStyle(
                      fontFamily: 'Cairo', color: AdminTheme.goldDark, fontWeight: FontWeight.bold, fontSize: 16))),
                    IconButton(tooltip: 'تعديل', onPressed: () => _edit(p),
                      icon: Icon(Icons.edit_outlined, color: AdminTheme.ink)),
                    Switch(value: active, onChanged: (v) => _toggle(p, v),
                      activeThumbColor: AdminTheme.goldDark),
                  ]),
                  Text(expired ? 'منتهي' : active ? 'نشط' : 'موقوف',
                    style: TextStyle(fontFamily: 'Cairo',
                      color: expired ? AdminTheme.error : active ? AppTheme.successLight : AdminTheme.muted)),
                  SizedBox(height: 5),
                  Text('الاستخدامات: $used / ${p['max_uses'] ?? 'غير محدود'}   |   '
                    'الأشخاص المؤكدون: $people / ${p['max_customers'] ?? 'غير محدود'}',
                    style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink, fontSize: 12)),
                  Text('لكل عميل: ${p['per_user_limit'] ?? 1} مرة   |   '
                    'ينتهي: ${p['valid_until'] == null ? 'بلا انتهاء' : _date(p['valid_until'])}',
                    style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.muted, fontSize: 12)),
                  if (legacy > 0) Padding(padding: EdgeInsets.only(top: 6),
                    child: Text('تنبيه: $legacy استخدام قديم بلا أسماء موثّقة. '
                      'حد الأشخاص للأكواد القديمة يحتاج كودًا جديدًا.',
                      style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.goldDark, fontSize: 11))),
                  Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                    onPressed: () => _uses(p), icon: Icon(Icons.people_alt_outlined),
                    label: Text('عرض العملاء وسجل الاستخدام',
                      style: TextStyle(fontFamily: 'Cairo')))),
                ])));
            })),
    ]);
  }
}

class _PromoEditor extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const _PromoEditor({this.initial});

  @override
  State<_PromoEditor> createState() => _PromoEditorState();
}

class _PromoEditorState extends State<_PromoEditor> {
  late final TextEditingController _code;
  late final TextEditingController _value;
  late final TextEditingController _uses;
  late final TextEditingController _people;
  late final TextEditingController _perPerson;
  late String _kind;
  late DateTime _starts;
  DateTime? _expires;
  late bool _active;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    String val(dynamic v) => v == null ? '' : v.toString();
    _kind = p?['discount_percent'] != null ? 'percent' : 'amount';
    _code = TextEditingController(text: val(p?['code']));
    _value = TextEditingController(text: val(p?[_kind == 'percent' ? 'discount_percent' : 'discount_amount']));
    _uses = TextEditingController(text: val(p?['max_uses']));
    _people = TextEditingController(text: val(p?['max_customers']));
    _perPerson = TextEditingController(text: val(p?['per_user_limit'] ?? 1));
    _starts = DateTime.tryParse(p?['valid_from']?.toString() ?? '')?.toLocal() ?? DateTime.now();
    _expires = DateTime.tryParse(p?['valid_until']?.toString() ?? '')?.toLocal();
    _active = p?['is_active'] == true || p == null;
  }

  @override
  void dispose() {
    for (final ctrl in [_code, _value, _uses, _people, _perPerson]) { ctrl.dispose(); }
    super.dispose();
  }

  int? _intOrNull(TextEditingController c) => c.text.trim().isEmpty ? null : int.tryParse(c.text.trim());
  String _date(DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  Future<void> _pickExpiry() async {
    final date = await showDatePicker(context: context, initialDate: _expires ?? DateTime.now(),
      firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (date == null || !mounted) return;
    setState(() => _expires = DateTime(date.year, date.month, date.day, 23, 59, 59));
  }

  Future<void> _save() async {
    final amount = double.tryParse(_value.text.trim());
    final perUser = int.tryParse(_perPerson.text.trim());
    final uses = _intOrNull(_uses);
    final people = _intOrNull(_people);
    if (_code.text.trim().isEmpty || amount == null || amount <= 0 ||
      (_kind == 'percent' && amount > 100) || perUser == null || perUser < 1 ||
      (_uses.text.trim().isNotEmpty && (uses == null || uses < 1)) ||
      (_people.text.trim().isNotEmpty && (people == null || people < 1))) {
      setState(() => _error = 'راجع الكود والخصم والحدود. كل الأعداد لازم تكون صحيحة وموجبة.');
      return;
    }
    if (_expires != null && !_expires!.isAfter(_starts)) {
      setState(() => _error = 'تاريخ الانتهاء لازم يكون بعد بداية العرض.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final raw = await SupabaseService.instance.client.rpc('admin_promo_save_v17', params: {
        'p_id': widget.initial?['id'],
        'p_code': _code.text.trim().toUpperCase(),
        'p_discount_amount': _kind == 'amount' ? amount : null,
        'p_discount_percent': _kind == 'percent' ? amount : null,
        'p_max_uses': uses, 'p_per_user_limit': perUser, 'p_max_customers': people,
        'p_valid_from': _starts.toUtc().toIso8601String(),
        'p_valid_until': _expires?.toUtc().toIso8601String(),
        'p_is_active': _active,
      });
      final result = Map<String, dynamic>.from(raw as Map);
      if (result['success'] != true) {
        throw StateError(_AdminPromoPanelState._saveError(result['error']?.toString()));
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر الحفظ: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(TextEditingController controller, String label, {bool number = false, bool readonly = false}) =>
    TextField(controller: controller, readOnly: readonly,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
      decoration: InputDecoration(labelText: label, labelStyle: TextStyle(fontFamily: 'Cairo',
        color: AdminTheme.muted), border: OutlineInputBorder()));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(backgroundColor: AdminTheme.surface,
      title: Text(widget.initial == null ? 'إنشاء بروموكود' : 'تعديل ${widget.initial?['code']}',
        style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.goldDark)),
      content: SizedBox(width: 560, child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _field(_code, 'الكود (إنجليزي)', readonly: widget.initial != null),
          SizedBox(height: 12),
          DropdownButtonFormField<String>(value: _kind,
            dropdownColor: AdminTheme.surfaceSoft,
            decoration: InputDecoration(labelText: 'نوع الخصم', border: OutlineInputBorder()),
            style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
            items: [DropdownMenuItem(value: 'amount', child: Text('مبلغ بالجنيه')),
              DropdownMenuItem(value: 'percent', child: Text('نسبة مئوية'))],
            onChanged: (v) { if (v != null) setState(() { _kind = v; _value.clear(); }); }),
          SizedBox(height: 12),
          _field(_value, _kind == 'amount' ? 'قيمة الخصم بالجنيه' : 'الخصم بالنسبة المئوية', number: true),
          SizedBox(height: 12),
          _field(_people, 'عدد الأشخاص المختلفين (اتركه فارغًا بلا حد)', number: true),
          SizedBox(height: 12),
          _field(_perPerson, 'أقصى عدد استخدامات لكل عميل', number: true),
          SizedBox(height: 12),
          _field(_uses, 'إجمالي مرات الاستخدام (اختياري)', number: true),
          SizedBox(height: 10),
          Text('بداية العرض: ${_date(_starts)}',
            style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.muted)),
          Row(children: [
            Expanded(child: Text('الانتهاء: ${_expires == null ? 'بدون تاريخ' : _date(_expires!)}',
              style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink))),
            TextButton(onPressed: _pickExpiry, child: Text('اختيار تاريخ')),
            TextButton(onPressed: () => setState(() => _expires = null),
              child: Text('بدون')),
          ]),
          Text('ينتهي الكود بنهاية اليوم المحدد حسب توقيت جهاز الأدمن.',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AdminTheme.muted)),
          SwitchListTile(value: _active, onChanged: (v) => setState(() => _active = v),
            title: Text('الكود نشط', style: TextStyle(fontFamily: 'Cairo',
              color: AdminTheme.ink))),
          if ((widget.initial?['v17_legacy_count'] as num? ?? 0) > 0)
            Text('هذا الكود له استخدامات قديمة غير منسوبة لأشخاص. '
              'أنشئ كودًا جديدًا إذا أردت حدًا لأول 100 عميل.',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AdminTheme.goldDark)),
          if (_error != null) Padding(padding: EdgeInsets.only(top: 9),
            child: Text(_error!, style: TextStyle(fontFamily: 'Cairo',
              color: AdminTheme.error))),
        ],
      ))),
      actions: [TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false),
        child: Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
        ElevatedButton(onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.goldDark,
            foregroundColor: AppTheme.primary),
          child: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ',
            style: TextStyle(fontFamily: 'Cairo')))],
    );
  }
}
