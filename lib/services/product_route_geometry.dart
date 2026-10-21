class ProductRouteGeometry {
  const ProductRouteGeometry(this.points);
  final List<List<double>> points;
  static ProductRouteGeometry? parse(dynamic value) {
    if (value is! Map) return null;
    final distance = value['distance_km'],
        duration = value['duration_minutes'],
        geometry = value['geometry'];
    if (distance is! num ||
        duration is! num ||
        !distance.isFinite ||
        !duration.isFinite ||
        distance <= 0 ||
        duration <= 0 ||
        geometry is! Map)
      return null;
    final coordinates = geometry['coordinates'];
    final lines = geometry['type'] == 'LineString'
        ? [coordinates]
        : geometry['type'] == 'MultiLineString'
        ? coordinates
        : null;
    if (lines is! List) return null;
    final points = <List<double>>[];
    for (final line in lines) {
      if (line is! List) return null;
      for (final p in line) {
        if (p is! List || p.length < 2 || p[0] is! num || p[1] is! num)
          return null;
        final lng = (p[0] as num).toDouble(), lat = (p[1] as num).toDouble();
        if (!lat.isFinite || !lng.isFinite || lat.abs() > 90 || lng.abs() > 180)
          return null;
        if (points.length >= 20000) return null;
        points.add([lat, lng]);
      }
    }
    return points.length >= 2 ? ProductRouteGeometry(points) : null;
  }
}
