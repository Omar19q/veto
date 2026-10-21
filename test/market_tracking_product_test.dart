import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/theme/app_theme.dart';
import 'package:vetosanya/services/market_tracking_backend.dart';
import 'package:vetosanya/presentation/vito_market/vito_market_order_tracking_screen.dart';

class TrackingStub extends MarketTrackingBackend {
  String uid='synthetic-a';
  final changes=StreamController<String?>.broadcast(sync:true);
  Completer<Map<String,dynamic>>? delayed;
  bool invalidCaptain=false;
  int reads=0;
  @override String? get accountId=>uid;
  @override Stream<String?> get accountChanges=>changes.stream;
  @override List<RealtimeChannel> subscribe(String id,void Function() changed)=>[];
  void switchTo(String value){uid=value;changes.add(value);}
  @override Future<Map<String,dynamic>> getContext(String id) async {
    reads++;
    if(delayed!=null)return delayed!.future;
    return value();
  }
  Map<String,dynamic> value()=>{
    'order':{'order_status':'delivered','store_order_number':12,'subtotal':'50.00','delivery_fee':5,'wallet_amount':null,'cash_amount':55,'total_amount':55},
    'store':{'name':'اسم المتجر الأصلي'},'items':[],
    'captain':invalidCaptain?{'full_name':'اسم الكابتن الأصلي','latitude':'NaN','longitude':'Infinity'}:{},
  };
}
Widget app(TrackingStub backend,String language,bool dark)=>MaterialApp(
  locale:Locale(language),localizationsDelegates:AppLocalizations.localizationsDelegates,
  supportedLocales:AppLocalizations.supportedLocales,theme:AppTheme.lightTheme,darkTheme:AppTheme.darkTheme,
  themeMode:dark?ThemeMode.dark:ThemeMode.light,home:VitoMarketOrderTrackingScreen(orderId:'synthetic-order',backend:backend),
);
void main(){
  for(final language in ['ar','en']) {
    for(final dark in [true,false]) {
      testWidgets('Market tracking $language dark=$dark server amounts and unknown wallet at320',(tester)async{
        tester.view.physicalSize=const Size(320,800);tester.view.devicePixelRatio=1;
        addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
        final backend=TrackingStub();addTearDown(backend.changes.close);
        await tester.pumpWidget(app(backend,language,dark));await tester.pumpAndSettle();
        final l=lookupAppLocalizations(Locale(language));
        expect(find.text(l.moneyValue('50.00')),findsOneWidget);
        expect(find.text(l.historyAmountUnavailable),findsOneWidget);
        expect(find.text(l.moneyValue('0.00')),findsNothing);
        await tester.scrollUntilVisible(find.text('اسم المتجر الأصلي'), 100, scrollable: find.byType(Scrollable).first);
        expect(find.text('اسم المتجر الأصلي'),findsOneWidget);
        expect(tester.takeException(),isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets('Account change clears market tracking and rejects old response',(tester)async{
    final backend=TrackingStub()..delayed=Completer<Map<String,dynamic>>();addTearDown(backend.changes.close);
    await tester.pumpWidget(app(backend,'en',true));await tester.pump();
    backend.switchTo('synthetic-b');await tester.pump();
    backend.delayed!.complete(backend.value());await tester.pumpAndSettle();
    expect(find.text('اسم المتجر الأصلي'),findsNothing);
    expect(find.text('Order could not be loaded. Refresh or check your sign-in.'),findsOneWidget);
    await tester.pump(const Duration(seconds:24));expect(backend.reads,1);
    expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Invalid map coordinates do not crash or create an arrival promise',(tester)async{
    final backend=TrackingStub()..invalidCaptain=true;addTearDown(backend.changes.close);
    await tester.pumpWidget(app(backend,'en',false));await tester.pumpAndSettle();
    expect(find.text('اسم الكابتن الأصلي'),findsOneWidget);
    expect(find.textContaining('arrival'),findsNothing);
    expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox());
  });
}
