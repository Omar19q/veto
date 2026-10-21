import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:vetosanya/theme/app_theme.dart';
import 'package:vetosanya/presentation/trip_booking_screen/widgets/extra_requests_field.dart';

void main() {
  test(
    'Product typography follows language; admin keeps its existing font',
    () {
      expect(AppTheme.darkTheme.textTheme.bodyMedium?.fontFamily, 'Cairo');
      for (final brightness in Brightness.values) {
        expect(
          AppTheme.productTheme(
            brightness,
            'ar',
          ).textTheme.bodyMedium?.fontFamily,
          'IBMPlexSansArabic',
        );
        expect(
          AppTheme.productTheme(
            brightness,
            'en',
          ).textTheme.bodyMedium?.fontFamily,
          'Inter',
        );
      }
    },
  );

  for (final language in ['ar', 'en']) {
    for (final brightness in Brightness.values) {
      for (final draft in ['', 'Customer original request / طلب العميل']) {
        testWidgets(
          '$language $brightness: ordinary booking is never blocked by extras introduction, draft=$draft',
          (tester) async {
            tester.view.physicalSize = const Size(320, 640);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final controller = TextEditingController(text: draft);
            await tester.pumpWidget(
              MaterialApp(
                locale: Locale(language),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                theme: AppTheme.productTheme(brightness, language),
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ExtraRequestsField(controller: controller),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.byType(Dialog), findsNothing);
            expect(find.byType(OutlinedButton), findsOneWidget);
            expect(controller.text, draft);
            expect(
              find.byType(TextField),
              draft.isEmpty ? findsNothing : findsOneWidget,
            );
            if (draft.isNotEmpty) {
              expect(
                tester.widget<TextField>(find.byType(TextField)).textDirection,
                language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
              );
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            controller.dispose();
          },
        );
      }
    }
  }
}
