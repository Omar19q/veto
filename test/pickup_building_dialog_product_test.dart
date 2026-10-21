import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/theme/app_theme.dart';
import 'package:vetosanya/services/pickup_building_suggestion_backend.dart';
import 'package:vetosanya/presentation/trip_booking_screen/widgets/booking_building_suggestion_dialog.dart';

Position position({double accuracy = 12, double latitude = 29.98}) => Position(
  latitude: latitude,
  longitude: 31.1,
  timestamp: DateTime.utc(2026),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class BuildingStub extends PickupBuildingSuggestionBackend {
  String? uid = 'synthetic-a';
  final changes = StreamController<String?>.broadcast(sync: true);
  bool enabled = true;
  LocationPermission allowed = LocationPermission.whileInUse;
  int requests = 0;
  int submissions = 0;
  Position point = position();
  Completer<Position>? delayed;
  String? savedArea;
  int? savedNumber;
  bool saveFails = false;
  @override
  String? get accountId => uid;
  @override
  Stream<String?> get accountChanges => changes.stream;
  @override
  Future<bool> locationEnabled() async => enabled;
  @override
  Future<LocationPermission> permission() async => allowed;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return allowed;
  }

  @override
  Future<Position> locate() async => delayed?.future ?? point;
  @override
  Future<void> submit({
    required String area,
    required int number,
    required Position position,
  }) async {
    submissions++;
    savedArea = area;
    savedNumber = number;
    if (saveFails) throw StateError('synthetic_private_database_error');
  }
}

Widget app(
  BuildingStub backend,
  String language,
  bool dark,
  void Function(PickupBuildingSuggestion?) result,
) => MaterialApp(
  locale: Locale(language),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () async => result(
          await showDialog<PickupBuildingSuggestion>(
            context: context,
            builder: (_) => BookingBuildingSuggestionDialog(
              initialArea: 'أ',
              initialNumber: '25',
              backend: backend,
            ),
          ),
        ),
        child: const Text('Open synthetic dialog'),
      ),
    ),
  ),
);

Future<void> open(
  WidgetTester tester,
  BuildingStub backend, {
  String language = 'en',
  bool dark = false,
  void Function(PickupBuildingSuggestion?)? result,
}) async {
  await tester.pumpWidget(app(backend, language, dark, result ?? (_) {}));
  await tester.tap(find.text('Open synthetic dialog'));
  await tester.pumpAndSettle();
}

Future<void> locate(WidgetTester tester, String language) async {
  final l = lookupAppLocalizations(Locale(language));
  await tester.ensureVisible(find.byType(CheckboxListTile));
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pump();
  await tester.ensureVisible(find.text(l.buildingLocate));
  await tester.tap(find.text(l.buildingLocate));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  for (final language in ['ar', 'en']) {
    for (final dark in [true, false]) {
      testWidgets('Building dialog $language dark=$dark at320', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final backend = BuildingStub();
        addTearDown(backend.changes.close);
        await open(tester, backend, language: language, dark: dark);
        final l = lookupAppLocalizations(Locale(language));
        expect(find.text(l.buildingTitle), findsOneWidget);
        expect(
          Directionality.of(tester.element(find.text(l.buildingTitle))),
          language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(l.buildingCancel));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
    'Existing GPS permission is not requested again; canonical area and V27 data retained',
    (tester) async {
      final backend = BuildingStub();
      addTearDown(backend.changes.close);
      PickupBuildingSuggestion? saved;
      await open(tester, backend, result: (value) => saved = value);
      await locate(tester, 'en');
      final l = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(l.buildingSave));
      await tester.pumpAndSettle();
      expect(backend.requests, 0);
      expect(backend.submissions, 1);
      expect(backend.savedArea, 'أ');
      expect(backend.savedNumber, 25);
      expect(saved?.latitude, 29.98);
      expect(saved?.longitude, 31.1);
      expect(tester.takeException(), isNull);
    },
  );
  for (final scenario in ['denied', 'weak', 'outside']) {
    testWidgets('Building $scenario location cannot submit', (tester) async {
      final backend = BuildingStub();
      addTearDown(backend.changes.close);
      if (scenario == 'denied')
        backend.allowed = LocationPermission.deniedForever;
      if (scenario == 'weak') backend.point = position(accuracy: 150);
      if (scenario == 'outside') backend.point = position(latitude: 31);
      await open(tester, backend);
      await locate(tester, 'en');
      final l = lookupAppLocalizations(const Locale('en'));
      expect(
        find.text(switch (scenario) {
          'denied' => l.buildingGpsAllow,
          'weak' => l.buildingAccuracyWeak('150'),
          _ => l.buildingOutside,
        }),
        findsOneWidget,
      );
      final save = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, l.buildingSave),
      );
      expect(save.onPressed, isNull);
      expect(backend.submissions, 0);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'Late old-account GPS result does not populate or submit a dismissed dialog',
    (tester) async {
      final backend = BuildingStub()..delayed = Completer<Position>();
      addTearDown(backend.changes.close);
      await open(tester, backend);
      await locate(tester, 'en');
      backend.uid = 'synthetic-b';
      backend.changes.add(backend.uid);
      await tester.pumpAndSettle();
      backend.delayed!.complete(position());
      await tester.pumpAndSettle();
      expect(find.byType(BookingBuildingSuggestionDialog), findsNothing);
      expect(backend.submissions, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Unconfirmed save retains dialog without blaming internet or disclosing SQL',
    (tester) async {
      final backend = BuildingStub()..saveFails = true;
      addTearDown(backend.changes.close);
      await open(tester, backend);
      await locate(tester, 'en');
      final l = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(l.buildingSave));
      await tester.pumpAndSettle();
      expect(find.text(l.buildingUnconfirmed), findsOneWidget);
      expect(
        find.textContaining('synthetic_private_database_error'),
        findsNothing,
      );
      expect(backend.submissions, 1);
      expect(find.byType(BookingBuildingSuggestionDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
