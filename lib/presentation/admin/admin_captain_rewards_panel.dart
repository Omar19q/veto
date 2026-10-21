import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/admin_theme.dart';

/// Admin-only UI. Creation, awarding and payment confirmation are enforced by RLS/RPC.
/// This screen never makes a wallet/captain-transaction entry or sends actual money.
class AdminCaptainRewardsPanel extends StatefulWidget {
  const AdminCaptainRewardsPanel({super.key});
  @override
  State<AdminCaptainRewardsPanel> createState() => _AdminCaptainRewardsPanelState();
}

class _AdminCaptainRewardsPanelState extends State<AdminCaptainRewardsPanel> {
  List<Map<String, dynamic>> _campaigns = [];
  List<Map<String, dynamic>> _participants = [];
  String? _selectedId;
  bool _loading = true;
  bool _loadingPeople = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _notice(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: TextStyle(fontFamily: 'Cairo')),
      backgroundColor: error ? AdminTheme.error : Color(0xFF22513C),
    ));
  }

  Future<void> _load() async {
    try {
      final rows = await SupabaseService.instance.client
          .from('captain_reward_campaigns')
          .select()
          .order('created_at', ascending: false);
      if (!mounted) return;
      final list = List<Map<String, dynamic>>.from(rows);
      setState(() {
        _campaigns = list;
        _error = null;
        _loading = false;
        if (_selectedId == null || !list.any((c) => c['id'].toString() == _selectedId)) {
          _selectedId = list.isNotEmpty ? list.first['id'].toString() : null;
        }
      });
      await _loadParticipants();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل المكافآت: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadParticipants() async {
    final id = _selectedId;
    if (id == null) {
      if (mounted) setState(() => _participants = []);
      return;
    }
    setState(() => _loadingPeople = true);
    try {
      final rows = await SupabaseService.instance.getAdminRewardParticipantsV22(id);
      if (mounted && _selectedId == id) setState(() => _participants = rows);
    } catch (e) {
      _notice('تعذر تحميل تقدم الكباتن: $e', error: true);
    } finally {
      if (mounted) setState(() => _loadingPeople = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? original]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _RewardCampaignDialog(original: original),
    );
    if (result == null) return;
    if (mounted) setState(() => _saving = true);
    String? uploadedPath;
    try {
      // Images are picked from this device; do not put binary bytes in the DB.
      final imageData = result.remove('_image_bytes');
      final imageMime = result.remove('_image_mime');
      if (imageData is Uint8List && imageMime is String) {
        final userId = SupabaseService.instance.currentUser?.id;
        if (userId == null) throw StateError('admin_not_authenticated');
        final extension = switch (imageMime) {
          'image/png' => 'png',
          'image/webp' => 'webp',
          _ => 'jpg',
        };
        uploadedPath = '$userId/${DateTime.now().microsecondsSinceEpoch}.$extension';
        final bucket = SupabaseService.instance.client.storage.from('captain-reward-banners-v23');
        await bucket.uploadBinary(uploadedPath, imageData,
          fileOptions: FileOptions(contentType: imageMime, upsert: false));
        result['image_url'] = bucket.getPublicUrl(uploadedPath);
      }
      if (original == null) {
        await SupabaseService.instance.client.from('captain_reward_campaigns').insert({
          ...result,
          'created_by': SupabaseService.instance.currentUser?.id,
        });
      } else {
        await SupabaseService.instance.client.from('captain_reward_campaigns')
            .update(result).eq('id', original['id']);
      }
      uploadedPath = null; // Keep the uploaded image on successful save.
      _notice('تم حفظ العرض');
      await _load();
    } catch (e) {
      if (uploadedPath != null) {
        try {
          await SupabaseService.instance.client.storage
            .from('captain-reward-banners-v23').remove([uploadedPath]);
        } catch (_) { /* Cleanup is best-effort; never hide original error. */ }
      }
      _notice('لم يُحفظ العرض: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setActive(Map<String, dynamic> c, bool value) async {
    try {
      await SupabaseService.instance.client.from('captain_reward_campaigns')
          .update({'is_active': value}).eq('id', c['id']);
      await _load();
    } catch (e) {
      _notice('تعذر تحديث العرض: $e', error: true);
    }
  }

  Future<void> _reconcile() async {
    final id = _selectedId;
    if (id == null) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.surface,
        title: Text('مراجعة عداد الرحلات',
          style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink)),
        content: Text(
          'سيتم فحص الرحلات المكتملة داخل فترة العرض وإضافة أي رحلات مؤهلة لم تُحتسب. قد ينشأ استحقاق مكافأة جديد، ولن يتم تحويل أي مال تلقائيًا.',
          style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('رجوع')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: Text('مراجعة وتحديث')),
        ],
      ),
    );
    if (approved != true) return;
    setState(() => _saving = true);
    try {
      final scanned = await SupabaseService.instance.reconcileCaptainRewardV22(id);
      _notice('اكتملت المراجعة: تم فحص $scanned رحلة غير مسجلة (حد 3000 لكل مرة).');
      await _loadParticipants();
    } catch (e) {
      _notice('تعذرت مراجعة العداد: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmPaid(Map<String, dynamic> participant) async {
    final claimId = participant['claim_id']?.toString();
    if (claimId == null || participant['status'] != 'pending') return;
    final details = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ConfirmVodafonePaymentDialog(participant: participant),
    );
    if (details == null) return;
    setState(() => _saving = true);
    try {
      await SupabaseService.instance.markCaptainRewardPaidV22(
        claimId: claimId,
        payoutPhone: details['phone']!,
        transferReference: details['reference']!,
      );
      _notice('تم تسجيل التحويل. لا يمكن تسجيل نفس المكافأة مرتين.');
      await _loadParticipants();
    } catch (e) {
      _notice('لم يتم تأكيد الصرف: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _campaigns.where((c) => c['id'].toString() == _selectedId)
        .cast<Map<String, dynamic>>().firstOrNull;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(18, 16, 18, 8),
          child: Wrap(
            spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('مكافآت الكباتن', style: TextStyle(fontFamily: 'Cairo',
                color: AdminTheme.ink, fontSize: 21, fontWeight: FontWeight.w800)),
              ElevatedButton.icon(onPressed: _saving ? null : () => _edit(),
                icon: Icon(Icons.add_rounded), label: Text('عرض جديد'),
                style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.goldDark,
                  foregroundColor: AppTheme.primary)),
              OutlinedButton.icon(onPressed: _saving ? null : _load,
                icon: Icon(Icons.refresh_rounded), label: Text('تحديث')),
            ],
          ),
        ),
        Padding(padding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Text('العروض تحسب الرحلات المكتملة تلقائيًا. مكافآت فودافون كاش تُحوّل يدويًا خارج التطبيق ثم تُسجّل برقم عملية فريد. لا تتغير أرصدة الكباتن.',
            style: TextStyle(fontFamily: 'Cairo', color: Color(0xFFD0D9E9), fontSize: 12))),
        if (_error != null)
          Padding(padding: EdgeInsets.all(12),
            child: Text(_error!, style: TextStyle(color: AdminTheme.error,
              fontFamily: 'Cairo'))),
        Expanded(child: _loading
          ? Center(child: CircularProgressIndicator(color: AdminTheme.goldDark))
          : ListView(padding: EdgeInsets.all(14), children: [
              if (_campaigns.isEmpty) _RewardEmpty('مفيش عروض حتى الآن. اضغط «عرض جديد» لإضافة أول مكافأة.'),
              ..._campaigns.map((c) => _campaignCard(c)),
              if (selected != null) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AdminTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AdminTheme.borderSoft)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('متابعة الكباتن: ${selected['title']}',
                      style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800,
                        fontSize: 16, color: AdminTheme.ink)),
                    SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      OutlinedButton.icon(onPressed: _saving ? null : _reconcile,
                        icon: Icon(Icons.fact_check_rounded),
                        label: Text('مراجعة العدادات')),
                      OutlinedButton.icon(onPressed: _loadParticipants,
                        icon: Icon(Icons.sync_rounded),
                        label: Text('تحديث التقدم')),
                    ]),
                    SizedBox(height: 10),
                    if (_loadingPeople)
                      Center(child: CircularProgressIndicator(color: AdminTheme.goldDark))
                    else if (_participants.isEmpty)
                      _RewardEmpty('لم تُسجل رحلات مؤهلة لهذا العرض بعد.')
                    else
                      ..._participants.map(_participantCard),
                  ]),
                ),
              ],
            ])),
      ]),
    );
  }

  Widget _campaignCard(Map<String, dynamic> c) {
    final selected = c['id'].toString() == _selectedId;
    final cap = (c['max_recipients'] as num?)?.toInt();
    final end = DateTime.tryParse(c['ends_at']?.toString() ?? '')?.toLocal().subtract(Duration(seconds: 1));
    return Card(
      color: selected ? Color(0xFF202B44) : AdminTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? AdminTheme.goldDark : AdminTheme.borderSoft)),
      child: InkWell(
        onTap: () {
          setState(() { _selectedId = c['id'].toString(); _participants = []; });
          _loadParticipants();
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(padding: EdgeInsets.all(14), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c['title']?.toString() ?? '',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 16,
                color: AdminTheme.ink, fontWeight: FontWeight.w800)),
            SizedBox(height: 4),
            Text('${c['target_trips']} رحلة مكتملة ← ${c['reward_amount']} جنيه فودافون كاش'
                '${cap == null ? '' : '  •  أول $cap كابتن'}',
              style: TextStyle(fontFamily: 'Cairo', color: Color(0xFFD0D9E9), fontSize: 12)),
            if (end != null)
              Text('ينتهي: ${end.day}/${end.month}/${end.year}',
                style: TextStyle(fontFamily: 'Cairo', color: Color(0xFFD0D9E9), fontSize: 11)),
            SizedBox(height: 6),
            Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('مفعّل', style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink)),
              Switch(value: c['is_active'] == true,
                onChanged: _saving ? null : (value) => _setActive(c, value),
                activeThumbColor: AdminTheme.goldDark),
              IconButton(tooltip: 'تعديل العرض',
                onPressed: _saving ? null : () => _edit(c),
                icon: Icon(Icons.edit_outlined, color: AdminTheme.goldDark)),
            ]),
          ])),
      ),
    );
  }

  Widget _participantCard(Map<String, dynamic> p) {
    final progress = (p['progress'] as num?)?.toInt() ?? 0;
    final goal = (p['target_trips'] as num?)?.toInt() ?? 1;
    final status = p['status']?.toString() ?? 'in_progress';
    final statusText = status == 'paid' ? 'تم الصرف'
        : status == 'pending' ? 'مستحقة — بانتظار التحويل' : 'جارٍ إكمال الرحلات';
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(color: AdminTheme.surfaceSoft,
          borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${p['name'] ?? 'كابتن'}  •  ${p['phone'] ?? ''}',
            style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink,
              fontWeight: FontWeight.w800)),
          Text('$progress / $goal رحلة  •  $statusText',
            style: TextStyle(fontFamily: 'Cairo', color: Color(0xFFD0D9E9), fontSize: 12)),
          SizedBox(height: 6),
          LinearProgressIndicator(value: (progress / goal).clamp(0.0, 1.0).toDouble(),
            minHeight: 7, backgroundColor: AdminTheme.borderSoft, color: AdminTheme.goldDark),
          if (status == 'paid')
            Text('إيصال التحويل: ${p['transfer_reference'] ?? '—'}  •  رقم المحفظة: ${p['payout_phone'] ?? '—'}',
              style: TextStyle(fontFamily: 'Cairo', color: Color(0xFFA4E6BD), fontSize: 12))
          else if (status == 'pending')
            Padding(padding: EdgeInsets.only(top: 8),
              child: FilledButton.icon(
                onPressed: _saving ? null : () => _confirmPaid(p),
                icon: Icon(Icons.receipt_long_rounded),
                label: Text('سجّل تحويل ${p['amount']} جنيه (بعد التحويل الفعلي)'),
                style: FilledButton.styleFrom(backgroundColor: AdminTheme.goldDark,
                  foregroundColor: AppTheme.primary),
              )),
        ]),
      ),
    );
  }
}

