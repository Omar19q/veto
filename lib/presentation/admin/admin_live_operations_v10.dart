import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_service.dart';
import '../../services/zone_pricing_service.dart';

class AdminLiveOperationsV10 extends StatefulWidget {
  const AdminLiveOperationsV10({super.key});
  @override
  State<AdminLiveOperationsV10> createState() => _AdminLiveOperationsV10State();
}

class _AdminLiveOperationsV10State extends State<AdminLiveOperationsV10> {
  final db = SupabaseService.instance.client;
  Map<String, dynamic> data = {};
  List<PricingZone> zones = [];
  TripRealtimeLease? channel;
  Timer? throttle;
  bool busy = false;
  String? error;
  LatLngBounds? _bounds;
  bool _dirty = false;
  @override
  void initState() {
    super.initState();
    load();
    ZonePricingService.instance
        .zones()
        .then((z) {
          if (mounted) setState(() => zones = z);
        })
        .catchError((_) {});
    channel = SupabaseService.instance.subscribeToScaleAdminPulse(schedule);
  }

  void schedule() {
    throttle ??= Timer(const Duration(seconds: 2), () {
      throttle = null;
      load();
    });
  }

  @override
  void dispose() {
    throttle?.cancel();
    channel?.unsubscribe();
    super.dispose();
  }

  Future<void> load() async {
    if (busy) {
      _dirty = true;
      return;
    }
    busy = true;
    try {
      final result = await db
          .rpc(
            'admin_map_window_scale_v15',
            params: {
              'p_south': _bounds?.south ?? 29.88,
              'p_north': _bounds?.north ?? 30.08,
              'p_west': _bounds?.west ?? 31.02,
              'p_east': _bounds?.east ?? 31.23,
            },
          )
          .timeout(const Duration(seconds: 10));
      if (mounted)
        setState(() {
          data = Map<String, dynamic>.from(result as Map);
          error = null;
        });
    } catch (_) {
      if (mounted)
        setState(() => error = 'تعذر تحديث الخريطة. آخر بيانات متاحة معروضة.');
    } finally {
      busy = false;
      if (_dirty && mounted) {
        _dirty = false;
        schedule();
      }
    }
  }

  LatLng? point(dynamic a, dynamic b) {
    final lat = double.tryParse('$a'), lng = double.tryParse('$b');
    return lat != null &&
            lng != null &&
            lat.isFinite &&
            lng.isFinite &&
            lat.abs() <= 90 &&
            lng.abs() <= 180
        ? LatLng(lat, lng)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final trips = (data['trips'] as List? ?? []).whereType<Map>().toList(),
        captains = (data['captains'] as List? ?? []).whereType<Map>().toList();
    final zoneRows = (data['zones'] as List? ?? []).whereType<Map>().toList();
    final positions = {
      for (final c in captains)
        c['id']: point(c['current_latitude'], c['current_longitude']),
    };
    final assigned = {
      for (final t in trips)
        if (t['captain_id'] != null) t['captain_id'],
    };
    LatLng? tripPoint(Map t) =>
        positions[t['captain_id']] ??
        point(t['pickup_latitude'], t['pickup_longitude']);
    return Column(
      children: [
        ListTile(
          title: const Text(
            'العمليات الحية',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          subtitle: Text(
            '${trips.length} رحلة نشطة • ${captains.length} كابتن بموقع حديث',
          ),
          trailing: IconButton(
            onPressed: load,
            icon: const Icon(Icons.refresh),
          ),
        ),
        if (error != null) Text(error!),
        Expanded(
          child: FlutterMap(
            options: MapOptions(
              initialCenter:
                  point(
                    trips.isEmpty ? null : trips.first['pickup_latitude'],
                    trips.isEmpty ? null : trips.first['pickup_longitude'],
                  ) ??
                  const LatLng(29.985, 31.117),
              initialZoom: 13,
              onPositionChanged: (camera, _) {
                _bounds = camera.visibleBounds;
                schedule();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.vetosanya.app',
              ),
              PolygonLayer(
                polygons: [
                  for (final z in zones.where(
                    (z) => !z.global && z.ring.length >= 3,
                  ))
                    Polygon(
                      points: z.ring,
                      color: Colors.amber.withValues(alpha: .08),
                      borderColor: Colors.amber,
                      borderStrokeWidth: 1,
                    ),
                ],
              ),
              CircleLayer(
                circles: [
                  for (final t in trips.where(
                    (t) => [
                      'requested',
                      'offer_received',
                    ].contains(t['trip_status']),
                  ))
                    if (point(t['pickup_latitude'], t['pickup_longitude']) !=
                        null)
                      CircleMarker(
                        point: point(
                          t['pickup_latitude'],
                          t['pickup_longitude'],
                        )!,
                        radius: 180,
                        useRadiusInMeter: true,
                        color: Colors.orange.withValues(alpha: .13),
                        borderStrokeWidth: 0,
                      ),
                ],
              ),
              MarkerLayer(
                markers: [
                  for (final t in trips)
                    if (tripPoint(t) != null)
                      Marker(
                        point: tripPoint(t)!,
                        width: 42,
                        height: 42,
                        child: Tooltip(
                          message:
                              '${t['trip_status']} • ${t['pickup_address']}',
                          child: GestureDetector(
                            onTap: () => context.push(
                              '/admin/trip-details?tripId=${t['id']}',
                            ),
                            child: Icon(
                              t['captain_id'] == null
                                  ? Icons.trip_origin
                                  : Icons.directions_car,
                              color:
                                  [
                                    'requested',
                                    'offer_received',
                                  ].contains(t['trip_status'])
                                  ? Colors.orange
                                  : Colors.green,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                  for (final c in captains.where(
                    (c) => !assigned.contains(c['id']),
                  ))
                    if (point(c['current_latitude'], c['current_longitude']) !=
                        null)
                      Marker(
                        point: point(
                          c['current_latitude'],
                          c['current_longitude'],
                        )!,
                        width: 42,
                        height: 42,
                        child: Tooltip(
                          message:
                              '${c['full_name']} • ${c['is_available'] == true ? 'متاح' : 'في رحلة'}',
                          child: Icon(
                            Icons.local_taxi,
                            color: c['is_available'] == true
                                ? Colors.amber
                                : Colors.blue,
                            size: 32,
                          ),
                        ),
                      ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            children: [
              for (final z in zoneRows)
                SizedBox(
                  width: 250,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${z['name']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${z['demand'] ?? 0} طلب • ${z['supply'] ?? 0} كابتن • ×${z['multiplier'] ?? 1}',
                          ),
                          Text(
                            (double.tryParse('${z['multiplier']}') ?? 1) > 1
                                ? 'ضغط مرتفع'
                                : 'ضغط عادي',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
