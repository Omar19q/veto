import 'package:flutter/material.dart';
import '../../services/captain_application_v16.dart';
import '../../theme/admin_theme.dart';
import '../../services/supabase_service.dart';
import 'admin_captain_form.dart';

/// An unverified APPLICATION inbox only. Nothing here grants captain access.
class AdminCaptainIntakeV19 extends StatefulWidget {
  const AdminCaptainIntakeV19({super.key});

  @override
  State<AdminCaptainIntakeV19> createState() => _AdminCaptainIntakeV19State();
}

class _AdminCaptainIntakeV19State extends State<AdminCaptainIntakeV19> {
  final api = CaptainApplicationV16();
  List<Map<String, dynamic>> requests = [];
  bool loading = true;
  int _page=0;
  String? error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final rows = await api.listIntakes(page:_page);
      if (mounted) setState(() => requests = rows);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'تعذر تحميل الطلبات. راجع صلاحية إدارة الكباتن وتثبيت SQL V19.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('طلبات انضمام الكباتن'),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))],
      ),
      body: Column(children:[
        Row(children:[
          IconButton(tooltip:'الصفحة السابقة',onPressed:_page==0?null:(){
            setState(()=>_page--);_refresh();
          }, icon:const Icon(Icons.chevron_right)),
          Text('طلبات V19 • صفحة ${_page+1}'),
          IconButton(tooltip:'الصفحة التالية',onPressed:requests.length<50?null:(){
            setState(()=>_page++);_refresh();
          },icon:const Icon(Icons.chevron_left)),
        ]),
        Expanded(child: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: Text(error!, textAlign: TextAlign.center))
          : requests.isEmpty
          ? const Center(child: Text('مفيش طلبات انضمام جديدة حاليًا'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('الطلبات الجديدة بتوصل هنا مباشرة، وبعد مراجعة المستندات بيتواصل الفريق مع مقدم الطلب.\nالمراجعة مش معناها تشغيل حساب كابتن تلقائيًا.'),
                ),
                for (final a in requests)
                  Card(
                    child: ListTile(
                      title: Text(a['full_name']?.toString() ?? ''),
                      subtitle: Text('${a['phone']} • ${a['vehicle_brand']} ${a['vehicle_model']}\n${_status(a['status'])}'),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => _IntakeDetailV19(row: a),
                        ));
                        _refresh();
                      },
                    ),
                  ),
              ],
            ),
        ),
      ]),
    ),
  );
}

String _status(Object? status) {
  switch (status) {
    case 'pending': return 'قيد المراجعة';
    case 'needs_info': return 'مطلوب استكمال';
    case 'reviewed': return 'تمت المراجعة الأولية';
    case 'rejected': return 'مرفوض';
    default: return 'غير معروف';
  }
}

class _IntakeDetailV19 extends StatefulWidget {
  final Map<String, dynamic> row;
  const _IntakeDetailV19({required this.row});
  @override
  State<_IntakeDetailV19> createState() => _IntakeDetailV19State();
}

class _IntakeDetailV19State extends State<_IntakeDetailV19> {
  final api = CaptainApplicationV16();
  bool saving = false;
  String? error;

