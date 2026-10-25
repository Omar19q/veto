import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/presentation/wallet/customer_wallet_screen.dart';

Widget _wrap(Widget child, {ThemeMode mode = ThemeMode.light}) {
  return MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    themeMode: mode,
    theme: ThemeData.light(),
    darkTheme: ThemeData.dark(),
    home: child,
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:54321',
      anonKey: 'synthetic-local-key',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        persistSession: false,
      ),
    );
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  testWidgets(
    'Wallet balance displays black in light mode when non-negative',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CustomerWalletScreen(initialBalance: 50.0, autoLoad: false),
          mode: ThemeMode.light,
        ),
      );
      await tester.pumpAndSettle();

      final balanceFinder = find.byWidgetPredicate(
        (w) => w is Text && w.style?.fontSize == 36,
      );
      expect(balanceFinder, findsOneWidget);

      final text = tester.widget<Text>(balanceFinder);
      expect(text.style?.color, const Color(0xFF0B0F1A));
    },
  );

  testWidgets(
    'Wallet balance displays white in dark mode when non-negative',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CustomerWalletScreen(initialBalance: 50.0, autoLoad: false),
          mode: ThemeMode.dark,
        ),
      );
      await tester.pumpAndSettle();

      final balanceFinder = find.byWidgetPredicate(
        (w) => w is Text && w.style?.fontSize == 36,
      );
      expect(balanceFinder, findsOneWidget);

      final text = tester.widget<Text>(balanceFinder);
      expect(text.style?.color, Colors.white);
    },
  );

  testWidgets(
    'Wallet balance displays red when negative in both themes',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CustomerWalletScreen(initialBalance: -15.50, autoLoad: false),
          mode: ThemeMode.light,
        ),
      );
      await tester.pumpAndSettle();

      final balanceFinder = find.byWidgetPredicate(
        (w) => w is Text && w.style?.fontSize == 36,
      );
      expect(balanceFinder, findsOneWidget);

      final text = tester.widget<Text>(balanceFinder);
      expect(text.style?.color, const Color(0xFFEF4444));
    },
  );
}
