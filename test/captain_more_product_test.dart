import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/presentation/captain_dashboard_screen/widgets/captain_more_v32.dart';
import 'package:vetosanya/theme/app_theme.dart';

void main() {
  for (final language in ['ar', 'en']) {
    for (final dark in [false, true]) {
      testWidgets('Captain account preserves actions and direction $language/$dark on small phone', (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var switched = 0, earnings = 0;
        void noop() {}
        await tester.pumpWidget(MaterialApp(
          locale: Locale(language), supportedLocales: AppLocalizations.supportedLocales,
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          localizationsDelegates: const [AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate],
          home: Scaffold(body: CaptainMoreV32(captain: const {'id':'synthetic','full_name':'Original name'},
            linkedCustomer: true, staffVerifier: false, onOpenProfile: noop,
            onSwitchCustomer: () => switched++, onQuickVerification: noop,
            onTrips: noop, onEarnings: () => earnings++, onDemand: noop,
            onNotifications: noop, onSupport: noop, onPrivacy: noop,
            onDelete: noop, onRefresh: noop, onSignOut: noop)),
        ));
        await tester.pumpAndSettle();
        final l = lookupAppLocalizations(Locale(language));
        expect(Directionality.of(tester.element(find.byType(CaptainMoreV32))),
          language == 'ar' ? TextDirection.rtl : TextDirection.ltr);
        expect(find.text(l.account8f2788c0), findsNothing);
        await tester.ensureVisible(find.text(l.account166aea7d));
        await tester.tap(find.text(l.account166aea7d));
        expect(earnings, 1);
        await tester.ensureVisible(find.text(l.accountb439a50f));
        await tester.tap(find.text(l.accountb439a50f));
        expect(switched, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
