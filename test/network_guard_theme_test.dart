import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/services/network_guard.dart';
import 'package:vetosanya/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('NetworkGuard card adopts pure white and slate in light mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        themeMode: ThemeMode.light,
        theme: ThemeData.light(),
        home: const NetworkGuard(child: SizedBox()),
      ),
    );
    await tester.pump();

    expect(find.text('إعادة المحاولة'), findsOneWidget);

    final cardContainer = tester.widget<Container>(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).borderRadius ==
                BorderRadius.circular(22),
      ),
    );
    final decoration = cardContainer.decoration as BoxDecoration;
    expect(decoration.color, Colors.white);
    expect((decoration.border! as Border).top.color, const Color(0xFFE2E8F0));

    final titleText = tester.widget<Text>(find.text('جاري فحص الاتصال'));
    expect(titleText.style?.color, const Color(0xFF0B0F1A));
  });

  testWidgets('NetworkGuard card retains dark navy and gold in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData.dark(),
        home: const NetworkGuard(child: SizedBox()),
      ),
    );
    await tester.pump();

    expect(find.text('إعادة المحاولة'), findsOneWidget);

    final cardContainer = tester.widget<Container>(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).borderRadius ==
                BorderRadius.circular(22),
      ),
    );
    final decoration = cardContainer.decoration as BoxDecoration;
    expect(decoration.color, AppTheme.surface);
    expect((decoration.border! as Border).top.color, AppTheme.cardBorder);

    final titleText = tester.widget<Text>(find.text('جاري فحص الاتصال'));
    expect(titleText.style?.color, AppTheme.textPrimary);
  });
}
