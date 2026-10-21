import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/presentation/home_screen/widgets/home_promo_widget.dart';
import 'package:vetosanya/theme/app_theme.dart';

void main() {
  for (final locale in ['ar', 'en']) {
    testWidgets(
      'All active ordered banners reachable with manual paging in $locale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: AppTheme.productTheme(Brightness.light, locale),
            home: Scaffold(
              body: HomePromoWidget(
                loadBanners: () async => [
                  {
                    'id': '1',
                    'title': 'FIRST',
                    'is_active': true,
                    'action_type': 'none',
                  },
                  {
                    'id': '2',
                    'title': 'SECOND',
                    'is_active': true,
                    'action_type': 'none',
                  },
                  {'id': '3', 'title': 'INACTIVE', 'is_active': false},
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('FIRST'), findsOneWidget);
        expect(find.text('INACTIVE'), findsNothing);
        final next = locale == 'ar' ? 'العرض التالي' : 'Next offer';
        await tester.tap(find.byTooltip(next));
        await tester.pumpAndSettle();
        expect(find.text('SECOND'), findsOneWidget);
        await tester.pump(const Duration(seconds: 30));
        expect(find.text('SECOND'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
