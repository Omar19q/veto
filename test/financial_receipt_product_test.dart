import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/theme/app_theme.dart';
import 'package:vetosanya/widgets/trip_financial_card_v11.dart';

void main() {
  for (final language in ['ar', 'en']) {
    for (final dark in [true, false]) {
      testWidgets(
        'Final invoice $language dark=$dark preserves authoritative cash and commission at 320px',
        (tester) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: TripFinancialCardV11(
                    captain: true,
                    trip: {
                      'trip_status': 'completed',
                      'promo_discount': 50,
                      'financial_preview_v11': {
                        'total_fare': 50,
                        'wallet_amount': 0,
                        'cash_amount': 50,
                        'commission_amount': 3.5,
                        'captain_earnings': 71.5,
                        'waiting_charge': 0,
                      },
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final l = lookupAppLocalizations(Locale(language));
          expect(find.text(l.moneyValue('50.00')), findsNWidgets(2));
          expect(find.text(l.moneyValue('3.50')), findsOneWidget);
          expect(find.text(l.moneyValue('71.50')), findsOneWidget);
          if (language == 'en') {
            expect(find.text('Final receipt'), findsOneWidget);
            expect(find.text('الحساب النهائي'), findsNothing);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
