import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetosanya/theme/admin_theme.dart';
import 'package:vetosanya/presentation/admin/admin_overview_v9.dart';
import 'package:vetosanya/presentation/trip_booking_screen/widgets/search_price_suggestion_v9.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Cairo',
    )..addFont(rootBundle.load('assets/fonts/Cairo.ttf'))).load();
  });
  for (final width in [320.0, 390.0, 1440.0])
    for (final dark in [false, true]) {
      testWidgets(
        'Admin report is responsive at $width in ${dark ? 'dark' : 'light'} mode',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 1000));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          AdminTheme.dark.value = dark;
          final key = GlobalKey();
          final daily = List.generate(
            30,
            (i) => <String, dynamic>{
              'day': '2026-09-${(i + 1).toString().padLeft(2, '0')}',
              'profit': i == 29 ? -10.0 : (i % 5) * 10.0,
              'revenue': 100.0,
              'trips': i % 7,
              'customers': i % 3,
              'captains': i % 2,
            },
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: AdminTheme.theme,
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  body: RepaintBoundary(
                    key: key,
                    child: AdminOverviewV9(
                      isLoading: false,
                      stats: {
                        'total_customers': 1200,
                        'total_captains': 85,
                        'online_captains': 51,
                        'today_trips': 36,
                        'active_trips': 12,
                        'today_revenue': 1888.0,
                        'today_company_profit': 155.0,
                        'completion_rate': .75,
                        'daily': daily,
                        'operations_v10': {
                          'searching_trips': 2,
                          'acceptance_rate': .8,
                          'cancellation_rate': .1,
                          'average_matching_minutes': 2.1,
                          'average_eta_minutes': 5.4,
                          'low_ratings': 3,
                          'open_incidents': 4,
                          'commission': 123,
                          'captain_earnings': 1220,
                        },
                        'states': {
                          'requested': 2,
                          'accepted': 5,
                          'completed': 27,
                          'cancelled': 9,
                        },
                      },
                      onRefresh: () {},
                      onNavigate: (_, __) {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('رؤية واضحة لكل رحلة'), findsOneWidget);
          await tester.scrollUntilVisible(
            find.text('30 يومًا'),
            300,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(find.text('30 يومًا'));
          await tester.pumpAndSettle();
          expect(
            find.textContaining('صافي الشركة خلال 30 أيام:'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          if (width == 1440) {
            await tester.runAsync(() async {
              final boundary =
                  key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 1);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final dir = Directory('../previews')..createSync(recursive: true);
              File(
                '${dir.path}/admin_${dark ? 'dark' : 'light'}_v10.png',
              ).writeAsBytesSync(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  for (final width in [320.0, 600.0]) {
    testWidgets(
      'Suggested fare shows total only with exactly two choices at $width',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        int continued = 0, improved = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: SearchPriceSuggestionV9(
                  total: 125,
                  busy: false,
                  onContinue: () => continued++,
                  onImprove: () => improved++,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('السعر المقترح الآن: 125.00 ج'), findsOneWidget);
        expect(find.textContaining('%'), findsNothing);
        await tester.tap(find.text('كمّل بالسعر الحالي'));
        await tester.tap(find.text('استخدام السعر المقترح'));
        expect(continued, 1);
        expect(improved, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
  test('Theme choice persists and dark text remains readable', () async {
    SharedPreferences.setMockInitialValues({});
    AdminTheme.dark.value = false;
    await AdminTheme.toggle();
    expect(AdminTheme.dark.value, true);
    final contrast =
        (AdminTheme.ink.computeLuminance() + .05) /
        (AdminTheme.surface.computeLuminance() + .05);
    expect(contrast, greaterThan(4.5));
    AdminTheme.dark.value = false;
    await AdminTheme.loadPreference();
    expect(AdminTheme.dark.value, true);
  });
}
