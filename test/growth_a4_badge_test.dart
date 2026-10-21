import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/services/growth_badge_pdf.dart';
import 'package:pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Print master is A4 landscape, not portrait', () {
    expect(GrowthBadgePdf.a4Landscape.width, greaterThan(GrowthBadgePdf.a4Landscape.height));
    expect(GrowthBadgePdf.a4Landscape.width, closeTo(297 * PdfPageFormat.mm, 0.1));
    expect(GrowthBadgePdf.a4Landscape.height, closeTo(210 * PdfPageFormat.mm, 0.1));
  });
  test(
    'A4 bilingual badge supports five digit captain codes; motorcycle cut-out remains safe',
    () async {
      // The advertising master is landscape even for the small motorcycle cut-out.
      expect(GrowthBadgePdf.a4Landscape.width, greaterThan(GrowthBadgePdf.a4Landscape.height));
      final dir = Directory('PRODUCT_UX_DESIGN/print_a4');
      await dir.create(recursive: true);
      for (final motorcycle in [false, true]) {
        final bytes = await GrowthBadgePdf.buildA4(
          '10001',
          motorcycle: motorcycle,
          sample: true,
        );
        expect(String.fromCharCodes(bytes.take(4)), '%PDF');
        expect(bytes.length, greaterThan(2000));
        await File(
          '${dir.path}/${motorcycle ? 'motorcycle' : 'car'}_A4_SAMPLE_10001.pdf',
        ).writeAsBytes(bytes);
      }
    },
  );
  test(
    'A4 badge rejects fake or blank codes instead of printing a misleading referral',
    () async {
      for (final code in ['', '1000', 'abc', '10001;', 'C123']) {
        await expectLater(GrowthBadgePdf.buildA4(code), throwsArgumentError);
      }
    },
  );
}
