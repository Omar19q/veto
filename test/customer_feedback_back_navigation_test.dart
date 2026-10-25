import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/presentation/feedback/feedback_screen.dart';
import 'package:vetosanya/services/customer_feedback_backend.dart';

class _FakeFeedbackBackend extends CustomerFeedbackBackend {
  @override
  String? get accountId => 'test_uid';
  @override
  Stream<String?> get accountChanges => const Stream.empty();
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
    'FeedbackScreen leading back button pops back to previous screen in stack',
    (tester) async {
      final backend = _FakeFeedbackBackend();
      final router = GoRouter(
        initialLocation: '/home-screen',
        routes: [
          GoRoute(
            path: '/home-screen',
            builder: (ctx, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => ctx.push('/feedback'),
                  child: const Text('Go Feedback'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/feedback',
            builder: (_, __) => FeedbackScreen(backend: backend),
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

      // Tap to go to feedback
      await tester.tap(find.text('Go Feedback'));
      await tester.pumpAndSettle();

      expect(find.byType(FeedbackScreen), findsOneWidget);

      // Tap leading back button in AppBar
      final backButton = find.byType(IconButton).first;
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Verify we returned to home screen
      expect(find.text('Go Feedback'), findsOneWidget);
      expect(find.byType(FeedbackScreen), findsNothing);

      router.dispose();
    },
  );

  testWidgets(
    'FeedbackScreen leading back button falls back to home screen if cannot pop',
    (tester) async {
      final backend = _FakeFeedbackBackend();
      final router = GoRouter(
        initialLocation: '/feedback',
        routes: [
          GoRoute(
            path: '/home-screen',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('HOME LANDING'))),
          ),
          GoRoute(
            path: '/feedback',
            builder: (_, __) => FeedbackScreen(backend: backend),
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

      expect(find.byType(FeedbackScreen), findsOneWidget);

      // Tap leading back button in AppBar when no previous history
      final backButton = find.byType(IconButton).first;
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Verify fallback to home screen
      expect(find.text('HOME LANDING'), findsOneWidget);
      expect(find.byType(FeedbackScreen), findsNothing);

      router.dispose();
    },
  );
}
