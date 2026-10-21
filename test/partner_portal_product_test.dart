import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/theme/app_theme.dart';
import 'package:vetosanya/services/partner_portal_backend.dart';
import 'package:vetosanya/presentation/customer/partner_portal_v39.dart';

class PartnerStub extends PartnerPortalBackend {
  String? uid = 'synthetic-a';
  final changes = StreamController<String?>.broadcast(sync: true);
  Completer<dynamic>? delayed;
  bool monthlyFails = false;
  final wallets = <String>[];
  @override
  String? get accountId => uid;
  @override
  Stream<String?> get accountChanges => changes.stream;
  Map<String, dynamic> value() => {
    'active': true,
    'name': 'Synthetic partner',
    'code': 'TEST',
    'captains': 2,
    'completed_trips': 10,
    'pending_egp': 25,
    'paid_egp': 15,
    'share_percent': 3,
    'share_enabled': true,
    'payout_wallet': '',
    'team': [],
    'settlements': [],
  };
  @override
  Future<dynamic> report() async => delayed?.future ?? value();
  @override
  Future<dynamic> monthlyReport() async {
    if (monthlyFails) throw StateError('synthetic_optional_unavailable');
    return [];
  }

  @override
  Future<dynamic> saveWallet(String wallet) async {
    wallets.add(wallet);
    return {};
  }
}

Widget app(PartnerStub backend, String language, bool dark) => MaterialApp(
  locale: Locale(language),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: PartnerPortalV39(backend: backend),
);
void main() {
  for (final language in ['ar', 'en']) {
    for (final dark in [true, false]) {
      testWidgets(
        'Partner report $language dark=$dark at320 retains V40 amounts',
        (tester) async {
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final backend = PartnerStub();
          addTearDown(backend.changes.close);
          final l = lookupAppLocalizations(Locale(language));
          await tester.pumpWidget(app(backend, language, dark));
          await tester.pumpAndSettle();
          expect(find.text(l.moneyValue('25')), findsOneWidget);
          expect(find.text(l.moneyValue('15')), findsOneWidget);
          expect(find.text(l.partnerShare('3')), findsOneWidget);
          expect(
            Directionality.of(tester.element(find.text(l.partnerTitle))),
            language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  testWidgets(
    'Closing payout editor disposes controller only after route unmount',
    (tester) async {
      final backend = PartnerStub();
      addTearDown(backend.changes.close);
      final l = lookupAppLocalizations(const Locale('en'));
      await tester.pumpWidget(app(backend, 'en', false));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text(l.partnerPayoutWallet), 150,
        scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text(l.partnerPayoutWallet));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '01000000000');
      await tester.tap(find.text(l.partnerCancel));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(backend.wallets, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Old account delayed report cannot disclose partnership data', (
    tester,
  ) async {
    final backend = PartnerStub()..delayed = Completer<dynamic>();
    addTearDown(backend.changes.close);
    await tester.pumpWidget(app(backend, 'en', true));
    await tester.pump();
    backend.uid = 'synthetic-b';
    backend.changes.add(backend.uid);
    await tester.pump();
    backend.delayed!.complete(backend.value());
    await tester.pumpAndSettle();
    expect(find.text('Synthetic partner'), findsNothing);
    expect(backend.wallets, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Optional monthly failure is visible and not presented as successful empty data',
    (tester) async {
      final backend = PartnerStub()..monthlyFails = true;
      addTearDown(backend.changes.close);
      final l = lookupAppLocalizations(const Locale('en'));
      await tester.pumpWidget(app(backend, 'en', true));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(l.partnerMonthlyUnavailable),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(l.partnerMonthlyUnavailable), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
