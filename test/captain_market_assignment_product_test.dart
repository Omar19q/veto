import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/theme/app_theme.dart';
import 'package:vetosanya/services/captain_market_assignment_backend.dart';
import 'package:vetosanya/presentation/captain_dashboard_screen/captain_market_jobs_screen.dart';

class AssignmentStub extends CaptainMarketAssignmentBackend {
  String? uid = 'synthetic-a';
  final changes = StreamController<String?>.broadcast(sync: true);
  bool fail = false;
  Completer<Map<String, dynamic>?>? delayed;
  @override
  String? get accountId => uid;
  @override
  Stream<String?> get accountChanges => changes.stream;
  @override
  Future<Map<String, dynamic>?> getAssignment() async {
    if (fail) throw StateError('synthetic_read_failure');
    if (delayed != null) return delayed!.future;
    return null;
  }
}

Widget app(AssignmentStub backend, String language, bool dark) => MaterialApp(
  locale: Locale(language),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: CaptainMarketJobsScreen(backend: backend),
);

void main() {
  for (final language in ['ar', 'en']) {
    for (final dark in [true, false]) {
      testWidgets('Assignment empty $language dark=$dark at320', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final backend = AssignmentStub();
        addTearDown(backend.changes.close);
        await tester.pumpWidget(app(backend, language, dark));
        await tester.pumpAndSettle();
        final l = lookupAppLocalizations(Locale(language));
        expect(find.text(l.captainAssignmentEmpty), findsOneWidget);
        expect(
          Directionality.of(
            tester.element(find.text(l.captainAssignmentEmpty)),
          ),
          language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('Failed assignment is not an empty assignment and can retry', (
    tester,
  ) async {
    final backend = AssignmentStub()..fail = true;
    addTearDown(backend.changes.close);
    final l = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(app(backend, 'en', false));
    await tester.pumpAndSettle();
    expect(find.text(l.captainMarketLoadFailed), findsOneWidget);
    expect(find.text(l.captainAssignmentEmpty), findsNothing);
    backend.fail = false;
    await tester.tap(
      find.widgetWithText(FilledButton, l.captainAssignmentRefresh),
    );
    await tester.pumpAndSettle();
    expect(find.text(l.captainAssignmentEmpty), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Delayed old account assignment cannot open for new account', (
    tester,
  ) async {
    final reply = Completer<Map<String, dynamic>?>();
    final backend = AssignmentStub()..delayed = reply;
    addTearDown(backend.changes.close);
    final l = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(app(backend, 'en', true));
    await tester.pump();
    backend.delayed = null;
    backend.uid = 'synthetic-b';
    backend.changes.add(backend.uid);
    await tester.pumpAndSettle();
    reply.complete({
      'order': {'id': 'synthetic-old-private-order'},
    });
    await tester.pumpAndSettle();
    expect(find.text(l.captainAssignmentOpen), findsNothing);
    expect(find.text(l.captainAssignmentEmpty), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
