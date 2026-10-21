import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/presentation/categories/admin_categories_screen.dart';
import 'package:vetosanya/presentation/categories/captain_categories_screen.dart';
import 'package:vetosanya/theme/app_theme.dart';
import 'v3_category_layout_test.dart' show categories;

class ControlHttp extends http.BaseClient {
  final requests = <String>[];
  final mutations = <Map<String, dynamic>>[];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request.url.path);
    if (request.url.host != '127.0.0.1')
      throw StateError('Nonlocal UI test endpoint refused');
    dynamic data = [];
    if (request.url.path.endsWith('v3_my_categories'))
      data = [
        for (var i = 0; i < categories.length; i++)
          {
            ...categories[i],
            'authorized': i < 3,
            'reason': 'SYNTHETIC qualification review',
          },
      ];
    if (request.url.path.endsWith('v3_admin_category_data'))
      data = {
        'categories': categories,
        'promises': [
          {
            'id': 'quiet',
            'name_ar': 'مشوار هادي',
            'name_en': 'Quiet ride',
            'enabled': true,
          },
        ],
        'prices': [],
        'zones': [],
        'approvals': [],
        'captains': [],
        'audit': [],
      };
    if (request.url.path.endsWith('v3_admin_save')) {
      mutations.add(jsonDecode((request as http.Request).body));
      data = {'success': true};
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(data))),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}

void main() {
  final api = ControlHttp();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:54321',
      anonKey: 'SYNTHETIC-LOCAL-UI',
      httpClient: api,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        persistSession: false,
      ),
    );
    for (final f in [
      ('IBMPlexSansArabic', 'assets/fonts/IBMPlexSansArabic-Regular.ttf'),
      ('Inter', 'assets/fonts/Inter-Variable.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ])
      await (FontLoader(f.$1)..addFont(rootBundle.load(f.$2))).load();
  });
  tearDownAll(() async {
    await Supabase.instance.dispose();
    api.close();
  });
  for (final admin in [false, true])
    for (final width in [320.0, 360.0, 390.0, 430.0])
      for (final lang in ['ar', 'en'])
        for (final dark in [false, true])
          for (final scale in [1.0, 2.0]) {
            testWidgets(
              '${admin ? 'Admin' : 'Captain'} category controls $width $lang dark=$dark scale=$scale',
              (tester) async {
                tester.view.physicalSize = Size(width, 700);
                tester.view.devicePixelRatio = 1;
                addTearDown(tester.view.resetPhysicalSize);
                addTearDown(tester.view.resetDevicePixelRatio);
                final key = GlobalKey();
                await tester.pumpWidget(
                  MaterialApp(
                    locale: Locale(lang),
                    supportedLocales: AppLocalizations.supportedLocales,
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    theme: AppTheme.productTheme(
                      dark ? Brightness.dark : Brightness.light,
                      lang,
                    ),
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                    home: RepaintBoundary(
                      key: key,
                      child: admin
                          ? const AdminCategoriesScreen()
                          : const CaptainCategoriesScreen(),
                    ),
                  ),
                );
                for (
                  var i = 0;
                  i < 40 &&
                      find.text('VETO Economy').evaluate().isEmpty &&
                      find.text('فيتو اقتصادي').evaluate().isEmpty;
                  i++
                ) {
                  await tester.runAsync(
                    () =>
                        Future<void>.delayed(const Duration(milliseconds: 10)),
                  );
                  await tester.pump(const Duration(milliseconds: 20));
                }
                await tester.pumpAndSettle();
                if (find
                    .text(lang == 'ar' ? 'فيتو اقتصادي' : 'VETO Economy')
                    .evaluate()
                    .isEmpty)
                  debugPrint(
                    'CONTROL DIAGNOSTIC requests=${api.requests}, text=${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList()}',
                  );
                expect(tester.takeException(), isNull);
                expect(
                  find.text(lang == 'ar' ? 'فيتو اقتصادي' : 'VETO Economy'),
                  findsOneWidget,
                );
                if (width == 390 && scale == 1)
                  await tester.runAsync(() async {
                    final picture =
                        await (key.currentContext!.findRenderObject()!
                                as RenderRepaintBoundary)
                            .toImage(pixelRatio: 2);
                    final bytes = await picture.toByteData(
                      format: ui.ImageByteFormat.png,
                    );
                    final file = File(
                      'verification/previews/${admin ? 'admin' : 'captain'}_categories_${lang}_${dark ? 'dark' : 'light'}_SYNTHETIC.png',
                    );
                    await file.parent.create(recursive: true);
                    await file.writeAsBytes(bytes!.buffer.asUint8List());
                    picture.dispose();
                  });
                await tester.drag(
                  find.byType(ListView).first,
                  const Offset(0, -450),
                );
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
                await tester.pumpWidget(const SizedBox.shrink());
              },
            );
          }
  for (final lang in ['ar', 'en'])
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Admin price dialog accepts local digits at 320 $lang scale=$scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final key = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: MaterialApp(
                locale: Locale(lang),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                theme: AppTheme.productTheme(Brightness.light, lang),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: const AdminCategoriesScreen(),
              ),
            ),
          );
          for (
            var i = 0;
            i < 60 &&
                find
                    .text(
                      lang == 'ar' ? 'الأسعار والمناطق' : 'Prices and zones',
                    )
                    .evaluate()
                    .isEmpty;
            i++
          ) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump(const Duration(milliseconds: 20));
          }
          await tester.pumpAndSettle();
          await tester.tap(
            find
                .text(lang == 'ar' ? 'الأسعار والمناطق' : 'Prices and zones')
                .first,
          );
          await tester.pumpAndSettle();
          final values = lang == 'ar'
              ? ['٢٢', '٧٫٥', '٣٥', '٢', '٤']
              : ['22', '7.5', '35', '2', '4'];
          for (var i = 0; i < values.length; i++) {
            await tester.ensureVisible(find.byType(TextField).at(i));
            await tester.enterText(find.byType(TextField).at(i), values[i]);
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (scale == 2)
            await tester.runAsync(() async {
              final image =
                  await (key.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary)
                      .toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final f = File(
                'verification/previews/admin_price_${lang}_320_scale2_SYNTHETIC.png',
              );
              await f.parent.create(recursive: true);
              await f.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          final count = api.mutations.length;
          await tester.tap(
            find.text(lang == 'ar' ? 'حفظ السعر' : 'Save price'),
          );
          for (var i = 0; i < 60 && api.mutations.length == count; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump(const Duration(milliseconds: 20));
          }
          expect(api.mutations.last['p_entity'], 'price');
          expect(api.mutations.last['p_value']['per_km'], 7.5);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
}
