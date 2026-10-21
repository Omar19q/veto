import 'package:flutter/material.dart';
import 'package:vetosanya/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/widgets/trip_financial_card_v11.dart';
import 'package:vetosanya/presentation/trip_booking_screen/widgets/captain_profile_card_v11.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Cairo',
    )..addFont(rootBundle.load('assets/fonts/Cairo.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final width in [320.0, 390.0, 600.0]) {
    for (final captain in [true, false]) {
      testWidgets(
        'Completed combined bill displays 35 total, 10 wallet, 25 cash at $width captain=$captain',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 1000));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            MaterialApp(
              // This existing Golden records the original dark invoice.
              theme: AppTheme.darkTheme,
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: TripFinancialCardV11(
                      captain: captain,
                      trip: const {
                        'trip_status': 'completed',
                        'base_fare': 35,
                        'financial_preview_v11': {
                          'total_fare': 35,
                          'wallet_amount': 10,
                          'cash_amount': 25,
                          'commission_amount': 3.5,
                          'captain_earnings': 31.5,
                          'company_incentive_amount': 0,
                          'captain_incentive_amount': 0,
                        },
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
          expect(
            find.text(captain ? 'استلم كاش من العميل' : 'المتبقي كاش للكابتن'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          if (width == 390 && captain) {
            await expectLater(
              find.byType(TripFinancialCardV11),
              matchesGoldenFile('goldens/v11_captain_bill.png'),
            );
          }
        },
      );
    }
    testWidgets(
      'Captain profile with long Egyptian name and reviews fits at $width',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1100));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          const MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: SingleChildScrollView(
                  child: CaptainProfileCardV11(
                    profile: {
                      'full_name': 'محمد أحمد عبد الرحمن',
                      'rating': 4.85,
                      'rating_count': 180,
                      'total_completed_trips': 1250,
                      'vehicle_brand': 'هيونداي',
                      'vehicle_model': 'إلنترا',
                      'vehicle_color': 'أسود',
                      'verified': true,
                      'vehicle_verified': true,
                      'reviews': [
                        {
                          'stars': 5,
                          'month': '2026-10',
                          'reasons': ['محترم', 'قيادة مريحة', 'المركبة نضيفة'],
                        },
                      ],
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('محمد'), findsOneWidget);
        expect(find.text('محمد أحمد عبد الرحمن'), findsNothing);
        expect(find.text('هوية موثقة'), findsOneWidget);
        expect(find.text('آراء الركاب'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (width == 390) {
          await expectLater(
            find.byType(CaptainProfileCardV11),
            matchesGoldenFile('goldens/v11_captain_profile.png'),
          );
        }
      },
    );
  }
  testWidgets(
    'Cancellation invoice shows refund separately and no fare collection',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TripFinancialCardV11(
              trip: {
                'trip_status': 'cancelled',
                'financial_preview_v11': {
                  'wallet_refund': 10,
                  'compensation': 0,
                },
              },
            ),
          ),
        ),
      );
      expect(find.text('10.00 ج'), findsOneWidget);
      expect(find.text('المبلغ المطلوب تحصيله من العميل'), findsNothing);
      expect(find.text('تعويض الإلغاء بعد المهلة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
