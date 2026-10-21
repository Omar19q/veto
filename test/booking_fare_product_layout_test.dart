import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/theme/app_theme.dart';
import 'package:vetosanya/presentation/trip_booking_screen/widgets/booking_fare_sheet_widget.dart';

void main() {
  for (final language in ['ar', 'en']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'Fare review at 320px $language/$brightness keeps confirmation visible and payment amounts intact',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var confirmed = 0;
          Map<String, Object>? payment;
          final l = lookupAppLocalizations(Locale(language));
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.productTheme(brightness, language),
              home: Scaffold(
                body: SizedBox(
                  height: 600,
                  child: BookingFareSheetWidget(
                    serviceId: 'car',
                    pickupLabel: 'Original pickup',
                    destinationLabel: 'عنوان العميل الأصلي',
                    distance: 1.4,
                    duration: 3,
                    fare: 100,
                    incentiveAmount: 5,
                    passengerCount: 1,
                    walletBalance: 50,
                    onPassengerCountChanged: (_) {},
                    onPackageWeightChanged: (_) {},
                    onCustomerNoteChanged: (_) {},
                    onPaymentMethodChanged: (method, wallet, cash) => payment =
                        {'method': method, 'wallet': wallet, 'cash': cash},
                    onConfirm: () => confirmed++,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(payment, {'method': 'combined', 'wallet': 50.0, 'cash': 55.0});
          expect(find.byType(Dialog), findsNothing);
          final confirm = find.widgetWithText(ElevatedButton, l.uia39f7a83);
          expect(confirm, findsOneWidget);
          expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(640));
          await tester.tap(confirm);
          expect(confirmed, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
