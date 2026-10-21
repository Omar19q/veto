import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/presentation/trip_booking_screen/widgets/smooth_live_trip_map.dart';
import 'package:vetosanya/services/osrm_routing_service.dart';
import 'package:vetosanya/theme/app_theme.dart';

void main() {
  for (final language in ['ar', 'en']) {
    for (final dark in [false, true]) {
      for (final width in [320.0, 390.0, 600.0]) {
        testWidgets('Live map $language/$dark at $width has localized readable state', (tester) async {
          tester.view.physicalSize = Size(width, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final l = lookupAppLocalizations(Locale(language));
          final theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
          await tester.pumpWidget(MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: theme,
            home: Scaffold(body: SmoothLiveTripMap(
              captainLat: 29.974, captainLng: 31.101,
              pickupLat: 29.978, pickupLng: 31.108,
              tripStatus: 'accepted', locationUpdatedAt: DateTime.now(),
              routeLoader: (from, to) async => RouteResult(
                distanceKm: 2, durationMinutes: 4,
                routePoints: [[from.latitude, from.longitude], [to.latitude, to.longitude]],
              ),
            )),
          ));
          await tester.pump();
          expect(find.text(l.liveMapEstimate), findsOneWidget);
          final estimate = tester.widget<Text>(find.text(l.liveMapEstimate));
          expect(estimate.style!.color, theme.colorScheme.onSurfaceVariant);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
  testWidgets('Missing GPS timestamp shows an update warning and navigation target changes at start', (tester) async {
    final targets = <LatLng>[];
    Widget app(String status) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SmoothLiveTripMap(
        key: const ValueKey('map'), tripStatus: status,
        captainLat: 29.974, captainLng: 31.101,
        pickupLat: 29.978, pickupLng: 31.108,
        destinationLat: 30.01, destinationLng: 31.11,
        routeLoader: (from, to) async { targets.add(to); return null; },
      )),
    );
    await tester.pumpWidget(app('accepted'));
    await tester.pump();
    final l = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l.liveMapStale), findsOneWidget);
    await tester.pumpWidget(app('started'));
    await tester.pump();
    expect(targets, [const LatLng(29.978, 31.108), const LatLng(30.01, 31.11)]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
