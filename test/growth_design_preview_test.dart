import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/presentation/growth/growth_screens.dart';
import 'package:vetosanya/theme/app_theme.dart';
import 'package:vetosanya/presentation/home_screen/widgets/home_route_first_v36.dart';
import 'package:vetosanya/presentation/growth/growth_booking_progress.dart';
import 'growth_service_test.dart' show ReviewGrowthService;

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Cairo',
    )..addFont(rootBundle.load('assets/fonts/Cairo.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final width in [320.0, 390.0, 600.0]) {
    testWidgets('Premium route surface preserves booking and market at $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var bookings = 0;
      var market = 0;
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: RepaintBoundary(
            key: key,
            child: Scaffold(
              body: Directionality(
                textDirection: TextDirection.rtl,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        HomeRouteFirstV36(
                          premium: true,
                          pickupCaption: 'اختار مكان الركوب',
                          onStart: () => bookings++,
                          onMarketTap: () => market++,
                        ),
                        const SizedBox(height: 20),
                        const GrowthBookingProgress(stage: 1),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('اختار مكان الركوب'), findsOneWidget);
      expect(find.text('موقعي الحالي'), findsNothing);
      await tester.tap(find.text('شوف أسعار المشوار'));
      await tester.tap(find.text('فيتو ماركت'));
      expect(bookings, 1);
      expect(market, 1);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('PHASE2_DESIGN/screens').create(recursive: true);
        await File(
          'PHASE2_DESIGN/screens/booking_component_${width.toInt()}_SYNTHETIC.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    });
    testWidgets('Render synthetic growth design at $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: RepaintBoundary(
            key: key,
            child: GrowthReferralScreen(service: ReviewGrowthService()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('PHASE2_DESIGN/screens').create(recursive: true);
        await File(
          'PHASE2_DESIGN/screens/referrals_${width.toInt()}_SYNTHETIC.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}
