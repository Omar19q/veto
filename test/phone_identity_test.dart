import 'package:flutter_test/flutter_test.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:vetosanya/services/phone_identity.dart';

void main() {
  test(
    'Egypt local/international/Arabic digits resolve to same existing phone identity',
    () {
      for (final value in [
        '01012345678',
        '+201012345678',
        '٢٠١٠١٢٣٤٥٦٧٨',
        '٠١٠١٢٣٤٥٦٧٨',
      ]) {
        final identity = PhoneIdentity.parse(value, IsoCode.EG);
        expect(identity.e164, '+201012345678');
        expect(identity.legacyLookup, '01012345678');
      }
    },
  );
  test('Valid international mobiles canonical; malformed phones rejected', () {
    final identity = PhoneIdentity.parse('0501234567', IsoCode.SA);
    expect(identity.e164, '+966501234567');
    expect(identity.legacyLookup, identity.e164);
    expect(() => PhoneIdentity.parse('123', IsoCode.EG), throwsFormatException);
  });
  test('Only countries verified through the real manual OTP lifecycle are enabled', () {
    expect(PhoneIdentity.parse('0501234567', IsoCode.SA).verificationSupported, isTrue);
    expect(PhoneIdentity.supportsVerificationInput('+966501234567'), isTrue);
    expect(PhoneIdentity.supportsVerificationInput('+447400123456'), isTrue);
    expect(PhoneIdentity.supportsVerificationInput('+971501234567'), isTrue);
    expect(PhoneIdentity.supportsVerificationInput('+33612345678'), isFalse);
    expect(PhoneIdentity.supportsVerificationInput('01012345678'), isTrue);
    expect(PhoneIdentity.supportsVerificationInput('+201012345678'), isTrue);
    expect(PhoneIdentity.supportsVerificationInput('123'), isFalse);
  });
}