  Future<void> _openPreparedPromotion() async {
    final accountId = widget.row['applicant_user_id']?.toString();
    if (accountId == null || accountId.isEmpty) {
      setState(() => error = 'الطلب غير مرتبط بحساب عميل موثق. لا يمكن تحويله تلقائيًا.');
      return;
    }
    try {
      final c = await SupabaseService.instance.client.from('customers')
        .select().eq('user_id',accountId).maybeSingle();
      if (c == null || c['id'] == null) {
        if (mounted) setState(() => error = 'لا يوجد حساب عميل لنفس هوية مقدم الطلب.');
        return;
      }
      if (!mounted) return;
      final merged = Map<String,dynamic>.from(c);
      for (final key in ['vehicle_type','vehicle_brand','vehicle_model',
                          'vehicle_year','vehicle_color','vehicle_plate']) {
        if (widget.row[key] != null) merged[key]=widget.row[key];
      }
      // Keep real customer name, phone, user id and customer photo from server.
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('تحويل الحساب لنظام الكابتن',
          style: TextStyle(fontFamily: 'Cairo')),
        content: SizedBox(width: 780,height: 610, child: AdminCaptainFormPanel(
          customerToPromote: merged,
          onSaved: () {
            Navigator.pop(ctx);
            if (mounted) Navigator.pop(context);
          },
        )),
      ));
    } catch (_) {
      if (mounted) setState(() => error =
        'تعذر جلب حساب العميل. راجع ربط الهوية وصلاحيات الإدارة.');
    }
  }

  Future<void> _showPhoto(String path, String label) async {
    try {
      final url = await api.previewIntake(path);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialog) => Dialog(
          child: Column(children: [
            ListTile(title: Text(label), trailing: IconButton(
              onPressed: () => Navigator.pop(dialog),
              icon: const Icon(Icons.close))),
            Expanded(child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain))),
          ]),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => error = 'مش قادر أفتح الصورة حاليًا، حاول تاني.');
    }
  }

  Future<void> _review(String action) async {
    var draft = '';
    final reason = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(action == 'reviewed' ? 'تأكيد فحص الطلب' :
            action == 'needs_info' ? 'إيه المطلوب استكماله؟' : 'سبب الرفض'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (action == 'reviewed')
            const Text('هيتحفظ إنك فحصت الطلب، ومش هيتفعّل حساب الكابتن تلقائيًا.'),
          TextField(onChanged: (value) => draft = value, maxLines: 2,
            decoration: const InputDecoration(labelText: 'ملاحظة للإدارة أو مقدم الطلب')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialog, draft.trim()),
            child: const Text('حفظ القرار')),
        ],
      ),
    );
    if (reason == null) {
      return;
    }
    if (action != 'reviewed' && reason.length < 3) {
      setState(() => error = 'اكتب سبب واضح من 3 حروف على الأقل.');
      return;
    }
    setState(() { saving = true; error = null; });
    try {
      await api.reviewIntake(widget.row, action, reason);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر حفظ القرار؛ حدث البيانات وجرب تاني.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.row;
    final docs = Map<String, dynamic>.from(a['documents'] as Map? ?? const {});
    final fields = <String, String>{
      'phone': 'رقم الهاتف', 'national_id': 'الرقم القومي',
      'birth_date': 'تاريخ الميلاد', 'vehicle_type': 'نوع المركبة',
      'vehicle_brand': 'الماركة', 'vehicle_model': 'الموديل',
      'vehicle_year': 'سنة الصنع', 'vehicle_color': 'اللون',
      'vehicle_plate': 'اللوحة', 'area': 'المنطقة', 'address': 'العنوان',
    };
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(a['full_name']?.toString() ?? 'الطلب')),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          Text('الحالة: ${_status(a['status'])}', style: const TextStyle(fontSize: 18,
            fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('البيانات ورقم الهاتف مقدمة من صاحب الطلب ولم يتم التحقق من ملكية الرقم.'),
          const Divider(),
          for (final f in fields.entries)
            Padding(padding: const EdgeInsets.symmetric(vertical: 5),
              child: SelectableText('${f.value}: ${a[f.key] ?? '—'}')),
          const Divider(),
          const Text('اضغط على صورة المستند لعرضها',
            style: TextStyle(fontWeight: FontWeight.bold)),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final entry in CaptainApplicationV16.documentLabels.entries)
              OutlinedButton.icon(
                icon: const Icon(Icons.image_outlined), label: Text(entry.value),
                onPressed: docs[entry.key] == null ? null :
                  () => _showPhoto(docs[entry.key].toString(), entry.value),
              ),
          ]),
          if (a['review_reason'] != null)
            Text('الملاحظة: ${a['review_reason']}'),
          if (a['status'] == 'reviewed')
            Padding(padding: const EdgeInsets.symmetric(vertical: 12),
              child: FilledButton.icon(
                onPressed: saving ? null : _openPreparedPromotion,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('استكمال تحويل العميل لكابتن — البيانات جاهزة'),
              )),
          if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
          if (saving) const LinearProgressIndicator(),
          if (a['status'] == 'pending')
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton(onPressed: saving ? null : () => _review('reviewed'),
                child: const Text('تمت المراجعة الأولية')),
              OutlinedButton(onPressed: saving ? null : () => _review('needs_info'),
                child: const Text('طلب استكمال')),
              TextButton(onPressed: saving ? null : () => _review('rejected'),
                child: const Text('رفض الطلب')),
            ]),
          const SizedBox(height: 12),
          Text('لن يتم إنشاء أو تفعيل كابتن من هذه الصفحة. إجراءات التحقق والاعتماد النهائي تتم فقط عبر مسارات الإدارة المعتمدة.',
            style: TextStyle(color: AdminTheme.muted)),
        ]),
      ),
    );
  }
}
