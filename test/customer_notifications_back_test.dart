import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/presentation/notifications/customer_notifications_screen.dart';

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
    'CustomerNotificationsScreen back button and system back return to Home when opened directly',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/notifications',
        routes: [
          GoRoute(
            path: '/home-screen',
            builder: (_, __) => const Scaffold(body: Text('Home Screen')),
          ),
          GoRoute(
            path: '/notifications',
            builder: (_, __) => const CustomerNotificationsScreen(),
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

      // Verify screen rendered
      expect(find.byType(CustomerNotificationsScreen), findsOneWidget);

      // Verify the leading back button exists even with empty navigation history
      final backButton = find.byType(IconButton).first;
      expect(backButton, findsOneWidget);

      // Simulate system back button (hardware back gesture)
      final didInterceptPop = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Handled internally by PopScope and navigated to Home
      expect(didInterceptPop, isTrue);
      expect(find.text('Home Screen'), findsOneWidget);

      router.dispose();
    },
  );

  testWidgets(
    'CustomerNotificationsScreen back button pops when pushed on top of Home',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/home-screen',
        routes: [
          GoRoute(
            path: '/home-screen',
            builder: (context, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => context.push('/notifications'),
                  child: const Text('Open Notifications'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/notifications',
            builder: (_, __) => const CustomerNotificationsScreen(),
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

      // Tap open notifications
      await tester.tap(find.text('Open Notifications'));
      await tester.pumpAndSettle();

      expect(find.byType(CustomerNotificationsScreen), findsOneWidget);

      // Tap the leading back button
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // Returns to Home
      expect(find.text('Open Notifications'), findsOneWidget);
      expect(find.byType(CustomerNotificationsScreen), findsNothing);

      router.dispose();
    },
  );
}
