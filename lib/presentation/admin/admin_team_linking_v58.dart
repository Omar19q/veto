import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../services/admin_environment_support.dart';
import '../growth/admin_badge_activation_screen.dart';

/// The team code identifies a marketing partner; badge code identifies the captain.
/// Changing team never alters historical earnings.
class AdminTeamLinkingV58 extends StatefulWidget {
  const AdminTeamLinkingV58({super.key});
  @override
  State<AdminTeamLinkingV58> createState()=>_AdminTeamLinkingV58State();
}
class _AdminTeamLinkingV58State extends State<AdminTeamLinkingV58> {
  List<Map<String,dynamic>> partners=[];
  List<Map<String,dynamic>> captains=[];
  bool loading=false;
  String? error;
  String query='';
  @override void initState(){super.initState();_reload();}
  Future<void> _reload() async {
    setState((){loading=true;error=null;});
    try {
      final raw=await SupabaseService.instance.client.rpc('v58_owner_team_roster');
      if(!mounted)return;
      final data=Map<String,dynamic>.from(raw as Map);
      setState((){
        partners=(data['partners'] as List? ?? [])
          .whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
        captains=(data['captains'] as List? ?? [])
          .whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
      });
    }catch (e) {if(mounted)setState(()=>error=AdminEnvironmentSupport.explain(e, 'v58_owner_team_roster'));}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> _choose(Map<String,dynamic> captain) async {
    String? selected=(captain['partner_id']?.toString().isNotEmpty==true)
      ? captain['partner_id'].toString():'none';
    final agreed=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(
      builder:(ctx,update)=>AlertDialog(
        title:Text('ربط ${captain['full_name']??'الكابتن'} بفريق'),
        content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('كود بادج الكابتن: ${captain['badge_code']??'لم يُخصّص بعد'}',
             style:const TextStyle(fontWeight:FontWeight.w700)),
          const SizedBox(height:12),
          DropdownButtonFormField<String>(
            value:selected,
            isExpanded:true,
            decoration:const InputDecoration(labelText:'فريق الكابتن'),
            items:[
              const DropdownMenuItem<String>(value:'none',child:Text('بدون فريق')),
              for (final p in partners)
                DropdownMenuItem<String>(value:p['id']?.toString(),
                  child:Text('${p['name']}  •  ${p['team_code']}${p['active']==true?'':' (غير نشط)'}')),
            ],
            onChanged:(value)=>update(()=>selected=value),
          ),
          const SizedBox(height:10),
          const Text('نقل الكابتن يغير الانتماء الحالي فقط، ولا يمس عمولات الشريك السابقة.',
              style:TextStyle(fontSize:12)),
        ]),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('رجوع')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حفظ الفريق')),
        ],
      )));
    if(agreed!=true||!mounted)return;
    try {
      await SupabaseService.instance.client.rpc('v58_owner_assign_team',
        params:{'p_captain_id':captain['id'],'p_partner_id':selected=='none'?null:selected});
      await _reload();
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('تم حفظ الفريق؛ الشريك الجديد سيجد إشعارًا داخل التطبيق.')));
    }catch (e) {if(mounted)ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content:Text(AdminEnvironmentSupport.explain(e, 'v58_owner_assign_team'))));}
  }
  @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,
    child:Scaffold(
      appBar:AppBar(title:const Text('أكواد الكباتن والفرق'),actions:[
        IconButton(tooltip:'تفعيل وطباعة البادجات',
          onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(
            builder:(_)=>const AdminBadgeActivationScreen())),
          icon:const Icon(Icons.qr_code_2)),
        IconButton(onPressed:_reload,icon:const Icon(Icons.refresh))]),
      body:Column(children:[
        const AdminEnvironmentBanner(),
        const Padding(padding:EdgeInsets.all(12),child:Text(
          'كود البادج للتسويق مستقل تمامًا عن كود الفريق. كل كابتن يظهر أمام فريقه الحالي، ويمكن ربطه أو نقله أو فصله.',
          style:TextStyle(fontSize:13))),
        Padding(padding:const EdgeInsets.symmetric(horizontal:12),
          child:TextField(onChanged:(v)=>setState(()=>query=v.trim().toLowerCase()),
            decoration:const InputDecoration(
              prefixIcon:Icon(Icons.search),hintText:'ابحث باسم الكابتن أو كود البادج'))),
        if(loading)const LinearProgressIndicator(),
        if(error!=null)Padding(padding:const EdgeInsets.all(12),child:Column(children:[
          Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
          const SizedBox(height:8),
          OutlinedButton.icon(onPressed:_reload,icon:const Icon(Icons.refresh),label:const Text('حاول تحميل الفرق مرة أخرى')),
        ])),
        Expanded(child:ListView.builder(
          itemCount:captains.length,
          itemBuilder:(context,index){
            final c=captains[index];
            if(query.isNotEmpty && !('${c['full_name']} ${c['badge_code']} ${c['team_name']}'
                .toLowerCase().contains(query)))return const SizedBox.shrink();
            return Card(margin:const EdgeInsets.symmetric(horizontal:12,vertical:4),
              child:ListTile(
                title:Text(c['full_name']?.toString()??'كابتن'),
                subtitle:Text('بادج: ${c['badge_code']??'غير مخصص'}  •  '
                  'الفريق: ${c['team_name']??'غير مرتبط'}\n'
                  'كود الفريق: ${c['team_code']??'—'}'),
                isThreeLine:true,
                trailing:const Icon(Icons.edit_note_rounded),
                onTap:()=>_choose(c),
              ),
            );
          },
        )),
        Padding(padding:const EdgeInsets.all(12),child:Text(
          error == null ? 'إجمالي: ${captains.length} كابتن • ${partners.length} فريق' : 'تعذر تحميل الأعداد — لا يعني وجود صفر كابتن',
          style:const TextStyle(fontWeight:FontWeight.w600))),
      ]),
    ));
}
