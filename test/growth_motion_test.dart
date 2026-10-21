import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/presentation/growth/growth_booking_progress.dart';
import 'package:vetosanya/presentation/growth/growth_badge_placement.dart';
import 'package:vetosanya/presentation/growth/growth_startup.dart';
import 'package:vetosanya/widgets/trip_financial_card_v11.dart';

void main() {
  testWidgets(
    'Completed zero-commission invoice explicitly shows verified zero commission',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TripFinancialCardV11(
              captain: true,
              trip: {
                'trip_status': 'completed',
                'financial_preview_v11': {
                  'total_fare': 100,
                  'wallet_amount': 0,
                  'cash_amount': 100,
                  'commission_amount': 0,
                  'captain_earnings': 100,
                },
              },
            ),
          ),
        ),
      );
      expect(find.text('عمولة الشركة'), findsOneWidget);
      expect(find.text('0.00 ج'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Missing captain settlement figures never render a fictitious final invoice',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TripFinancialCardV11(
              captain: true,
              trip: {
                'trip_status': 'completed',
                'financial_preview_v11': {
                  'total_fare': 100,
                  'wallet_amount': 0,
                  'cash_amount': 100,
                },
              },
            ),
          ),
        ),
      );
      expect(find.text('غير متاح'), findsOneWidget);
      expect(find.text('0.00 ج'), findsNothing);
    },
  );

  testWidgets('Unsettled raw figures cannot be masked by zero-filled preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TripFinancialCardV11(
            captain: true,
            trip: {
              'trip_status': 'completed',
              'financial_settled_at': null,
              'total_fare': null,
              'wallet_amount': null,
              'commission_amount': null,
              'captain_earnings': null,
              'financial_preview_v11': {
                'total_fare': 0,
                'wallet_amount': 0,
                'cash_amount': 0,
                'commission_amount': 0,
                'captain_earnings': 0,
              },
            },
          ),
        ),
      ),
    );
    expect(find.text('غير متاح'), findsOneWidget);
    expect(find.text('0.00 ج'), findsNothing);
  });

  for (final width in [320.0, 390.0, 600.0]) {
    testWidgets('All four booking stages fit $width and honor reduced motion', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (var stage = 0; stage < 4; stage++) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(body: GrowthBookingProgress(stage: stage)),
            ),
          ),
        );
        for (final label in GrowthBookingProgress.labels) {
          expect(find.text(label), findsOneWidget);
        }
        expect(
          tester
              .widget<AnimatedContainer>(find.byType(AnimatedContainer).first)
              .duration,
          Duration.zero,
        );
        expect(tester.takeException(), isNull);
      }
    });
  }
  testWidgets(
    'Placement opens once, supports safe motorcycle alternative and reduced motion',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(body: GrowthBadgePlacement()),
          ),
        ),
      );
      await tester.pump();
      final slide = tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));
      expect(slide.offset, Offset.zero);
      expect(slide.duration, Duration.zero);
      await tester.tap(find.text('حقيبة توصيل الموتوسيكل'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.delivery_dining), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Default protected build never overlays startup or intercepts existing screen',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: GrowthStartup(
            child: TextButton(
              onPressed: () => taps++,
              child: const Text('existing'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('existing'));
      expect(taps, 1);
      expect(find.text('VETO SANYA'), findsNothing);
    },
  );
}
