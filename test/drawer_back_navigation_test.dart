import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    'Pressing system back when drawer is open closes the drawer and stays on screen',
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
                    builder: (context, state) => Scaffold(
                      body: Center(
                        child: ElevatedButton(
                          onPressed: () => Scaffold.of(context).openDrawer(),
                          child: const Text('Open'),
                        ),
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
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      // Open drawer from Home
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Drawer is visible
      expect(find.byType(Drawer), findsOneWidget);

      // Trigger system back button (simulate Android back button)
      final didPopRoute = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // The pop was handled internally and drawer closed
      expect(didPopRoute, isTrue);
      expect(find.byType(Drawer), findsNothing);
      expect(find.text('Open'), findsOneWidget);

      // Navigate to /trips (branch 1)
      router.go('/trips');
      await tester.pumpAndSettle();
      expect(find.text('Trips Page'), findsOneWidget);

      // Trigger system back button from trips tab -> returns to Home tab (branch 0)
      final handledTripsBack = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(handledTripsBack, isTrue);
      expect(find.text('Open'), findsOneWidget);

      router.dispose();
    },
  );
}
