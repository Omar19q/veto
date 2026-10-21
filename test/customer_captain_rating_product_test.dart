import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/theme/app_theme.dart';
import 'package:vetosanya/presentation/trip_booking_screen/widgets/trip_rating_sheet_v10.dart';

void main() {
  for (final language in ['ar', 'en']) {
    for (final dark in [true, false]) {
      testWidgets('Customer captain rating $language dark=$dark at 320px', (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final strings = lookupAppLocalizations(Locale(language));
        await tester.pumpWidget(MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.lightTheme, darkTheme: AppTheme.darkTheme,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: const Scaffold(body: TripRatingSheetV10(tripId: 'synthetic-trip', captainName: 'اسم الكابتن الأصلي')),
        ));
        await tester.pumpAndSettle();
        expect(find.text(strings.customerRatingTitle), findsOneWidget);
        expect(find.text(strings.customerRatingCaptain('اسم الكابتن الأصلي')), findsOneWidget);
        await tester.tap(find.byTooltip(strings.customerRatingStars('2')));
        await tester.pumpAndSettle();
        expect(find.text(strings.customerRatingReason0), findsOneWidget);
        await tester.tap(find.text(strings.customerRatingReason0));
        await tester.pump();
        expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, strings.customerRatingReason0)).selected, isTrue);
        await tester.tap(find.byTooltip(strings.customerRatingStars('5')));
        await tester.pumpAndSettle();
        expect(find.text(strings.customerRatingReason0), findsNothing);
        expect(find.text(strings.customerRatingReason7), findsOneWidget);
        expect(Directionality.of(tester.element(find.byType(TripRatingSheetV10))), language == 'ar' ? TextDirection.rtl : TextDirection.ltr);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
