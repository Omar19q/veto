import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/services/customer_profile_backend.dart';
import 'package:vetosanya/presentation/customer/customer_loyalty_panel_v29.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/theme/app_theme.dart';

class ProfileStub extends CustomerProfileBackend {
  String user = 'synthetic-a';
  final changes = StreamController<String?>.broadcast(sync: true);
  final saved = <List<String>>[];
  final names = <String>[];
  Completer<dynamic>? firstProfile;
  int profileCalls = 0;
  @override
  String? get accountId => user;
  @override
  Stream<String?> get accountChanges => changes.stream;
  @override
  Future<dynamic> profile() async {
    profileCalls++;
    if (profileCalls == 1 && firstProfile != null)
      return await firstProfile!.future;
    return {'completed_trips': 3, 'tier': 'Synthetic tier', 'frames': []};
  }

  @override
  Future<Map<String, dynamic>?> customer(String userId) async => {
    'id': userId,
    'full_name': userId,
  };
  @override
  Future<dynamic> preferences() async => {'interests': []};
  @override
  Future<void> savePreferences(List<String> values) async {
    saved.add(List.of(values));
  }

  @override
  Future<void> name(String id, String value) async {
    names.add('$id:$value');
  }

  void switchTo(String id) {
    user = id;
    changes.add(id);
  }
}

Widget app(ProfileStub backend, {String language = 'en', bool dark = false}) =>
    MaterialApp(
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      home: CustomerLoyaltyPanelV29(backend: backend),
    );
void main() {
  setUpAll(() async {
    await (FontLoader(
      'Cairo',
    )..addFont(rootBundle.load('assets/fonts/Cairo.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final language in ['ar', 'en'])
    for (final dark in [true, false]) {
      testWidgets(
        'Profile $language dark=$dark preserves canonical preference value at 320px',
        (tester) async {
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final backend = ProfileStub();
          addTearDown(backend.changes.close);
          final boundary = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: app(backend, language: language, dark: dark),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('synthetic-a'), findsOneWidget);
          await tester.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await render.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              'PRODUCT_UX_DESIGN/screens/customer_profile_${language}_${dark ? 'dark' : 'light'}_320_SYNTHETIC.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          final label = language == 'en' ? 'Quiet ride' : 'أفضل الهدوء';
          await tester.ensureVisible(find.text(label));
          await tester.pumpAndSettle();
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          expect(backend.saved.single, ['أفضل الهدوء']);
          if (language == 'en') expect(find.text('ملفي الشخصي'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  testWidgets(
    'Switching account closes previous-account name editor without saving to new account',
    (tester) async {
      final backend = ProfileStub();
      addTearDown(backend.changes.close);
      await tester.pumpWidget(app(backend));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit name').last);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Old-account edit');
      backend.switchTo('synthetic-b');
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(backend.names, isEmpty);
      expect(find.text('synthetic-a'), findsNothing);
      expect(find.text('synthetic-b'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Delayed previous-account profile cannot overwrite current account',
    (tester) async {
      final backend = ProfileStub()..firstProfile = Completer<dynamic>();
      addTearDown(backend.changes.close);
      await tester.pumpWidget(app(backend));
      await tester.pump();
      backend.switchTo('synthetic-b');
      await tester.pumpAndSettle();
      backend.firstProfile!.complete({
        'name': 'previous-account private name',
        'frames': [],
      });
      await tester.pumpAndSettle();
      expect(find.text('synthetic-b'), findsOneWidget);
      expect(find.text('synthetic-a'), findsNothing);
      expect(find.text('previous-account private name'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
