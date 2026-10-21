import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as vector;
import '../services/growth_service.dart';
import '../services/openfreemap_style_service.dart';
import '../l10n/strings.dart';

/// Actual vector renderer. No device tracking, pricing or paid provider fallback.
class OpenFreeMapSurface extends StatefulWidget {
  static bool get enabled =>
      const bool.fromEnvironment('VETO_OPENFREEMAP_ENABLED') &&
      GrowthService.buildEnabled;
  final LatLng center;
  final List<LatLng> points;
  final List<String> pointColors;
  final List<LatLng> route;
  final ValueChanged<LatLng>? onTap;
  final VoidCallback? onReady;
  final int cameraRevision;
  const OpenFreeMapSurface({
    super.key,
    required this.center,
    this.points = const [],
    this.pointColors = const [],
    this.route = const [],
    this.onTap,
    this.onReady,
    this.cameraRevision = 0,
  });
  @override
  State<OpenFreeMapSurface> createState() => _OpenFreeMapSurfaceState();
}

class _OpenFreeMapSurfaceState extends State<OpenFreeMapSurface> {
  vector.MapLibreMapController? _controller;
  bool _ready = false, _drawing = false, _pending = false, _failed = false;
  int _revision = 0;
  Timer? _styleTimeout;
  Future<String>? _style;
  String? _variant;
  final List<vector.Circle> _circles = [];
  List<LatLng> _routeSnapshot = const [];
  vector.Line? _line;
  LatLng? _cameraCenter;
  int? _cameraRevision;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final language = Localizations.localeOf(context).languageCode;
    final variant = '$dark:$language';
    if (variant != _variant) {
      _variant = variant;
      _ready = false;
      _circles.clear();
      _line = null;
      _routeSnapshot = const [];
      _cameraCenter = null;
      _revision++;
      _armTimeout();
      _style = OpenFreeMapStyleService.instance.style(
        dark: dark,
        language: language,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _armTimeout();
  }

  void _armTimeout() {
    _styleTimeout?.cancel();
    _styleTimeout = Timer(const Duration(seconds: 12), () {
      if (mounted && !_ready) setState(() => _failed = true);
    });
  }

  bool valid(LatLng p) =>
      p.latitude.isFinite &&
      p.longitude.isFinite &&
      p.latitude.abs() <= 90 &&
      p.longitude.abs() <= 180;
  vector.LatLng convert(LatLng p) => vector.LatLng(p.latitude, p.longitude);
  @override
  void didUpdateWidget(covariant OpenFreeMapSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.center == widget.center &&
        oldWidget.cameraRevision == widget.cameraRevision &&
        listEquals(oldWidget.points, widget.points) &&
        listEquals(oldWidget.pointColors, widget.pointColors) &&
        listEquals(oldWidget.route, widget.route))
      return;
    _revision++;
    unawaited(_draw());
  }

  Future<void> _draw() async {
    if (!_ready || !mounted) return;
    if (_drawing) {
      _pending = true;
      return;
    }
    _drawing = true;
    final revision = _revision;
    try {
      final controller = _controller!;
      final points = widget.points.where(valid).toList();
      if (_circles.length != points.length) {
        await controller.clearCircles();
        _circles.clear();
      }
      if (!mounted || revision != _revision) return;
      for (var i = 0; i < points.length; i++) {
        if (_circles.length == points.length) {
          await controller.updateCircle(
            _circles[i],
            vector.CircleOptions(
              geometry: convert(points[i]),
              circleColor: i < widget.pointColors.length
                  ? widget.pointColors[i]
                  : '#122039',
            ),
          );
        } else {
          final circle = await controller.addCircle(
            vector.CircleOptions(
              geometry: convert(points[i]),
              circleRadius: 10,
              circleColor: i < widget.pointColors.length
                  ? widget.pointColors[i]
                  : '#122039',
              circleStrokeColor: i == 0 ? '#FFC247' : '#FFFFFF',
              circleStrokeWidth: 3,
            ),
          );
          if (!mounted || revision != _revision) return;
          _circles.add(circle);
        }
        if (!mounted || revision != _revision) return;
      }
      final route = widget.route.where(valid).toList();
      if (!listEquals(_routeSnapshot, route)) {
        if (route.length < 2) {
          await controller.clearLines();
          _line = null;
        } else if (_line != null) {
          await controller.updateLine(
            _line!,
            vector.LineOptions(geometry: route.map(convert).toList()),
          );
        } else {
          final line = await controller.addLine(
            vector.LineOptions(
              geometry: route.map(convert).toList(),
              lineColor: '#D29B26',
              lineWidth: 4,
            ),
          );
          if (!mounted || revision != _revision) return;
          _line = line;
        }
        _routeSnapshot = List.of(route);
      }
      if (!mounted || revision != _revision) return;
      if (_cameraCenter != widget.center ||
          _cameraRevision != widget.cameraRevision) {
        await controller.moveCamera(
          vector.CameraUpdate.newLatLng(convert(widget.center)),
        );
        _cameraCenter = widget.center;
        _cameraRevision = widget.cameraRevision;
      }
      if (mounted) {
        setState(() => _failed = false);
        widget.onReady?.call();
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      _drawing = false;
      if (_pending && mounted) {
        _pending = false;
        unawaited(_draw());
      }
    }
  }

  @override
  void dispose() {
    _styleTimeout?.cancel();
    _revision++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      FutureBuilder<String>(
        future: _style,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text(context.strings.vectorMapUnavailable));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          return vector.MapLibreMap(
            key: ValueKey(_variant),
            styleString: snapshot.data!,
            initialCameraPosition: vector.CameraPosition(
              target: convert(widget.center),
              zoom: 14,
            ),
            myLocationEnabled: false,
            onMapCreated: (controller) => _controller = controller,
            onStyleLoadedCallback: () {
              _styleTimeout?.cancel();
              _ready = true;
              unawaited(_draw());
            },
            onMapClick: (_, point) =>
                widget.onTap?.call(LatLng(point.latitude, point.longitude)),
          );
        },
      ),
      if (_failed)
        Positioned(
          left: 12,
          right: 12,
          bottom: 30,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text(context.strings.vectorMapUnavailable),
            ),
          ),
        ),
    ],
  );
}
