import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/presentation/sign_up_login_screen/captain_registration_screen.dart';
import 'package:vetosanya/services/captain_application_v16.dart';
import 'package:vetosanya/theme/app_theme.dart';

class SyntheticApplicationApi extends CaptainApplicationV16 {
  SyntheticApplicationApi() : super(client: SupabaseClient(
      'http://127.0.0.1:54321','synthetic-local-test-key',
      authOptions: const AuthClientOptions(autoRefreshToken:false)));
  @override Future<Map<String,dynamic>?> identity() async => null;
  @override Future<Map<String,dynamic>?> intakeMine() async => null;
}
void main() {
  for (final language in ['ar','en']) {
    for (final dark in [false,true]) {
      testWidgets('Captain intake keeps required Egyptian fields and fits 320px $language/$dark', (tester) async {
        tester.view.physicalSize = const Size(320,720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = (await tester.runAsync(() async => SyntheticApplicationApi()))!;
        addTearDown(() => tester.runAsync(api.client.dispose));
        await tester.pumpWidget(MaterialApp(locale:Locale(language),
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          supportedLocales:AppLocalizations.supportedLocales,
          localizationsDelegates:const [AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate],
          home:CaptainRegistrationScreen(applicationApi:api)));
        await tester.pumpAndSettle();
        expect(find.byType(TextFormField),findsWidgets);
        expect(Directionality.of(tester.element(find.byType(CaptainRegistrationScreen))),
          language=='ar'?TextDirection.rtl:TextDirection.ltr);
        final l=lookupAppLocalizations(Locale(language));
        expect(find.text(l.applicationStep(1,l.applicationPersonalStep)),findsOneWidget);
        if(language=='en') {
          expect(find.text('رقم موبايلك المصري'),findsNothing);
          expect(find.text('الرقم القومي'),findsNothing);
        }
        expect(tester.takeException(),isNull);
      });
    }
  }
}
