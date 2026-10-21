import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/services/growth_service.dart';
import 'package:vetosanya/presentation/growth/growth_screens.dart';

void main() {
  testWidgets('Paused invitations still permit typing without promising an award',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = GrowthService(rpc: (name, args) async {
      if (name == 'growth_claim_onboarding_v1') return <String, dynamic>{'show': false};
      return <String, dynamic>{};
    });
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      home: Scaffold(body: GrowthGiftSheet(service: service, canUseCode: false)),
    ));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField).last).enabled, isTrue);
    await tester.enterText(find.byType(TextField).last, 'F123456');
    await tester.ensureVisible(find.text('تأكيد كود الدعوة'));
    await tester.tap(find.text('تأكيد كود الدعوة'));
    await tester.pumpAndSettle();
    expect(find.textContaining('تفعيله متوقف حاليًا'), findsOneWidget);
    expect(find.textContaining('كودك اتسجل بنجاح'), findsNothing);
  });

  test('Server duplicate decision is not a fresh reward', () async {
    final service = GrowthService(rpc: (name, args) async =>
      <String, dynamic>{'success': true, 'already_decided': true});
    final result = await service.bindDecision('F123456');
    expect(result['already_decided'], isTrue);
    await expectLater(service.bind('F123456'),
      throwsA(isA<StateError>()));
  });
}
