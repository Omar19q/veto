import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:vetosanya/presentation/trip_booking_screen/widgets/product_searching_view.dart';
import 'package:vetosanya/l10n/app_localizations.dart';

void main() {
  testWidgets('Search polling pauses in background and restores the same server trip', (tester) async {
    var reads = 0;
    final ids = <String>[];
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(MaterialApp(home: ProductSearchingView(
      tripId: 'existing-trip', pickupLabel: 'Pickup', destinationLabel: 'Destination',
      pickup: const LatLng(30, 31), destination: null,
      onRefresh: () async {}, onCancel: () {}, onHome: () {},
      price: const Text('Synthetic fare'), offerControls: const SizedBox(),
      loadSnapshot: (id) async { reads++; ids.add(id); return {
        'offers_created': 1, 'approximate_clusters': [],
      }; },
    )));
    await tester.pump();
    expect(reads, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 15));
    expect(reads, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(reads, 2);
    expect(ids, ['existing-trip', 'existing-trip']);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Status refresh failure clears stale offers and leaves cancellation usable', (tester) async {
    var cancelled = 0;
    final refresh = Completer<void>();
    final l = lookupAppLocalizations(const Locale('ar'));
    await tester.pumpWidget(MaterialApp(home: ProductSearchingView(
      tripId: 'synthetic', pickupLabel: 'Pickup', destinationLabel: 'Destination',
      pickup: const LatLng(30, 31), destination: null,
      onRefresh: () => refresh.future, onCancel: () => cancelled++, onHome: () {},
      price: const Text('Synthetic fare'), offerControls: const SizedBox(),
      loadSnapshot: (_) async => {'offers_created': 12, 'approximate_clusters': []},
    )));
    await tester.pump();
    expect(find.text('${l.offersDelivered}: 12'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, l.refresh));
    await tester.pump();
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, l.refresh));
    expect(button.onPressed, isNull);
    await tester.tap(find.text(l.cancel));
    expect(cancelled, 1);
    refresh.completeError(StateError('synthetic status failure'));
    await tester.pump();
    expect(find.text('${l.offersDelivered}: 12'), findsNothing);
    expect(find.text(l.bookingStatusUnavailable), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('A late search response cannot reveal a previous trip snapshot', (tester) async {
    final old = Completer<dynamic>();
    Widget app(String id) => MaterialApp(home: ProductSearchingView(
      key: const ValueKey('search'), tripId: id,
      pickupLabel: 'Synthetic pickup', destinationLabel: 'Synthetic destination',
      pickup: const LatLng(30, 31), destination: null,
      onRefresh: () async {}, onCancel: () {}, onHome: () {},
      price: const Text('Synthetic fare'), offerControls: const SizedBox(),
      loadSnapshot: (trip) => trip == 'old' ? old.future : Future.value({
        'offers_created': 0, 'approximate_clusters': [],
      }),
    ));
    await tester.pumpWidget(app('old'));
    await tester.pumpWidget(app('new'));
    await tester.pump();
    old.complete({'offers_created': 99, 'approximate_clusters': []});
    await tester.pump();
    expect(find.textContaining('99'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
