import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';

/// Read-only history of the original application records, all pages.
class LegacyApplicationsV16 extends StatefulWidget {
  const LegacyApplicationsV16({super.key});
  @override State<LegacyApplicationsV16> createState()=>_LegacyApplicationsV16State();
}
class _LegacyApplicationsV16State extends State<LegacyApplicationsV16> {
  int page=0,total=0;
  static const pageSize=50;
  bool loading=false;
  String? error;
  List<Map<String,dynamic>> rows=[];
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {
    if(loading)return;
    setState((){loading=true;error=null;});
    try{
      final raw=await SupabaseService.instance.client.rpc('v58_owner_legacy_page',
        params:{'p_offset':page*pageSize,'p_limit':pageSize});
      if(!mounted)return;
      final data=Map<String,dynamic>.from(raw as Map);
      setState((){
        total=(data['total'] as num?)?.toInt()??0;
        rows=(data['rows'] as List? ?? [])
          .whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
      });
    }catch (_){
      if(mounted)setState(()=>error='تعذر تحميل أرشيف الطلبات. راجع SQL وصلاحيات الأونر.');
    }finally{if(mounted)setState(()=>loading=false);}
  }
  @override Widget build(BuildContext context)=>Directionality(
    textDirection:TextDirection.rtl,child:Scaffold(
    appBar:AppBar(title:const Text('كل الطلبات القديمة'),
      actions:[IconButton(onPressed:_load,icon:const Icon(Icons.refresh))]),
    body:Column(children:[
      const Padding(padding:EdgeInsets.all(12),child:Text(
        'الطلبات التاريخية محفوظة للعرض. تحويل حساب قديم لكابتن يحتاج اعتماد الهوية والمستندات بالطريقة الحالية.',
        style:TextStyle(fontSize:13))),
      if(loading)const LinearProgressIndicator(),
      if(error!=null)Text(error!),
      Expanded(child:rows.isEmpty
        ?const Center(child:Text('لا توجد سجلات أرشيف في هذه الصفحة'))
        :ListView.builder(itemCount:rows.length,itemBuilder:(ctx,i){
          final r=rows[i];
          return Card(child:ListTile(
            title:Text(r['full_name']?.toString()??'طلب قديم'),
            subtitle:SelectableText('${r['phone']??''} • ${r['status']??'pending'} • ${r['vehicle_type']??''}'),
          ));
        })),
      Row(children:[
        const SizedBox(width:12),
        Expanded(child:Text('صفحة ${page+1} • $total طلب تاريخي')),
        IconButton(tooltip:'السابق',onPressed:page==0?null:(){
          setState(()=>page--);_load();
        },icon:const Icon(Icons.chevron_right)),
        IconButton(tooltip:'التالي',onPressed:(page+1)*pageSize>=total?null:(){
          setState(()=>page++);_load();
        },icon:const Icon(Icons.chevron_left)),
      ]),
    ]),
  ));
}
