import 'dart:async';
import 'scale_metrics_v15.dart';
import 'package:latlong2/latlong.dart';
import 'supabase_service.dart';

class PricingZone {
  final Map<String, dynamic> row;
  PricingZone(this.row);
  String get id => row['id'].toString();
  String get name => row['name'].toString();
  bool get global => row['is_global'] == true;
  bool get active => row['is_active'] == true;
  String get iconKey => (row['icon_key']?.toString().trim().isNotEmpty ?? false)
      ? row['icon_key'].toString().trim()
      : 'city';
  double number(String key) => double.tryParse('${row[key]}') ?? 0;
  double get multiplier => number('multiplier');
  LatLng? get center => row['latitude'] == null || row['longitude'] == null
      ? null
      : LatLng(number('latitude'), number('longitude'));
  List<LatLng> get ring {
    final geometry = row['geojson'];
    if (geometry is! Map || geometry['coordinates'] is! List) return [];
    final rings = geometry['coordinates'] as List;
    if (rings.isEmpty || rings.first is! List) return [];
    return (rings.first as List)
        .whereType<List>()
        .where((p) => p.length >= 2)
        .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
        .toList();
  }

  bool contains(double lat, double lng) {
    if (global || !active) return false;
    final polygon = ring;
    if (polygon.length < 3) return false;
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final yi = polygon[i].latitude;
      final xi = polygon[i].longitude;
      final yj = polygon[j].latitude;
      final xj = polygon[j].longitude;
      final dy = yj - yi;
      final denominator = dy.abs() < 1e-12 ? (dy < 0 ? -1e-12 : 1e-12) : dy;
      final crosses =
          ((yi > lat) != (yj > lat)) &&
          (lng < (xj - xi) * (lat - yi) / denominator + xi);
      if (crosses) inside = !inside;
    }
    return inside;
  }
}

class ZonePricingService {
  static final instance = ZonePricingService();
  final db = SupabaseService.instance.client;
  Future<List<PricingZone>> zones() async {
    dynamic result;
    try {
      result = await db.rpc('list_pricing_zones_v8');
    } catch (_) {
      result = await db.rpc('list_pricing_zones_v4');
    }
    if (result is! List) throw StateError('invalid_zones_response');
    return result
        .whereType<Map>()
        .map((r) => PricingZone(Map<String, dynamic>.from(r)))
        .toList();
  }

  /// Resolves the customer-visible city using the same PostGIS boundaries and
  /// priority order used by the backend. A local polygon fallback keeps V8
  /// usable before the migration is installed, without affecting pricing.
  Future<PricingZone?> resolveCity(double lat, double lng) async {
    try {
      final result = await db.rpc(
        'resolve_customer_city_v8',
        params: {'p_lat': lat, 'p_lng': lng},
      );
      if (result == null) return null;
      if (result is Map) {
        final row = Map<String, dynamic>.from(result);
        if (row.isEmpty) return null;
        return PricingZone(row);
      }
    } catch (_) {
      // V8 SQL may not have been installed yet; use the existing zone list.
    }

    final all = await zones();
    for (final zone in all) {
      if (!zone.global && zone.active && zone.contains(lat, lng)) return zone;
    }
    return null;
  }

  Future<Map<String, dynamic>> quote({
    required String service,
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    String? timeoutRetryTripId,
    String? categoryId,
  }) async {
    final result = await db.functions
        .invoke(
          categoryId==null ? 'route-price-quote' : 'route-price-quote-v3',
          body: {
            'service_type': service,
            if (categoryId != null) 'ride_category_id': categoryId,
            'pickup_lat': fromLat,
            'pickup_lng': fromLng,
            'destination_lat': toLat,
            'destination_lng': toLng,
            if (timeoutRetryTripId != null) 'timeout_retry_trip_id': timeoutRetryTripId,
          },
        )
        .observeScaleV15('pricing_quote');
    if (result.status != 200 ||
        result.data is! Map ||
        (result.data as Map)['id'] == null) {
      throw StateError(
        result.data is Map ? '${(result.data as Map)['error'] ?? 'quote_unavailable'}' : 'quote_unavailable',
      );
    }
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<void> save({
    String? id,
    required String name,
    required List<LatLng> vertices,
    required bool global,
    required double km,
    required double opening,
    required double waiting,
    required int priority,
    required bool active,
    String iconKey = 'city',
  }) async {
    final coordinates = vertices.map((p) => [p.longitude, p.latitude]).toList();
    if (!global && coordinates.length < 3)
      throw StateError('حدد ٣ نقاط على الأقل للمنطقة');
    if (!global &&
        (coordinates.first[0] != coordinates.last[0] ||
            coordinates.first[1] != coordinates.last[1]))
      coordinates.add(List<double>.from(coordinates.first));
    try {
      await db.rpc(
        'admin_save_pricing_zone_v8',
        params: {
          'p_id': id,
          'p_name': name,
          'p_geojson': global
              ? null
              : {
                  'type': 'Polygon',
                  'coordinates': [coordinates],
                },
          'p_global': global,
          'p_per_km': km,
          'p_opening': opening,
          'p_waiting': waiting,
          'p_priority': priority,
          'p_active': active,
          'p_icon_key': iconKey,
        },
      );
    } catch (_) {
      // Backward-compatible fallback until the V8 migration is installed.
      await db.rpc(
        'admin_save_pricing_zone',
        params: {
          'p_id': id,
          'p_name': name,
          'p_geojson': global
              ? null
              : {
                  'type': 'Polygon',
                  'coordinates': [coordinates],
                },
          'p_global': global,
          'p_per_km': km,
          'p_opening': opening,
          'p_waiting': waiting,
          'p_priority': priority,
          'p_active': active,
        },
      );
    }
  }

  // Read-only aggregated demand. Never changes a trip's price or accounting.
  Future<List<Map<String, dynamic>>> activeDemandAlerts() async {
    try {
      final result = await db.rpc('v35_hot_zones').timeout(
        const Duration(seconds: 8),
      );
      if (result is! List) return const [];
      return result.whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (_) {
      // V35 SQL is optional until deployed; no guessed demand figures.
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> serviceTariffs() async {
    final result = await db.rpc('admin_list_zone_service_tariffs_v28');
    if (result is! List) throw StateError('invalid_tariffs');
    return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> saveServiceTariff({
    required String zoneId, required String service,
    required double minimum, required double opening,
    required double km, required double waiting,
  }) async {
    await db.rpc('admin_save_zone_service_tariff_v28', params: {
      'p_zone_id': zoneId, 'p_service': service,
      'p_minimum': minimum, 'p_opening': opening,
      'p_per_km': km, 'p_waiting': waiting,
    });
  }

  Future<void> commission(String captainId, double? percent) => db.rpc(
    'admin_set_custom_commission',
    params: {'p_captain_id': captainId, 'p_percent': percent},
  );
}
