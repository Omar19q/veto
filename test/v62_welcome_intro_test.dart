import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/services/growth_service.dart';
import 'package:vetosanya/presentation/growth/growth_screens.dart';

void main() {
  testWidgets('V62 welcome shows name and invitation without trapping user', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = GrowthService(rpc: (name, params) async {
      if (name == 'growth_campaign_terms_v1') {
        return <String, dynamic>{'discounts': [50, 35, 15]};
      }
      return <String, dynamic>{'success': true};
    });
    await tester.pumpWidget(MaterialApp(locale: const Locale('ar'), home: Scaffold(
      body: GrowthGiftSheet(service: service),
    )));
    await tester.pumpAndSettle();
    expect(find.text('أهلًا بيك في فيتو ثانية!'), findsOneWidget);
    expect(find.text('تحب نناديك بإيه؟'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('المتابعة بدون كود'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'F123456');
    await tester.ensureVisible(find.text('تأكيد كود الدعوة'));
    await tester.tap(find.text('تأكيد كود الدعوة'));
    await tester.pumpAndSettle();
    expect(find.textContaining('كودك اتسجل بنجاح'), findsOneWidget);
    expect(find.text('3 فرص للتوفير حسب الاستحقاق'), findsOneWidget);
  });

  testWidgets('V62 unavailable invitations are not falsely advertised', (tester) async {
    final service = GrowthService(rpc: (_, __) async => <String,dynamic>{});
    await tester.pumpWidget(MaterialApp(locale: const Locale('ar'), home: Scaffold(
      body: GrowthGiftSheet(service: service, canUseCode: false),
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('تقدر تكتب الكود'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'تأكيد كود الدعوة'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField).last).enabled, isTrue);
    await tester.enterText(find.byType(TextField).last, 'F123456');
    expect(tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'تأكيد كود الدعوة')).onPressed, isNotNull);
  });
}
