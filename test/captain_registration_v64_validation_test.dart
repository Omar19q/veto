import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/services/captain_application_v16.dart';

void main() {
  test('Egyptian ID yields a valid date, not a typed guess', () {
    final birth = CaptainApplicationV16.birthDateFromNationalId('29203211234567');
    expect(birth?.year, 1992);
    expect(birth?.month, 3);
    expect(birth?.day, 21);
    expect(CaptainApplicationV16.birthDateFromNationalId('29902311234567'), isNull);
    expect(CaptainApplicationV16.birthDateFromNationalId('29202311234567'), isNull);
    expect(CaptainApplicationV16.birthDateFromNationalId('too-short'), isNull);
  });

  test('Adults and minors are checked against current date', () {
    expect(CaptainApplicationV16.isAdult(DateTime(2000, 6, 1), DateTime(2026, 10, 15)), isTrue);
    expect(CaptainApplicationV16.isAdult(DateTime(2009, 6, 1), DateTime(2026, 10, 15)), isFalse);
    expect(CaptainApplicationV16.isAdult(DateTime(2008, 10, 15), DateTime(2026, 10, 15)), isTrue);
  });

  test('Missing 8th document is named precisely', () {
    const docs = ['portrait', 'id_front', 'id_back', 'license_front',
      'license_back', 'vehicle_front', 'vehicle_back'];
    expect(CaptainApplicationV16.missingDocuments(docs), ['vehicle_photo']);
    expect(CaptainApplicationV16.missingDocuments([...docs, 'vehicle_photo']), isEmpty);
  });
}
