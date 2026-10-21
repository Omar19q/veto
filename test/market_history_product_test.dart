import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/theme/app_theme.dart';
import 'package:vetosanya/services/market_history_backend.dart';
import 'package:vetosanya/presentation/vito_market/vito_market_history_screen.dart';

class HistoryStub extends MarketHistoryBackend {
  String uid='synthetic-a';
  final changes=StreamController<String?>.broadcast(sync:true);
  Completer<List<Map<String,dynamic>>>? delayed;
  bool fail=false;
  @override String? get accountId=>uid;
  @override Stream<String?> get accountChanges=>changes.stream;
  void switchTo(String value){uid=value;changes.add(value);}
  @override Future<Map<String,dynamic>?> getCustomer(String uid) async=>{'id':uid};
  @override Future<List<Map<String,dynamic>>> getOrders(String cid) async {
    if(fail)throw StateError('synthetic');
    if(cid=='synthetic-a' && delayed!=null)return delayed!.future;
    return [order(cid)];
  }
  Map<String,dynamic> order(String owner)=>{'id':'short','owner':owner,'supermarket_id':'synthetic-store','order_status':'completed','total_amount':42,'created_at':owner,'market_order_items':[{'product_id':'p','product_name':'اسم المنتج الأصلي','quantity':3}]};
  @override Future<List<Map<String,dynamic>>> getStores()async=>[{'id':'synthetic-store','name':'Synthetic store','is_open':true}];
  @override Future<List<Map<String,dynamic>>> getProducts(String sid)async=>[{'id':'p','name':'اسم المنتج الأصلي','price':30,'vm_stock_qty':1}];
}
Widget app(HistoryStub backend,String language,bool dark)=>MaterialApp(
  locale:Locale(language),localizationsDelegates:AppLocalizations.localizationsDelegates,
  supportedLocales:AppLocalizations.supportedLocales,theme:AppTheme.lightTheme,darkTheme:AppTheme.darkTheme,
  themeMode:dark?ThemeMode.dark:ThemeMode.light,home:VitoMarketHistoryScreen(backend:backend),
);
void main(){
  for(final language in ['ar','en']) {
    for(final dark in [true,false]) {
      testWidgets('Market history $language dark=$dark short id and current-price consent at320', (tester)async{
        tester.view.physicalSize=const Size(320,800);tester.view.devicePixelRatio=1;
        addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
        final backend=HistoryStub();addTearDown(backend.changes.close);
        final l=lookupAppLocalizations(Locale(language));
        await tester.pumpWidget(app(backend,language,dark));await tester.pumpAndSettle();
        expect(find.text(l.marketHistoryAmount('42')),findsOneWidget);
        await tester.tap(find.text(l.marketHistoryReorder));await tester.pumpAndSettle();
        expect(find.text(l.marketHistoryPartial),findsOneWidget);
        expect(find.text(l.marketHistoryMissing(l.marketHistoryStock('اسم المنتج الأصلي','1'))),findsOneWidget);
        await tester.tap(find.text(l.marketHistoryCancel));await tester.pumpAndSettle();
        expect(find.byType(AlertDialog),findsNothing);expect(tester.takeException(),isNull);
      });
    }
  }
  testWidgets('Old account history response is rejected after account change',(tester)async{
    final backend=HistoryStub()..delayed=Completer<List<Map<String,dynamic>>>();addTearDown(backend.changes.close);
    await tester.pumpWidget(app(backend,'en',true));await tester.pump();await tester.pump();
    backend.switchTo('synthetic-b');await tester.pumpAndSettle();
    final l=lookupAppLocalizations(const Locale('en'));
    expect(find.text(l.marketHistoryDate('synthetic-b')),findsOneWidget);
    backend.delayed!.complete([backend.order('synthetic-a')]);await tester.pumpAndSettle();
    expect(find.text(l.marketHistoryDate('synthetic-a')),findsNothing);
    expect(find.text(l.marketHistoryDate('synthetic-b')),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
  testWidgets('Account change closes old-account reorder consent',(tester)async{
    final backend=HistoryStub();addTearDown(backend.changes.close);
    await tester.pumpWidget(app(backend,'en',false));await tester.pumpAndSettle();
    final l=lookupAppLocalizations(const Locale('en'));
    await tester.tap(find.text(l.marketHistoryReorder));await tester.pumpAndSettle();
    expect(find.byType(AlertDialog),findsOneWidget);
    backend.switchTo('synthetic-b');await tester.pumpAndSettle();
    expect(find.byType(AlertDialog),findsNothing);
    expect(find.text(l.marketHistoryDate('synthetic-b')),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
  testWidgets('Failed order history is not falsely empty',(tester)async{
    final backend=HistoryStub()..fail=true;addTearDown(backend.changes.close);
    await tester.pumpWidget(app(backend,'en',true));await tester.pumpAndSettle();
    final l=lookupAppLocalizations(const Locale('en'));
    expect(find.text(l.marketHistoryFailed),findsOneWidget);expect(find.text(l.marketHistoryEmpty),findsNothing);
    backend.fail=false;await tester.tap(find.byIcon(Icons.refresh));await tester.pumpAndSettle();
    expect(find.text(l.marketHistoryAmount('42')),findsOneWidget);expect(tester.takeException(),isNull);
  });
}
