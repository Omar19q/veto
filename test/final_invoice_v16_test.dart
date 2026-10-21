import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/widgets/trip_financial_card_v11.dart';

void main() {
  for (final status in [
    'pending',
    'accepted',
    'arriving',
    'arrived',
    'started',
    'cancelled',
  ]) {
    testWidgets(
      'final bill cannot render for $status even if amounts are present',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: TripFinancialCardV11(
              captain: true,
              trip: {
                'trip_status': status,
                'total_fare': 35,
                'cash_amount': 25,
                'wallet_amount': 10,
              },
            ),
          ),
        );
        expect(find.text('الحساب النهائي'), findsNothing);
        expect(find.text('25.00 ج'), findsNothing);
      },
    );
  }
  for (final captain in [true, false]) {
    testWidgets(
      'completed bill preserves server amounts for captain=$captain at 320px',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: SingleChildScrollView(
                  child: TripFinancialCardV11(
                    captain: captain,
                    trip: const {
                      'trip_status': 'completed',
                      'financial_preview_v11': {
                        'total_fare': 35,
                        'wallet_amount': 10,
                        'cash_amount': 25,
                        'commission_amount': 3.5,
                        'captain_earnings': 31.5,
                      },
                      'change_transfer': {'amount': 2},
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('35.00 ج'), findsOneWidget);
        expect(find.text('10.00 ج'), findsOneWidget);
        expect(find.text('25.00 ج'), findsOneWidget);
        expect(find.text('2.00 ج'), findsOneWidget);
        expect(find.text('3.50 ج'), captain ? findsOneWidget : findsNothing);
        expect(find.text('31.50 ج'), captain ? findsOneWidget : findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
