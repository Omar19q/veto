import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/supabase_service.dart';
import '../../../services/osrm_routing_service.dart';
import '../../../widgets/openfreemap_surface.dart';
import '../../../l10n/strings.dart';

const _navy = Color(0xFF10192B);
const _gold = Color(0xFFFFC42C);

/// Read-only preview. The API enforces captain ownership/offer eligibility.
/// No maps API key or background-location permission is requested.
class CaptainRoutePreviewV45 extends StatelessWidget {
  const CaptainRoutePreviewV45({super.key, required this.tripId, this.loadSnapshot, this.loadRoad});
  final String tripId;
  final Future<Map<String, dynamic>> Function(String id)? loadSnapshot;
  final Future<RouteResult?> Function(LatLng start, LatLng end)? loadRoad;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: tripId.isEmpty ? null : () => _show(context),
    icon: const Icon(Icons.route_rounded, size: 18),
    label: Text(context.strings.captainRoadPreview, style: const TextStyle(fontWeight: FontWeight.w800)),
    style: OutlinedButton.styleFrom(foregroundColor: _gold),
  );

  static double? _coord(Object? value, double max) {
    final n = value is num ? value.toDouble() : double.tryParse('$value');
    if (n == null || !n.isFinite || n.abs() > max) return null;
    return n;
  }

  void _show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _navy,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.70,
          child: FutureBuilder<dynamic>(
            future: loadSnapshot != null ? loadSnapshot!(tripId) : SupabaseService.instance.client.rpc(
              'get_captain_trip_route_preview_v45',
              params: {'p_trip_id': tripId},
            ),
            builder: (ctx, snap) {
              if (!snap.hasData && !snap.hasError) return Center(
                child: CircularProgressIndicator(color: _gold));
              if (snap.hasError || snap.data is! Map) return Center(
                child: Padding(padding: EdgeInsets.all(24),
                  child: Text(context.strings.captainRoadUnavailable,
                    style: TextStyle( color: Colors.white))));
              final data = Map<String, dynamic>.from(snap.data as Map);
              final lat1 = _coord(data['pickup_lat'], 90);
              final lng1 = _coord(data['pickup_lng'], 180);
              final lat2 = _coord(data['destination_lat'], 90);
              final lng2 = _coord(data['destination_lng'], 180);
              if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) {
                return Center(child: Text(context.strings.captainRoadCoordinatesUnavailable,
                    style: TextStyle( color: Colors.white)));
              }
              final start = LatLng(lat1, lng1), end = LatLng(lat2, lng2);
              final cLat = _coord(data['captain_lat'], 90);
              final cLng = _coord(data['captain_lng'], 180);
              final captain = cLat != null && cLng != null ? LatLng(cLat, cLng) : null;
              final points = [start, end, if (captain != null) captain];
              final bounds = LatLngBounds.fromPoints(points);
              final distance = data['distance_km'];
              final distanceText = distance is num ? context.strings.distanceValue(distance.toStringAsFixed(1)) : context.strings.captainRoadDistanceUnknown;
              return Column(children: [
                Padding(padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                  child: Row(children: [
                    const Icon(Icons.route_rounded, color: _gold),
                    const SizedBox(width: 9),
                    Expanded(child: Text(context.strings.captainRoadTitle,
                      style: TextStyle( color: Colors.white,
                        fontSize: 18, fontWeight: FontWeight.w900))),
                    Text(distanceText, style: const TextStyle( color: _gold)),
                  ])),
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(14),
                  child: FutureBuilder<RouteResult?>(
                    future: loadRoad != null ? loadRoad!(start, end) : RoutingService.instance.getRouteWithGeometry(
                      fromLat: lat1, fromLng: lng1, toLat: lat2, toLng: lng2),
                    builder: (context, routeSnapshot) {
                      final road = routeSnapshot.data?.routePoints
                          .where((p) => p.length >= 2)
                          .map((p) => LatLng(p[0], p[1])).toList() ?? <LatLng>[];
                      if (OpenFreeMapSurface.enabled) {
                        return OpenFreeMapSurface(
                          center: start, points: points,
                          pointColors: ['#0CAB7D', '#E94958', if (captain != null) '#166DE8'],
                          route: road,
                        );
                      }
                      return FlutterMap(
                    options: MapOptions(initialCameraFit: CameraFit.bounds(
                      bounds: bounds, padding: const EdgeInsets.all(52))),
                    children: [
                      TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.vetosanya.app'),
                      // Endpoint coordinates must never be drawn as a road.
                      if (road.length >= 2) PolylineLayer(polylines: [Polyline(
                        points: road, color: const Color(0xFF17A5EF), strokeWidth: 4)]),
                      MarkerLayer(markers: [
                        Marker(point: start, width: 42, height: 42,
                          child: const Icon(Icons.trip_origin_rounded, color: Color(0xFF0CAB7D), size: 37)),
                        Marker(point: end, width: 42, height: 42,
                          child: const Icon(Icons.location_on_rounded, color: Color(0xFFE94958), size: 39)),
                        if (captain != null) Marker(point: captain, width: 42, height: 42,
                          child: const Icon(Icons.navigation_rounded, color: Color(0xFF166DE8), size: 35)),
                      ]),
                    ],
                      );
                    },
                  ))),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(children: [
                    Expanded(child: Text(context.strings.captainRoadLegend,
                      style: TextStyle( fontSize: 10, color: Colors.white))),
                    TextButton.icon(onPressed: () async {
                      final url = Uri.https('www.google.com', '/maps/dir/', {
                        'api': '1',
                        'origin': '$lat1,$lng1',
                        'destination': '$lat2,$lng2',
                        'travelmode': 'driving',
                      });
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }, icon: const Icon(Icons.open_in_new_rounded, size: 17),
                      label: Text(context.strings.captainRoadDirections,
                        style: TextStyle( fontSize: 11))),
                  ])),
                Padding(padding: EdgeInsets.only(left: 16, right: 16, bottom: 12),
                  child: Text(context.strings.captainRoadExplanation,
                    textAlign: TextAlign.center,
                    style: TextStyle( fontSize: 11, color: Color(0xFFAAB8D2))),
                ),
              ]);
            },
          ),
        ),
      ),
    );
  }
}