class _RewardEmpty extends StatelessWidget {
  _RewardEmpty(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: 20),
    child: Text(message, style: TextStyle(fontFamily: 'Cairo',
      color: AdminTheme.muted)),
  );
}

class _RewardCampaignDialog extends StatefulWidget {
  const _RewardCampaignDialog({this.original});
  final Map<String, dynamic>? original;
  @override
  State<_RewardCampaignDialog> createState() => _RewardCampaignDialogState();
}

class _RewardCampaignDialogState extends State<_RewardCampaignDialog> {
  late final TextEditingController title = TextEditingController(
      text: widget.original?['title']?.toString() ?? '');
  late final TextEditingController description = TextEditingController(
      text: widget.original?['description']?.toString() ?? '');
  late final TextEditingController url = TextEditingController(
      text: widget.original?['action_url']?.toString() ?? '');
  late final TextEditingController target = TextEditingController(
      text: widget.original?['target_trips']?.toString() ?? '10');
  late final TextEditingController amount = TextEditingController(
      text: widget.original?['reward_amount']?.toString() ?? '100');
  late final TextEditingController maxUsers = TextEditingController(
      text: widget.original?['max_recipients']?.toString() ?? '');
  late DateTime startDay = DateTime.tryParse(widget.original?['starts_at']?.toString() ?? '')?.toLocal()
      ?? DateTime.now();
  late DateTime endDay = DateTime.tryParse(widget.original?['ends_at']?.toString() ?? '')?.toLocal()
      ?? DateTime.now().add(Duration(days: 7));
  final TextEditingController countdownMinutes = TextEditingController(text: '30');
  String scheduleMode = 'range';
  XFile? selectedImage;
  bool readingImage = false;
  bool changedStart = false;
  bool changedEnd = false;
  late bool enabled = widget.original?['is_active'] == null || widget.original?['is_active'] == true;
  String? error;

