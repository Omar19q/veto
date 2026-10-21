import '../../../l10n/strings.dart';
import 'dart:async';
import '../../../widgets/openfreemap_surface.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/zone_pricing_service.dart';

/// V30: visual-only driver map. No new location tracking, trip requests,
/// accounting writes or price calculations. Demand is read from existing RPC.
class CaptainHomeMapV30 extends StatefulWidget {
  final Map<String, dynamic>? captain;
  final bool online;
  final double? liveLatitude;
  final double? liveLongitude;
  final bool visible;
  final VoidCallback onOpenDemandMap;

  const CaptainHomeMapV30({
    super.key,
    required this.captain,
    required this.online,
    this.liveLatitude,
    this.liveLongitude,
    this.visible = true,
    required this.onOpenDemandMap,
  });

  @override
  State<CaptainHomeMapV30> createState() => _CaptainHomeMapV30State();
}

class _CaptainHomeMapV30State extends State<CaptainHomeMapV30>
    with WidgetsBindingObserver {
  static const _prefVisible = 'veto_captain_demand_overlay_v30';
  static const _prefRadius = 'veto_captain_demand_radius_v30';
  static const _navy = Color(0xFF0D192A);
  static const _gold = Color(0xFFF8C44D);

  bool _showDemand = false;
  bool _loading = false;
  int _radiusKm = 10;
  List<PricingZone> _zones = const [];
  Map<String, int> _hotDemand = const {};
  DateTime? _lastUpdated;
  bool _failed = false;
  Timer? _poll;
  Timer? _zoneDebounce;
  RealtimeChannel? _zoneChannel;

  double? _validNumber(Object? value, double maximum) {
    final parsed = value is num ? value.toDouble() : double.tryParse('$value');
    return parsed == null || !parsed.isFinite || parsed.abs() > maximum
        ? null
        : parsed;
  }

  LatLng? get _captainLocation {
    final liveLat = _validNumber(widget.liveLatitude, 90);
    final liveLng = _validNumber(widget.liveLongitude, 180);
    if (liveLat != null && liveLng != null) return LatLng(liveLat, liveLng);
    final current = widget.captain;
    if (current == null) return null;
    final lat = _validNumber(
      current['current_latitude'] ?? current['latitude'],
      90,
    );
    final lng = _validNumber(
      current['current_longitude'] ?? current['longitude'],
      180,
    );
    return lat == null || lng == null ? null : LatLng(lat, lng);
  }

  // The fallback is a map center, not the captain's claimed current position.
  LatLng get _initialCenter => _captainLocation ?? const LatLng(29.975, 31.103);

  bool _fresh(PricingZone zone) {
    final stamp = DateTime.tryParse(
      zone.row['surge_updated_at']?.toString() ?? '',
    );
    return stamp != null &&
        DateTime.now().toUtc().difference(stamp.toUtc()).inSeconds >= 0 &&
        DateTime.now().toUtc().difference(stamp.toUtc()).inSeconds < 120;
  }

  List<PricingZone> get _nearby {
    if (!_showDemand || _captainLocation == null) return [];
    final distance = Distance();
    final from = _captainLocation!;
    return _zones
        .where(
          (z) =>
              z.active &&
              !z.global &&
              z.center != null &&
              ((_fresh(z) && z.multiplier > 1) ||
                  _hotDemand.containsKey(z.id)) &&
              distance.as(LengthUnit.Kilometer, from, z.center!) <= _radiusKm,
        )
        .toList()
      ..sort((a, b) => b.multiplier.compareTo(a.multiplier));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restore();
    _poll = Timer.periodic(Duration(seconds: 60), (_) {
      if (_showDemand && widget.visible) _refresh();
    });
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _showDemand = prefs.getBool(_prefVisible) ?? false;
        final km = prefs.getInt(_prefRadius) ?? 10;
        _radiusKm = [5, 10, 15].contains(km) ? km : 10;
      });
      if (_showDemand) {
        _listenZones();
        await _refresh();
      }
    } catch (_) {
      // The map continues to work without device preferences.
    }
  }

  Future<void> _toggle(bool value) async {
    if (!mounted) return;
    setState(() => _showDemand = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefVisible, value);
    } catch (_) {}
    if (value) {
      _listenZones();
      await _refresh();
    } else {
      _zoneDebounce?.cancel();
      final previous = _zoneChannel;
      _zoneChannel = null;
      if (previous != null) {
        unawaited(ZonePricingService.instance.db.removeChannel(previous));
      }
    }
  }

  Future<void> _changeRadius(int radius) async {
    setState(() => _radiusKm = radius);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefRadius, radius);
    } catch (_) {}
  }

  void _listenZones() {
    if (_zoneChannel != null) return;
    _zoneChannel = ZonePricingService.instance.db
        .channel('v30-driver-map-zones')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'pricing_zones',
          callback: (_) {
            if (!_showDemand || !widget.visible) return;
            _zoneDebounce?.cancel();
            _zoneDebounce = Timer(Duration(milliseconds: 750), _refresh);
          },
        )
        .subscribe();
  }

  Future<void> _refresh() async {
    if (!mounted || !_showDemand || _loading) return;
    setState(() => _loading = true);
    try {
      final rows = await ZonePricingService.instance.zones().timeout(
        Duration(seconds: 12),
      );
      final alerts = await ZonePricingService.instance.activeDemandAlerts();
      final hotDemand = <String, int>{};
      for (final alert in alerts) {
        final id = alert['zone_id']?.toString();
        if (id != null) {
          hotDemand[id] = (alert['waiting_count'] as num?)?.toInt() ?? 0;
        }
      }
      if (mounted && _showDemand) {
        setState(() {
          _zones = rows;
          _hotDemand = hotDemand;
          _failed = false;
          _lastUpdated = DateTime.now();
        });
      }
    } catch (_) {
      if (mounted && _showDemand) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _showDemand && widget.visible)
      _refresh();
  }

  @override
  void didUpdateWidget(covariant CaptainHomeMapV30 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.visible && widget.visible && _showDemand) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _zoneDebounce?.cancel();
    final channel = _zoneChannel;
    if (channel != null) {
      unawaited(ZonePricingService.instance.db.removeChannel(channel));
    }
    super.dispose();
  }

  Widget _littleStat(String label, String value, {Color? valueColor}) =>
      Expanded(
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 5),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Color(0xFF263B54)),
          ),
          child: Column(
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: valueColor ?? Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final nearby = _nearby;
    final point = _captainLocation;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: Color(0xFF34445D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 415,
            child: Stack(
              children: [
                Positioned.fill(
                  child: OpenFreeMapSurface.enabled
                      ? OpenFreeMapSurface(
                          center: _initialCenter,
                          points: [
                            if (point != null) point,
                            for (final zone in nearby)
                              if (zone.center != null) zone.center!,
                          ],
                        )
                      : FlutterMap(
                          options: MapOptions(
                            initialCenter: _initialCenter,
                            initialZoom: 13,
                          ),
                          children: [
                            ColorFiltered(
                              colorFilter: ColorFilter.matrix(
                                Theme.of(context).brightness == Brightness.dark
                                    ? [
                                        -.53,
                                        0,
                                        0,
                                        0,
                                        125,
                                        0,
                                        -.53,
                                        0,
                                        0,
                                        137,
                                        0,
                                        0,
                                        -.53,
                                        0,
                                        155,
                                        0,
                                        0,
                                        0,
                                        1,
                                        0,
                                      ]
                                    : [
                                        1,
                                        0,
                                        0,
                                        0,
                                        0,
                                        0,
                                        1,
                                        0,
                                        0,
                                        0,
                                        0,
                                        0,
                                        1,
                                        0,
                                        0,
                                        0,
                                        0,
                                        0,
                                        1,
                                        0,
                                      ],
                              ),
                              child: TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.vetosanya.app',
                              ),
                            ),
                            if (_showDemand)
                              PolygonLayer(
                                polygons: [
                                  for (final zone in nearby.where(
                                    (z) => z.ring.length >= 3,
                                  ))
                                    Polygon(
                                      points: zone.ring,
                                      color: Color.lerp(
                                        Color(0x33F5B93A),
                                        Color(0x55E74F4F),
                                        ((zone.multiplier - 1) / .30)
                                            .clamp(0, 1)
                                            .toDouble(),
                                      )!,
                                      borderColor: Color(0x99F3AD3C),
                                      borderStrokeWidth: 1.2,
                                    ),
                                ],
                              ),
                            if (_showDemand)
                              CircleLayer(
                                circles: [
                                  for (final zone in nearby)
                                    CircleMarker(
                                      point: zone.center!,
                                      radius: 29,
                                      color: Color.lerp(
                                        Color(0x66F6BF47),
                                        Color(0x88E94A4A),
                                        ((zone.multiplier - 1) / .30)
                                            .clamp(0, 1)
                                            .toDouble(),
                                      )!,
                                      borderColor: Color(0x99FFD572),
                                      borderStrokeWidth: 1,
                                    ),
                                ],
                              ),
                            MarkerLayer(
                              markers: [
                                if (point != null)
                                  Marker(
                                    point: point,
                                    width: 45,
                                    height: 45,
                                    child: Icon(
                                      Icons.my_location_rounded,
                                      color: Color(0xFF4DA8FF),
                                      size: 30,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black87,
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                for (final zone in nearby)
                                  Marker(
                                    point: zone.center!,
                                    width: 90,
                                    height: 43,
                                    child: Container(
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainer,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: _gold),
                                      ),
                                      child: Text(
                                        _hotDemand.containsKey(zone.id)
                                            ? context
                                                  .strings
                                                  .captainMapHighDemand
                                            : '×${zone.multiplier.toStringAsFixed(1)}',
                                        style: TextStyle(
                                          color: _gold,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            RichAttributionWidget(
                              attributions: [
                                TextSourceAttribution(
                                  '© OpenStreetMap contributors',
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  left: 10,
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.online
                                  ? Icons.wifi_tethering_rounded
                                  : Icons.pause_circle_outline,
                              size: 16,
                              color: widget.online
                                  ? Color(0xFF68D8B0)
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                            SizedBox(width: 6),
                            Text(
                              widget.online
                                  ? context.strings.captainMapConnected
                                  : context.strings.captainMapOffline,
                              style: TextStyle(
                                
                                fontSize: 10,
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Spacer(),
                      Material(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                        child: IconButton(
                          onPressed: widget.onOpenDemandMap,
                          tooltip: context.strings.captainMapOpen,
                          icon: Icon(Icons.layers_rounded, color: _gold),
                        ),
                      ),
                    ],
                  ),
                ),
                if (point == null)
                  Positioned(
                    bottom: 9,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        context.strings.captainMapMissingLocation,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(12, 13, 12, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.local_fire_department_rounded, color: _gold),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context.strings.captainMapHotspots,
                        style: TextStyle(
                          
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: _showDemand,
                      onChanged: _toggle,
                      activeTrackColor: Color(0xFF137F5D),
                    ),
                  ],
                ),
                if (_showDemand) ...[
                  SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 3,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        context.strings.captainMapRange,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          
                          fontSize: 11,
                        ),
                      ),
                      for (final radius in [5, 10, 15])
                        ChoiceChip(
                          label: Text(
                            context.strings.captainMapKilometres('$radius'),
                            style: TextStyle( fontSize: 10),
                          ),
                          selected: _radiusKm == radius,
                          onSelected: (_) => _changeRadius(radius),
                          selectedColor: _gold,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainer,
                          labelStyle: TextStyle(
                            color: _radiusKm == radius
                                ? _navy
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      IconButton(
                        onPressed: _loading ? null : _refresh,
                        tooltip: context.strings.captainMapRefresh,
                        icon: Icon(
                          Icons.refresh_rounded,
                          color: _loading
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : _gold,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 7),
                  Row(
                    children: [
                      _littleStat(
                        context.strings.captainMapNearby,
                        point == null ? '—' : '${nearby.length}',
                        valueColor: _gold,
                      ),
                      SizedBox(width: 7),
                      _littleStat(
                        context.strings.captainMapMultiplier,
                        nearby.where((z) => z.multiplier > 1).isEmpty
                            ? '—'
                            : '×${nearby.where((z) => z.multiplier > 1).first.multiplier.toStringAsFixed(1)}',
                        valueColor: _gold,
                      ),
                      SizedBox(width: 7),
                      _littleStat(
                        context.strings.captainMapSearchRange,
                        context.strings.captainMapKilometres('$_radiusKm'),
                      ),
                    ],
                  ),
                  for (final zone in nearby.take(3))
                    Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            color: _gold,
                            size: 15,
                          ),
                          SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              zone.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            zone.row['demand'] == null
                                ? context.strings.captainMapRequests('—')
                                : context.strings.captainMapRequests(
                                    '${_hotDemand[zone.id] ?? zone.row['demand']}',
                                  ),
                            style: TextStyle(
                              
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            _hotDemand.containsKey(zone.id)
                                ? context.strings.captainMapHighDemand
                                : '×${zone.multiplier.toStringAsFixed(1)}',
                            style: TextStyle(
                              color: _gold,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_failed)
                    Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: Text(
                        context.strings.captainMapDemandError,
                        style: TextStyle(
                          
                          fontSize: 10,
                          color: Colors.orangeAccent,
                        ),
                      ),
                    ),
                  if (_lastUpdated != null)
                    Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: Text(
                        context.strings.captainMapUpdated(
                          TimeOfDay.fromDateTime(_lastUpdated!).format(context),
                        ),
                        style: TextStyle(
                          
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: widget.onOpenDemandMap,
                    icon: Icon(Icons.open_in_full_rounded, size: 17),
                    label: Text(
                      context.strings.captainMapOpenFull,
                      style: TextStyle( fontSize: 12),
                    ),
                    style: TextButton.styleFrom(foregroundColor: _gold),
                  ),
                ] else
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      context.strings.captainMapEnable,
                      style: TextStyle(
                        
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
