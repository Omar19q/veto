import 'package:dio/dio.dart';
import 'growth_service.dart';
import 'product_preferences.dart';
import 'product_geocoding_service.dart';

class PlaceSearchResult {
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? areaLetter, buildingNumber;

  const PlaceSearchResult({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.areaLetter, this.buildingNumber,
  });
}

class PlaceSearchService {
  PlaceSearchService._();
  static final PlaceSearchService instance = PlaceSearchService._();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {
        'Accept': 'application/json',
        'Accept-Language': 'ar,en',
        'User-Agent': 'VetoSanya/1.0',
      },
    ),
  );

  Future<List<PlaceSearchResult>> search(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    if (GrowthService.buildEnabled) {
      final rows = await ProductGeocodingService().search(
        q,
        language: ProductPreferences.instance.locale.languageCode,
      );
      return rows
          .map(
            (p) => PlaceSearchResult(
              name: p.address,
              address: p.address,
              latitude: p.latitude,
              longitude: p.longitude,
            ),
          )
          .toList();
    }
    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': '$q, Egypt',
          'format': 'jsonv2',
          'addressdetails': 1,
          'limit': 8,
          'countrycodes': 'eg',
          'accept-language': 'ar,en',
        },
      );
      final data = response.data is List ? response.data as List : const [];
      return data
          .whereType<Map>()
          .map((row) {
            final lat = double.tryParse(row['lat']?.toString() ?? '');
            final lon = double.tryParse(row['lon']?.toString() ?? '');
            if (lat == null ||
                lon == null ||
                !lat.isFinite ||
                !lon.isFinite ||
                lat.abs() > 90 ||
                lon.abs() > 180)
              return null;
            final display = row['display_name']?.toString().trim() ?? '';
            final name = _bestName(row, display);
            return PlaceSearchResult(
              name: name.isEmpty ? display : name,
              address: display,
              latitude: lat,
              longitude: lon,
            );
          })
          .whereType<PlaceSearchResult>()
          .toList();
    } catch (_) {
      throw StateError('address_search_unavailable');
    }
  }

  String _bestName(Map row, String display) {
    final name = row['name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    final address = row['address'];
    if (address is Map) {
      for (final key in const [
        'road',
        'neighbourhood',
        'suburb',
        'town',
        'city',
      ]) {
        final value = address[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
    }
    return display.split(',').first.trim();
  }
}
