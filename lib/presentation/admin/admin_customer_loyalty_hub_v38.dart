import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import 'admin_customer_frames_v29.dart';

/// The owner finds frames AND reward setup in one customer-loyalty section.
class AdminCustomerLoyaltyHubV38 extends StatefulWidget {
  const AdminCustomerLoyaltyHubV38({super.key});
  @override State<AdminCustomerLoyaltyHubV38> createState() => _AdminCustomerLoyaltyHubV38State();
}

class _AdminCustomerLoyaltyHubV38State extends State<AdminCustomerLoyaltyHubV38> {
  bool _showRewards = false;
  @override Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.all(12), child: SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value:false, icon:Icon(Icons.workspace_premium_outlined), label:Text('الرتب والإطارات')),
        ButtonSegment(value:true, icon:Icon(Icons.card_giftcard_outlined), label:Text('مكافآت العملاء')),
      ],
      selected:{_showRewards},
      onSelectionChanged: (choices) => setState(() => _showRewards=choices.first),
    )),
    Expanded(child:_showRewards ? const AdminRewardDraftsV38() : const AdminCustomerFramesV29()),
  ]);
}

class AdminRewardDraftsV38 extends StatefulWidget {
  const AdminRewardDraftsV38({super.key});
  @override State<AdminRewardDraftsV38> createState()=>_AdminRewardDraftsV38State();
}