  @override
  void dispose() {
    for (final c in [title, description, url, target, amount, maxUsers, countdownMinutes]) { c.dispose(); }
    super.dispose();
  }

  InputDecoration _dec(String name) => InputDecoration(labelText: name,
    labelStyle: TextStyle(color: Color(0xFFD0D9E9), fontFamily: 'Cairo'),
    filled: true, fillColor: AdminTheme.surfaceSoft,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)));

  Widget _field(TextEditingController c, String label, {bool numeric = false, int lines = 1}) =>
    Padding(padding: EdgeInsets.only(bottom: 12),
      child: TextField(controller: c, maxLines: lines,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
        decoration: _dec(label)));

  Future<void> _pickDay({required bool start}) async {
    final firstDay = DateTime.now().subtract(Duration(days: 365));
    final initial = start ? startDay : endDay;
    final picked = await showDatePicker(context: context,
      firstDate: firstDay, lastDate: DateTime.now().add(Duration(days: 730)),
      initialDate: initial.isBefore(firstDay) ? firstDay : initial,
      helpText: start ? 'تاريخ بداية العرض' : 'آخر يوم في العرض');
    if (picked != null) setState(() {
      final old = start ? startDay : endDay;
      final combined = DateTime(picked.year, picked.month, picked.day, old.hour, old.minute);
      if (start) { startDay = combined; changedStart = true; }
      else { endDay = combined; changedEnd = true; }
    });
  }

  Future<void> _pickTime({required bool start}) async {
    final original = start ? startDay : endDay;
    final value = await showTimePicker(context: context,
      initialTime: TimeOfDay(hour: original.hour, minute: original.minute),
      helpText: start ? 'ساعة بداية العرض' : 'ساعة نهاية العرض');
    if (value == null || !mounted) return;
    setState(() {
      final d = DateTime(original.year, original.month, original.day, value.hour, value.minute);
      if (start) { startDay = d; changedStart = true; }
      else { endDay = d; changedEnd = true; }
    });
  }

  Future<void> _pickBanner() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery,
        imageQuality: 82, maxWidth: 1600);
      if (picked != null && mounted) setState(() => selectedImage = picked);
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر اختيار الصورة. تحقق من صلاحية الوصول للصور.');
    }
  }

  Future<void> _save() async {
    if (readingImage) return;
    final n = int.tryParse(target.text.trim());
    final money = double.tryParse(amount.text.trim());
    final maxText = maxUsers.text.trim();
    final cap = maxText.isEmpty ? null : int.tryParse(maxText);
    final imageUrl = widget.original?['image_url']?.toString().trim() ?? '';
    final actionUrl = url.text.trim();
    final link = actionUrl.isEmpty ? null : Uri.tryParse(actionUrl);
    final imgLink = imageUrl.isEmpty ? null : Uri.tryParse(imageUrl);
    if (title.text.trim().length < 3 || title.text.trim().length > 160 ||
        description.text.trim().length > 1200 || n == null || n < 1 || n > 10000 ||
        money == null || !money.isFinite || money <= 0 || money > 1000000 ||
        (maxText.isNotEmpty && (cap == null || cap < 1)) ||
        (actionUrl.isNotEmpty && (link == null || !['http', 'https'].contains(link.scheme) || link.host.isEmpty)) ||
        (imageUrl.isNotEmpty && (imgLink == null || !['http', 'https'].contains(imgLink.scheme) || imgLink.host.isEmpty))) {
      setState(() => error = 'راجع العنوان والعدد والمبلغ والرابط. الروابط لازم تبدأ بـ https:// أو http://');
      return;
    }
    final duration = int.tryParse(countdownMinutes.text.trim());
    if (scheduleMode == 'countdown' && !enabled) {
      setState(() => error = 'العد يبدأ عند تفعيل العرض. فعّل العرض قبل الحفظ.');
      return;
    }
    if (scheduleMode == 'countdown' && (duration == null || duration < 1 || duration > 525600)) {
      setState(() => error = 'مدة العد التنازلي من دقيقة حتى سنة.');
      return;
    }
    final start = scheduleMode == 'countdown' ? DateTime.now()
        : widget.original != null && !changedStart
          ? DateTime.parse(widget.original!['starts_at'].toString()).toLocal() : startDay;
    final end = scheduleMode == 'countdown' ? start.add(Duration(minutes: duration!))
        : widget.original != null && !changedEnd
          ? DateTime.parse(widget.original!['ends_at'].toString()).toLocal() : endDay;
    if (!end.isAfter(start)) {
      setState(() => error = 'تاريخ انتهاء العرض لازم يكون بعد بدايته.');
      return;
    }
    Uint8List? bytes;
    String? mime;
    if (selectedImage != null) {
      if (mounted) setState(() { readingImage = true; error = null; });
      try {
        bytes = await selectedImage!.readAsBytes();
        if (bytes.length > 3 * 1024 * 1024) throw FormatException('too_large');
        if (bytes.length > 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
          mime = 'image/png';
        } else if (bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
          mime = 'image/jpeg';
        } else if (bytes.length > 12 && String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
                   String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
          mime = 'image/webp';
        } else {
          throw FormatException('bad_type');
        }
      } catch (_) {
        if (mounted) setState(() { error = 'اختار صورة JPG أو PNG أو WebP أقل من 3 ميجابايت.'; readingImage = false; });
        return;
      }
      if (mounted) setState(() => readingImage = false);
    }
    if (!mounted) return;
    Navigator.of(context).pop(<String, dynamic>{
      'title': title.text.trim(),
      'description': description.text.trim(),
      'image_url': imageUrl.isEmpty ? null : imageUrl,
      if (bytes != null) '_image_bytes': bytes,
      if (mime != null) '_image_mime': mime,
      'action_url': actionUrl.isEmpty ? null : actionUrl,
      'target_trips': n, 'reward_amount': money,
      'max_recipients': cap,
      'starts_at': start.toUtc().toIso8601String(),
      'ends_at': end.toUtc().toIso8601String(),
      'is_active': enabled,
    });
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: AlertDialog(
      backgroundColor: AdminTheme.surface,
      title: Text(widget.original == null ? 'عرض مكافأة جديد' : 'تعديل عرض المكافأة',
        style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink,
          fontWeight: FontWeight.w800)),
      content: SizedBox(width: 480,
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          _field(title, 'عنوان العرض للكابتن'),
          _field(description, 'الشروط والوصف (مراجعة الإدارة قبل الصرف)', lines: 3),
          OutlinedButton.icon(onPressed: readingImage ? null : _pickBanner,
            icon: Icon(Icons.add_photo_alternate_outlined),
            label: Text(selectedImage == null ? 'اختيار صورة البانر من الجهاز' : 'تغيير الصورة المختارة')),
          if (selectedImage != null)
            Padding(padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('تم اختيار: ${selectedImage!.name}',
                style: TextStyle(color: AdminTheme.ink, fontFamily: 'Cairo')))
          else if (widget.original?['image_url'] != null)
            Padding(padding: EdgeInsets.symmetric(vertical: 8),
              child: Image.network(widget.original!['image_url'].toString(), height: 90,
                fit: BoxFit.contain, errorBuilder: (_, __, ___) =>
                  Text('صورة البانر السابقة', style: TextStyle(color: AdminTheme.ink)))),
          _field(url, 'الرابط عند الضغط على البانر (اختياري)'),
          _field(target, 'عدد الرحلات المكتملة المطلوبة', numeric: true),
          _field(amount, 'مبلغ المكافأة بالجنيه', numeric: true),
          _field(maxUsers, 'الحد الأقصى للفائزين (اتركه فارغًا بدون حد)', numeric: true),
          SizedBox(height: 12),
          Text('تحديد وقت العرض (بتوقيت جهاز الأدمن)', style: TextStyle(fontFamily: 'Cairo',
            color: AdminTheme.ink, fontWeight: FontWeight.w700)),
          RadioListTile<String>(value: 'range', groupValue: scheduleMode,
            onChanged: (v) => setState(() => scheduleMode = v!),
            title: Text('تاريخ وساعة بداية ونهاية حسب اختيارك',
              style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink))),
          RadioListTile<String>(value: 'countdown', groupValue: scheduleMode,
            onChanged: (v) => setState(() => scheduleMode = v!),
            title: Text('عد تنازلي يبدأ الآن',
              style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink))),
          if (scheduleMode == 'countdown')
            _field(countdownMinutes, 'مدة العرض بالدقائق (مثلاً 30)', numeric: true),
          if (scheduleMode == 'range') ...[
          TextButton.icon(onPressed: () => _pickDay(start: true),
            icon: Icon(Icons.calendar_today_rounded),
            label: Text('بداية العرض: ${startDay.day}/${startDay.month}/${startDay.year}')),
          TextButton.icon(onPressed: () => _pickTime(start: true),
            icon: Icon(Icons.access_time_rounded),
            label: Text('ساعة البداية: ${startDay.hour.toString().padLeft(2,'0')}:${startDay.minute.toString().padLeft(2,'0')}')),
          TextButton.icon(onPressed: () => _pickDay(start: false),
            icon: Icon(Icons.event_available_rounded),
            label: Text('تاريخ نهاية العرض: ${endDay.day}/${endDay.month}/${endDay.year}')),
          TextButton.icon(onPressed: () => _pickTime(start: false),
            icon: Icon(Icons.access_time_filled_rounded),
            label: Text('ساعة النهاية: ${endDay.hour.toString().padLeft(2,'0')}:${endDay.minute.toString().padLeft(2,'0')}')),
          ],
          SwitchListTile(value: enabled, title: Text('تفعيل العرض',
            style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink)),
            onChanged: (v) => setState(() => enabled = v),
            activeThumbColor: AdminTheme.goldDark),
          Text('بعد احتساب أول رحلة، شروط العدد والمبلغ والتواريخ لا تتغير. تقدر تعدل العنوان والصورة والرابط وتوقف العرض.',
            style: TextStyle(fontFamily: 'Cairo', color: Color(0xFFD0D9E9), fontSize: 11)),
          if (error != null)
            Text(error!, style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.error)),
        ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
        ElevatedButton(onPressed: readingImage ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.goldDark,
            foregroundColor: AppTheme.primary),
          child: Text('حفظ العرض', style: TextStyle(fontFamily: 'Cairo'))),
      ],
    ),
  );
}

