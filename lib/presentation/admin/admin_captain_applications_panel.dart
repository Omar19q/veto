import 'admin_captain_intake_v19.dart';
import 'admin_marketing_partners_v39.dart';
import 'legacy_applications_v16.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/captain_application_v16.dart';
import '../../theme/admin_theme.dart';

class AdminCaptainApplicationsPanel extends StatefulWidget {
  const AdminCaptainApplicationsPanel({super.key});
  @override
  State<AdminCaptainApplicationsPanel> createState() =>
      _AdminCaptainApplicationsPanelState();
}

class _AdminCaptainApplicationsPanelState
    extends State<AdminCaptainApplicationsPanel> {
  final api = CaptainApplicationV16();
  List<Map<String, dynamic>> rows = [];
  bool loading = true, refreshing = false;
  int _page = 0;
  String? error;
  RealtimeChannel? channel;
  @override
  void initState() {
    super.initState();
    _load();
    channel = api.client
        .channel('v16-admin-applications')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'v16_captain_applications',
          callback: (_) => _load(),
        )
        .subscribe((s, e) {
          if (s == RealtimeSubscribeStatus.subscribed) _load();
        });
  }

  @override
  void dispose() {
    if (channel != null) api.client.removeChannel(channel!);
    super.dispose();
  }

  Future<void> _load() async {
    if (refreshing) return;
    refreshing = true;
    try {
      final data = await api.list(page:_page);
      if (mounted) {
        setState(() {
          rows = data;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'تعذر تحميل الطلبات. تحقق من الاتصال وصلاحية عرض الكباتن.',
        );
      }
    } finally {
      refreshing = false;
      if (mounted) setState(() => loading = false);
    }
  }

  // V32 presentation only: both current and historical review flows remain.
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        child: Row(children: [
          Image.asset('assets/images/veto_sanya_app_icon.png',
            width: 42, height: 42, semanticLabel: 'VETO SANYA'),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('طلبات الكباتن', style: TextStyle(
                fontFamily: 'Cairo', fontSize: 21, fontWeight: FontWeight.w900,
                color: AdminTheme.ink)),
              const Text('مراجعة الانضمام والتحقق من المستندات',
                style: TextStyle(fontFamily: 'Cairo',
                  color: Color(0xFF7D7560), fontSize: 11)),
            ],
          )),
          IconButton(tooltip: 'شركاء التسويق',
            onPressed: () => Navigator.push(context,
              MaterialPageRoute<void>(builder: (_) => const AdminMarketingPartnersV39())),
            icon: const Icon(Icons.groups_2_outlined)),
          IconButton(tooltip: 'الطلبات المحفوظة',
            onPressed: () => Navigator.push(context,
              MaterialPageRoute<void>(builder: (_) => const LegacyApplicationsV16())),
            icon: const Icon(Icons.history_rounded)),
          IconButton(tooltip: 'تحديث الطلبات',
            onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: SizedBox(width: double.infinity, child: FilledButton.icon(
          onPressed: () async {
            await Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const AdminCaptainIntakeV19(),
            ));
            _load();
          },
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('طلبات الانضمام الجديدة', style: TextStyle(
            fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        )),
      ),
      if (error != null)
        Padding(padding: const EdgeInsets.all(15), child: Text(error!,
          style: const TextStyle(fontFamily: 'Cairo', color: Colors.red))),
      Row(children:[
        IconButton(tooltip:'السابق',icon:const Icon(Icons.chevron_right),
          onPressed:_page==0?null:(){setState(()=>_page--);_load();}),
        Text('طلبات V16 • صفحة ${_page+1}',style:const TextStyle(fontSize:11)),
        IconButton(tooltip:'التالي',icon:const Icon(Icons.chevron_left),
          onPressed:rows.length<50?null:(){setState(()=>_page++);_load();}),
      ]),
      Expanded(child: loading
        ? const Center(child: CircularProgressIndicator())
        : rows.isEmpty
          ? Center(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Image.asset('assets/images/veto_sanya_app_icon.png',
                  width: 60, height: 60, semanticLabel: 'VETO SANYA'),
                const SizedBox(height: 14),
                const Text('لا توجد طلبات معروضة حاليًا',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 17,
                    fontWeight: FontWeight.w800)),
                const SizedBox(height: 7),
                const Text('يمكن مراجعة الطلبات الجديدة أو فتح الطلبات المحفوظة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Cairo',
                    color: Color(0xFF877D69), fontSize: 12)),
                const SizedBox(height: 13),
                TextButton.icon(onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('تحديث', style: TextStyle(fontFamily: 'Cairo'))),
              ]),
            ))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final application = rows[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 9),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
                    title: Text(application['full_name']?.toString() ?? 'طلب انضمام',
                      style: const TextStyle(fontFamily: 'Cairo',
                        fontWeight: FontWeight.w800)),
                    subtitle: Text(
                      '${application['phone'] ?? ''} • ${application['vehicle_brand'] ?? ''} ${application['vehicle_model'] ?? ''}\n${CaptainApplicationV16.statuses[application['status']] ?? 'قيد المراجعة'}',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_left_rounded),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => _ApplicationReview(application: application),
                      ));
                      _load();
                    },
                  ),
                );
              },
            ),
      ),
    ]),
  );

}

class _ApplicationReview extends StatefulWidget {
  final Map<String, dynamic> application;
  const _ApplicationReview({required this.application});
  @override
  State<_ApplicationReview> createState() => _ApplicationReviewState();
}

