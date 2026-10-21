import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/presentation/admin/admin_banners_panel.dart';
import 'package:vetosanya/theme/admin_theme.dart';

void main() {
  for (final lang in ['ar', 'en']) {
    for (final dark in [false, true]) {
      testWidgets(
        'Admin banner retry, visibility and editor fit 320px $lang/$dark',
        (tester) async {
          tester.view.physicalSize = const Size(320, 720);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          AdminTheme.dark.value = dark;
          var fail = true, active = false, updates = 0;
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(lang),
              theme: AdminTheme.theme,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: Scaffold(
                body: AdminBannersPanel(
                  loadBanners: () async {
                    if (fail) throw StateError('network');
                    return [
                      {
                        'id': 'synthetic',
                        'title': 'SYNTHETIC • بانر تجريبي',
                        'is_active': active,
                        'action_type': 'none',
                      },
                    ];
                  },
                  setActive: (id, value) async {
                    active = value;
                    updates++;
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.textContaining(lang == 'ar' ? 'تعذر تحميل' : 'Could not load'),
            findsOneWidget,
          );
          fail = false;
          await tester.tap(find.byIcon(Icons.refresh));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(Switch));
          await tester.pumpAndSettle();
          expect(updates, 1);
          expect(active, true);
          await tester.tap(find.byIcon(Icons.edit_rounded));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  test('Admin primary action text meets WCAG contrast in both modes', () {
    for (final dark in [false, true]) {
      AdminTheme.dark.value = dark;
      final c = AdminTheme.theme.colorScheme;
      final a = c.primary.computeLuminance(),
          b = c.onPrimary.computeLuminance();
      expect(
        ((a > b ? a : b) + .05) / ((a > b ? b : a) + .05),
        greaterThan(4.5),
      );
    }
  });
}
