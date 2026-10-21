import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vetosanya/services/customer_location_state.dart';

void main() {
  final now = DateTime.utc(2026, 10, 13);
  Position fix({double accuracy = 10, double latitude = 30, int age = 0}) =>
      Position(
        longitude: 31,
        latitude: latitude,
        timestamp: now.subtract(Duration(seconds: age)),
        accuracy: accuracy,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
  test('Only finite, recent, accurate real fixes are usable', () {
    expect(CustomerLocationState.usable(fix(), now), isTrue);
    expect(CustomerLocationState.usable(fix(age: 61), now), isFalse);
    expect(CustomerLocationState.usable(fix(age: -6), now), isFalse);
    expect(CustomerLocationState.usable(fix(accuracy: 101), now), isFalse);
    expect(
      CustomerLocationState.usable(fix(latitude: double.nan), now),
      isFalse,
    );
    expect(CustomerLocationState.usable(fix(latitude: 91), now), isFalse);
  });
  test(
    'Unavailable GPS and denied permission have distinct manual-selection messages',
    () {
      final off = const CustomerLocationSnapshot(
        CustomerLocationPhase.gpsOff,
      ).message;
      final denied = const CustomerLocationSnapshot(
        CustomerLocationPhase.denied,
      ).message;
      expect(off, contains('خدمة الموقع مغلقة'));
      expect(denied, contains('إذن الموقع غير متاح'));
      expect(off, isNot(denied));
      CustomerLocationState.resolved(null);
      expect(
        CustomerLocationState.state.value.phase,
        CustomerLocationPhase.outsideCoverage,
      );
      CustomerLocationState.resolved('حدائق الأهرام');
      expect(CustomerLocationState.state.value.city, 'حدائق الأهرام');
    },
  );
}
