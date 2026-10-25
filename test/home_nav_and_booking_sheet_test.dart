import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/widgets/app_scaffold.dart';
import 'package:vetosanya/widgets/customer_map_home.dart';

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
    'Bottom navigation bar has الرئيسية centered and navigates correctly',
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
                    builder: (_, __) => const Center(child: Text('Home Screen')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/trips',
                    builder: (_, __) => const Center(child: Text('Trips Page')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/wallet',
                    builder: (_, __) => const Center(child: Text('Wallet Page')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/news',
                    builder: (_, __) => const Center(child: Text('News Page')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/more',
                    builder: (_, __) => const Center(child: Text('More Page')),
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

      // Verify Home Screen initially
      expect(find.text('Home Screen'), findsOneWidget);

      // Verify the 5 tabs exist
      expect(find.text('الرئيسية'), findsOneWidget);
      expect(find.text('رحلاتي'), findsOneWidget);
      expect(find.text('المحفظة'), findsOneWidget);
      expect(find.text('الأخبار'), findsOneWidget);
      expect(find.text('المزيد'), findsOneWidget);

      // Verify الرئيسية is centered: its horizontal center should match screen center
      final homeRect = tester.getRect(find.text('الرئيسية'));
      final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect((homeRect.center.dx - (screenWidth / 2)).abs(), lessThan(20));

      // Tap رحلاتي
      await tester.tap(find.text('رحلاتي'));
      await tester.pumpAndSettle();
      expect(find.text('Trips Page'), findsOneWidget);

      // Tap المحفظة
      await tester.tap(find.text('المحفظة'));
      await tester.pumpAndSettle();
      expect(find.text('Wallet Page'), findsOneWidget);

      // Tap الرئيسية in the center to return to Home
      await tester.tap(find.text('الرئيسية'));
      await tester.pumpAndSettle();
      expect(find.text('Home Screen'), findsOneWidget);

      router.dispose();
    },
  );

  testWidgets(
    'CustomerMapHome renders expand/collapse button with drag handle cleanly',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: CustomerMapHome(
              map: const SizedBox(),
              city: 'حدائق الأهرام',
              onCity: () {},
              onLocate: () {},
              onNotifications: () {},
              locating: false,
              unreadCount: 0,
              slivers: const [
                SliverToBoxAdapter(child: Text('Booking Options Content')),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the booking expand header exists and is visible
      expect(find.text('عرض خيارات الحجز'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);

      // Tap to expand
      await tester.tap(find.text('عرض خيارات الحجز'));
      await tester.pumpAndSettle();

      expect(find.text('تصغير لوحة الحجز'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    },
  );
}
