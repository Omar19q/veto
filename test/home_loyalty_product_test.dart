import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/presentation/home_screen/widgets/home_progress_v37.dart';
import 'package:vetosanya/theme/app_theme.dart';
import 'package:vetosanya/widgets/customer_identity_v29.dart';

void main() {
  for (final language in ['ar', 'en']) {
    for (final dark in [false, true]) {
      testWidgets('Existing loyalty $language/$dark stays readable at 320', (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final l = lookupAppLocalizations(Locale(language));
        await tester.pumpWidget(MaterialApp(
          locale: Locale(language),localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          home: Scaffold(body: HomeProgressV37(customerId: 'synthetic',
            loadProfile: () async => {'tier':'عضو','completed_trips':3,'frames':[]},
            loadRank: () async => {'rank':2}, loadReward: () async => {'available':false},
          )),
        ));
        await tester.pumpAndSettle();
        expect(find.text(l.newsMember), findsOneWidget);
        expect(find.text(l.homeLoyaltyCompleted(3)), findsOneWidget);
        expect(find.text(l.homeLoyaltyRank(2)), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets('Account change clears old loyalty and rejects its late response', (tester) async {
    final oldResponse = Completer<dynamic>();
    Widget app(String id) => MaterialApp(home: Scaffold(body: HomeProgressV37(
      key: const ValueKey('loyalty'), customerId: id,
      loadProfile: () => id=='old' ? oldResponse.future : Future.value({'tier':'NEW_ACCOUNT','completed_trips':1,'frames':[]}),
      loadRank: () async => null,loadReward: () async => null,
    )));
    await tester.pumpWidget(app('old'));
    await tester.pumpWidget(app('new'));
    await tester.pumpAndSettle();
    oldResponse.complete({'tier':'OLD_PRIVATE_ACCOUNT','completed_trips':99,'frames':[]});
    await tester.pumpAndSettle();
    expect(find.text('NEW_ACCOUNT'), findsOneWidget);
    expect(find.text('OLD_PRIVATE_ACCOUNT'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Malformed loyalty data cannot invent a zero-trip status', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: HomeProgressV37(
      customerId:'synthetic',loadProfile:() async => {},
      loadRank:() async => null,loadReward:() async => null,
    ))));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerFrameAvatarV29), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
