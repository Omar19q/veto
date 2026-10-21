import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/services/scale_metrics_v15.dart';

void main() {
  test(
    'local metrics remain bounded and snapshots cannot mutate samples',
    () async {
      for (var i = 0; i < 150; i++) {
        await Future.value(i).observeScaleV15('test_bound');
      }
      final snap = ScaleMetricsV15.snapshot()['test_bound'] as Map;
      expect(snap['count'], 150);
      expect((snap['samples_ms'] as List).length, 128);
      (snap['samples_ms'] as List).clear();
      expect(
        (ScaleMetricsV15.snapshot()['test_bound']['samples_ms'] as List).length,
        128,
      );
      await Future.value({'success': false}).observeScaleV15('test_error');
      expect(ScaleMetricsV15.snapshot()['test_error']['errors'], 1);
    },
  );
}
