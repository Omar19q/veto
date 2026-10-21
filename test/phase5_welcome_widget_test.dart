import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/services/growth_service.dart';
import 'package:vetosanya/presentation/growth/growth_screens.dart';

void main() {
  for (final size in const [Size(320, 620), Size(390, 720)]) {
    testWidgets('welcome offer shows code + Skip at ${size.width}px', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = GrowthService(rpc: (name, params) async => <String, dynamic>{});
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        home: Scaffold(body: GrowthGiftSheet(service: service)),
      ));
      await tester.pumpAndSettle();
      expect(find.text('أهلًا بيك في فيتو ثانية!'), findsOneWidget);
      expect(find.text('المتابعة بدون كود'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('تأكيد كود الدعوة'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'F123456');
      await tester.pumpAndSettle();
      expect(find.text('صاحبك باعتلك مفاجأة 🎁'), findsOneWidget);
    });
  }
}
