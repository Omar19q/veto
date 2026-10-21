import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/presentation/customer/customer_trip_details_v46.dart';
import 'package:vetosanya/theme/app_theme.dart';

void main() {
  for (final language in ['ar', 'en']) {
    for (final dark in [true, false]) {
      testWidgets(
        'Server receipt $language ${dark ? "dark" : "light"} on small screen preserves amounts and address',
        (tester) async {
          tester.view.physicalSize = const Size(320, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          const trip = {
            'id': 'synthetic-trip',
            'trip_status': 'completed',
            'service_type': 'car_ride',
            'pickup_address': 'عنوان العميل المحفوظ',
            'destination_address': 'User destination',
            'base_fare': 100,
            'promo_discount': 50,
            'wallet_amount': 20,
            'cash_amount': 30,
            'total_fare': 50,
            'created_at': '2026-10-13T12:00:00Z',
          };
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
              home: Scaffold(
                body: CustomerTripDetailsV46(
                  trip: trip,
                  invoiceLoader: (id) async {
                    expect(id, 'synthetic-trip');
                    return {'trip': trip};
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('عنوان العميل المحفوظ'), findsOneWidget);
          expect(find.text('User destination'), findsOneWidget);
          if (language == 'en') {
            expect(find.text('Ride details'), findsOneWidget);
            expect(find.text('تفاصيل المشوار'), findsNothing);
          }
          await tester.drag(find.byType(ListView), const Offset(0, -500));
          await tester.pumpAndSettle();
          final l = lookupAppLocalizations(Locale(language));
          expect(
            find.text(l.moneyValue(language == 'en' ? '20.00' : '٢٠٫٠٠')),
            findsOneWidget,
          );
          expect(
            find.text(l.moneyValue(language == 'en' ? '30.00' : '٣٠٫٠٠')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
