import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vetosanya/widgets/app_navigation.dart';
import 'package:vetosanya/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final cairo = FontLoader('Cairo')
      ..addFont(rootBundle.load('assets/fonts/Cairo.ttf'));
    await cairo.load();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(url: 'https://test.supabase.co', anonKey: 'test');
  });
  tearDownAll(() async => Supabase.instance.dispose());

  test('Dark text and hint contrast are readable', () {
    double contrast(Color foreground, Color background) =>
        (foreground.computeLuminance() + .05) /
        (background.computeLuminance() + .05);
    expect(contrast(AppTheme.textPrimary, AppTheme.surface), greaterThan(4.5));
    expect(
      contrast(AppTheme.textSecondary, AppTheme.surface),
      greaterThan(4.5),
    );
    expect(contrast(AppTheme.textMuted, AppTheme.surface), greaterThan(4.5));
  });

  for (final width in [320.0, 390.0, 600.0]) {
    testWidgets('Liquid bar tabs work at width $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      final router = GoRouter(
        initialLocation: '/tab0',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) => Scaffold(
              body: shell,
              bottomNavigationBar: AppNavigation(navigationShell: shell),
            ),
            branches: List.generate(
              5,
              (i) => StatefulShellBranch(
                routes: [
                  GoRoute(path: '/tab$i', builder: (_, __) => Text('page$i')),
                ],
              ),
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router, theme: ThemeData.dark()),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      if (width == 390) {
        await expectLater(
          find.byType(AppNavigation),
          matchesGoldenFile('goldens/liquid_customer_navigation.png'),
        );
      }
      await tester.tap(find.text('المحفظة'));
      await tester.pumpAndSettle();
      expect(find.text('page2'), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_wallet_rounded), findsOneWidget);
      // Deep linking also updates selection; it is not local tap-only state.
      router.go('/tab4');
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      await tester.binding.setSurfaceSize(null);
    });
  }
}
