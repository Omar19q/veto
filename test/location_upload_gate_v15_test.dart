import 'package:flutter_test/flutter_test.dart';
import '../lib/services/location_upload_gate_v15.dart';

void main() {
  test('movement throttle, jitter, freshness heartbeat and session reset', () {
    final gate = LocationUploadGateV15();
    final t = DateTime.utc(2026, 10, 7);
    expect(gate.shouldUpload(30, 31, t), isTrue);
    gate.committed(30, 31, t);
    expect(
      gate.shouldUpload(30.01, 31, t.add(const Duration(seconds: 4))),
      isFalse,
    );
    expect(
      gate.shouldUpload(30.00001, 31, t.add(const Duration(seconds: 14))),
      isFalse,
    );
    expect(
      gate.shouldUpload(30.0002, 31, t.add(const Duration(seconds: 5))),
      isTrue,
    );
    expect(
      gate.shouldUpload(30, 31, t.add(const Duration(seconds: 15))),
      isTrue,
    );
    gate.attempted(t.add(const Duration(seconds: 15)));
    expect(
      gate.shouldUpload(30.01, 31, t.add(const Duration(seconds: 19))),
      isFalse,
    );
    gate.reset();
    expect(gate.shouldUpload(30, 31, t), isTrue);
  });
}
