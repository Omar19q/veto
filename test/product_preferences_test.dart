import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/services/product_preferences.dart';
import 'package:vetosanya/services/address_suggestion_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Arabic and system presentation default; saved settings restore',
    () async {
      SharedPreferences.setMockInitialValues({});
      final p = ProductPreferences();
      await p.load();
      expect(p.locale.languageCode, 'ar');
      expect(p.themeMode, ThemeMode.system);
      await p.setLanguage('en');
      await p.setTheme(ThemeMode.dark);
      final restored = ProductPreferences();
      await restored.load();
      expect(restored.locale.languageCode, 'en');
      expect(restored.themeMode, ThemeMode.dark);
      expect(() => p.setLanguage('zz'), throwsArgumentError);
    },
  );
  testWidgets(
    'Locale changes direction and text immediately without recreating session',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final p = ProductPreferences();
      await p.load();
      await tester.pumpWidget(
        ListenableBuilder(
          listenable: p,
          builder: (context, _) => MaterialApp(
            locale: p.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Builder(
              builder: (context) => Text(AppLocalizations.of(context).whereTo),
            ),
          ),
        ),
      );
      expect(find.text('رايح فين؟'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('رايح فين؟'))),
        TextDirection.rtl,
      );
      await p.setLanguage('en');
      await tester.pumpAndSettle();
      expect(find.text('Where to?'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('Where to?'))),
        TextDirection.ltr,
      );
    },
  );
  test(
    'Suggestion retries preserve operation key and never use a booking RPC',
    () async {
      final calls = <Map<String, dynamic>>[];
      final key = AddressSuggestionService.requestKey();
      final service = AddressSuggestionService(
        rpc: (name, params) async {
          expect(name, 'v51_customer_suggest_address');
          calls.add(params);
          return key;
        },
      );
      final params = {
        'p_request_key': key,
        'p_city': 'مدينة اختبار',
        'p_address': 'وصف العميل',
        'p_note': 'مدخل جانبي',
      };
      await service.submit(params);
      await service.submit(params);
      expect(calls[0]['p_request_key'], calls[1]['p_request_key']);
      expect(calls.first['p_note'], 'مدخل جانبي');
      expect(
        RegExp(
          r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
        ).hasMatch(key),
        isTrue,
      );
    },
  );
}
