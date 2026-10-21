import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

LatLng interpolatePosition(LatLng from, LatLng to, double fraction) {
  final t = fraction.clamp(0.0, 1.0);
  final delta = ((to.longitude - from.longitude + 540) % 360) - 180;
  final lng = ((from.longitude + delta * t + 540) % 360) - 180;
  return LatLng(from.latitude + (to.latitude - from.latitude) * t, lng);
}

class RouteProjection {
  final LatLng point;
  final int segment;
  final double progressMeters;
  final double offRouteMeters;
  const RouteProjection(
    this.point,
    this.segment,
    this.progressMeters,
    this.offRouteMeters,
  );
}

class RouteProgress {
  final List<LatLng> points;
  final List<double> cumulative = [0];
  final Distance _distance = const Distance();
  RouteProgress(List<LatLng> source) : points = List.unmodifiable(source) {
    for (var i = 1; i < points.length; i++) {
      cumulative.add(cumulative.last + _distance(points[i - 1], points[i]));
    }
  }
  double get totalMeters => cumulative.last;

  RouteProjection project(LatLng position, {double minimumProgress = 0}) {
    if (points.length < 2) {
      throw StateError('route_requires_two_points');
    }
    var bestDistance = double.infinity;
    RouteProjection? best;
    final scale = math.cos(position.latitude * math.pi / 180);
    for (var i = 0; i < points.length - 1; i++) {
      if (cumulative[i + 1] < minimumProgress) continue;
      final a = points[i];
      final b = points[i + 1];
      final ax = (a.longitude - position.longitude) * scale;
      final ay = a.latitude - position.latitude;
      final bx = (b.longitude - position.longitude) * scale;
      final by = b.latitude - position.latitude;
      final dx = bx - ax;
      final dy = by - ay;
      final denominator = dx * dx + dy * dy;
      var t = denominator == 0
          ? 0.0
          : (-(ax * dx + ay * dy) / denominator).clamp(0.0, 1.0);
      final length = cumulative[i + 1] - cumulative[i];
      if (length > 0) {
        t = math.max(
          t,
          ((minimumProgress - cumulative[i]) / length).clamp(0.0, 1.0),
        );
      }
      final point = interpolatePosition(a, b, t);
      final distance = _distance(position, point);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = RouteProjection(point, i, cumulative[i] + length * t, distance);
      }
    }
    return best ??
        RouteProjection(
          points.last,
          points.length - 2,
          totalMeters,
          _distance(position, points.last),
        );
  }

  List<LatLng> remaining(RouteProjection projection) => [
    projection.point,
    ...points.skip(projection.segment + 1),
  ];
}
