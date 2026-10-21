import '../../services/admin_directory_pager_v15.dart';
import 'package:flutter/material.dart';
import '../../widgets/admin_copy_button.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/supabase_service.dart';
import '../../theme/admin_theme.dart';
import './admin_captain_form.dart';
import './admin_customer_wallet_history_v46.dart';

/// V16: customer statistics come from trips, not customers.total_completed_trips.
/// All mutations are admin-only RPCs. Auth phone edits use a server Edge Function.
class AdminCustomersPanel extends StatefulWidget {
  const AdminCustomersPanel({super.key});

  @override
  State<AdminCustomersPanel> createState() => _AdminCustomersPanelState();
}

class _AdminCustomersPanelState extends State<AdminCustomersPanel> {
  List<Map<String, dynamic>> _customers = [];
  String _query = '';
  List<Map<String, dynamic>> get _filteredCustomers => _customers.where((c) {
    final text = '${c['full_name'] ?? ''} ${c['phone'] ?? ''}'.toLowerCase();
    return text.contains(_query.trim().toLowerCase());
  }).toList();
  bool _loading = true;
  String? _error;
  TripRealtimeLease? _tripChannel;
  final _pager = AdminDirectoryPagerV15('customer_stats');
  void _syncPage() {
    if (!mounted) return;
    setState(() {
      _customers = List.of(_pager.rows);
      _loading = _pager.loading;
      _error = _pager.error == null ? null : 'تعذر تحديث بيانات العملاء';
    });
  }

  @override
  void initState() {
    super.initState();
    _pager.addListener(_syncPage);
    _load();
    _tripChannel = SupabaseService.instance.subscribeToScaleAdminPulse(() {
      if (mounted && !_pager.loading) _pager.resync();
    });
  }

  @override
  void dispose() {
    _tripChannel?.unsubscribe();
    _pager.dispose();
    super.dispose();
  }

  Future<void> _load() => _pager.refresh();