class _ConfirmVodafonePaymentDialog extends StatefulWidget {
  const _ConfirmVodafonePaymentDialog({required this.participant});
  final Map<String, dynamic> participant;
  @override
  State<_ConfirmVodafonePaymentDialog> createState() => _ConfirmVodafonePaymentDialogState();
}

class _ConfirmVodafonePaymentDialogState extends State<_ConfirmVodafonePaymentDialog> {
  late final TextEditingController phone = TextEditingController(
      text: widget.participant['payout_phone']?.toString()
          ?? widget.participant['phone']?.toString() ?? '');
  final TextEditingController receipt = TextEditingController();
  bool transferred = false;
  @override
  void initState() {
    super.initState();
    phone.addListener(_rebuild);
    receipt.addListener(_rebuild);
  }
  void _rebuild() { if (mounted) setState(() {}); }
  @override
  void dispose() { phone.dispose(); receipt.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: AlertDialog(backgroundColor: AdminTheme.surface,
      title: Text('تأكيد تحويل فودافون كاش',
        style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink)),
      content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          Text('${widget.participant['name']} • ${widget.participant['amount']} جنيه',
            style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink)),
          SizedBox(height: 8),
          Text('نفّذ التحويل خارج التطبيق أولًا. الضغط هنا يسجّل إيصالًا فقط ولا يرسل مالًا.',
            style: TextStyle(fontFamily: 'Cairo', color: Color(0xFFFFDA84))),
          SizedBox(height: 12),
          TextField(controller: phone,
            style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
            decoration: InputDecoration(labelText: 'رقم محفظة فودافون كاش المستلمة')),
          SizedBox(height: 8),
          TextField(controller: receipt,
            style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
            decoration: InputDecoration(labelText: 'رقم العملية الفعلي (إجباري)')),
          CheckboxListTile(value: transferred,
            onChanged: (v) => setState(() => transferred = v ?? false),
            title: Text('أؤكد أنني حولت المبلغ بالفعل وراجعت رقم المحفظة',
              style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink, fontSize: 12)),
            activeColor: AdminTheme.goldDark,
          ),
        ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
        FilledButton(
          onPressed: !transferred || receipt.text.trim().length < 4 || phone.text.trim().length < 11
            ? null : () => Navigator.pop(context, <String, String>{
              'phone': phone.text.trim(), 'reference': receipt.text.trim(),
            }),
          child: Text('تسجيل إيصال التحويل'),
        ),
      ],
    ),
  );
}
