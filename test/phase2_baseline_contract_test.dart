import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/services/location_upload_gate_v15.dart';
import 'package:vetosanya/widgets/trip_financial_card_v11.dart';

void main() {
  test('GPS movement and heartbeat respect current upload boundaries', () {
    final gate = LocationUploadGateV15();
    final now = DateTime.utc(2026, 10, 13);
    gate.committed(30, 31, now);
    expect(
      gate.shouldUpload(30.01, 31, now.add(const Duration(seconds: 4))),
      isFalse,
    );
    expect(
      gate.shouldUpload(30.01, 31, now.add(const Duration(seconds: 5))),
      isTrue,
    );
    expect(
      gate.shouldUpload(30.00001, 31, now.add(const Duration(seconds: 14))),
      isFalse,
    );
    expect(
      gate.shouldUpload(30, 31, now.add(const Duration(seconds: 15))),
      isTrue,
    );
  });

  test(
    'GPS failed attempts throttle retries without committing a location',
    () {
      final gate = LocationUploadGateV15();
      final now = DateTime.utc(2026, 10, 13);
      gate.attempted(now);
      expect(
        gate.shouldUpload(30, 31, now.add(const Duration(seconds: 4))),
        isFalse,
      );
      expect(
        gate.shouldUpload(30, 31, now.add(const Duration(seconds: 5))),
        isTrue,
      );
      gate.reset();
      expect(gate.shouldUpload(30, 31, now), isTrue);
    },
  );

  for (final status in ['searching', 'accepted', 'started', 'cancelled']) {
    testWidgets('Final invoice never collects a fare for $status', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripFinancialCardV11(
              trip: {
                'trip_status': status,
                'financial_preview_v11': {
                  'total_fare': 35,
                  'cash_amount': 25,
                  'wallet_amount': 10,
                },
              },
            ),
          ),
        ),
      );
      expect(find.text('الحساب النهائي'), findsNothing);
      expect(find.text('25.00 ج'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Completed invoice separates cash and wallet from the fare', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TripFinancialCardV11(
            trip: {
              'trip_status': 'completed',
              'financial_preview_v11': {
                'total_fare': 35,
                'cash_amount': 25,
                'wallet_amount': 10,
              },
            },
          ),
        ),
      ),
    );
    expect(find.text('35.00 ج'), findsOneWidget);
    expect(find.text('25.00 ج'), findsOneWidget);
    expect(find.text('10.00 ج'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Missing completed cash amount stays unavailable rather than zero',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TripFinancialCardV11(
              trip: {
                'trip_status': 'completed',
                'financial_preview_v11': {'total_fare': 35},
              },
            ),
          ),
        ),
      );
      expect(find.text('غير متاح'), findsOneWidget);
      expect(find.text('0.00 ج'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
