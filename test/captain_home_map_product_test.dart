import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/theme/app_theme.dart';
import 'package:vetosanya/presentation/captain_dashboard_screen/widgets/captain_home_map_v30.dart';

void main() {
  for (final language in ['ar', 'en']) {
    for (final dark in [true, false]) {
      testWidgets(
        'Captain map $language dark=$dark at320, missing GPS is explicit',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var opened = 0;
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: CaptainHomeMapV30(
                    captain: null,
                    online: true,
                    onOpenDemandMap: () => opened++,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final l = lookupAppLocalizations(Locale(language));
          expect(find.text(l.captainMapConnected), findsOneWidget);
          expect(find.text(l.captainMapMissingLocation), findsOneWidget);
          expect(find.text(l.captainMapHotspots), findsOneWidget);
          expect(find.text('متاح لاستقبال الطلبات'), findsNothing);
          expect(
            Directionality.of(tester.element(find.text(l.captainMapHotspots))),
            language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          );
          await tester.tap(find.byTooltip(l.captainMapOpen));
          expect(opened, 1);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