class _AdminRewardDraftsV38State extends State<AdminRewardDraftsV38> {
  bool _loading=false;
  List<Map<String,dynamic>> _rewards=[];
  Map<String,dynamic>? _liveV39;
  String? _error;

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading=true; _error=null; });
    try {
      final response = await SupabaseService.instance.client
          .rpc('v37_admin_city_catalog').timeout(const Duration(seconds:12));
      if (!mounted) return;
      if (response is! Map) throw StateError('invalid_response');
      setState(() => _rewards=(response['rewards'] as List? ?? [])
          .whereType<Map>().map((r)=>Map<String,dynamic>.from(r)).toList());
      try {
        final v39 = await SupabaseService.instance.client.rpc('v39_owner_reward_policy')
            .timeout(const Duration(seconds: 7));
        if (mounted && v39 is Map) {
          setState(() => _liveV39 = Map<String,dynamic>.from(v39));
        }
      } catch (_) { /* V39 has not been installed: keep V38 read-only. */ }

    } catch (_) {
      if(mounted) setState(()=>_error='تعذر تحميل المكافآت. راجع صلاحيات الأونر وSQL.');
    } finally { if(mounted)setState(()=>_loading=false); }
  }

  Future<void> _edit(Map<String,dynamic> reward) async {
    final title=TextEditingController(text:reward['title']?.toString()??'');
    final trips=TextEditingController(text:'${reward['completed_trips_required']??50}');
    final amount=TextEditingController(text:'${reward['proposed_credit_egp']??0}');
    try {
      final save=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
        title:const Text('تعديل المكافأة'),
        content:Column(mainAxisSize:MainAxisSize.min,children:[
          TextField(controller:title,decoration:const InputDecoration(labelText:'اسم المكافأة')),
          TextField(controller:trips,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'عدد الرحلات')),
          TextField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'قيمة المكافأة بالجنيه')),
          const SizedBox(height:8),
          const Text('الحفظ لا يضيف رصيدًا للمحفظة. صرف المكافآت يحتاج منظومة معتمدة.',
            style:TextStyle(fontSize:11)),
        ]),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('رجوع')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حفظ')),
        ],
      ));
      if(save!=true||!mounted)return;
      final n=int.tryParse(trips.text.trim());
      final v=double.tryParse(amount.text.trim());
      if(n==null||n<=0||n>100000||v==null||v<0||v>100000 || title.text.trim().length<2) {
        throw const FormatException('invalid_reward');
      }
      await SupabaseService.instance.client.rpc('v37_admin_edit_reward_draft',params:{
        'p_id':reward['id'], 'p_title':title.text.trim(), 'p_trips':n, 'p_credit':v,
      }).timeout(const Duration(seconds:12));
      await _load();
    } catch (_) { if(mounted)setState(()=>_error='راجع اسم المكافأة والقيمة وحاول تاني.'); }
    finally {title.dispose();trips.dispose();amount.dispose();}
  }

  Future<void> _markForReview(Map<String,dynamic> reward,bool ready) async {
    try {
      await SupabaseService.instance.client.rpc('v38_admin_set_reward_readiness',params:{
        'p_id':reward['id'], 'p_ready':ready,
      }).timeout(const Duration(seconds:12));
      await _load();
    } catch (_) { if(mounted)setState(()=>_error='تعذر تغيير الجاهزية؛ تأكد من تنفيذ SQL V38.'); }
  }

  Future<void> _setLiveV39(bool enabled) async {
    final current=_liveV39;
    if (current == null) return;
    final confirmed=await showDialog<bool>(context:context,builder:(dialog) => AlertDialog(
      title:Text(enabled ? 'تشغيل مكافأة العملاء؟' : 'إيقاف المكافأة؟'),
      content:Text(enabled
        ? 'ده بيضيف رصيد حقيقي مرة واحدة للعملاء المؤهلين بعد اكتمال الرحلة. لازم تختبره على نسخة تجريبية الأول.'
        : 'لن تُصرف مكافآت جديدة بعد الإيقاف. المدفوعات القديمة مش هتتغير.'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(dialog,false),child:const Text('رجوع')),
        FilledButton(onPressed:()=>Navigator.pop(dialog,true),child:const Text('تأكيد')),
      ],
    ));
    if (confirmed != true || !mounted) return;
    try {
      await SupabaseService.instance.client.rpc('v39_owner_set_customer_reward',params:{
        'p_enabled': enabled,
        'p_completed_trips': (current['trips'] as num?)?.toInt() ?? 10,
        'p_credit': (current['amount'] as num?)?.toDouble() ?? 150.0,
      }).timeout(const Duration(seconds:12));
      await _load();
    } catch (_) {
      if (mounted) setState(()=>_error='تعذر تحديث المكافأة. راجع صلاحية الأونر.');
    }
  }

  Future<void> _editLiveV39() async {
    if (_liveV39==null) return;
    final trips=TextEditingController(text:'${_liveV39!['trips'] ?? 10}');
    final credit=TextEditingController(text:'${_liveV39!['amount'] ?? 150}');
    try {
      final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
        title:const Text('شروط مكافأة العملاء'),
        content:Column(mainAxisSize:MainAxisSize.min,children:[
          TextField(controller:trips,keyboardType:TextInputType.number,
            decoration:const InputDecoration(labelText:'عدد الرحلات المكتملة')),
          TextField(controller:credit,keyboardType:TextInputType.number,
            decoration:const InputDecoration(labelText:'المكافأة بالجنيه')),
        ]),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('رجوع')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حفظ'))],
      ));
      if (ok!=true || !mounted) return;
      final n=int.tryParse(trips.text);
      final amount=double.tryParse(credit.text);
      if (n==null || n<1 || n>10000 || amount==null || amount<=0 || amount>10000) {
        throw const FormatException('invalid');
      }
      await SupabaseService.instance.client.rpc('v39_owner_set_customer_reward',params:{
        'p_enabled':_liveV39!['enabled']==true,
        'p_completed_trips':n,
        'p_credit':amount,
      }).timeout(const Duration(seconds:12));
      await _load();
    } catch (_) {
      if (mounted) setState(()=>_error='راجع العدد وقيمة المكافأة وحاول تاني.');
    } finally { trips.dispose();credit.dispose(); }
  }

  Future<void> _reconcileV39() async {
    if (_liveV39?['enabled'] != true) return;
    final confirm=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('مراجعة مكافآت الرحلات السابقة'),
      content:const Text('سيتم صرف المستحقات المؤهلة لحد أقصى 50 عميل في المحاولة، مع منع صرف نفس المكافأة مرتين. اختبر العملية على قاعدة تجريبية أولًا.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('بدء المراجعة'))],
    ));
    if (confirm!=true || !mounted) return;
    try {
      final count=await SupabaseService.instance.client.rpc('v39_owner_backfill_customer_rewards',
        params:{'p_limit':50}).timeout(const Duration(seconds:25));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text('تمت معالجة $count مكافأة')));
    } catch (_) { if (mounted) setState(()=>_error='تعذر معالجة المكافآت القديمة.'); }
  }

  @override Widget build(BuildContext context) => Container(
    color:const Color(0xFF0B1122),
    child:Column(children:[
      const Padding(padding:EdgeInsets.all(12),child:Text(
        'جهّز المكافآت هنا. الاعتماد الداخلي مش معناه صرف رصيد تلقائي.',
        style:TextStyle(fontFamily:'Cairo',color:Colors.white70,fontSize:12),
      )),
      if (_liveV39 != null) Card(
        color:const Color(0xFF1B2A42),
        child:ListTile(
          title:Text('مكافأة ${( _liveV39!['trips'] ?? 10)} رحلات',
            style:const TextStyle(fontFamily:'Cairo',color:Colors.white,
              fontWeight:FontWeight.bold)),
          subtitle:Text('${_liveV39!['amount']} ج · مرة واحدة لكل عميل',
            style:const TextStyle(fontFamily:'Cairo',color:Colors.white70)),
          leading:Switch(value:_liveV39!['enabled']==true,
            onChanged:_setLiveV39),
          trailing:IconButton(icon:const Icon(Icons.edit,color:Colors.amber),
            onPressed:_editLiveV39),
        ),
      ),
      if (_liveV39?['enabled'] == true)
        TextButton.icon(onPressed:_reconcileV39,
          icon:const Icon(Icons.fact_check_outlined),
          label:const Text('مراجعة مكافآت الرحلات السابقة')),
      if(_loading) const LinearProgressIndicator(),
      if(_error!=null) Text(_error!,style:const TextStyle(color:Colors.orange)),
      Expanded(child:ListView(children:[if (_liveV39 == null) for(final reward in _rewards)
        Card(color:const Color(0xFF19243B),child:ListTile(
          title:Text(reward['title']?.toString()??'',style:const TextStyle(color:Colors.white,fontFamily:'Cairo')),
          subtitle:Text('${reward['completed_trips_required']} رحلة · ${reward['proposed_credit_egp']} ج · لا يُصرف تلقائيًا',
            style:const TextStyle(color:Colors.white70,fontFamily:'Cairo',fontSize:11)),
          leading:Switch(value:reward['review_ready']==true,
            onChanged:(value)=>_markForReview(reward,value)),
          trailing:IconButton(onPressed:()=>_edit(reward),icon:const Icon(Icons.edit_outlined,color:Colors.amber)),
        )),
      ])),
    ]),
  );
}
