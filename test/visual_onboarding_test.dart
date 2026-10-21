import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../lib/presentation/onboarding/onboarding_screen.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    testWidgets('Visual onboarding pages fit $size and next reaches start button', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
      await tester.pumpAndSettle();
      expect(find.text('اطلب مشوارك بسهولة'), findsOneWidget);
      expect(find.byType(SvgPicture), findsWidgets);
      expect(find.text('تخطي'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('التالي'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(find.text('ابدأ الآن'), findsOneWidget);
      expect(find.text('ادفع كاش أو محفظة'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
