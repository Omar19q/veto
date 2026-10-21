import 'package:flutter/material.dart';
import '../../widgets/admin_copy_button.dart';
import '../../services/supabase_service.dart';
import '../../theme/admin_theme.dart';

class AdminFeedbackPanel extends StatefulWidget { const AdminFeedbackPanel({super.key}); @override State<AdminFeedbackPanel> createState()=>_AdminFeedbackPanelState(); }
class _AdminFeedbackPanelState extends State<AdminFeedbackPanel>{
  bool _loading=true; List<Map<String,dynamic>> _rows=[]; dynamic _sub;
  @override void initState(){super.initState(); _load(); _sub=SupabaseService.instance.subscribeToCustomerFeedback((_){_load();});}
  @override void dispose(){_sub?.unsubscribe();super.dispose();}
  Future<void> _load() async { try{final rows=await SupabaseService.instance.getAllCustomerFeedback(); if(mounted)setState(()=>_rows=rows);}catch(_){}finally{if(mounted)setState(()=>_loading=false);} }
  Future<void> _update(Map<String,dynamic> row,String status) async { try{await SupabaseService.instance.updateCustomerFeedbackStatus(row['id'].toString(),status);await _load();}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر تحديث الحالة',style:TextStyle(fontFamily:'Cairo'))));}}
  @override Widget build(BuildContext context)=>ListView(padding:EdgeInsets.all(20),children:[Row(children:[Text('الاقتراحات والشكاوى',style:TextStyle(fontFamily:'Cairo',fontSize:22,fontWeight:FontWeight.w800,color:AdminTheme.ink)),Spacer(),IconButton(onPressed:_load,icon:Icon(Icons.refresh_rounded,color:AdminTheme.goldDark))]),SizedBox(height:14),if(_loading)Center(child:CircularProgressIndicator(color:AdminTheme.goldDark)) else if(_rows.isEmpty)Padding(padding:EdgeInsets.all(30),child:Center(child:Text('لا توجد رسائل حتى الآن',style:TextStyle(fontFamily:'Cairo',color:AdminTheme.muted)))) else ..._rows.map((r)=>_card(r)),]);
  Widget _card(Map<String,dynamic> r){
    final type=r['type']?.toString()??'';
    final status=r['status']?.toString()??'new';
    final phone=r['phone']?.toString() ?? r['customer_phone']?.toString() ?? 'غير متوفر';
    final customerId=r['customer_id']?.toString() ?? 'غير متوفر';

    return Container(
      margin:EdgeInsets.only(bottom:10),
      padding:EdgeInsets.all(15),
      decoration:BoxDecoration(
        color:AdminTheme.surface,
        borderRadius:BorderRadius.circular(14),
        border:Border.all(color:AdminTheme.borderSoft),
      ),
      child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          Row(children:[
            Icon(
              type=='complaint'
                  ? Icons.report_problem_outlined
                  : Icons.lightbulb_outline_rounded,
              color:type=='complaint'
                  ? AdminTheme.error
                  : AdminTheme.goldDark,
            ),
            SizedBox(width:8),
            Text(
              type=='complaint'?'شكوى':'اقتراح',
              style:TextStyle(
                fontFamily:'Cairo',
                fontWeight:FontWeight.w800,
                color:AdminTheme.ink,
              ),
            ),
            Spacer(),
            Text(
              statusLabel(status),
              style:TextStyle(
                fontFamily:'Cairo',
                fontSize:11,
                color:AdminTheme.muted,
              ),
            ),
          ]),
          SizedBox(height:9),
          Row(children:[
            Icon(Icons.phone_rounded,color:AdminTheme.goldDark,size:16),
            SizedBox(width:5),
            Expanded(
              child:Text(
                phone,
                style:TextStyle(
                  fontFamily:'Cairo',
                  color:AdminTheme.muted,
                  fontSize:12,
                ),
              ),
            ),
            AdminCopyButton(text:phone,description:'رقم صاحب الرسالة'),
          ]),
          SizedBox(height:4),
          Text(
            'اسم العميل: ${r['customer_name']?.toString().trim().isNotEmpty == true ? r['customer_name'] : 'غير متوفر'}',
            style:TextStyle(
              fontFamily:'Cairo',
              color:AdminTheme.muted,
              fontSize:12,
            ),
          ),
          SizedBox(height:3),
          Text(
            'حساب العميل: $customerId',
            style:TextStyle(
              fontFamily:'Cairo',
              color:AdminTheme.mutedLight,
              fontSize:10,
            ),
          ),
          SizedBox(height:4),
          Text(
            'تاريخ الإرسال: ${_formatDate(r['created_at'])}',
            style:TextStyle(fontFamily:'Cairo',color:AdminTheme.mutedLight,fontSize:10),
          ),
          SizedBox(height:9),
          Text(
            r['message']?.toString()??'',
            style:TextStyle(
              fontFamily:'Cairo',
              color:AdminTheme.ink,
              height:1.5,
            ),
          ),
          if(r['admin_reply']?.toString().trim().isNotEmpty==true)
            Padding(
              padding:EdgeInsets.only(top:8),
              child:Text(
                'رد الإدارة: ${r['admin_reply']}',
                style:TextStyle(
                  fontFamily:'Cairo',
                  color:AdminTheme.muted,
                ),
              ),
            ),
          SizedBox(height:10),
          Wrap(
            spacing:8,
            runSpacing:8,
            children:[
              _btn('جديد','new',r),
              _btn('قيد المراجعة','in_review',r),
              _btn('تم الحل','resolved',r),
              _btn('مرفوض','rejected',r),
            ],
          ),
        ],
      ),
    );
  }
  String _formatDate(Object? value) {
    final d = DateTime.tryParse(value?.toString() ?? '');
    return d == null ? 'غير معروف' : d.toLocal().toString().substring(0, 16);
  }

  Widget _btn(String label,String value,Map<String,dynamic> row)=>OutlinedButton(onPressed:row['status']==value?null:()=>_update(row,value),style:OutlinedButton.styleFrom(side:BorderSide(color:AdminTheme.borderSoft),foregroundColor:AdminTheme.ink),child:Text(label,style:TextStyle(fontFamily:'Cairo',fontSize:11)));
  String statusLabel(String s)=>{'new':'جديد','in_review':'قيد المراجعة','resolved':'تم الحل','rejected':'مرفوض'}[s]??s;
}
