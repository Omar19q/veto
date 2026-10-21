import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/theme/app_theme.dart';
import 'package:vetosanya/widgets/customer_identity_v29.dart';

void main() {
  Widget app(
    String id,
    Future<Map<String, dynamic>?> Function(String) load, {
    String language = 'en',
    bool dark = false,
  }) => MaterialApp(
    locale: Locale(language),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
    home: Scaffold(
      body: CaptainCustomerBadgeV29(
        key: const ValueKey('badge'),
        tripId: id,
        customerName: 'Customer $id',
        loadBadge: load,
      ),
    ),
  );
  testWidgets(
    'Previous trip badge disappears while next authorized-trip read is pending',
    (tester) async {
      final pending = Completer<Map<String, dynamic>?>();
      Future<Map<String, dynamic>?> load(String id) async {
        if (id == 'a')
          return {
            'frame_title': 'Previous private frame',
            'interests': ['أفضل الهدوء'],
          };
        return await pending.future;
      }

      await tester.pumpWidget(app('a', load));
      await tester.pumpAndSettle();
      expect(find.text('Previous private frame'), findsOneWidget);
      await tester.pumpWidget(app('b', load));
      await tester.pump();
      expect(find.text('Previous private frame'), findsNothing);
      expect(find.text('Quiet ride'), findsNothing);
      pending.complete({'frame_title': 'Current frame'});
      await tester.pumpAndSettle();
      expect(find.text('Current frame'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final language in ['ar', 'en'])
    for (final dark in [true, false]) {
      testWidgets(
        'Assigned customer preference $language dark=$dark fits at 320 and preserves unknown content',
        (tester) async {
          tester.view.physicalSize = const Size(320, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            app(
              'synthetic',
              (id) async => {
                'interests': ['أفضل الهدوء', 'وصف شخصي'],
                'frame_title': 'Synthetic frame',
              },
              language: language,
              dark: dark,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(
              language == 'en'
                  ? 'Quiet ride • وصف شخصي'
                  : 'أفضل الهدوء • وصف شخصي',
            ),
            findsOneWidget,
          );
          expect(find.text('Customer synthetic'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
}
