import 'dart:math' as math;

/// GPS jitter is not movement. A bounded liveness heartbeat is still required
/// by dispatch's two-minute freshness rule, even for a stationary captain.
class LocationUploadGateV15 {
  DateTime? _last, _attempt;
  double? _lat, _lng;
  bool shouldUpload(double lat, double lng, DateTime now) {
    if (_attempt != null &&
        now.difference(_attempt!) < const Duration(seconds: 5))
      return false;
    if (_last == null) return true;
    final elapsed = now.difference(_last!);
    if (elapsed < const Duration(seconds: 5)) return false;
    if (elapsed >= const Duration(seconds: 15)) return true;
    const radians = math.pi / 180;
    final dLat = (lat - _lat!) * radians;
    final dLng = (lng - _lng!) * radians;
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat * radians) *
            math.cos(_lat! * radians) *
            math.pow(math.sin(dLng / 2), 2);
    final meters = 6371000 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
    return meters >= 15;
  }

  void attempted(DateTime now) {
    _attempt = now;
  }

  void committed(double lat, double lng, DateTime now) {
    _lat = lat;
    _lng = lng;
    _last = now;
  }

  void reset() {
    _last = null;
    _attempt = null;
    _lat = null;
    _lng = null;
  }
}
