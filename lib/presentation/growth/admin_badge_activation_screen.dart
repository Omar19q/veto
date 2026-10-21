import 'package:flutter/material.dart';
import '../../services/growth_service.dart';
import '../../services/growth_badge_pdf.dart';
import '../../services/admin_environment_support.dart';
import 'package:printing/printing.dart';

/// Owner-controlled badge installation, team attribution and earned zero-fee
/// vouchers. No direct table writes or wallet math in the Flutter client.
class AdminBadgeActivationScreen extends StatefulWidget {
  const AdminBadgeActivationScreen({super.key});
  @override
  State<AdminBadgeActivationScreen> createState() => _AdminBadgeActivationScreenState();
}

class _AdminBadgeActivationScreenState extends State<AdminBadgeActivationScreen> {
  final _service = GrowthService();
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _partners = const [];
  Map<String, dynamic>? _referralTotals;
  bool _busy = false;
  String? _error;
  String? _teamWarning;
  String _search = '';

  @override
  void initState() { super.initState(); _reload(); }

  Future<void> _reload() async {
    // The badge panel is independent from partner reporting. Do not hide all
    // captains when team directory or optional marketing totals are unavailable.
    try {
      final badge = await _service.call('v52_owner_badge_panel');
      if (!mounted) return;
      setState(() { _data = badge; _error = null; });
    } catch (error) {
      if (mounted) setState(() => _error = AdminEnvironmentSupport.explain(
          error, 'v52_owner_badge_panel'));
      return;
    }
    try {
      final teams = await _service.call('v52_owner_team_directory');
      if (!mounted) return;
      setState(() {
        _partners = ((teams['partners'] as List?) ?? [])
          .whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        _teamWarning = null;
      });
    } catch (error) {
      if (mounted) setState(() {
        _teamWarning = AdminEnvironmentSupport.explain(error, 'v52_owner_team_directory');
        _partners = const [];
      });
    }
    try {
      final totals = await _service.ownerReferralOverview();
      if (mounted) setState(() => _referralTotals = totals);
    } catch (_) {
      if (mounted) setState(() => _referralTotals = null);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await action();
      await _reload();
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر حفظ الطلب. تحقق من الصلاحيات والاتصال وحالة الكابتن. لا تعِد منح المكافأة قبل التحقق من سجلها.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editPolicy() async {
    final p = Map<String, dynamic>.from(_data?['policy'] as Map? ?? {});
    final place = TextEditingController(text: '${p['location'] ?? ''}');
    final opens = TextEditingController(text: '${p['opens'] ?? ''}');
    final closes = TextEditingController(text: '${p['closes'] ?? ''}');
    final days = TextEditingController(text: '${p['days'] ?? ''}');
    final copies = TextEditingController(text: '${p['print_copies'] ?? 2}');
    bool requireNew = p['enforce_new'] == true;
    bool autoCredit = p['auto_credit_rewards'] == true;
    try {
      final submit = await showDialog<bool>(context: context, builder: (ctx) =>
        StatefulBuilder(builder: (ctx, update) => AlertDialog(
          title: const Text('مكان ومواعيد تفعيل البادج'),
          content: SizedBox(width: 430, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: place, decoration: const InputDecoration(labelText: 'مكان التفعيل')),
            TextField(controller: opens, decoration: const InputDecoration(labelText: 'من الساعة')),
            TextField(controller: closes, decoration: const InputDecoration(labelText: 'إلى الساعة')),
            TextField(controller: days, decoration: const InputDecoration(labelText: 'الأيام')),
            TextField(controller: copies, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد نسخ الطباعة الملونة')),
            SwitchListTile(value: requireNew, onChanged: (v) => update(() => requireNew = v),
              title: const Text('اشتراط تفعيل البادج للكباتن الجدد فقط'),
              subtitle: const Text('لن يتم تعطيل الكباتن السابقين. التفعيل يتم من الأدمن بعد التركيب.')),
            SwitchListTile(value: autoCredit, onChanged: (v) => update(() => autoCredit = v),
              title: const Text('إيداع مكافآت الإحالة الجديدة بالمحفظة تلقائيًا'),
              subtitle: const Text('للأكواد المفعّلة فقط، ولا يتم إعادة صرف أرصدة تاريخية.')),
          ]))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('رجوع')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
          ],
        )));
      if (submit != true || !mounted) return;
      final count = int.tryParse(copies.text.trim());
      if (count == null || count < 1 || count > 10 || place.text.trim().length < 6) {
        setState(() => _error = 'راجع الموقع وعدد النسخ (من 1 إلى 10).');
        return;
      }
      await _run(() async {
        await _service.call('v52_owner_badge_settings', {
          'p_location': place.text.trim(), 'p_opens': opens.text.trim(),
          'p_closes': closes.text.trim(), 'p_days': days.text.trim(),
          'p_copies': count, 'p_require_new': requireNew, 'p_auto_credit': autoCredit,
        });
      });
    } finally { place.dispose(); opens.dispose(); closes.dispose(); days.dispose(); copies.dispose(); }
  }

  Future<void> _setBadge(Map<String, dynamic> captain, bool active) async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(active ? 'تأكيد تركيب البادج وتفعيل الكابتن' : 'إلغاء تفعيل البادج'),
      content: Text('${captain['name']}\n${active ? 'هل تسلمت النسختين وتم تركيب البادج بالفعل؟' : 'لن نحذف سجل الرحلات أو الإحالات السابقة.'}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('رجوع')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد')),
      ],
    ));
    if (yes != true) return;
    await _run(() => _service.call('v52_owner_badge_activate', {
      'p_captain': captain['captain_id'], 'p_activate': active,
      'p_note': active ? 'تم تسليم وتركيب البادج بواسطة نقطة التفعيل' : 'تعطيل من لوحة المالك',
    }).then((_) {}));
  }

  /// An unused badge code may be corrected by the owner. Previously scanned
  /// codes and already-earned referrals must never be silently reassigned.
  Future<void> _editUnusedBadgeCode(Map<String, dynamic> captain) async {
    final current = captain['badge_code']?.toString() ?? '';
    final controller = TextEditingController(text: current);
    try {
      final agreed = await showDialog<bool>(context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تصحيح كود بادج غير مستخدم'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('الكابتن: ${captain['name']}'),
            const SizedBox(height: 10),
            TextField(controller: controller, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'كود جديد فريد يبدأ من 1001')),
            const SizedBox(height: 8),
            const Text('لن يسمح النظام بالتغيير بعد تسجيل إحالة، صرف مكافأة أو تفعيل بادج؛ لحماية الأكواد المطبوعة.',
              style: TextStyle(fontSize: 12)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('احفظ بعد التحقق')),
          ],
        ),
      );
      if (agreed != true || !mounted) return;
      final value = controller.text.trim();
      if (!RegExp(r'^[0-9]{4,19}$').hasMatch(value) || BigInt.parse(value) < BigInt.from(1001)) {
        setState(() => _error = 'الكود غير صحيح: اكتب رقمًا يبدأ من 1001.'); return;
      }
      await _run(() async {
        final result = await _service.call('v59_owner_change_unused_badge_code', {
          'p_captain_id': captain['captain_id'], 'p_new_code': value,
        });
        if (result['success'] != true) throw StateError('badge_code_not_changed');
      });
    } finally { controller.dispose(); }
  }

  Future<void> _grantZero(Map<String, dynamic> captain) async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('عرض ساعتين بدون عمولة'),
      content: Text('كابتن: ${captain['name']}\nيظهر العرض للكابتن لمدة 24 ساعة لتفعيله بنفسه. بعد التفعيل يعمل ساعتين على مشاوير السيارة فقط. الحافز والفكة والتسويات تبقى بالقواعد الأصلية.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('منح العرض')),
      ],
    ));
    if (yes != true) return;
    // One UUID for this user action; never retry a timed-out financial grant
    // under a second request ID automatically.
    final requestId = GrowthService.uuid();
    await _run(() => _service.call('v52_owner_grant_zero_offer', {
      'p_captain': captain['captain_id'], 'p_request_id': requestId,
    }).then((_) {}));
  }

  Future<void> _printCaptainBadge(Map<String, dynamic> captain) async {
    final code = captain['badge_code']?.toString() ?? '';
    if (!GrowthBadgePdf.validCode(code)) {
      if (!mounted) return;
      setState(() => _error = 'ليس للكابتن كود بادج صحيح بعد. يجب اعتماد حسابه وتخصيص الكود أولًا.');
      return;
    }
    if (captain['status'] != 'active') {
      if (!mounted) return;
      setState(() => _error = 'لا يمكن طباعة بادج لحساب لم يتم اعتماده.');
      return;
    }
    try {
      await Printing.layoutPdf(onLayout: (_) => GrowthBadgePdf.buildA4(
        code, motorcycle: captain['vehicle'] != 'car'));
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر عرض ملف الطباعة. تأكد من توفر أصول التصميم والخطوط.');
    }
  }

  Future<void> _team(Map<String, dynamic> captain) async {
    if (_teamWarning != null) {
      if (mounted) setState(() => _error = 'لا يمكن تعديل الفريق قبل تحميل دليل الشركاء بنجاح.');
      return;
    }
    String? selected = _partners.where((p) => p['code'] == captain['team_code'])
        .map((p) => p['id']?.toString()).firstOrNull;
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) =>
      StatefulBuilder(builder: (ctx, update) => AlertDialog(
        title: Text('فريق ${captain['name']}'),
        content: DropdownButtonFormField<String>(
          value: selected, isExpanded: true,
          decoration: const InputDecoration(labelText: 'اختر الفريق / الشريك'),
          items: [const DropdownMenuItem<String>(value: null, child: Text('بدون فريق')),
            for (final p in _partners.where((p) => p['active'] == true))
              DropdownMenuItem(value: '${p['id']}', child: Text('${p['name']} · ${p['code']}'))],
          onChanged: (v) => update(() => selected = v),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('رجوع')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ الارتباط'))],
      )));
    if (confirmed != true) return;
    await _run(() => _service.call('v52_owner_team_assign', {
      'p_captain': captain['captain_id'], 'p_partner': selected,
    }).then((_) {}));
  }

  Widget _summaryRow(String label, dynamic amount) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Expanded(child: Text(label)),
      Text('${amount ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final all = ((_data?['captains'] as List?) ?? [])
        .whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final captains = all.where((p) => '${p['name']} ${p['phone']} ${p['badge_code']}'
        .toLowerCase().contains(_search.toLowerCase())).toList();
    final policy = Map<String, dynamic>.from(_data?['policy'] as Map? ?? {});
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(title: const Text('تفعيل البادج والفرق والعروض'), actions: [
        IconButton(icon: const Icon(Icons.refresh), tooltip: 'تحديث', onPressed: _busy ? null : _reload),
      ]),
      body: _data == null && _error == null ? const Center(child: CircularProgressIndicator()) :
      ListView(padding: const EdgeInsets.all(16), children: [
        const AdminEnvironmentBanner(),
        if (_teamWarning != null) Text('تنبيه: بيانات البادج متاحة، لكن الفرق لم تُحمّل. $_teamWarning',
          style: TextStyle(color: scheme.error)),
        if (_error != null) Text(_error!, style: TextStyle(color: scheme.error)),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('نقطة التفعيل', style: Theme.of(context).textTheme.titleLarge),
            Text('${policy['location'] ?? ''}'),
            Text('${policy['days'] ?? ''} · ${policy['opens'] ?? ''} – ${policy['closes'] ?? ''}'),
            Text('طباعة ملونة: ${policy['print_copies'] ?? 2} نسخة A4 أفقي'),
            OutlinedButton.icon(onPressed: _busy ? null : _editPolicy,
              icon: const Icon(Icons.edit_calendar), label: const Text('تعديل المكان والمواعيد والشروط')),
          ],
        ))),
        if (_referralTotals != null) Card(child: ExpansionTile(
          initiallyExpanded: true,
          title: const Text('تقارير الدعوات والبادج والشراكات'),
          subtitle: const Text('كل مصدر منفصل عن الآخر؛ الأرصدة من الخادم'),
          childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          children: [
            _summaryRow('أكواد الكباتن', _referralTotals!['captain_codes']),
            _summaryRow('بادجات مفعلة', _referralTotals!['badge_activated']),
            _summaryRow('عملاء من أكواد الكباتن', _referralTotals!['captain_registrations']),
            _summaryRow('رحلات إحالة كابتن مكتملة', _referralTotals!['captain_completed']),
            _summaryRow('مكافآت كباتن مستحقة (ج)', _referralTotals!['captain_due']),
            _summaryRow('مكافآت كباتن مدفوعة (ج)', _referralTotals!['captain_paid']),
            const Divider(),
            _summaryRow('أكواد دعوة الأصدقاء', _referralTotals!['friend_codes']),
            _summaryRow('تسجيلات دعوة صديق', _referralTotals!['friend_registrations']),
            _summaryRow('أول رحلات أصدقاء مكتملة', _referralTotals!['friend_completed']),
            _summaryRow('مكافآت أصدقاء مدفوعة (ج)', _referralTotals!['friends_paid']),
            _summaryRow('أرصدة ترويجية قديمة (ج)', _referralTotals!['friends_promotional_legacy']),
            const Divider(),
            _summaryRow('عدد الفرق / الشركاء', _referralTotals!['teams']),
            _summaryRow('الكباتن المرتبطون بالفرق', _referralTotals!['team_links']),
            _summaryRow('مستحقات الشركاء غير المدفوعة (ج)', _referralTotals!['team_due']),
            _summaryRow('مستحقات الشركاء المدفوعة (ج)', _referralTotals!['team_paid']),
          ],
        )),
        if (_referralTotals == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('تفاصيل تقارير المرحلة الرابعة غير متاحة قبل ترحيل SQL؛ وظائف الإدارة السابقة تظل متاحة.'),
          ),
        if (_partners.isNotEmpty) Card(child: ExpansionTile(
          title: const Text('الفرق والشركاء'),
          children: [for (final p in _partners) ListTile(
            title: Text('${p['name']} · ${p['code']}'),
            subtitle: Text('الكباتن ${p['members']} · مستحقات ${p['earned']} ج · مدفوع ${p['paid']} ج'),
          )],
        )),
        TextField(onChanged: (value) => setState(() => _search = value),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search),
            hintText: 'ابحث باسم أو رقم الكابتن أو كود البادج')),
        const SizedBox(height: 12),
        for (final c in captains) Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${c['name']} · ${c['badge_code'] ?? 'الكود لم يتخصص بعد'}',
              style: Theme.of(context).textTheme.titleMedium),
            Text('${c['phone']} · ${c['vehicle']} · ${c['status']}'),
            Text(c['activated_at'] == null ? 'البادج لم يُفعّل' : 'البادج مفعّل من ${c['activated_at']}'),
            Text('أدخل ${c['registrations']} عميل · مكافآت مودعة ${c['reward_paid']} ج'),
            Text('كود البادج: ${c['badge_code'] ?? 'غير مخصص'} · كود الفريق: ${c['team_code'] ?? 'غير مرتبط'}'),
            Text('الشريك: ${c['partner'] ?? 'غير مرتبط'}'),
            Text('الرمز شخصي ويظهر نفسه في كل PDF وQR، ولا يُستبدل تلقائيًا.'),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              FilledButton.tonalIcon(onPressed: _busy ? null : () => _setBadge(c,c['activated_at'] == null),
                icon: Icon(c['activated_at'] == null ? Icons.verified_outlined : Icons.block_outlined),
                label: Text(c['activated_at'] == null ? 'تفعيل بعد التركيب' : 'تعطيل البادج')),
              OutlinedButton.icon(onPressed: _busy ? null : () => _editUnusedBadgeCode(c),
                icon: const Icon(Icons.edit_outlined), label: const Text('تصحيح كود غير مستخدم')),
              OutlinedButton.icon(onPressed: _busy ? null : () => _team(c),
                icon: const Icon(Icons.groups), label: const Text('إدارة الفريق')),
              OutlinedButton.icon(onPressed: _busy || !GrowthBadgePdf.validCode('${c['badge_code'] ?? ''}')
                  ? null : () => _printCaptainBadge(c),
                icon: const Icon(Icons.print), label: const Text('طباعة بادج الكابتن')),
              if (c['vehicle'] == 'car') OutlinedButton.icon(
                onPressed: _busy ? null : () => _grantZero(c),
                icon: const Icon(Icons.timer_outlined), label: const Text('ساعتان 0% عمولة')),
            ]),
          ],
        ))),
        if (_busy) const LinearProgressIndicator(),
        const SizedBox(height: 32),
      ]),
    ));
  }
}
