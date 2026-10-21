import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/services/captain_application_v16.dart';

void main() {
  group('Private captain document boundary', () {
    test('rejects executable / SVG payloads even if caller names them JPEG', () {
      for (final content in ['<svg onload="alert(1)">', '<script>alert(1)</script>', 'MZ executable payload']) {
        expect(CaptainApplicationV16.imageType(Uint8List.fromList(content.codeUnits)), isNull);
      }
    });
    test('rejects truncated and empty file headers', () {
      expect(CaptainApplicationV16.imageType(Uint8List(0)), isNull);
      expect(CaptainApplicationV16.imageType(Uint8List.fromList([255,216,255])), isNull);
    });
    test('rejects image larger than Storage 8MiB limit before upload', () {
      final bytes = Uint8List(8388609)..setAll(0,[255,216,255]);
      expect(CaptainApplicationV16.imageType(bytes),isNull);
    });
    test('recognizes only supported raster signatures', () {
      final png=Uint8List(32)..setAll(0,[137,80,78,71,13,10,26,10]);
      final jpeg=Uint8List(32)..setAll(0,[255,216,255]);
      final webp=Uint8List(32)..setAll(0,'RIFF'.codeUnits)..setAll(8,'WEBP'.codeUnits);
      expect(CaptainApplicationV16.imageType(png),'image/png');
      expect(CaptainApplicationV16.imageType(jpeg),'image/jpeg');
      expect(CaptainApplicationV16.imageType(webp),'image/webp');
      final falseWebp=Uint8List(32)..setAll(0,'RIFF'.codeUnits)..setAll(8,'WAVE'.codeUnits);
      expect(CaptainApplicationV16.imageType(falseWebp),isNull);
    });
  });
}
