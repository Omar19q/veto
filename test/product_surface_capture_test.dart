import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/presentation/home_screen/widgets/home_header_widget.dart';
import 'package:vetosanya/presentation/home_screen/widgets/product_home_panel.dart';
import 'package:vetosanya/theme/app_theme.dart';

// Export review images of real Flutter components with explicitly synthetic
// addresses. These are design evidence, not live booking or usability tests.
void main() {
  setUpAll(() async {
    await (FontLoader('Cairo')..addFont(rootBundle.load('assets/fonts/Cairo.ttf'))).load();
    await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final language in ['ar', 'en']) {
    for (final dark in [false, true]) {
      testWidgets('Capture home components $language/${dark ? 'dark' : 'light'}', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundary = GlobalKey();
        await tester.pumpWidget(MaterialApp(
          locale: Locale(language), theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate],
          home: RepaintBoundary(key: boundary, child: Scaffold(body: SafeArea(
            child: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16),
              child: Column(children: [
                HomeHeaderWidget(customerName: 'Synthetic User',
                  locationCaption: 'Synthetic saved address', walletBalance: 0,
                  completedTrips: 0, unreadCount: 0, onNotificationTap: () {}, onProfileTap: () {}),
                ProductHomePanel(customerId: 'synthetic', pickupCaption: 'Synthetic pickup',
                  loadAddresses: (_) async => [
                    {'label':'Home','display_address':'Synthetic home','latitude':30.0,'longitude':31.0,'is_default':true},
                    {'label':'Work','display_address':'Synthetic work','latitude':30.1,'longitude':31.1},
                  ], loadRecentTrips: (_) async => [], onMarket: () {}, onStart: (_, __) {}),
              ])),
            ),
          ))),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('PRODUCT_UX_DESIGN/screens/home_components_${language}_${dark ? 'dark' : 'light'}_SYNTHETIC.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      });
    }
  }
}