class _ApplicationReviewState extends State<_ApplicationReview> {
  final api = CaptainApplicationV16();
  bool busy = false;
  String? error;
  Future<void> _photo(String path, String label) async {
    try {
      final url = await api.preview(path);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => Dialog(
          child: Column(
            children: [
              ListTile(
                title: Text(label),
                trailing: IconButton(
                  onPressed: () => Navigator.pop(c),
                  icon: const Icon(Icons.close),
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: .5,
                  maxScale: 5,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, e, s) => const Center(
                      child: Text(
                        'انتهت صلاحية المعاينة. أغلق وافتح الصورة مجددًا.',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => error = 'تعذر فتح المستند أو انتهت صلاحية الوصول.');
      }
    }
  }

  Future<void> _review(String action) async {
    if (busy) return;
    final a = widget.application;
    final reason = TextEditingController();
    var confirmed = false;
    if (action == 'approved') {
      // An explicit account-link screen; no arbitrary UUID or customer conversion is accepted.
      confirmed =
          await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (c) => Scaffold(
                appBar: AppBar(title: const Text('ربط الحساب الموثق')),
                body: Directionality(
                  textDirection: TextDirection.rtl,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const Icon(
                        Icons.verified_user,
                        size: 64,
                        color: Colors.green,
                      ),
                      const Text(
                        'الحساب المطابق لرقم الطلب',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('${a['full_name']}\n${a['phone']}'),
                      SelectableText('معرف الحساب: ${a['user_id']}'),
                      const SizedBox(height: 16),
                      const Text(
                        'سيتحقق السيرفر مجددًا من ملكية الرقم والصلاحية وعدم وجود عميل أو كابتن أو موظف مرتبط. ستبقى المستندات خاصة ومربوطة بالكابتن. أي تعارض يوقف العملية دون تغيير الحساب.',
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('اعتماد وربط هذا الحساب'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ) ??
          false;
    } else {
      confirmed =
          await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: Text(
                action == 'needs_info' ? 'طلب استكمال المستندات' : 'رفض الطلب',
              ),
              content: TextField(
                controller: reason,
                maxLength: 1000,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'السبب الذي سيظهر للكابتن',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () {
                    if (reason.text.trim().length >= 3) Navigator.pop(c, true);
                  },
                  child: const Text('حفظ القرار'),
                ),
              ],
            ),
          ) ??
          false;
    }
    final note = reason.text;
    reason.dispose();
    if (!confirmed || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await api.review(a, action, note);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e.toString().contains('conflict')
              ? 'يوجد تعارض أدوار. لم يتم تعديل حساب العميل أو إنشاء كابتن.'
              : e.toString().contains('application_changed')
              ? 'راجع موظف آخر هذا الطلب أو تغيرت نسخته. ارجع وحدّث القائمة.'
              : 'تعذر تنفيذ القرار. تحقق من الصلاحية والاتصال ثم حدّث الطلب.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.application;
    final docs = Map<String, dynamic>.from(a['documents'] as Map);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('ملف طلب الكابتن')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  a['full_name'] as String,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${CaptainApplicationV16.statuses[a['status']]} • نسخة ${a['revision']}',
                ),
                const Divider(),
                for (final e in {
                  'phone': 'الهاتف',
                  'national_id': 'الرقم القومي',
                  'birth_date': 'الميلاد',
                  'area': 'المنطقة',
                  'address': 'العنوان',
                  'vehicle_type': 'المركبة',
                  'vehicle_brand': 'الماركة',
                  'vehicle_model': 'الموديل',
                  'vehicle_year': 'سنة الصنع',
                  'vehicle_color': 'اللون',
                  'vehicle_plate': 'اللوحة',
                }.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: SelectableText('${e.value}: ${a[e.key]}'),
                  ),
                const Divider(),
                const Text(
                  'المستندات • اضغط للفحص والتكبير',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final e
                        in CaptainApplicationV16.documentLabels.entries)
                      OutlinedButton.icon(
                        onPressed: docs[e.key] == null
                            ? null
                            : () => _photo(docs[e.key] as String, e.value),
                        icon: const Icon(Icons.zoom_in),
                        label: Text(e.value),
                      ),
                  ],
                ),
                if (a['review_reason'] != null)
                  Text('سبب القرار: ${a['review_reason']}'),
                const SizedBox(height: 24),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
                if (busy) const LinearProgressIndicator(),
                if (a['status'] == 'pending')
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: busy ? null : () => _review('approved'),
                        icon: const Icon(Icons.check),
                        label: const Text('قبول وربط حساب'),
                      ),
                      OutlinedButton(
                        onPressed: busy ? null : () => _review('needs_info'),
                        child: const Text('طلب استكمال'),
                      ),
                      TextButton(
                        onPressed: busy ? null : () => _review('rejected'),
                        child: const Text('رفض مع السبب'),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
                const Text(
                  'سجل المراجعة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: api.client
                      .from('v16_captain_audit')
                      .select()
                      .eq('application_id', a['id'])
                      .order('created_at', ascending: false)
                      .limit(100),
                  builder: (c, s) {
                    if (s.hasError) return const Text('تعذر تحميل السجل');
                    if (!s.hasData) return const LinearProgressIndicator();
                    return Column(
                      children: s.data!
                          .map(
                            (e) => ListTile(
                              title: Text(e['action'] as String),
                              subtitle: Text(
                                '${e['reason'] ?? ''}\n${e['created_at']} • ${e['actor_id']}',
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

