import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:country_picker/country_picker.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/presentation/sign_up_login_screen/widgets/auth_phone_step_widget.dart';

void main() {
  for (final language in ['ar', 'en']) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets('Phone entry $language/$brightness keeps Egypt default and country chooser closed', (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        String? requested,submitted;
        await tester.pumpWidget(MaterialApp(
          locale: Locale(language),
          theme: ThemeData(brightness: brightness),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [AppLocalizations.delegate, CountryLocalizations.delegate,
            GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          home: Scaffold(body: SingleChildScrollView(child: Padding(
            padding: const EdgeInsets.all(16), child: AuthPhoneStepWidget(onSubmit: (phone)=>submitted=phone,requestVerification:(phone)async{requested=phone;}),
          ))),
        ));
        await tester.pumpAndSettle();
        expect(find.text('🇪🇬 +20'), findsOneWidget);
        expect(find.byType(ListView), findsNothing);
        expect(Directionality.of(tester.element(find.byType(AuthPhoneStepWidget))), language == 'ar' ? TextDirection.rtl : TextDirection.ltr);
        final l = lookupAppLocalizations(Locale(language));
        expect(find.text(l.authWelcomeV2), findsOneWidget);
        await tester.enterText(find.byType(TextFormField), '123');
        await tester.tap(find.text(l.requestCode));
        await tester.pump();
        expect(find.text(l.phoneInvalid), findsOneWidget);
        await tester.enterText(find.byType(TextFormField), '+966501234567');
        await tester.tap(find.text(l.requestCode));
        await tester.pump();
        expect(requested,'+966501234567');
        expect(submitted,requested);
        expect(find.text(l.internationalUnavailable), findsNothing);
        expect(find.text('🇸🇦 +966'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
