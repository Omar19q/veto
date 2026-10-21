import 'dart:async';

/// Local bounded counters only: no IDs, coordinates, tokens or message bodies.
/// Read snapshot from a debug session; no extra backend writes per operation.
class ScaleMetricsV15 {
  static final _rows = <String, Map<String, dynamic>>{};
  static void record(String operation, int milliseconds, bool success) {
    final row = _rows.putIfAbsent(
      operation,
      () => {'count': 0, 'errors': 0, 'samples_ms': <int>[]},
    );
    row['count'] = (row['count'] as int) + 1;
    if (!success) row['errors'] = (row['errors'] as int) + 1;
    final samples = row['samples_ms'] as List<int>;
    if (samples.length >= 128) samples.removeAt(0);
    samples.add(milliseconds);
  }

  static Map<String, dynamic> snapshot() => {
    for (final e in _rows.entries)
      e.key: {
        'count': e.value['count'],
        'errors': e.value['errors'],
        'samples_ms': List<int>.of(e.value['samples_ms'] as List<int>),
      },
  };
}

extension ScaleFutureV15<T> on Future<T> {
  Future<T> observeScaleV15(String operation) async {
    final clock = Stopwatch()..start();
    var success = false;
    try {
      final result = await this;
      success = !(result is Map && result['success'] == false);
      return result;
    } finally {
      ScaleMetricsV15.record(operation, clock.elapsedMilliseconds, success);
    }
  }
}
