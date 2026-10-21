import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/theme/app_theme.dart';
import 'package:vetosanya/presentation/vito_market/vito_market_products_screen.dart';

final categories = [for(final id in ['a','b','c']) {'id':id, 'name':'Category $id'}];
Map<String,dynamic> product(String id) => {'id':id,'name':'منتج أصلي $id','price':25.0,'effective_price':20.0,'is_available':true};
Widget app(String language,bool dark,Future<List<Map<String,dynamic>>> Function(String,String?) load) => MaterialApp(
  locale: Locale(language),localizationsDelegates:AppLocalizations.localizationsDelegates,
  supportedLocales:AppLocalizations.supportedLocales,theme:AppTheme.lightTheme,darkTheme:AppTheme.darkTheme,
  themeMode:dark?ThemeMode.dark:ThemeMode.light,
  home:VitoMarketProductsScreen(supermarket:const {'id':'synthetic-store','name':'اسم المتجر الأصلي','is_open':true},loadCategories:(_) async=>categories,loadProducts:load),
);
void main() {
  for(final language in ['ar','en']) {
    for(final dark in [true,false]) {
      testWidgets('Market products $language dark=$dark cart at 320px', (tester) async {
        tester.view.physicalSize=const Size(320,800);tester.view.devicePixelRatio=1;
        addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(app(language,dark,(_,__) async=>[product('a')]));
        await tester.pumpAndSettle();
        final l=lookupAppLocalizations(Locale(language));
        expect(find.text('منتج أصلي a'),findsOneWidget);
        expect(find.text(l.moneyValue('20.00')),findsOneWidget);
        await tester.tap(find.text(l.marketProductsAdd));await tester.pumpAndSettle();
        expect(find.text(l.marketProductsViewCart('1','20.00')),findsOneWidget);
        await tester.tap(find.text(l.marketProductsViewCart('1','20.00')));await tester.pumpAndSettle();
        expect(find.text(l.marketProductsLine('20.00','1','20.00')),findsOneWidget);
        expect(tester.takeException(),isNull);
      });
    }
  }
  testWidgets('Late previous category cannot overwrite current products', (tester) async {
    final old=Completer<List<Map<String,dynamic>>>();
    await tester.pumpWidget(app('en',false,(_,category) async=> category=='b'?old.future:[product(category!)]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Category b'));
    await tester.tap(find.text('Category c'));
    await tester.pumpAndSettle();
    expect(find.text('منتج أصلي c'),findsOneWidget);
    old.complete([product('b')]);await tester.pumpAndSettle();
    expect(find.text('منتج أصلي c'),findsOneWidget);
    expect(find.text('منتج أصلي b'),findsNothing);
    expect(tester.takeException(),isNull);
  });
  testWidgets('Product error has retry and is not falsely empty', (tester) async {
    var calls=0;
    await tester.pumpWidget(app('en',true,(_,__) async {if(++calls==1)throw StateError('synthetic');return [];}));
    await tester.pumpAndSettle();final l=lookupAppLocalizations(const Locale('en'));
    expect(find.text(l.marketProductsFailed),findsOneWidget);expect(find.text(l.marketProductsEmpty),findsNothing);
    await tester.tap(find.text(l.retry));await tester.pumpAndSettle();
    expect(find.text(l.marketProductsEmpty),findsOneWidget);expect(calls,2);
    expect(tester.takeException(),isNull);
  });
}
