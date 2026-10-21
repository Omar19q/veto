import 'package:latlong2/latlong.dart';
import 'growth_service.dart';
import 'supabase_service.dart';
import 'product_route_geometry.dart';
import 'map_data_gateway.dart';

class ConfirmedMapPoint extends LatLng {
  ConfirmedMapPoint(double lat, double lng, this.address) : super(lat, lng);
  final String address;
}

class GeocodedAddress {
  const GeocodedAddress(this.latitude, this.longitude, this.address);
  final double latitude, longitude;
  final String address;
  static GeocodedAddress? parse(Map row) {
    final lat = row['latitude'],
        lng = row['longitude'],
        address = row['address'];
    if (lat is! num ||
        lng is! num ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180 ||
        address is! String ||
        address.trim().isEmpty)
      return null;
    return GeocodedAddress(lat.toDouble(), lng.toDouble(), address.trim());
  }
}

typedef GeocodingInvoke = Future<dynamic> Function(Map<String, dynamic> body);

class ProductGeocodingService {
  ProductGeocodingService({GeocodingInvoke? invoke})
    : _invoke =
          MapDataGateway(geoapify: invoke ??
          ((body) async {
            if (!GrowthService.buildEnabled)
              throw StateError('isolated_geocoding_not_enabled');
            final result = await SupabaseService.instance.client.functions
                .invoke('product-geocoding', body: body);
            if (result.status != 200) throw StateError('geocoding_unavailable');
            return result.data;
          })).call;
  final GeocodingInvoke _invoke;
  final _cache = <String, GeocodedAddress?>{};
  Future<ProductRouteGeometry> route(
    double fromLat,
    double fromLng,
    double toLat,
    double toLng, {
    required String language,
  }) async {
    for (final p in [
      [fromLat, fromLng],
      [toLat, toLng],
    ]) {
      if (!p[0].isFinite ||
          !p[1].isFinite ||
          p[0].abs() > 90 ||
          p[1].abs() > 180)
        throw ArgumentError('invalid_coordinates');
    }
    final raw = await _invoke({
      'operation': 'route',
      'points': [
        [fromLat, fromLng],
        [toLat, toLng],
      ],
      'language': language,
    }).timeout(const Duration(seconds: 8));
    final result = ProductRouteGeometry.parse(raw);
    if (result == null) throw StateError('invalid_route_geometry');
    return result;
  }

  Future<GeocodedAddress?> reverse(
    double lat,
    double lng, {
    required String language,
  }) async {
    if (!lat.isFinite || !lng.isFinite || lat.abs() > 90 || lng.abs() > 180)
      throw ArgumentError('invalid_coordinates');
    final key = '$language:${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
    if (_cache.containsKey(key)) return _cache[key];
    final raw = await _invoke({
      'operation': 'reverse',
      'latitude': lat,
      'longitude': lng,
      'language': language,
    }).timeout(const Duration(seconds: 8));
    if (raw is! Map || raw['results'] is! List)
      throw StateError('invalid_geocoding_response');
    final parsed = (raw['results'] as List)
        .whereType<Map>()
        .map(GeocodedAddress.parse)
        .whereType<GeocodedAddress>();
    final result = parsed.firstOrNull;
    if (_cache.length >= 40) _cache.clear();
    _cache[key] = result;
    return result;
  }

  Future<List<GeocodedAddress>> search(
    String query, {
    required String language,
  }) async {
    if (query.trim().length < 2) return [];
    final raw = await _invoke({
      'operation': 'search',
      'query': query.trim(),
      'language': language,
    }).timeout(const Duration(seconds: 8));
    if (raw is! Map || raw['results'] is! List)
      throw StateError('invalid_geocoding_response');
    return (raw['results'] as List)
        .whereType<Map>()
        .map(GeocodedAddress.parse)
        .whereType<GeocodedAddress>()
        .toList();
  }
}
