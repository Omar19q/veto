import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/presentation/legal/legal_center_screen.dart';

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
    'VetoLegalCenterScreen (safety) back button pops back to previous screen in stack',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/home-screen',
        routes: [
          GoRoute(
            path: '/home-screen',
            builder: (ctx, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => ctx.push('/safety-support'),
                  child: const Text('Open Safety'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/safety-support',
            builder: (_, __) => const VetoLegalCenterScreen(pageKey: 'safety'),
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

      // Open safety support
      await tester.tap(find.text('Open Safety'));
      await tester.pumpAndSettle();

      expect(find.byType(VetoLegalCenterScreen), findsOneWidget);

      // Tap leading back button in AppBar
      final backButton = find.byType(IconButton).first;
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Verify we returned to home screen
      expect(find.text('Open Safety'), findsOneWidget);
      expect(find.byType(VetoLegalCenterScreen), findsNothing);

      router.dispose();
    },
  );

  testWidgets(
    'VetoLegalCenterScreen falls back to /home-screen if cannot pop',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/safety-support',
        routes: [
          GoRoute(
            path: '/home-screen',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('HOME LANDING'))),
          ),
          GoRoute(
            path: '/safety-support',
            builder: (_, __) => const VetoLegalCenterScreen(pageKey: 'safety'),
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

      expect(find.byType(VetoLegalCenterScreen), findsOneWidget);

      // Tap leading back button in AppBar when no previous history
      final backButton = find.byType(IconButton).first;
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Verify fallback to home screen
      expect(find.text('HOME LANDING'), findsOneWidget);
      expect(find.byType(VetoLegalCenterScreen), findsNothing);

      router.dispose();
    },
  );
}
