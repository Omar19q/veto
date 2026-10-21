import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/theme/app_theme.dart';
import 'package:vetosanya/presentation/vito_market/vito_market_screen.dart';

Widget app(String language, bool dark, Future<List<Map<String, dynamic>>> Function() load) => MaterialApp(
  locale: Locale(language), localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales, theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme, themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: VitoMarketScreen(loadStores: load),
);
void main() {
  for (final language in ['ar','en']) {
    for (final dark in [true,false]) {
      testWidgets('Market stores $language dark=$dark preserves names and has no invented ETA', (tester) async {
        tester.view.physicalSize = const Size(320,800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final strings = lookupAppLocalizations(Locale(language));
        await tester.pumpWidget(app(language,dark,() async => [
          {'id':'synthetic-store-a','name':'اسم المتجر الأصلي','address':'العنوان الأصلي','is_open':true},
          {'id':'synthetic-store-b','name':'Synthetic second store','is_open':false,'delivery_estimate_minutes':12},
        ]));
        await tester.pumpAndSettle();
        expect(find.text('اسم المتجر الأصلي'), findsOneWidget);
        expect(find.text(strings.marketStoresOpen), findsOneWidget);
        expect(find.text(strings.marketStoresMinutes('12')), findsOneWidget);
        expect(find.text(strings.marketStoresMinutes('30')), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('Failed store fetch is not represented as no stores; retry recovers', (tester) async {
    var calls=0;
    await tester.pumpWidget(app('en',false,() async {
      if (++calls==1) throw StateError('synthetic-fetch-failed');
      return [];
    }));
    await tester.pumpAndSettle();
    final strings=lookupAppLocalizations(const Locale('en'));
    expect(find.text(strings.marketStoresFailed), findsOneWidget);
    expect(find.text(strings.marketStoresEmpty), findsNothing);
    await tester.tap(find.text(strings.retry));
    await tester.pumpAndSettle();
    expect(calls,2);
    expect(find.text(strings.marketStoresEmpty), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
