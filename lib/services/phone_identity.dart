import 'package:phone_numbers_parser/phone_numbers_parser.dart';

class PhoneIdentity {
  const PhoneIdentity({
    required this.e164,
    required this.legacyLookup,
    required this.iso,
  });
  final String e164, legacyLookup;
  final IsoCode iso;
  // Expand only after the corresponding server OTP/account-role lifecycle has
  // passed integration verification. A valid number alone is not support.
  static const verifiedCountries = <IsoCode>{
    IsoCode.EG,
    IsoCode.GB,
    IsoCode.SA,
    IsoCode.AE,
  };
  bool get verificationSupported => verifiedCountries.contains(iso);
  static bool supportsVerificationInput(String input) {
    try {
      return parse(input, IsoCode.EG).verificationSupported;
    } catch (_) {
      return false;
    }
  }

  static String normalizeDigits(String input) => String.fromCharCodes(
    input.runes.map(
      (r) => r >= 0x660 && r <= 0x669
          ? r - 0x660 + 48
          : r >= 0x6f0 && r <= 0x6f9
          ? r - 0x6f0 + 48
          : r,
    ),
  );
  static String lookup(String input) => parse(input, IsoCode.EG).legacyLookup;
  static PhoneIdentity parse(String input, IsoCode country) {
    var normalized = normalizeDigits(input).trim();
    if (normalized.startsWith('00')) normalized = '+${normalized.substring(2)}';
    final parsed = PhoneNumber.parse(normalized, callerCountry: country);
    if (!parsed.isValid(type: PhoneNumberType.mobile))
      throw const FormatException('invalid_phone');
    final canonical = parsed.international;
    final legacy = parsed.isoCode == IsoCode.EG ? '0${parsed.nsn}' : canonical;
    return PhoneIdentity(
      e164: canonical,
      legacyLookup: legacy,
      iso: parsed.isoCode,
    );
  }
}
