import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/presentation/sign_up_login_screen/captain_registration_screen.dart';

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
    'CaptainRegistrationScreen leading back button pops to previous route in stack',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/more',
        routes: [
          GoRoute(
            path: '/more',
            builder: (ctx, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => ctx.push('/captain-registration'),
                  child: const Text('Open Registration'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/captain-registration',
            builder: (_, __) => const CaptainRegistrationScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Registration'));
      await tester.pumpAndSettle();

      expect(find.byType(CaptainRegistrationScreen), findsOneWidget);

      // Verify the leading back button exists in the AppBar
      final backButton = find.widgetWithIcon(
        IconButton,
        Icons.arrow_back_rounded,
      );
      expect(backButton, findsOneWidget);

      // Tap back button
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Verify we returned to /more
      expect(find.text('Open Registration'), findsOneWidget);
      expect(find.byType(CaptainRegistrationScreen), findsNothing);

      router.dispose();
    },
  );

  testWidgets(
    'CaptainRegistrationScreen falls back to /home-screen if cannot pop',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/captain-registration',
        routes: [
          GoRoute(
            path: '/home-screen',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('HOME SCREEN'))),
          ),
          GoRoute(
            path: '/captain-registration',
            builder: (_, __) => const CaptainRegistrationScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CaptainRegistrationScreen), findsOneWidget);

      final backButton = find.widgetWithIcon(
        IconButton,
        Icons.arrow_back_rounded,
      );
      expect(backButton, findsOneWidget);

      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Verify fallback
      expect(find.text('HOME SCREEN'), findsOneWidget);
      expect(find.byType(CaptainRegistrationScreen), findsNothing);

      router.dispose();
    },
  );
}
