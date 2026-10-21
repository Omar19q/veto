import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetosanya/services/product_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Presentation preferences persist per owner without role or financial keys',
    () async {
      final writes = <Map<String, dynamic>>[];
      final preferences = ProductPreferences();
      preferences.accountWriter = (owner, values) async {
        expect(owner, 'account-a');
        writes.add(values);
      };
      await preferences.load();
      await preferences.useAccount('account-a', {});
      await preferences.setLanguage('en');
      await preferences.setTheme(ThemeMode.light);
      expect(writes, [
        {'veto_product_language': 'en'},
        {'veto_product_theme': 'light'},
      ]);
      final restored = ProductPreferences();
      await restored.load();
      await restored.useAccount('account-b', {
        'veto_product_language': 'ar',
        'veto_product_theme': 'dark',
      });
      expect(restored.locale.languageCode, 'ar');
      expect(restored.themeMode, ThemeMode.dark);
      await restored.useAccount('account-a', {});
      expect(restored.locale.languageCode, 'en');
      expect(restored.themeMode, ThemeMode.light);
    },
  );
  test(
    'Signed-out changes stay device-only; server write failures remain observable',
    () async {
      final preferences = ProductPreferences();
      var calls = 0;
      preferences.accountWriter = (owner, values) async {
        calls++;
        throw StateError('synthetic network failure');
      };
      await preferences.load();
      await preferences.setLanguage('en');
      expect(calls, 0);
      await preferences.useAccount('account-a', {});
      await expectLater(preferences.setLanguage('ar'), throwsStateError);
      expect(calls, 1);
      expect(preferences.locale.languageCode, 'ar');
    },
  );
  test(
    'An account change rejects the previous in-flight setting write',
    () async {
      final preferences = ProductPreferences();
      final owners = <String>[];
      preferences.accountWriter = (owner, values) async => owners.add(owner);
      await preferences.load();
      await preferences.useAccount('account-a', {});
      final pending = preferences.setLanguage('en');
      await preferences.useAccount('account-b', {
        'veto_product_language': 'ar',
      });
      await pending;
      expect(owners, isEmpty);
      expect(preferences.locale.languageCode, 'ar');
    },
  );
}
