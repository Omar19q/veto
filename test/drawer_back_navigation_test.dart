import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/widgets/app_scaffold.dart';

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
    'Pressing system back on secondary branches returns to Home tab without exiting',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/home-screen',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) =>
                AppScaffold(navigationShell: shell),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/home-screen',
                    builder: (context, state) => const Scaffold(
                      body: Center(
                        child: Text('Home Screen'),
                      ),
                    ),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/trips',
                    builder: (_, __) => const Text('Trips Page'),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/wallet',
                    builder: (_, __) => const Text('Wallet Page'),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/karizma',
                    builder: (_, __) => const Text('Karizma Page'),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/more',
                    builder: (_, __) => const Text('More Page'),
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home Screen'), findsOneWidget);

      // On Home (branch 0), the first system back triggers the exit-confirmation SnackBar
      final homePopResult = await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(homePopResult, isTrue);
      expect(find.text('اضغط مرة أخرى للخروج من التطبيق'), findsOneWidget);

      // Navigate to /more (branch 4)
      router.go('/more');
      await tester.pumpAndSettle();
      expect(find.text('More Page'), findsOneWidget);

      // Trigger system back button from More tab -> intercepted and returns to Home (branch 0)
      final handledMoreBack = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(handledMoreBack, isTrue);
      expect(find.text('Home Screen'), findsOneWidget);

      // Navigate to /trips (branch 1)
      router.go('/trips');
      await tester.pumpAndSettle();
      expect(find.text('Trips Page'), findsOneWidget);

      // Trigger system back button from trips tab -> returns to Home tab (branch 0)
      final handledTripsBack = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(handledTripsBack, isTrue);
      expect(find.text('Home Screen'), findsOneWidget);

      // Navigate to /wallet (branch 2)
      router.go('/wallet');
      await tester.pumpAndSettle();
      expect(find.text('Wallet Page'), findsOneWidget);

      // Trigger system back button from wallet tab -> returns to Home tab (branch 0)
      final handledWalletBack = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(handledWalletBack, isTrue);
      expect(find.text('Home Screen'), findsOneWidget);

      // Navigate to /karizma (branch 3 - News)
      router.go('/karizma');
      await tester.pumpAndSettle();
      expect(find.text('Karizma Page'), findsOneWidget);

      // Trigger system back button from news tab -> returns to Home tab (branch 0)
      final handledNewsBack = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(handledNewsBack, isTrue);
      expect(find.text('Home Screen'), findsOneWidget);

      router.dispose();
    },
  );
}
