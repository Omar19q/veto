import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vetosanya/services/trip_data_v10.dart';
import 'package:vetosanya/presentation/trip_booking_screen/widgets/trip_rating_sheet_v10.dart';

void main() {
  test(
    'Trip mapping accepts numeric strings and null related records without NaN',
    () {
      final row = normalizeTripV10({
        'id': 'trip',
        'total_fare': '72.50',
        'pickup_latitude': 'NaN',
        'captain_context': {'rating': '4.8', 'current_latitude': null},
        'customers': null,
      });
      expect(row['total_fare'], 72.5);
      expect(row['pickup_latitude'], isNull);
      expect(row['captain_context']['rating'], 4.8);
      expect(row['customers'], isNull);
    },
  );
  test(
    'Temporary read failure retries once and authorization failure never retries',
    () async {
      var calls = 0;
      final value = await tripReadWithRetryV10(() async {
        if (++calls == 1) throw StateError('offline');
        return 12;
      });
      expect(value, 12);
      expect(calls, 2);
      calls = 0;
      await expectLater(
        tripReadWithRetryV10(() async {
          calls++;
          throw const PostgrestException(
            message: 'not_trip_participant',
            code: '42501',
          );
        }),
        throwsA(isA<PostgrestException>()),
      );
      expect(calls, 1);
    },
  );
  for (final width in [320.0, 600.0]) {
    testWidgets(
      'Rating reasons change between low and high stars without overflow at $width',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 850));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: TripRatingSheetV10(tripId: 'test', captainName: 'محمود'),
            ),
          ),
        );
        expect(find.text('محترم'), findsOneWidget);
        expect(find.text('طلب فلوس زيادة'), findsNothing);
        await tester.tap(find.byTooltip('2 نجوم'));
        await tester.pump();
        expect(find.text('طلب فلوس زيادة'), findsOneWidget);
        expect(find.text('محترم'), findsNothing);
        await tester.tap(find.text('طلب فلوس زيادة'));
        await tester.pump();
        await tester.tap(find.byTooltip('5 نجوم'));
        await tester.pump();
        expect(find.text('تجربة ممتازة'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
