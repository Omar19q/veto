import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/wallet_topup_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/admin_theme.dart';

Color get _bg => AdminTheme.background;
Color get _surface => AdminTheme.surface;
Color get _gold => AdminTheme.gold;
Color get _light => AdminTheme.ink;
Color get _muted => AdminTheme.muted;

class AdminTopupPanel extends StatefulWidget {
  final int initialTab;
  final String? initialRequestId;
  const AdminTopupPanel({
    super.key,
    this.initialTab = 0,
    this.initialRequestId,
  });
  @override
  State<AdminTopupPanel> createState() => _AdminTopupPanelState();
}

class _AdminTopupPanelState extends State<AdminTopupPanel>
    with SingleTickerProviderStateMixin {
  final _svc = WalletTopupService.instance;
  late final TabController _tabs;
  List<Map<String, dynamic>> _requests = [], _offers = [], _methods = [];
  bool _loading = true;
  String? _error;
  bool _initialOpened = false;
  Timer? _timer;
  RealtimeChannel? _channel;
  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _load();
    _channel = _svc.watchRequests(_load);
    _timer = Timer.periodic(Duration(seconds: 25), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _channel?.unsubscribe();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final requests = await _svc.requests(admin: true);
      final offers = await _svc.offers(admin: true);
      final methods = await _svc.methods();
      if (mounted) {
        setState(() {
          _requests = requests;
          _offers = offers;
          _methods = methods;
          _loading = false;
          _error = null;
        });
        if (!_initialOpened && widget.initialRequestId != null) {
          _initialOpened = true;
          for (final request in requests) {
            if (request['id'] == widget.initialRequestId) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _showReview(request);
              });
              break;
            }
          }
        }
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = 'تعذر تحميل بيانات الشحن: $e';
        });
    }
  }

  void _message(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text, style: TextStyle(fontFamily: 'Cairo')),
        ),
      );
  }

  Text _text(String s, {double size = 13, Color? color, bool bold = false}) =>
      Text(
        s,
        style: TextStyle(
          fontFamily: 'Cairo',
          color: color ?? _light,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          fontSize: size,
        ),
      );
  Widget _tile(Widget child) => Container(
    margin: EdgeInsets.only(bottom: 10),
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AdminTheme.border),
    ),
    child: child,
  );
  Widget _action(String s, VoidCallback? cb, {bool outlined = false}) =>
      OutlinedButton(
        onPressed: cb,
        style: OutlinedButton.styleFrom(
          foregroundColor: outlined ? _light : _bg,
          backgroundColor: outlined ? null : _gold,
          side: BorderSide(color: outlined ? AdminTheme.border : _gold),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        child: Text(
          s,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      );
  Widget _header(String name, String button, VoidCallback onAdd) => Padding(
    padding: EdgeInsets.only(bottom: 14),
    child: Wrap(
      spacing: 14,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [_text(name, size: 22, bold: true), _action(button, onAdd)],
    ),
  );
  Widget _requestsView() {
    final pending = _requests.where((r) => r['status'] == 'pending').toList();
    return ListView(
      padding: EdgeInsets.all(18),
      children: [
        _text('طلبات شحن المحفظة', size: 22, bold: true),
        _text(
          'قرار الموظف يتم على السيرفر مرة واحدة فقط. افحص وصول التحويل لدى مزود الدفع قبل الاعتماد.',
          color: _muted,
          size: 12,
        ),
        SizedBox(height: 12),
        _tile(
          Row(
            children: [
              Icon(Icons.pending_actions_rounded, color: _gold),
              SizedBox(width: 10),
              Expanded(child: _text('طلبات المراجعة المعروضة', bold: true)),
              _text(
                '${pending.length} طلب',
                size: 22,
                color: _gold,
                bold: true,
              ),
            ],
          ),
        ),
        if (_requests.isEmpty)
          _tile(_text('لا توجد طلبات شحن حتى الآن.', color: _muted)),
        ..._requests.map(
          (r) => _tile(
            Row(
              children: [
                Icon(
                  r['status'] == 'approved'
                      ? Icons.check_circle
                      : r['status'] == 'rejected'
                      ? Icons.cancel
                      : Icons.hourglass_top,
                  color: r['status'] == 'approved'
                      ? AdminTheme.goldDark
                      : r['status'] == 'rejected'
                      ? AdminTheme.error
                      : _gold,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _text('${r['reference']}', bold: true, size: 14),
                      _text(
                        '${r['paid_amount']} جنيه مدفوع + ${r['bonus_amount']} جنيه مكافأة',
                        color: _gold,
                        size: 12,
                      ),
                      _text(
                        '${r['method_name']} • ${r['created_at'].toString().replaceFirst('T', ' ').split('.').first}',
                        color: _muted,
                        size: 11,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 6),
                _action(
                  r['status'] == 'pending' ? 'مراجعة' : 'تفاصيل',
                  () => _showReview(r),
                  outlined: r['status'] != 'pending',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showReview(Map<String, dynamic> request) async {
    List<Map<String, dynamic>> log = [];
    String? name;
    try {
      log = await _svc.decisions(request['id'].toString());
      if (request['reviewed_by'] != null) {
        final profile = await SupabaseService.instance.getUserProfile(
          request['reviewed_by'].toString(),
        );
        name = profile?['full_name']?.toString();
      }
    } catch (e) {
      _message('تعذر تحميل سجل القرارات: $e');
    }
    if (!mounted) return;
    final note = TextEditingController();
    bool verified = false, busy = false;
    final isPending = request['status'] == 'pending';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refresh) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: _surface,
            title: _text('مراجعة طلب الشحن', size: 19, bold: true),
            content: SizedBox(
              width: 510,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _tile(
                      Column(
                        children: [
                          _detail('الرقم المرجعي', '${request['reference']}'),
                          _detail('وقت الاستلام', '${request['created_at']}'),
                          _detail(
                            'المبلغ المدفوع',
                            '${request['paid_amount']} جنيه',
                          ),
                          _detail(
                            'المكافأة الترويجية',
                            '${request['bonus_amount']} جنيه',
                          ),
                          _detail('وسيلة الدفع', '${request['method_name']}'),
                          _detail(
                            'رقم التحويل المستهدف',
                            '${request['transfer_destination']}',
                          ),
                          _detail(
                            'الرقم المحوّل منه',
                            '${request['sender_number']}',
                          ),
                          _detail(
                            'رقم العملية',
                            '${request['operation_number'] ?? 'لم يُقدّم'}',
                          ),
                          _detail('الحالة', '${request['status']}'),
                          if (name != null) _detail('اسم الموظف المراجع', name),
                          if (request['reviewed_at'] != null)
                            _detail('وقت القرار', '${request['reviewed_at']}'),
                          if (request['review_note'] != null)
                            _detail(
                              'ملاحظات القرار',
                              '${request['review_note']}',
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    _text('سجل القرارات', size: 16, color: _gold, bold: true),
                    ...log.map(
                      (entry) => _tile(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _text(
                              '${entry['action']} • ${entry['created_at']}',
                              size: 11,
                              bold: true,
                            ),
                            _text(
                              'معرّف الموظف/المستخدم: ${entry['actor_id']}',
                              color: _muted,
                              size: 10,
                            ),
                            if (entry['note'] != null)
                              _text(
                                '${entry['note']}',
                                color: _muted,
                                size: 11,
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (isPending) ...[
                      _text(
                        'تنبيه أمان: لا تَقبل الطلب بناءً على رقم العملية فقط؛ تحقق من دخول المبلغ فعليًا إلى حساب الشركة.',
                        size: 12,
                        color: _gold,
                        bold: true,
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        activeColor: _gold,
                        title: _text(
                          'تحققت بنفسي من وصول التحويل والمبلغ والجهة المستقبلة.',
                          size: 12,
                        ),
                        value: verified,
                        onChanged: busy
                            ? null
                            : (v) => refresh(() => verified = v ?? false),
                      ),
                      TextField(
                        controller: note,
                        style: TextStyle(fontFamily: 'Cairo', color: _light),
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'ملاحظة / سبب الرفض (إلزامي عند الرفض)',
                          labelStyle: TextStyle(
                            fontFamily: 'Cairo',
                            color: _muted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              _action(
                'إغلاق',
                () => Navigator.pop(dialogContext),
                outlined: true,
              ),
              if (isPending) ...[
                _action(
                  'رفض الطلب',
                  busy
                      ? null
                      : () async {
                          if (note.text.trim().isEmpty) {
                            _message('اكتب سبب الرفض أولًا.');
                            return;
                          }
                          await _decide(
                            request,
                            false,
                            note.text,
                            dialogContext,
                            refresh,
                            () => busy = true,
                            () => busy = false,
                          );
                        },
                  outlined: true,
                ),
                _action(
                  busy ? 'جارٍ التنفيذ' : 'قبول الطلب',
                  busy || !verified
                      ? null
                      : () async {
                          await _decide(
                            request,
                            true,
                            note.text,
                            dialogContext,
                            refresh,
                            () => busy = true,
                            () => busy = false,
                          );
                        },
                ),
              ],
            ],
          ),
        ),
      ),
    );
    // Dialog builder can close normally; controllers are not used beyond the dialog.
    note.dispose();
  }

  Widget _detail(String label, String value) => Padding(
    padding: EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _text(label, color: _muted, size: 11)),
        Flexible(
          child: SelectableText(
            value,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: _light,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
  Future<void> _decide(
    Map<String, dynamic> request,
    bool approve,
    String note,
    BuildContext dialogContext,
    StateSetter refresh,
    VoidCallback start,
    VoidCallback end,
  ) async {
    refresh(start);
    try {
      await _svc.review(request['id'].toString(), approve, note);
      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
      _message(
        approve
            ? 'تم اعتماد الطلب وإضافة الرصيد مرة واحدة.'
            : 'تم رفض الطلب وتسجيل السبب.',
      );
      await _load();
    } catch (e) {
      _message('تعذر إتمام القرار. لم تُحدَّث الحالة: $e');
      if (dialogContext.mounted) refresh(end);
    }
  }

  Widget _offersView() => ListView(
    padding: EdgeInsets.all(18),
    children: [
      _header('إدارة عروض الشحن', '+ إضافة عرض', () => _offerDialog(null)),
      _tile(
        _text(
          'المبلغ المدفوع والمكافأة الترويجية يُسجلان في معاملتين منفصلتين بعد الموافقة فقط. العروض الجديدة تبدأ متوقفة.',
          size: 12,
          color: _gold,
        ),
      ),
      if (_offers.isEmpty)
        _tile(_text('لا توجد عروض حتى الآن.', color: _muted)),
      ..._offers.map(
        (r) => _tile(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _text('${r['title']}', size: 16, bold: true),
              SizedBox(height: 8),
              _detail('المبلغ المدفوع', '${r['paid_amount']} جنيه'),
              _detail('المكافأة', '${r['bonus_amount']} جنيه'),
              _detail(
                'المدة',
                '${r['starts_at'] ?? 'بدون بداية'} ← ${r['ends_at'] ?? 'بدون نهاية'}',
              ),
              _detail(
                'الحد الإجمالي للمستفيدين',
                '${r['max_redemptions'] ?? 'بدون حد'}',
              ),
              _detail('الحد لكل عميل', '${r['per_customer_limit']} مرة'),
              _detail('حالة العرض', r['is_active'] == true ? 'مفعّل' : 'موقوف'),
              Wrap(
                spacing: 8,
                children: [
                  _action('تعديل', () => _offerDialog(r)),
                  _action(r['is_active'] == true ? 'إيقاف' : 'تفعيل', () async {
                    try {
                      await _svc.saveOffer({
                        'is_active': r['is_active'] != true,
                      }, id: r['id'].toString());
                      await _load();
                    } catch (e) {
                      _message('تعذر تحديث العرض: $e');
                    }
                  }, outlined: true),
                ],
              ),
            ],
          ),
        ),
      ),
    ],
  );
  Future<void> _offerDialog(Map<String, dynamic>? old) async {
    final title = TextEditingController(text: old?['title']?.toString() ?? '');
    final paid = TextEditingController(
      text: old?['paid_amount']?.toString() ?? '',
    );
    final bonus = TextEditingController(
      text: old?['bonus_amount']?.toString() ?? '0',
    );
    final max = TextEditingController(
      text: old?['max_redemptions']?.toString() ?? '',
    );
    final per = TextEditingController(
      text: old?['per_customer_limit']?.toString() ?? '1',
    );
    final start = TextEditingController(
      text: old?['starts_at']?.toString() ?? '',
    );
    final end = TextEditingController(text: old?['ends_at']?.toString() ?? '');
    bool active = old?['is_active'] == true, busy = false;
    await showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, refresh) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: _surface,
            title: _text(
              old == null ? 'إضافة عرض شحن' : 'تعديل عرض الشحن',
              size: 18,
              bold: true,
            ),
            content: SizedBox(
              width: 430,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _edit(title, 'اسم العرض'),
                    _edit(paid, 'مبلغ الشحن بالجنيه', numeric: true),
                    _edit(bonus, 'قيمة المكافأة بالجنيه', numeric: true),
                    _edit(
                      max,
                      'الحد الإجمالي للمستفيدين (اختياري)',
                      numeric: true,
                    ),
                    _edit(per, 'الحد لكل عميل', numeric: true),
                    _edit(start, 'البداية ISO أو YYYY-MM-DD (اختياري)'),
                    _edit(end, 'النهاية ISO أو YYYY-MM-DD (اختياري)'),
                    SwitchListTile(
                      activeThumbColor: _gold,
                      title: _text('تفعيل العرض', size: 12),
                      value: active,
                      onChanged: (v) => refresh(() => active = v),
                    ),
                    _text(
                      'راجع ميزانية المكافآت قبل التفعيل؛ لا تُضاف مكافآت إلا للطلبات المعتمدة.',
                      color: _gold,
                      size: 11,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              _action('إلغاء', () => Navigator.pop(c), outlined: true),
              _action(
                busy ? 'حفظ...' : 'حفظ العرض',
                busy
                    ? null
                    : () async {
                        final a = double.tryParse(paid.text.trim()),
                            b = double.tryParse(bonus.text.trim());
                        final p = int.tryParse(per.text.trim()),
                            m = max.text.trim().isEmpty
                                ? null
                                : int.tryParse(max.text.trim());
                        DateTime? s, e;
                        if (start.text.trim().isNotEmpty)
                          s = DateTime.tryParse(start.text.trim());
                        if (end.text.trim().isNotEmpty)
                          e = DateTime.tryParse(end.text.trim());
                        if (title.text.trim().length < 3 ||
                            a == null ||
                            a <= 0 ||
                            a > 1000000 ||
                            b == null ||
                            b < 0 ||
                            p == null ||
                            p < 1 ||
                            (max.text.trim().isNotEmpty &&
                                (m == null || m < 1)) ||
                            (start.text.trim().isNotEmpty && s == null) ||
                            (end.text.trim().isNotEmpty && e == null) ||
                            (s != null && e != null && !e.isAfter(s))) {
                          _message('راجع الاسم والمبالغ والحدود والتواريخ.');
                          return;
                        }
                        refresh(() => busy = true);
                        try {
                          await _svc.saveOffer({
                            'title': title.text.trim(),
                            'paid_amount': a,
                            'bonus_amount': b,
                            'max_redemptions': m,
                            'per_customer_limit': p,
                            'is_active': active,
                            'starts_at': s?.toUtc().toIso8601String(),
                            'ends_at': e?.toUtc().toIso8601String(),
                          }, id: old?['id']?.toString());
                          if (c.mounted) Navigator.pop(c);
                          await _load();
                          _message('تم حفظ إعدادات العرض.');
                        } catch (ex) {
                          _message('تعذر حفظ العرض: $ex');
                          if (c.mounted) refresh(() => busy = false);
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
    title.dispose();
    paid.dispose();
    bonus.dispose();
    max.dispose();
    per.dispose();
    start.dispose();
    end.dispose();
  }

  Widget _edit(
    TextEditingController ctl,
    String label, {
    bool numeric = false,
    int lines = 1,
  }) => Padding(
    padding: EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: ctl,
      maxLines: lines,
      keyboardType: numeric
          ? TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: TextStyle(fontFamily: 'Cairo', color: _light),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontFamily: 'Cairo', color: _muted),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: _muted),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: _gold),
        ),
      ),
    ),
  );
  Widget _methodsView() => ListView(
    padding: EdgeInsets.all(18),
    children: [
      _header('وسائل الدفع', '+ إضافة وسيلة دفع', () => _methodDialog(null)),
      _tile(
        _text(
          'أدخل رقم التحويل الحقيقي وتعليماته قبل تفعيل الوسيلة. يمكنك إخفاؤها دون تعديل الكود.',
          color: _gold,
          size: 12,
        ),
      ),
      if (_methods.isEmpty)
        _tile(
          _text(
            'لا توجد وسائل دفع مضافة. لا يستطيع العميل إرسال طلب شحن حتى تُضاف وسيلة نشطة.',
            color: _muted,
          ),
        ),
      ..._methods.map(
        (r) => _tile(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if ((r['image_url'] ?? '').toString().startsWith('https://'))
                    Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Image.network(
                        r['image_url'].toString(),
                        height: 42,
                        width: 42,
                        errorBuilder: (_, __, ___) =>
                            Icon(Icons.account_balance_wallet, color: _gold),
                      ),
                    ),
                  Expanded(child: _text('${r['name']}', size: 17, bold: true)),
                  _text(
                    r['is_active'] == true ? 'متاحة للعملاء' : 'مخفية',
                    color: r['is_active'] == true
                        ? AdminTheme.goldDark
                        : _muted,
                    size: 11,
                  ),
                ],
              ),
              _detail('رقم التحويل أو الحساب', '${r['transfer_number']}'),
              _detail('التعليمات', '${r['instructions']}'),
              Wrap(
                spacing: 8,
                children: [
                  _action('تعديل', () => _methodDialog(r)),
                  _action(r['is_active'] == true ? 'إخفاء' : 'إظهار', () async {
                    try {
                      await _svc.saveMethod({
                        'is_active': r['is_active'] != true,
                      }, id: r['id'].toString());
                      await _load();
                    } catch (e) {
                      _message('تعذر تحديث الوسيلة: $e');
                    }
                  }, outlined: true),
                ],
              ),
            ],
          ),
        ),
      ),
    ],
  );
  Future<void> _methodDialog(Map<String, dynamic>? old) async {
    final name = TextEditingController(text: old?['name']?.toString() ?? '');
    final number = TextEditingController(
      text: old?['transfer_number']?.toString() ?? '',
    );
    final instructions = TextEditingController(
      text: old?['instructions']?.toString() ?? '',
    );
    final order = TextEditingController(
      text: old?['sort_order']?.toString() ?? '0',
    );
    String? existingImage = old?['image_url']?.toString();
    Uint8List? selectedBytes;
    String? selectedExtension;
    String? selectionError;
    bool active = old?['is_active'] == true, busy = false;
    await showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, refresh) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: _surface,
            title: _text(
              old == null ? 'إضافة وسيلة دفع' : 'تعديل وسيلة دفع',
              size: 19,
              bold: true,
            ),
            content: SizedBox(
              width: 410,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _edit(name, 'اسم وسيلة الدفع'),
                    _edit(number, 'رقم التحويل أو الحساب'),
                    _edit(instructions, 'تعليمات التحويل', lines: 3),
                    SizedBox(height: 4),
                    if (selectedBytes != null ||
                        (existingImage != null && existingImage!.isNotEmpty))
                      Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: selectedBytes != null
                              ? Image.memory(
                                  selectedBytes!,
                                  width: 96,
                                  height: 96,
                                  fit: BoxFit.contain,
                                )
                              : Image.network(
                                  existingImage!,
                                  width: 96,
                                  height: 96,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.broken_image_outlined,
                                    color: _muted,
                                    size: 54,
                                  ),
                                ),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () async {
                              try {
                                final picked = await ImagePicker().pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 82,
                                  maxWidth: 1200,
                                );
                                if (picked == null || !c.mounted) return;
                                final filename = picked.name.toLowerCase();
                                final extension = filename.endsWith('.png')
                                    ? 'png'
                                    : filename.endsWith('.webp')
                                    ? 'webp'
                                    : (filename.endsWith('.jpg') ||
                                          filename.endsWith('.jpeg'))
                                    ? 'jpg'
                                    : null;
                                if (extension == null) {
                                  refresh(
                                    () => selectionError =
                                        'اختر صورة بصيغة JPG أو PNG أو WEBP.',
                                  );
                                  return;
                                }
                                final bytes = await picked.readAsBytes();
                                if (!c.mounted) return;
                                if (bytes.isEmpty ||
                                    bytes.length > 5 * 1024 * 1024) {
                                  refresh(
                                    () => selectionError =
                                        'الصورة يجب أن تكون أقل من 5 ميجابايت وغير فارغة.',
                                  );
                                  return;
                                }
                                refresh(() {
                                  selectedBytes = bytes;
                                  selectedExtension = extension;
                                  selectionError = null;
                                });
                              } catch (e) {
                                if (c.mounted)
                                  refresh(
                                    () => selectionError =
                                        'تعذر اختيار الصورة: $e',
                                  );
                              }
                            },
                      icon: Icon(Icons.photo_library_rounded, color: _gold),
                      label: _text(
                        selectedBytes != null ||
                                (existingImage != null &&
                                    existingImage!.isNotEmpty)
                            ? 'تغيير الصورة من المعرض'
                            : 'اختيار صورة من المعرض',
                        color: _gold,
                        bold: true,
                      ),
                    ),
                    if (selectedBytes != null ||
                        (existingImage != null && existingImage!.isNotEmpty))
                      TextButton.icon(
                        onPressed: busy
                            ? null
                            : () => refresh(() {
                                selectedBytes = null;
                                selectedExtension = null;
                                existingImage = null;
                                selectionError = null;
                              }),
                        icon: Icon(
                          Icons.delete_outline,
                          color: AdminTheme.error,
                        ),
                        label: _text(
                          'إزالة الصورة',
                          color: AdminTheme.error,
                          size: 12,
                        ),
                      ),
                    if (selectionError != null)
                      Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: _text(
                          selectionError!,
                          color: AdminTheme.error,
                          size: 12,
                        ),
                      ),
                    _edit(order, 'ترتيب العرض', numeric: true),
                    SwitchListTile(
                      activeThumbColor: _gold,
                      title: _text('إظهار الوسيلة للعملاء', size: 12),
                      value: active,
                      onChanged: busy ? null : (v) => refresh(() => active = v),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              _action(
                'إلغاء',
                busy ? null : () => Navigator.pop(c),
                outlined: true,
              ),
              _action(
                busy ? 'حفظ...' : 'حفظ الوسيلة',
                busy
                    ? null
                    : () async {
                        final sort = int.tryParse(order.text.trim());
                        if (name.text.trim().length < 2 ||
                            number.text.trim().length < 3 ||
                            sort == null) {
                          refresh(
                            () => selectionError =
                                'راجع الاسم ورقم التحويل وترتيب الوسيلة.',
                          );
                          return;
                        }
                        refresh(() {
                          busy = true;
                          selectionError = null;
                        });
                        try {
                          String? imageUrl = existingImage;
                          if (selectedBytes != null) {
                            final extension = selectedExtension!;
                            final contentType = extension == 'png'
                                ? 'image/png'
                                : extension == 'webp'
                                ? 'image/webp'
                                : 'image/jpeg';
                            imageUrl = await SupabaseService.instance
                                .uploadPublicImage(
                                  path:
                                      'topup-methods/${DateTime.now().microsecondsSinceEpoch}.$extension',
                                  bytes: selectedBytes!,
                                  contentType: contentType,
                                );
                          }
                          await _svc.saveMethod({
                            'name': name.text.trim(),
                            'transfer_number': number.text.trim(),
                            'instructions': instructions.text.trim(),
                            'image_url': imageUrl,
                            'sort_order': sort,
                            'is_active': active,
                          }, id: old?['id']?.toString());
                          if (c.mounted) Navigator.pop(c);
                          await _load();
                          _message('تم حفظ وسيلة الدفع.');
                        } catch (ex) {
                          if (c.mounted)
                            refresh(() {
                              busy = false;
                              selectionError =
                                  'تعذر حفظ الوسيلة أو رفع الصورة: $ex';
                            });
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
    name.dispose();
    number.dispose();
    instructions.dispose();
    order.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Column(
      children: [
        Container(
          color: _bg,
          child: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: _gold,
            unselectedLabelColor: _muted,
            indicatorColor: _gold,
            labelStyle: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w800,
            ),
            tabs: [
              Tab(
                text:
                    'طلبات الشحن (${_requests.where((r) => r['status'] == 'pending').length})',
              ),
              Tab(text: 'إدارة العروض'),
              Tab(text: 'وسائل الدفع'),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: _gold))
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _text(_error!, color: AdminTheme.error),
                      _action('إعادة المحاولة', _load),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabs,
                  children: [_requestsView(), _offersView(), _methodsView()],
                ),
        ),
      ],
    ),
  );
}
