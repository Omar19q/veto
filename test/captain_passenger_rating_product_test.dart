import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/theme/app_theme.dart';
import 'package:vetosanya/presentation/captain_dashboard_screen/widgets/captain_customer_rating_v29.dart';

void main() {
  for (final language in ['ar', 'en']) {
    for (final dark in [true, false]) {
      testWidgets('Captain passenger rating $language dark=$dark at 320px', (tester) async {
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
          home: const Scaffold(body: CaptainCustomerRatingV29(tripId: 'synthetic-trip', customerName: 'اسم الراكب الأصلي')),
        ));
        await tester.pumpAndSettle();
        expect(find.text(strings.ratingExperience), findsOneWidget);
        expect(find.text('اسم الراكب الأصلي'), findsOneWidget);
        await tester.tap(find.byTooltip(strings.ratingStars('2')));
        await tester.pumpAndSettle();
        expect(find.text(strings.ratingReason0), findsOneWidget);
        await tester.tap(find.text(strings.ratingReason0));
        await tester.pump();
        expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, strings.ratingReason0)).selected, isTrue);
        await tester.tap(find.byTooltip(strings.ratingStars('5')));
        await tester.pumpAndSettle();
        expect(find.text(strings.ratingReason0), findsNothing);
        expect(find.text(strings.ratingExcellent), findsOneWidget);
        expect(Directionality.of(tester.element(find.byType(CaptainCustomerRatingV29))), language == 'ar' ? TextDirection.rtl : TextDirection.ltr);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