  void _toast(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: error ? Color(0xFFB63838) : null,
      ),
    );
  }

  String _money(dynamic value) =>
      '${(num.tryParse(value?.toString() ?? '') ?? 0).toStringAsFixed(2)} ج';

  String _date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (parsed == null) return 'غير متاح';
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(parsed.day)}/${pad(parsed.month)}/${parsed.year} '
        '${pad(parsed.hour)}:${pad(parsed.minute)}';
  }

  String _status(dynamic raw) => switch (raw?.toString()) {
    'completed' => 'مكتملة',
    'cancelled' => 'ملغاة',
    'requested' => 'مطلوبة',
    'offer_received' => 'وصلت عروض',
    'accepted' => 'مقبولة',
    'arriving' => 'الكابتن في الطريق',
    'arrived' => 'الكابتن وصل',
    'started' => 'بدأت',
    _ => raw?.toString() ?? 'غير معروف',
  };

  bool _active(Map<String, dynamic> c) => c['account_active'] == true;

  Widget _avatar(Map<String, dynamic> customer, {double size = 44}) {
    final name = customer['full_name']?.toString() ?? '';
    final url = customer['profile_photo_url']?.toString() ?? '';
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AdminTheme.goldDark.withAlpha(35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        name.isNotEmpty ? name.substring(0, 1) : '؟',
        style: TextStyle(
          fontFamily: 'Cairo',
          color: AdminTheme.goldDark,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    if (!url.startsWith('https://')) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }

  Widget _item(String label, String value) => Padding(
    padding: EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: AdminTheme.muted,
              fontSize: 12,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: AdminTheme.ink,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        if (label == 'رقم الهاتف')
          AdminCopyButton(text: value, description: 'رقم العميل'),
      ],
    ),
  );

  Future<void> _details(Map<String, dynamic> fromList) async {
    try {
      final payload = await SupabaseService.instance.getAdminCustomerProfileV16(
        fromList['id'].toString(),
      );
      if (!mounted) return;
      final c = Map<String, dynamic>.from(payload['customer'] as Map);
      final trips = (payload['trips'] as List? ?? [])
          .whereType<Map>()
          .map((x) => Map<String, dynamic>.from(x))
          .toList();
      Map<String, dynamic>? customerExtrasV31;
      try {
        final extras = await SupabaseService.instance.client.rpc(
          'owner_customer_preferences_v31',
          params: {'p_customer_id': c['id'].toString()},
        ).timeout(const Duration(seconds: 7));
        if (extras is Map) customerExtrasV31 = Map<String, dynamic>.from(extras);
      } catch (_) { // Show the V16 account detail even if V31 is not installed.
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AdminTheme.surface,
            title: Row(
              children: [
                _avatar(c),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    c['full_name']?.toString() ?? 'حساب العميل',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: AdminTheme.ink,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: Icon(Icons.close, color: AdminTheme.muted),
                ),
              ],
            ),
            content: SizedBox(
              width: 680,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _item('الحالة', _active(c) ? 'نشط' : 'محظور'),
                    _item('رقم الهاتف', c['phone']?.toString() ?? '—'),
                    if (customerExtrasV31 != null) ...[
                      _item('النوع', customerExtrasV31['gender'] == 'male' ? 'ذكر'
                          : customerExtrasV31['gender'] == 'female' ? 'أنثى' : 'غير محدد'),
                      _item('الإطار المختار',
                        customerExtrasV31['selected_frame']?.toString() ?? 'بدون إطار'),
                      _item('تقييم العميل', customerExtrasV31['rating'] == null
                          ? 'جديد' : '${customerExtrasV31['rating']} ⭐'),
                      _item('اهتمامات الرحلة',
                        (customerExtrasV31['interests'] as List? ?? const []).isEmpty
                            ? 'لا توجد اهتمامات محددة'
                            : (customerExtrasV31['interests'] as List).join(' • ')),
                    ],
                    _item('رصيد العميل', _money(c['wallet_balance'])),
                    const SizedBox(height: 10),
                    ExpansionTile(
                      title: const Text('سجل المحفظة',
                          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
                      children: [AdminCustomerWalletHistoryV46(customerId: c['id'].toString())],
                    ),
                    _item('إجمالي الرحلات', '${c['total_trips'] ?? 0}'),
                    _item('الرحلات المكتملة', '${c['completed_trips'] ?? 0}'),
                    _item('الرحلات الملغاة', '${c['cancelled_trips'] ?? 0}'),
                    _item('إنفاق الرحلات المكتملة', _money(c['total_spent'])),
                    _item('آخر رحلة', _date(c['last_trip_at'])),
                    _item(
                      'فتح الحساب',
                      _date(c['account_created_at'] ?? c['created_at']),
                    ),
                    _item(
                      'نوع الحساب الحالي',
                      '${c['primary_role'] ?? 'customer'}',
                    ),
                    Divider(color: AdminTheme.muted),
                    Text(
                      'أحدث الرحلات (${trips.length} معروضة من إجمالي ${c['total_trips'] ?? 0})',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: AdminTheme.goldDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (trips.isEmpty) _item('الرحلات', 'لا توجد رحلات مسجلة'),
                    ...trips.map(
                      (trip) => Card(
                        color: AdminTheme.surfaceSoft,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _item(
                                _status(trip['trip_status']),
                                _money(trip['total_fare']),
                              ),
                              _item('تاريخ الرحلة', _date(trip['created_at'])),
                              Text(
                                '${trip['pickup_address'] ?? '—'} ← ${trip['destination_address'] ?? '—'}',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  color: AdminTheme.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      Navigator.pop(dialogContext);
                      await _edit(c);
                    },
                    icon: Icon(Icons.edit),
                    label: Text(
                      'تعديل البيانات',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      Navigator.pop(dialogContext);
                      await _toggleBlock(c);
                    },
                    icon: Icon(_active(c) ? Icons.block : Icons.lock_open),
                    label: Text(
                      _active(c) ? 'حظر الحساب' : 'فك الحظر',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      Navigator.pop(dialogContext);
                      await _endSession(c);
                    },
                    icon: Icon(Icons.phonelink_erase_rounded),
                    label: Text(
                      'إنهاء الجلسة',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                  ),
                  if (c['primary_role']?.toString() != 'captain')
                    TextButton.icon(
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        await _promote(c);
                      },
                      icon: Icon(Icons.drive_eta),
                      label: Text(
                        'تحويل لكابتن',
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      _toast('تعذر عرض تفاصيل العميل: $e', error: true);
    }
  }

  Future<void> _toggleBlock(Map<String, dynamic> customer) async {
    final blocking = _active(customer);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            blocking ? 'تأكيد حظر العميل' : 'تأكيد فك الحظر',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          content: Text(
            blocking
                ? 'سيتم منع الدخول الجديد وطلب رحلات جديدة. لن تُحذف الرحلات أو المحفظة.'
                : 'سيُسمح للعميل باستخدام حسابه مجددًا.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: Text(blocking ? 'حظر' : 'فك الحظر'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await SupabaseService.instance.adminEditCustomerV16(
        customer['id'].toString(),
        isActive: !blocking,
      );
      _toast(blocking ? 'تم حظر الحساب' : 'تم فك الحظر');
      await _load();
    } catch (e) {
      _toast('تعذر تغيير حالة الحساب: $e', error: true);
    }
  }

  Future<void> _endSession(Map<String, dynamic> customer) async {
    final userId = customer['user_id']?.toString() ?? '';
    if (userId.isEmpty) {
      _toast('هذا العميل ليس لديه حساب تسجيل دخول مرتبط', error: true);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            'إنهاء جلسة العميل',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          content: Text(
            'سيخرج العميل من حسابه الحالي، ويمكنه تسجيل الدخول من جديد. '
            'لن تُحذف رحلاته أو رصيده، ولن تُلغى أي رحلة جارية.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: Text('رجوع'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: Text('إنهاء الجلسة'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await SupabaseService.instance.adminEndUserSessionV25(userId);
      _toast('تم إنهاء الجلسة. سيظهر طلب تسجيل الدخول على جهاز العميل.');
    } catch (e) {
      _toast('تعذر إنهاء الجلسة: $e', error: true);
    }
  }

  String _normalizePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('20') && digits.length == 12)
      digits = '0${digits.substring(2)}';
    return digits;
  }

  Future<void> _edit(Map<String, dynamic> customer) async {
    final name = TextEditingController(
      text: customer['full_name']?.toString() ?? '',
    );
    final phone = TextEditingController(
      text: customer['phone']?.toString() ?? '',
    );
    XFile? picked;
    bool saving = false;
    String? formError;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (d) => StatefulBuilder(
          builder: (ctx, update) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: AdminTheme.surface,
              title: Text(
                'تعديل بيانات العميل',
                style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: name,
                        enabled: !saving,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: AdminTheme.ink,
                        ),
                        decoration: InputDecoration(labelText: 'الاسم بالكامل'),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: phone,
                        enabled: !saving,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: AdminTheme.ink,
                        ),
                        decoration: InputDecoration(labelText: 'رقم الهاتف'),
                      ),
                      SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                final image = await ImagePicker().pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 85,
                                  maxWidth: 1200,
                                );
                                if (image != null) update(() => picked = image);
                              },
                        icon: Icon(Icons.image),
                        label: Text(
                          picked == null ? 'تغيير الصورة' : 'تم اختيار صورة',
                          style: TextStyle(fontFamily: 'Cairo'),
                        ),
                      ),
                      if (formError != null)
                        Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Text(
                            formError!,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      SizedBox(height: 8),
                      Text(
                        'تغيير الهاتف يغيّر بيانات الدخول لنفس الحساب دون إنشاء حساب جديد.',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: AdminTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(d),
                  child: Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (name.text.trim().length < 2) {
                            update(() => formError = 'الاسم لا يقل عن حرفين');
                            return;
                          }
                          final normalized = _normalizePhone(phone.text);
                          if (!RegExp(r'^01\d{9}$').hasMatch(normalized)) {
                            update(
                              () => formError =
                                  'أدخل رقمًا مصريًا صحيحًا من 11 رقمًا',
                            );
                            return;
                          }
                          update(() {
                            saving = true;
                            formError = null;
                          });
                          try {
                            final id = customer['id'].toString();
                            // Phone must be changed through Auth Admin API before
                            // updating the public profiles. Do not change phone directly.
                            if (normalized !=
                                _normalizePhone(
                                  customer['phone']?.toString() ?? '',
                                )) {
                              await SupabaseService.instance
                                  .adminUpdateCustomerPhoneV16(id, normalized);
                            }
                            String? photoUrl;
                            if (picked != null) {
                              photoUrl = await SupabaseService.instance
                                  .uploadPublicImage(
                                    path:
                                        'customers/$id/profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
                                    bytes: await picked!.readAsBytes(),
                                    contentType: 'image/jpeg',
                                  );
                            }
                            await SupabaseService.instance.adminEditCustomerV16(
                              id,
                              fullName: name.text.trim(),
                              profilePhotoUrl: photoUrl,
                            );
                            if (d.mounted) Navigator.pop(d);
                            _toast(
                              'تم تعديل البيانات مع الاحتفاظ بنفس الحساب والرحلات',
                            );
                            await _load();
                          } catch (e) {
                            if (d.mounted)
                              update(() {
                                saving = false;
                                formError = 'تعذر الحفظ: $e';
                              });
                          }
                        },
                  child: Text(saving ? 'جارٍ الحفظ...' : 'حفظ التعديلات'),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      name.dispose();
      phone.dispose();
    }
  }

  Future<void> _promote(Map<String, dynamic> customer) async {
    if (!_active(customer)) {
      _toast('فك الحظر أولًا قبل التحويل لكابتن', error: true);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (d) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: AdminTheme.surface,
          child: SizedBox(
            width: 760,
            height: 650,
            child: AdminCaptainFormPanel(
              customerToPromote: customer,
              onSaved: () {
                Navigator.pop(d);
                _toast('تم التحويل لكابتن بنفس حساب المستخدم');
                _load();
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Text(
              'العملاء (${_customers.length})',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                color: AdminTheme.ink,
                fontWeight: FontWeight.bold,
              ),
            ),
            Spacer(),
            IconButton(
              tooltip: 'تحديث الإحصائيات',
              onPressed: _load,
              icon: Icon(Icons.refresh, color: AdminTheme.goldDark),
            ),
          ],
        ),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: TextField(
          onChanged: (v) {
            setState(() => _query = v);
            _pager.search(v);
          },
          style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'ابحث باسم العميل أو رقم الهاتف',
            hintStyle: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      ),
      if (_error != null)
        Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            _error!,
            style: TextStyle(fontFamily: 'Cairo', color: Colors.redAccent),
          ),
        ),
      Expanded(
        child: _loading
            ? Center(
                child: CircularProgressIndicator(color: AdminTheme.goldDark),
              )
            : _filteredCustomers.isEmpty
            ? Center(
                child: Text(
                  'لا يوجد عملاء',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: AdminTheme.muted,
                  ),
                ),
              )
            : ListView.separated(
                controller: _pager.scroll,
                padding: EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filteredCustomers.length,
                separatorBuilder: (_, __) => SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final c = _filteredCustomers[i];
                  return Card(
                    color: AdminTheme.surfaceSoft,
                    child: InkWell(
                      onTap: () => _details(c),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            _avatar(c),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c['full_name']?.toString() ?? 'بدون اسم',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      color: AdminTheme.ink,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          c['phone']?.toString() ?? '—',
                                          style: TextStyle(
                                            fontFamily: 'Cairo',
                                            color: AdminTheme.muted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      AdminCopyButton(
                                        text: c['phone']?.toString() ?? '',
                                        description: 'رقم العميل',
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'فتح: ${_date(c['account_created_at'] ?? c['created_at'])}',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      color: AdminTheme.muted,
                                      fontSize: 10,
                                    ),
                                  ),
                                  if (!_active(c))
                                    Text(
                                      'محظور',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _money(c['wallet_balance']),
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    color: AdminTheme.goldDark,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${c['total_trips'] ?? 0} رحلة',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    color: AdminTheme.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    ],
  );
}
