import 'dart:convert';
import 'package:dio/dio.dart';

class RouteResult {
  final double distanceKm;
  final double durationMinutes;
  final List<List<double>> routePoints;

  const RouteResult({
    required this.distanceKm,
    required this.durationMinutes,
    required this.routePoints,
  });
}

class RoutingService {
  RoutingService._();
  static final RoutingService instance = RoutingService._();

  static const _baseUrl = String.fromEnvironment(
    'OSRM_ROUTING_URL',
    defaultValue: 'https://router.project-osrm.org',
  );
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 12),
      headers: const {'Accept': 'application/json'},
    ),
  );

  Future<RouteResult?> getRouteWithGeometry({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    if (!_validCoord(fromLat, fromLng) || !_validCoord(toLat, toLng)) {
      return null;
    }

    try {
      // OSRM expects longitude,latitude.
      final url =
          '${_baseUrl.replaceAll(RegExp(r"/+$"), "")}/route/v1/driving/'
          '$fromLng,$fromLat;$toLng,$toLat';

      final response = await _dio.get(
        url,
        queryParameters: const {
          'overview': 'full',
          'geometries': 'geojson',
          'steps': 'false',
          'alternatives': 'false',
        },
      );

      if (response.statusCode != 200 || response.data == null) {
        return null;
      }

      final data = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;

      if (data is! Map || data['code'] != 'Ok') {
        return null;
      }

      final routes = data['routes'];
      if (routes is! List || routes.isEmpty) {
        return null;
      }

      final route = routes.first;
      final distanceMeters = (route['distance'] as num?)?.toDouble();
      final durationSeconds = (route['duration'] as num?)?.toDouble();

      if (distanceMeters == null || durationSeconds == null) {
        return null;
      }

      final geometry = route['geometry'];
      final coordinates = geometry is Map ? geometry['coordinates'] : null;

      final points = <List<double>>[];
      if (coordinates is List) {
        for (final item in coordinates) {
          if (item is List && item.length >= 2) {
            final lng = (item[0] as num?)?.toDouble();
            final lat = (item[1] as num?)?.toDouble();
            if (lat != null && lng != null) {
              points.add([lat, lng]);
            }
          }
        }
      }

      return RouteResult(
        distanceKm: distanceMeters / 1000.0,
        durationMinutes: durationSeconds / 60.0,
        routePoints: points,
      );
    } catch (_) {
      return null;
    }
  }

  bool _validCoord(double lat, double lng) {
    return lat.isFinite &&
        lng.isFinite &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180;
  }
}
