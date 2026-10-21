import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/supabase_service.dart';

/// Read-only oversight: no automatic suspensions, penalties, or wallet mutations.
class AdminBehaviorRobotV58 extends StatefulWidget {
  const AdminBehaviorRobotV58({super.key});
  @override
  State<AdminBehaviorRobotV58> createState()=>_AdminBehaviorRobotV58State();
}
class _AdminBehaviorRobotV58State extends State<AdminBehaviorRobotV58> {
  Map<String,dynamic> report={};
  bool loading=false;
  String? error;
  Timer? _timer;
  @override void initState(){
    super.initState();
    _refresh();
    _timer=Timer.periodic(const Duration(minutes:1),(_)=>_refresh());
  }
  @override void dispose(){_timer?.cancel();super.dispose();}
  Future<void> _refresh() async {
    if(loading)return;
    setState((){loading=true;error=null;});
    try{
      final r=await SupabaseService.instance.client.rpc('v58_owner_behavior_robot');
      if(mounted)setState(()=>report=Map<String,dynamic>.from(r as Map));
    }catch(_){if(mounted)setState(()=>error='تعذر جلب مؤشرات المراقبة. راجع SQL وصلاحيات الأدمن.');}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Widget card(String title,IconData icon,Map<String,dynamic> stats,List<(String,String)> labels){
    return Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Icon(icon),const SizedBox(width:9),
          Text(title,style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold))]),
        const Divider(),
        for(final item in labels) ListTile(
          dense:true,
          title:Text(item.$2),
          trailing:Text('${stats[item.$1]??0}',
            style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900))),
      ])));
  }
  @override Widget build(BuildContext context)=>Directionality(
    textDirection:TextDirection.rtl,child:Scaffold(
      appBar:AppBar(title:const Text('روبوت متابعة السلوك'),actions:[
        IconButton(tooltip:'تحديث',onPressed:_refresh,icon:const Icon(Icons.refresh))]),
      body:ListView(padding:const EdgeInsets.all(14),children:[
        const Text('فحص دوري كل دقيقة: تنبيهات للمراجعة البشرية فقط. لا حظر ولا غرامات ولا خصم آلي.',
           style:TextStyle(fontWeight:FontWeight.w600)),
        const SizedBox(height:12),
        if(loading)const LinearProgressIndicator(),
        if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
        card('سلوك العميل',Icons.person_outline,
          Map<String,dynamic>.from(report['customer'] as Map? ??{}),
          const [('cancellations_24h','إلغاءات العملاء خلال 24 ساعة'),
                 ('feedback_open','شكاوى قيد المتابعة')]),
        card('سلوك الكابتن',Icons.drive_eta_outlined,
          Map<String,dynamic>.from(report['captain'] as Map? ??{}),
          const [('cancellations_24h','إلغاءات الكباتن خلال 24 ساعة'),
                 ('online_stale_gps','كباتن متصلون وموقعهم غير محدّث')]),
        card('سلوك الرحلة',Icons.route_outlined,
          Map<String,dynamic>.from(report['trip'] as Map? ??{}),
          const [('search_older_10m','طلبات تبحث منذ أكثر من 10 دقائق'),
                 ('accepted_older_45m','رحلات مقبولة منذ أكثر من 45 دقيقة'),
                 ('completed_24h','رحلات اكتملت خلال 24 ساعة')]),
        const SizedBox(height:8),
        Text('آخر فحص: ${report['checked_at']??'غير متاح'}',
          style:const TextStyle(fontSize:11)),
      ]),
    ));
}
