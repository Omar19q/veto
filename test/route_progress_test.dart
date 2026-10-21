import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:vetosanya/services/route_progress.dart';

void main() {
  test('Interpolation follows the shortest path across the date line', () {
    final middle = interpolatePosition(
      const LatLng(0, 179),
      const LatLng(0, -179),
      0.5,
    );
    expect(middle.latitude, 0);
    expect(middle.longitude.abs(), closeTo(180, 0.00001));
  });
  test('An interrupted animation can continue from the displayed position', () {
    final displayed = interpolatePosition(
      const LatLng(0, 0),
      const LatLng(0, 0.01),
      0.4,
    );
    final next = interpolatePosition(displayed, const LatLng(0, 0.02), 0);
    expect(next.longitude, closeTo(displayed.longitude, 0.00001));
  });
  test('GPS jitter cannot restore the consumed route', () {
    final route = RouteProgress([
      const LatLng(0, 0),
      const LatLng(0, 0.01),
      const LatLng(0, 0.02),
    ]);
    final first = route.project(const LatLng(0, 0.015));
    final jitter = route.project(
      const LatLng(0, 0.014),
      minimumProgress: first.progressMeters,
    );
    expect(jitter.progressMeters, greaterThanOrEqualTo(first.progressMeters));
    expect(route.remaining(jitter).first.longitude, closeTo(0.015, 0.00001));
  });
  test('Progress follows a bend rather than a direct start to end line', () {
    final route = RouteProgress([
      const LatLng(0, 0),
      const LatLng(0, 0.01),
      const LatLng(0.01, 0.01),
    ]);
    final projection = route.project(const LatLng(0.005, 0.01));
    expect(projection.segment, 1);
    expect(projection.progressMeters / route.totalMeters, closeTo(0.75, 0.005));
  });
  test('Duplicate route coordinates do not produce NaN', () {
    final route = RouteProgress([
      const LatLng(0, 0),
      const LatLng(0, 0),
      const LatLng(0, 0.01),
    ]);
    final projection = route.project(const LatLng(0, 0.005));
    expect(projection.progressMeters.isFinite, true);
    expect(projection.offRouteMeters.isFinite, true);
  });
  test('Arriving at the destination leaves zero remaining distance', () {
    final route = RouteProgress([const LatLng(0, 0), const LatLng(0, 0.01)]);
    final projection = route.project(const LatLng(0, 0.01));
    expect(route.totalMeters - projection.progressMeters, closeTo(0, 0.01));
  });
}
