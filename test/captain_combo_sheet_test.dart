import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/widgets/captain_combo_introduction.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    testWidgets(
      'Combo sheet fits $size and saves acknowledgement before closing',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var saved = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CaptainComboSheet(
                onAcknowledge: () async {
                  saved = true;
                },
              ),
            ),
          ),
        );
        expect(find.text('يا بطل، دي رحلة (هاتلي معاك) 🛍️'), findsOneWidget);
        expect(find.text('خطواتك:'), findsOneWidget);
        await tester.ensureVisible(find.text('فهمت، يلا بينا'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('فهمت، يلا بينا'));
        await tester.pumpAndSettle();
        expect(saved, true);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Failed acknowledgement keeps sheet open and supports retry', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CaptainComboSheet(
            onAcknowledge: () async {
              attempts++;
              throw StateError('offline');
            },
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('فهمت، يلا بينا'));
    await tester.tap(find.text('فهمت، يلا بينا'));
    await tester.pumpAndSettle();
    expect(attempts, 1);
    expect(
      find.text('تعذر حفظ التأكيد. تأكد من الإنترنت وحاول تاني.'),
      findsOneWidget,
    );
    expect(find.text('فهمت، يلا بينا'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
