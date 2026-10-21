import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../services/osrm_routing_service.dart';
import '../../../services/route_progress.dart';
import '../../../widgets/openfreemap_surface.dart';
import '../../../l10n/strings.dart';
import 'package:intl/intl.dart';

class SmoothLiveTripMap extends StatefulWidget {
  final double topInset;
  /// Visual-only theme used by the captain; customers keep their existing map.
  final bool darkTiles;
  final double? customerLat, customerLng;
  final String? serviceType;
  final String? tripStatus;
  final DateTime? locationUpdatedAt;
  final Future<RouteResult?> Function(LatLng from, LatLng to)? routeLoader;
  final double? captainLat,
      captainLng,
      pickupLat,
      pickupLng,
      destinationLat,
      destinationLng;
  const SmoothLiveTripMap({
    super.key,
    this.topInset = 0,
    this.darkTiles = false,
    this.customerLat,
    this.customerLng,
    this.serviceType,
    this.tripStatus,
    this.locationUpdatedAt,
    this.routeLoader,
    this.captainLat,
    this.captainLng,
    this.pickupLat,
    this.pickupLng,
    this.destinationLat,
    this.destinationLng,
  });
  @override
  State<SmoothLiveTripMap> createState() => _SmoothLiveTripMapState();
}

class _SmoothLiveTripMapState extends State<SmoothLiveTripMap>
    with SingleTickerProviderStateMixin {
  final _map = MapController();
  late final AnimationController _animation;
  LatLng? _from, _to, _car;
  RouteProgress? _route;
  double _progress = 0;
  double _routeMinutes = 0;
  DateTime? _lastSample, _lastRouteRequest;
  Timer? _clock;
  int _routeVersion = 0;
  bool _mapReady = false;
  bool _routeBusy = false;
  bool _routeError = false;
  int _cameraRevision = 0;

  LatLng? _point(double? lat, double? lng) =>
      lat != null &&
          lng != null &&
          lat.isFinite &&
          lng.isFinite &&
          lat.abs() <= 90 &&
          lng.abs() <= 180
      ? LatLng(lat, lng)
      : null;
  LatLng? get _target =>
      const {'started', 'completed'}.contains(widget.tripStatus)
      ? _point(widget.destinationLat, widget.destinationLng)
      : _point(widget.pickupLat, widget.pickupLng);

  @override
  void initState() {
    super.initState();
    _car = _point(widget.captainLat, widget.captainLng);
    _animation =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..addListener(() {
            if (_from == null || _to == null || !mounted) return;
            setState(
              () => _car = interpolatePosition(_from!, _to!, _animation.value),
            );
          });
    _clock = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
    _refreshRoute(force: true);
  }

  @override
  void didUpdateWidget(covariant SmoothLiveTripMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final targetChanged =
        oldWidget.tripStatus != widget.tripStatus ||
        oldWidget.pickupLat != widget.pickupLat ||
        oldWidget.pickupLng != widget.pickupLng ||
        oldWidget.destinationLat != widget.destinationLat ||
        oldWidget.destinationLng != widget.destinationLng;
    final next = _point(widget.captainLat, widget.captainLng);
    if (next != null &&
        (oldWidget.captainLat != widget.captainLat ||
            oldWidget.captainLng != widget.captainLng)) {
      final now = DateTime.now();
      final milliseconds = _lastSample == null
          ? 2000
          : now.difference(_lastSample!).inMilliseconds.clamp(500, 8000);
      _lastSample = now;
      _from = _car ?? next;
      _to = next;
      _animation.duration = Duration(milliseconds: milliseconds);
      _animation.forward(from: 0);
    }
    if (targetChanged) {
      _routeVersion++;
      _routeBusy = false;
      _route = null;
      _progress = 0;
    }
    _refreshRoute(force: targetChanged);
  }

  Future<void> _refreshRoute({bool force = false}) async {
    final car = _point(widget.captainLat, widget.captainLng);
    final target = _target;
    if (car == null || target == null) return;
    if (_routeBusy && !force) return;
    final now = DateTime.now();
    if (!force &&
        _lastRouteRequest != null &&
        now.difference(_lastRouteRequest!) < const Duration(seconds: 30))
      return;
    _lastRouteRequest = now;
    _routeBusy = true;
    final version = ++_routeVersion;
    final result = await (widget.routeLoader?.call(car, target) ?? RoutingService.instance.getRouteWithGeometry(
      fromLat: car.latitude,
      fromLng: car.longitude,
      toLat: target.latitude,
      toLng: target.longitude,
    ));
    if (!mounted || version != _routeVersion) return;
    _routeBusy = false;
    if (result == null || result.routePoints.length < 2) {
      setState(() => _routeError = true);
      return;
    }
    setState(() {
      _route = RouteProgress(
        result.routePoints.map((p) => LatLng(p[0], p[1])).toList(),
      );
      _routeError = false;
      _progress = 0;
      _routeMinutes = result.durationMinutes;
    });
  }

  void _fit() {
    if (OpenFreeMapSurface.enabled) {
      setState(() => _cameraRevision++);
      return;
    }
    if (!_mapReady) return;
    final points = [if (_car != null) _car!, if (_target != null) _target!];
    if (points.length > 1 && const Distance()(points.first, points.last) > 20) {
      _map.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(55),
        ),
      );
    } else if (points.isNotEmpty) {
      _map.move(points.first, 15);
    }
  }

  @override
  void dispose() {
    _routeVersion++;
    _clock?.cancel();
    _animation.dispose();
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l = context.strings;
    RouteProjection? projection;
    final route = _route;
    if (route != null && _car != null) {
      projection = route.project(_car!, minimumProgress: _progress);
      _progress = projection.progressMeters;
    }
    final remainingMeters = route == null
        ? null
        : (route.totalMeters - _progress).clamp(0.0, double.infinity);
    final eta =
        route == null || route.totalMeters <= 0 || remainingMeters == null
        ? null
        : _routeMinutes * remainingMeters / route.totalMeters;
    final stale =
        widget.locationUpdatedAt == null ||
        DateTime.now().difference(widget.locationUpdatedAt!) >
            const Duration(seconds: 90) ||
        widget.locationUpdatedAt!.difference(DateTime.now()) >
            const Duration(seconds: 5);
    return Stack(
      children: [
        if (OpenFreeMapSurface.enabled)
          OpenFreeMapSurface(
            center: _target ?? const LatLng(29.97764, 31.1121),
            cameraRevision: _cameraRevision,
            pointColors: [
              if (_point(widget.pickupLat, widget.pickupLng) != null) '#F8C44D',
              if (_point(widget.destinationLat, widget.destinationLng) != null) '#10B981',
              if (_point(widget.captainLat, widget.captainLng) != null) '#3B82F6',
            ],
            points: [
              if (_point(widget.pickupLat, widget.pickupLng) != null)
                _point(widget.pickupLat, widget.pickupLng)!,
              if (_point(widget.destinationLat, widget.destinationLng) != null)
                _point(widget.destinationLat, widget.destinationLng)!,
              if (_point(widget.captainLat, widget.captainLng) != null)
                _point(widget.captainLat, widget.captainLng)!,
            ],
            route: route?.points ?? const [],
          )
        else FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _car ?? _target ?? const LatLng(29.97764, 31.1121),
            initialZoom: 14,
            onMapReady: () {
              _mapReady = true;
              _fit();
            },
          ),
          children: [
            if (Theme.of(context).brightness == Brightness.dark)
              ColorFiltered(colorFilter: const ColorFilter.matrix([
                  -.53, 0, 0, 0, 125,
                  0, -.53, 0, 0, 137,
                  0, 0, -.53, 0, 155,
                  0, 0, 0, 1, 0,
                ]),
                child: TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.vetosanya.app',
                  maxZoom: 19,
                ))
            else
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.vetosanya.app',
                maxZoom: 19,
              ),
            if (route != null && projection != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: route.remaining(projection),
                    color: const Color(0xff18b9a5),
                    strokeWidth: 5,
                    borderColor: Colors.white,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (_point(widget.customerLat, widget.customerLng) != null)
                  Marker(
                    point: _point(widget.customerLat, widget.customerLng)!,
                    width: 24,
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
                if (_point(widget.pickupLat, widget.pickupLng) != null &&
                    _target != _point(widget.pickupLat, widget.pickupLng))
                  Marker(
                    point: _point(widget.pickupLat, widget.pickupLng)!,
                    width: 36,
                    height: 36,
                    child: const Icon(
                      Icons.trip_origin,
                      color: Colors.green,
                      size: 30,
                    ),
                  ),
                if (_point(widget.destinationLat, widget.destinationLng) !=
                        null &&
                    _target !=
                        _point(widget.destinationLat, widget.destinationLng))
                  Marker(
                    point: _point(
                      widget.destinationLat,
                      widget.destinationLng,
                    )!,
                    width: 36,
                    height: 36,
                    child: const Icon(
                      Icons.flag,
                      color: Colors.deepOrange,
                      size: 30,
                    ),
                  ),
                if (_target != null)
                  Marker(
                    point: _target!,
                    width: 42,
                    height: 42,
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Colors.redAccent,
                      size: 40,
                    ),
                  ),
                if (_car != null)
                  Marker(
                    point: _car!,
                    width: 48,
                    height: 48,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 10),
                        ],
                      ),
                      child: Icon(
                        widget.serviceType?.contains('motorcycle') == true
                            ? Icons.two_wheeler_rounded
                            : Icons.directions_car_rounded,
                        color: Colors.amber,
                        size: 28,
                      ),
                    ),
                  ),
              ],
            ),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('© OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        if(!const {'completed','cancelled'}.contains(widget.tripStatus))
        Positioned(
          top: 12 + widget.topInset,
          left: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 12),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, color: Color(0xff18b9a5)),
                const SizedBox(width: 10),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      stale
                          ? l.liveMapStale
                          : _routeError
                          ? l.liveMapEtaUnavailable
                          : eta == null
                          ? (_routeError
                                ? l.liveMapEtaUnavailable
                                : l.liveMapCalculating)
                          : eta < 0.5
                          ? l.liveMapNearTarget
                          : l.liveMapEtaDistance(eta.ceil(), NumberFormat('0.0', Localizations.localeOf(context).languageCode).format(remainingMeters! / 1000)),
                      key: ValueKey(stale ? 'stale' : eta?.ceil()),
                      style: TextStyle(
                        color: colors.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Text(
                  l.liveMapEstimate,
                  style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 28,
          right: 12,
          child: FloatingActionButton.small(
            heroTag: null,
            onPressed: _fit,
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }
}
