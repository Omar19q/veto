import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/openfreemap_surface.dart';

/// Real interactive map widget using flutter_map + OpenStreetMap tiles.
/// Replaces the previous fake CustomPainter grid map.
class BookingMapWidget extends StatefulWidget {
  final double? pickupLat;
  final double? pickupLng;
  final double? destLat;
  final double? destLng;
  final String? pickupLabel;
  final String? destLabel;
  final List<List<double>>? routePoints; // [[lat, lng], ...]

  const BookingMapWidget({
    super.key,
    this.pickupLat,
    this.pickupLng,
    this.destLat,
    this.destLng,
    this.pickupLabel,
    this.destLabel,
    this.routePoints,
  });

  @override
  State<BookingMapWidget> createState() => _BookingMapWidgetState();
}

class _BookingMapWidgetState extends State<BookingMapWidget> {
  final MapController _mapController = MapController();

  // Default center: Hadayek Al Ahram, Giza
  static const double _defaultLat = 29.9792;
  static const double _defaultLng = 31.1342;

  @override
  void didUpdateWidget(BookingMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-center map when coordinates change
    if (widget.pickupLat != oldWidget.pickupLat ||
        widget.pickupLng != oldWidget.pickupLng) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitBounds();
      });
    }
  }

  void _fitBounds() {
    if (!mounted) return;
    try {
      if (widget.pickupLat != null && widget.destLat != null) {
        // Fit both markers
        final bounds = LatLngBounds(
          LatLng(
            widget.pickupLat! < widget.destLat!
                ? widget.pickupLat!
                : widget.destLat!,
            widget.pickupLng! < widget.destLng!
                ? widget.pickupLng!
                : widget.destLng!,
          ),
          LatLng(
            widget.pickupLat! > widget.destLat!
                ? widget.pickupLat!
                : widget.destLat!,
            widget.pickupLng! > widget.destLng!
                ? widget.pickupLng!
                : widget.destLng!,
          ),
        );
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
        );
      } else if (widget.pickupLat != null) {
        _mapController.move(LatLng(widget.pickupLat!, widget.pickupLng!), 15.0);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (OpenFreeMapSurface.enabled) {
      final pickup = widget.pickupLat != null && widget.pickupLng != null
          ? LatLng(widget.pickupLat!, widget.pickupLng!)
          : const LatLng(_defaultLat, _defaultLng);
      return OpenFreeMapSurface(
        center: pickup,
        pointColors: [
          if (widget.pickupLat != null && widget.pickupLng != null) '#122039',
          if (widget.destLat != null && widget.destLng != null) '#10B981',
        ],
        points: [
          if (widget.pickupLat != null && widget.pickupLng != null) pickup,
          if (widget.destLat != null && widget.destLng != null)
            LatLng(widget.destLat!, widget.destLng!),
        ],
        route: [
          for (final p in widget.routePoints ?? <List<double>>[])
            if (p.length >= 2) LatLng(p[0], p[1]),
        ],
      );
    }
    final center = widget.pickupLat != null
        ? LatLng(widget.pickupLat!, widget.pickupLng!)
        : const LatLng(_defaultLat, _defaultLng);

    final markers = <Marker>[];

    // Pickup marker (gold)
    if (widget.pickupLat != null) {
      markers.add(
        Marker(
          point: LatLng(widget.pickupLat!, widget.pickupLng!),
          width: 70,
          height: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 43,
                decoration: BoxDecoration(
                  color: AppTheme.gold,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.gold.withAlpha(100),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person_pin_circle_rounded,
                  color: AppTheme.primary,
                  size: 27,
                ),
              ),
              Container(width: 2, height: 10, color: AppTheme.gold),
            ],
          ),
        ),
      );
    }

    // Destination marker (red)
    if (widget.destLat != null) {
      markers.add(
        Marker(
          point: LatLng(widget.destLat!, widget.destLng!),
          width: 70,
          height: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 43,
                decoration: BoxDecoration(
                  color: const Color(0xFF197F78),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF197F78).withAlpha(90),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              Container(width: 2, height: 10, color: const Color(0xFF197F78)),
            ],
          ),
        ),
      );
    }

    // Route polyline
    final polylines = <Polyline>[];
    if (widget.routePoints != null && widget.routePoints!.isNotEmpty) {
      polylines.add(
        Polyline(
          points: widget.routePoints!.map((p) => LatLng(p[0], p[1])).toList(),
          color: AppTheme.gold,
          strokeWidth: 4.0,
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 14.0,
        minZoom: 5.0,
        maxZoom: 19.0,
        onMapReady: () {
          WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.vetosanya.app',
          maxZoom: 19,
        ),
        if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
        const RichAttributionWidget(
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
        ),
      ],
    );
  }
}
