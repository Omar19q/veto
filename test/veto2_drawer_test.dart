import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/theme/app_theme.dart';
import 'package:vetosanya/widgets/customer_drawer.dart';

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
  for (final lang in ['ar', 'en'])
    for (final dark in [true, false])
      for (final width in [320.0, 600.0]) {
        testWidgets(
          'Drawer fits large text and wallet route works $lang/$dark/$width',
          (tester) async {
            tester.view.physicalSize = Size(width, 720);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final router = GoRouter(
              initialLocation: '/home-screen',
              routes: [
                GoRoute(
                  path: '/home-screen',
                  builder: (_, __) => Scaffold(
                    appBar: AppBar(),
                    drawer: const CustomerDrawer(),
                    body: const Text('Home'),
                  ),
                ),
                GoRoute(
                  path: '/feedback',
                  builder: (_, __) =>
                      const Scaffold(body: Text('FEEDBACK ROUTE')),
                ),
              ],
            );
            await tester.pumpWidget(
              MaterialApp.router(
                routerConfig: router,
                locale: Locale(lang),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                theme: AppTheme.productTheme(
                  dark ? Brightness.dark : Brightness.light,
                  lang,
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
              ),
            );
            await tester.tap(find.byIcon(Icons.menu));
            await tester.pumpAndSettle();
            final l = lookupAppLocalizations(Locale(lang));
            expect(tester.getSize(find.byType(Drawer)).width, lessThan(width));
            await tester.scrollUntilVisible(
              find.text(l.menuHelp),
              200,
              scrollable: find
                  .descendant(
                    of: find.byType(Drawer),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            await tester.ensureVisible(find.text(l.menuHelp));
            await tester.pumpAndSettle();
            await tester.tap(find.text(l.menuHelp));
            await tester.pumpAndSettle();
            expect(find.text('FEEDBACK ROUTE'), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
            router.dispose();
          },
        );
      }
}
