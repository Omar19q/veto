import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/widgets/extra_purchase_limit.dart';

void main() {
  test('Purchase amount accepts Egyptian Arabic digits and inclusive 500', () {
    expect(validateExtraPurchaseAmount(''), isNull);
    expect(validateExtraPurchaseAmount('500'), isNull);
    expect(validateExtraPurchaseAmount('٥٠٠٫٠٠'), isNull);
    expect(validateExtraPurchaseAmount('۴۹۹٫۹۹'), isNull);
    expect(normalizePurchaseAmount('١٢٫٥٠'), '12.50');
  });
  test(
    'Purchase amount rejects excess, nonfinite, negatives and invalid decimals',
    () {
      for (final value in [
        '500.01',
        '٥٠١',
        'NaN',
        'Infinity',
        '-1',
        '1e2',
        '1.234',
        '12,34',
      ]) {
        expect(validateExtraPurchaseAmount(value), isNotNull, reason: value);
      }
    },
  );
  testWidgets('Purchase banner is readable on a narrow screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: ExtraPurchaseLimitBanner(),
          ),
        ),
      ),
    );
    expect(
      find.text('الطلبات الإضافية يجب ألا تتجاوز 500 جنيه'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
