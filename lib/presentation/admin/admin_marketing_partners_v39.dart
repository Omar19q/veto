import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';

/// Owner-only UI. Existing Auth users are linked; no passwords or secret keys are handled here.
class AdminMarketingPartnersV39 extends StatefulWidget {
  const AdminMarketingPartnersV39({super.key});
  @override
  State<AdminMarketingPartnersV39> createState() => _AdminMarketingPartnersV39State();
}

class _AdminMarketingPartnersV39State extends State<AdminMarketingPartnersV39> {
  static const gold = Color(0xFFFFC928);
  List<Map<String, dynamic>> partners = const [];
  List<Map<String, dynamic>> settlements = const [];
  double sharePercent = 3;
  bool shareEnabled = false;
  bool loading = true;
  Timer? _liveReportTimer;
  String? error;

  @override
  void initState() {
    super.initState();
    _reload();
    _liveReportTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && !loading) _reload(silent: true);
    });
  }

  @override
  void dispose() {
    _liveReportTimer?.cancel();
    super.dispose();
  }

  Future<void> _reload({bool silent = false}) async {
    if (!silent && mounted) setState(() { loading = true; error = null; });
    try {
      final result = await SupabaseService.instance.client
          .rpc('v40_owner_partner_report').timeout(const Duration(seconds: 12));
      if (!mounted) return;
      final data = result is Map ? Map<String, dynamic>.from(result) : <String, dynamic>{};
      final policy = data['share'] is Map ? Map<String, dynamic>.from(data['share'] as Map) : <String, dynamic>{};
      setState(() {
        partners = (data['partners'] as List? ?? const [])
            .whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        settlements = (data['settlements'] as List? ?? const [])
            .whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        sharePercent = (policy['percent'] as num?)?.toDouble() ?? 3;
        shareEnabled = policy['enabled'] == true;
      });
    } catch (_) {
      if (mounted && !silent) setState(() => error = 'تعذّر تحميل تقارير الشراكة. تأكد من اتصالك وصلاحية الأونر.');
    } finally {
      if (mounted && !silent) setState(() => loading = false);
    }
  }

  Future<void> _editBonusPolicy() async {
    try {
      final raw=await SupabaseService.instance.client.rpc('v39_owner_partner_policy')
        .timeout(const Duration(seconds: 10));
      if (!mounted || raw is! Map) return;
      final trips=TextEditingController(text:'${raw['trips'] ?? 10}');
      final bonus=TextEditingController(text:'${raw['bonus'] ?? 50}');
      try {
        final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
          title:const Text('مكافأة انضمام الكابتن'),
          content:Column(mainAxisSize:MainAxisSize.min, children:[
            TextField(controller:trips,keyboardType:TextInputType.number,
              decoration:const InputDecoration(labelText:'عدد الرحلات المطلوبة')),
            TextField(controller:bonus,keyboardType:TextInputType.number,
              decoration:const InputDecoration(labelText:'مبلغ المكافأة للشريك')),
            const Text('مستحقات الشريك منفصلة عن محفظة العميل وأرباح الكابتن.',
              style:TextStyle(fontSize:11)),
          ]),
          actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('رجوع')),
            FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حفظ'))],
        ));
        if (yes!=true || !mounted) return;
        final count=int.tryParse(trips.text.trim());
        final value=double.tryParse(bonus.text.trim());
        if (count==null || count<1 || count>1000 || value==null || value<0 || value>10000) {
          throw const FormatException('invalid');
        }
        await SupabaseService.instance.client.rpc('v39_owner_set_partner_bonus', params:{
          'p_trips':count,'p_bonus':value,
        }).timeout(const Duration(seconds:10));
        await _reload();
      } finally {trips.dispose();bonus.dispose();}
    } catch (_) {
      if (mounted) setState(()=>error='تعذر حفظ إعدادات المكافأة.');
    }
  }

  // This screen accepts a phone number only. Internal UUIDs stay server-side.
  String? _normalizePartnerPhone(String raw) {
    const arabicNumbers = '٠١٢٣٤٥٦٧٨٩';
    const persianNumbers = '۰۱۲۳۴۵۶۷۸۹';
    final normalizedText = raw.split('').map((char) {
      final arabicIndex = arabicNumbers.indexOf(char);
      if (arabicIndex >= 0) return '$arabicIndex';
      final persianIndex = persianNumbers.indexOf(char);
      return persianIndex >= 0 ? '$persianIndex' : char;
    }).join();
    var digits = normalizedText.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0020') && digits.length == 14) {
      digits = '0${digits.substring(4)}';
    } else if (digits.startsWith('20') && digits.length == 12) {
      digits = '0${digits.substring(2)}';
    } else if (digits.startsWith('1') && digits.length == 10) {
      digits = '0$digits';
    }
    return RegExp(r'^01[0-9]{9}$').hasMatch(digits) ? digits : null;
  }

  String _partnerErrorMessage(Object exception) {
    final detail = exception.toString().toLowerCase();
    if (detail.contains('invalid_partner_phone')) {
      return 'رقم الهاتف غير صحيح.';
    }
    if (detail.contains('partner_account_not_found')) {
      return 'لا يوجد حساب مسجل بهذا الرقم.';
    }
    if (detail.contains('phone_ambiguous')) {
      return 'الرقم مرتبط بأكثر من حساب. راجع الدعم الفني.';
    }
    if (detail.contains('partner_code_taken') || detail.contains('23505')) {
      return 'كود الفريق مستخدم بالفعل. اختر كودًا آخر.';
    }
    if (detail.contains('owner_required') || detail.contains('42501')) {
      return 'ليس لديك صلاحية لإدارة الشركاء.';
    }
    if (detail.contains('invalid_partner_fields') || detail.contains('invalid_partner')) {
      return 'راجع الاسم وكود الفريق.';
    }
    if (detail.contains('v42_owner_add_partner_by_phone') ||
        detail.contains('42883') || detail.contains('pgrst202')) {
      return 'يجب تثبيت تحديث الشركاء في Supabase أولًا.';
    }
    return 'تعذّر حفظ الشريك. حاول مرة أخرى.';
  }

  Future<void> _edit({Map<String, dynamic>? partner}) async {
    final phone = TextEditingController();
    final name = TextEditingController(text: partner?['name']?.toString() ?? '');
    final code = TextEditingController(text: partner?['code']?.toString() ?? '');
    var active = partner?['active'] != false;
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, update) => AlertDialog(
            title: Text(partner == null ? 'إضافة شريك' : 'تعديل الشريك'),
            content: SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (partner == null) ...[
                      TextField(
                        controller: phone,
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        maxLength: 18,
                        decoration: const InputDecoration(
                          labelText: 'رقم هاتف الشريك',
                          hintText: '01xxxxxxxxx',
                          prefixIcon: Icon(Icons.phone_android_rounded),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    TextField(
                      controller: name,
                      maxLength: 120,
                      decoration: const InputDecoration(labelText: 'اسم الشريك'),
                    ),
                    TextField(
                      controller: code,
                      maxLength: 20,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        labelText: 'كود الفريق',
                        hintText: 'VETOTEAM01',
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('الشراكة مفعّلة'),
                      value: active,
                      onChanged: (value) => update(() => active = value),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      );
      if (ok != true || !mounted) return;
      final partnerName = name.text.trim();
      final partnerCode = code.text.trim().toUpperCase();
      if (partnerName.length < 2 ||
          !RegExp(r'^[A-Z0-9]{5,20}$').hasMatch(partnerCode)) {
        throw const FormatException('invalid_partner_fields');
      }

      if (partner == null) {
        final registeredPhone = _normalizePartnerPhone(phone.text);
        if (registeredPhone == null) {
          throw const FormatException('invalid_partner_phone');
        }
        // One owner-only server transaction resolves the account and creates
        // the partnership. No account IDs or private lists are exposed to UI.
        await SupabaseService.instance.client.rpc(
          'v42_owner_add_partner_by_phone',
          params: {
            'p_phone': registeredPhone,
            'p_name': partnerName,
            'p_code': partnerCode,
            'p_active': active,
          },
        ).timeout(const Duration(seconds: 12));
      } else {
        final userId = partner['user_id']?.toString();
        if (userId == null ||
            !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(userId)) {
          throw const FormatException('invalid_partner_account');
        }
        await SupabaseService.instance.client.rpc(
          'v39_owner_save_partner',
          params: {
            'p_user_id': userId,
            'p_name': partnerName,
            'p_code': partnerCode,
            'p_active': active,
          },
        ).timeout(const Duration(seconds: 12));
      }
      if (!mounted) return;
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(partner == null
            ? 'تمت إضافة الشريك بنجاح.' : 'تم حفظ بيانات الشريك.')),
      );
    } catch (exception) {
      if (!mounted) return;
      final message = _partnerErrorMessage(exception);
      setState(() => error = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      phone.dispose();
      name.dispose();
      code.dispose();
    }
  }

  Future<void> _editShare() async {
    final rate = TextEditingController(text: sharePercent.toString());
    bool enabled = shareEnabled;
    try {
      final ok = await showDialog<bool>(context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
          title: const Text('عمولة الشريك'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: rate, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'نسبة من أجرة الرحلة (%)')),
            SwitchListTile(title: const Text('تفعيل عمولة الرحلات'), value: enabled,
              onChanged: (value) => update(() => enabled = value)),
            const Text('لن تتجاوز عمولة الشريك عمولة الشركة الفعلية. الرحلات السابقة لا يعاد حسابها.',
              style: TextStyle(fontSize: 11)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
          ],
        )),
      );
      if (ok != true || !mounted) return;
      final parsed = double.tryParse(rate.text.trim());
      if (parsed == null || parsed < 0 || parsed > 100) throw const FormatException('invalid_percent');
      await SupabaseService.instance.client.rpc('v40_owner_set_share', params: {
        'p_percent': parsed, 'p_enabled': enabled,
      }).timeout(const Duration(seconds: 12));
      await _reload();
    } catch (_) {
      if (mounted) setState(() => error = 'تعذّر حفظ نسبة عمولة الشريك');
    } finally { rate.dispose(); }
  }

  Future<void> _monthlyReport(Map<String,dynamic> partner) async {
    try {
      final result=await SupabaseService.instance.client.rpc(
        'v43_partner_monthly_report',params:{'p_partner':partner['id']},
      ).timeout(const Duration(seconds:12));
      if (!mounted) return;
      final rows=(result is List ? result : const [])
        .whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
      await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
        title:Text('التقرير الشهري • ${partner['name'] ?? ''}'),
        content:SizedBox(width:440,height:350,child:rows.isEmpty
          ? const Center(child:Text('مفيش مستحقات للشهور دي'))
          :ListView(children:[for(final row in rows) ListTile(
            leading:const Icon(Icons.calendar_month_rounded),
            title:Text('${row['month'] ?? ''} • ${row['earned']??0} ج'),
            subtitle:Text('مستحق: ${row['due']??0} ج | مصروف: ${row['paid']??0} ج'),
          )])),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إغلاق'))],
      ));
    } catch (_) {
      if(mounted)setState(()=>error='تعذر تحميل التقرير الشهري. تأكد من SQL V43.');
    }
  }

  Future<void> _recordTransfer(Map<String, dynamic> row) async {
    final reference = TextEditingController();
    try {
      final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('تأكيد التحويل بعد الدفع'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${row['name'] ?? ''} • ${row['amount'] ?? 0} ج'),
          Text('محفظة: ${row['wallet'] ?? 'غير محددة'}'),
          const SizedBox(height: 8),
          TextField(controller: reference,
            decoration: const InputDecoration(labelText: 'رقم عملية التحويل', hintText: 'مرجع عملية الدفع')),
          const Text('تأكد إن المبلغ اتحوّل فعلًا قبل الضغط على التأكيد.',
            style: TextStyle(fontSize: 11)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('رجوع')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد الدفع')),
        ],
      ));
      if (ok != true || !mounted) return;
      await SupabaseService.instance.client.rpc('v40_owner_record_transfer', params: {
        'p_settlement': row['id'], 'p_reference': reference.text.trim(),
      }).timeout(const Duration(seconds: 12));
      await _reload();
    } catch (_) {
      if (mounted) setState(() => error = 'تعذّر تأكيد التحويل. راجع المرجع والحالة.');
    } finally { reference.dispose(); }
  }

  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('شركاء فيتو', style: TextStyle(fontFamily: 'Cairo')),
        actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh))]),
      body: Column(children: [
        const Padding(padding: EdgeInsets.all(12), child: Text(
          'إدارة الشركاء وتقارير الأداء.',
          style: TextStyle(fontFamily: 'Cairo', fontSize: 12))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
          child: OutlinedButton.icon(onPressed: _editShare,
            icon: const Icon(Icons.percent_rounded),
            label: Text('عمولة الشركاء: $sharePercent% • ${shareEnabled ? 'مفعلة' : 'موقوفة'}'))),
        Padding(padding: const EdgeInsets.symmetric(horizontal:12),
          child: OutlinedButton.icon(onPressed:_editBonusPolicy,
            icon:const Icon(Icons.tune_rounded),
            label:const Text('شروط مكافأة الفريق'))),
        Padding(padding: const EdgeInsets.all(12), child: SizedBox(width: double.infinity,
          child: FilledButton.icon(onPressed: () => _edit(),
            icon: const Icon(Icons.person_add_alt), label: const Text('إضافة شريك برقم الموبايل')))),
        if (error != null) Padding(padding: const EdgeInsets.all(12),
          child: Text(error!, style: const TextStyle(color: Colors.red))),
        if (loading) const LinearProgressIndicator(),
        if (settlements.isNotEmpty) SizedBox(height: 155,
          child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: settlements.length,
            itemBuilder: (ctx, index) {
              final row = settlements[index];
              final paid = row['state'] == 'paid';
              return SizedBox(width: 280, child: Card(child: Padding(
                padding: const EdgeInsets.all(10), child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${row['name'] ?? 'شريك'} • ${row['amount'] ?? 0} ج',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('محفظة: ${row['wallet'] ?? 'غير محددة'}', style: const TextStyle(fontSize: 11)),
                    const Spacer(),
                    paid ? const Text('تم التحويل', style: TextStyle(color: Colors.green))
                      : TextButton.icon(onPressed: () => _recordTransfer(row),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('تأكيد التحويل')),
                  ],
                ),
              )));
            }),
        ),
        Expanded(child: ListView.builder(itemCount: partners.length, itemBuilder: (ctx, index) {
          final item = partners[index];
          return Card(child: ListTile(
            leading: const Icon(Icons.groups_rounded, color: gold),
            title: Text(item['name']?.toString() ?? 'شريك', style: const TextStyle(fontFamily: 'Cairo')),
            subtitle: Text('${item['code']} · ${item['captains']} كابتن · ${item['completed']} رحلة\nعمولات: ${item['earned']} ج',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
            trailing: Row(mainAxisSize: MainAxisSize.min,children:[
              IconButton(tooltip:'التقرير الشهري',icon:const Icon(Icons.analytics_outlined),
                onPressed:()=>_monthlyReport(item)),
              IconButton(tooltip:'تعديل الشريك',icon:const Icon(Icons.edit_outlined),
                onPressed:()=>_edit(partner:item)),
            ]),
          ));
        })),
      ]),
    ),
  );
}
