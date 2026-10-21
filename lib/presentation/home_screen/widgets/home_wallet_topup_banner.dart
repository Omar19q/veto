import '../../../l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../routes/app_routes.dart';
import '../../../services/wallet_topup_service.dart';
import '../../../services/supabase_service.dart';

/// Optional banner, hidden until an admin explicitly activates a valid offer.
class HomeWalletTopupBanner extends StatefulWidget {
  const HomeWalletTopupBanner({super.key});
  @override State<HomeWalletTopupBanner> createState()=>_HomeWalletTopupBannerState();
}
class _HomeWalletTopupBannerState extends State<HomeWalletTopupBanner> {
  Map<String,dynamic>? _featured;
  RealtimeChannel? _channel;
  @override void initState(){super.initState();_load();
    _channel=SupabaseService.instance.client.channel('wallet-offer-home')
      .onPostgresChanges(event:PostgresChangeEvent.all,schema:'public',table:'wallet_topup_offers',
        callback:(_)=>_load()).subscribe();}
  Future<void> _load()async{
    try{
      final items=await WalletTopupService.instance.offers();
      if(!mounted)return;
      setState(()=>_featured=items.where((r)=>(r['bonus_amount'] as num?)?.toDouble()!=null &&
        (r['bonus_amount'] as num).toDouble()>0).isEmpty?null:
        items.firstWhere((r)=>(r['bonus_amount'] as num?)?.toDouble()!=null &&
        (r['bonus_amount'] as num).toDouble()>0));
    }catch(_){if(mounted)setState(()=>_featured=null);}
  }
  @override void dispose(){_channel?.unsubscribe();super.dispose();}
  @override Widget build(BuildContext context){
    final offer=_featured;
    if(offer==null)return const SizedBox.shrink();
    final paid=(offer['paid_amount'] as num).toDouble();
    final total=paid+(offer['bonus_amount'] as num).toDouble();
    return InkWell(onTap:()=>context.push(AppRoutes.walletTopup,extra:offer['id'].toString()),
      borderRadius:BorderRadius.circular(20),child:Container(width:double.infinity,
        decoration:BoxDecoration(borderRadius:BorderRadius.circular(20),
          border:Border.all(color:const Color(0xFFFFC83D),width:1.2),
          gradient:const LinearGradient(colors:[Color(0xFF18243D),Color(0xFF422D05)]),
          boxShadow:[BoxShadow(color:const Color(0xFFFFC83D).withAlpha(28),blurRadius:22)]),
        padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(context.strings.topupBannerTitle,style:TextStyle(color:Color(0xFFFFC83D),fontWeight:FontWeight.w800,fontSize:12)),
          const SizedBox(height:7),Text(context.strings.topupBannerAmount(paid.toStringAsFixed(2), total.toStringAsFixed(2)),
            style:const TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900)),
          Text(context.strings.topupBannerApproval,
            style:TextStyle(color:Color(0xFFD3DEEA),fontSize:11)),
          const SizedBox(height:10),Align(alignment:Alignment.centerLeft,child:Container(
            decoration:BoxDecoration(color:const Color(0xFFFFC83D),borderRadius:BorderRadius.circular(12)),
            padding:const EdgeInsets.symmetric(horizontal:18,vertical:9),child:Text(context.strings.topupBannerOpen,
              style:TextStyle(color:Color(0xFF0B1428),fontWeight:FontWeight.w800)))),
        ])));
  }
}
