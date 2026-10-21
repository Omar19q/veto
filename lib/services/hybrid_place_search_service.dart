import 'place_search_service.dart';
import 'supabase_service.dart';
import 'customer_city_scope_v38.dart';

typedef PlaceSearchRead =
    Future<List<PlaceSearchResult>> Function(String query);

class HybridPlaceSearchResponse {
  final List<PlaceSearchResult> results;
  final bool approvedUnavailable, externalUnavailable;
  const HybridPlaceSearchResponse(
    this.results, {
    required this.approvedUnavailable,
    required this.externalUnavailable,
  });
}

/// Search combines approved server addresses with external candidates. Search
/// results never bypass the existing server quote/service-coverage validation.
class HybridPlaceSearchService {
  final PlaceSearchRead approved, external;
  HybridPlaceSearchService({
    PlaceSearchRead? approved,
    PlaceSearchRead? external,
  }) : approved = approved ?? _approved,
       external = external ?? PlaceSearchService.instance.search;
  static PlaceSearchResult? parse(Map row) {
    final lat = double.tryParse('${row['latitude']}'),
        lng = double.tryParse('${row['longitude']}');
    final name = (row['name'] ?? row['short_name'] ?? row['address'] ?? '')
        .toString()
        .trim();
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180 ||
        name.isEmpty)
      return null;
    return PlaceSearchResult(
      name: name,
      address: row['address']?.toString() ?? name,
      latitude: lat,
      longitude: lng,
      areaLetter: row['area_letter']?.toString(),
      buildingNumber: row['building_number']?.toString(),
    );
  }

  static Future<List<PlaceSearchResult>> _approved(String q) async {
    final api = SupabaseService.instance;
    final city = CustomerCityScopeV38.name;
    final rows = <Map>[];
    if (city != null && !CustomerCityScopeV38.isHadayek) {
      final raw = await api.client.rpc(
        'v39_customer_city_places',
        params: {'p_city': city},
      );
      if (raw is List) rows.addAll(raw.whereType<Map>());
    } else {
      final famous = await api.client
          .from('famous_places')
          .select()
          .eq('is_active', true)
          .ilike('name', '%${q.replaceAll('%', '\\%').replaceAll('_', '\\_')}%')
          .limit(12);
      rows.addAll(famous);
      if (RegExp(r'\d').hasMatch(q)) {
        final buildings = await api.searchBuildingsGlobalForCustomer(
          searchQuery: q,
        );
        // Keep building naming canonical; no edit to areas/numbers/locations.
        for (final b in buildings) {
          rows.add({
            ...b,
            'name': b['address'] ?? b['display_name'] ?? b['name'] ?? '${b['area_letter']??''} ${b['building_number']??''}',
          });
        }
      }
    }
    final query = q.toLowerCase();
    return rows
        .map(parse)
        .whereType<PlaceSearchResult>()
        .where(
          (p) =>
              p.name.toLowerCase().contains(query) ||
              p.address.toLowerCase().contains(query),
        )
        .take(12)
        .toList();
  }

  Future<HybridPlaceSearchResponse> search(
    String query, {
    void Function(List<PlaceSearchResult>)? onApproved,
  }) async {
    final q = query.trim();
    if (q.length < 2)
      return const HybridPlaceSearchResponse(
        [],
        approvedUnavailable: false,
        externalUnavailable: false,
      );
    var approvedFailed = false, externalFailed = false;
    Future<List<PlaceSearchResult>> read(
      PlaceSearchRead source,
      bool isApproved,
    ) async {
      try {
        final rows = await source(
          q,
        ).timeout(Duration(seconds: isApproved ? 8 : 3));
        if (isApproved) onApproved?.call(rows);
        return rows;
      } catch (_) {
        if (isApproved) {
          approvedFailed = true;
        } else {
          externalFailed = true;
        }
        return [];
      }
    }

    final sources = await Future.wait([
      read(approved, true),
      read(external, false),
    ]);
    if (approvedFailed && externalFailed)
      throw StateError('all_address_sources_unavailable');
    final merged = <PlaceSearchResult>[];
    final seen = <String>{};
    for (final items in sources) {
      for (final p in items) {
        if (!p.latitude.isFinite ||
            !p.longitude.isFinite ||
            p.latitude.abs() > 90 ||
            p.longitude.abs() > 180)
          continue;
        final key =
            '${p.latitude.toStringAsFixed(5)}:${p.longitude.toStringAsFixed(5)}:${p.name.trim().toLowerCase()}';
        if (seen.add(key)) merged.add(p);
      }
    }
    return HybridPlaceSearchResponse(
      merged,
      approvedUnavailable: approvedFailed,
      externalUnavailable: externalFailed,
    );
  }
}
