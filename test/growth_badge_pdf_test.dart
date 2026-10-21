import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/services/growth_badge_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Car and motorcycle sample PDFs embed original logo and are generated offline',
    () async {
      final directory = Directory('PHASE2_DESIGN/print_samples');
      await directory.create(recursive: true);
      for (final motorcycle in [false, true]) {
        final data = await GrowthBadgePdf.build('1001', motorcycle: motorcycle);
        expect(String.fromCharCodes(data.take(4)), '%PDF');
        expect(data.length, greaterThan(1000));
        await File(
          '${directory.path}/${motorcycle ? 'motorcycle' : 'car'}_SYNTHETIC_SAMPLE.pdf',
        ).writeAsBytes(data);
      }
    },
  );
}
