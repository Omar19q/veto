import 'dart:async';
import 'package:flutter/material.dart';
import '../../../widgets/openfreemap_surface.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../l10n/strings.dart';
import '../../../services/supabase_service.dart';
import '../../../services/foreground_refresh_loop.dart';

class ProductSearchingView extends StatefulWidget {
  const ProductSearchingView({
    super.key,
    required this.tripId,
    required this.pickupLabel,
    required this.destinationLabel,
    required this.pickup,
    required this.destination,
    required this.onRefresh,
    required this.onCancel,
    required this.onHome,
    required this.price,
    required this.offerControls,
    this.loadSnapshot,
    this.searchStarted,
  });
  final String tripId, pickupLabel, destinationLabel;
  final LatLng pickup;
  final LatLng? destination;
  final Future<void> Function() onRefresh;
  final VoidCallback onCancel, onHome;
  final Widget price, offerControls;
  final Future<dynamic> Function(String tripId)? loadSnapshot;
  final DateTime? searchStarted;
  @override
  State<ProductSearchingView> createState() => _ProductSearchingViewState();
}

class _ProductSearchingViewState extends State<ProductSearchingView>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _snapshot;
  late final ForegroundRefreshLoop _refreshLoop;
  bool _loading = false, _failed = false;
  bool _refreshing = false;
  int _revision = 0;
  Timer? _elapsedTimer;
  void _startClock() {
    _elapsedTimer?.cancel();
    if (widget.searchStarted == null) return;
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant ProductSearchingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tripId != widget.tripId) {
      _revision++;
      _snapshot = null;
      _failed = false;
      _loading = false;
      _load();
      _startClock();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshLoop = ForegroundRefreshLoop(
      refresh: _load,
      interval: const Duration(seconds: 10),
    );
    _refreshLoop.setForeground(
      WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    );
    if (_refreshLoop.isForeground) _startClock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _refreshLoop.setForeground(state == AppLifecycleState.resumed);
    if (state != AppLifecycleState.resumed && mounted) {
      _elapsedTimer?.cancel();
      // Availability is not confirmed while the app is away. Restoration must
      // fetch the existing server trip; it never creates another request.
      _revision++;
      _loading = false;
      setState(() => _snapshot = null);
    } else if (state == AppLifecycleState.resumed) {
      _startClock();
      // A request started before suspension must not delay restoration.
      _load();
    }
  }

  @override
  void dispose() {
    _revision++;
    _elapsedTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _refreshLoop.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted || !_refreshLoop.isForeground || _loading) return;
    _loading = true;
    final revision = _revision;
    final tripId = widget.tripId;
    try {
      final raw =
          await (widget.loadSnapshot?.call(tripId) ??
                  SupabaseService.instance.client.rpc(
                    'v51_customer_search_snapshot',
                    params: {'p_trip': tripId},
                  ))
              .timeout(const Duration(seconds: 8));
      if (raw is! Map) throw StateError('invalid_dispatch_snapshot');
      if (mounted && _refreshLoop.isForeground && revision == _revision)
        setState(() {
          _snapshot = Map<String, dynamic>.from(raw);
          _failed = false;
        });
    } catch (_) {
      if (mounted && revision == _revision) {
        setState(() {
          // Availability is short-lived. Never display stale captain clusters
          // after a failed refresh, including loss of internet connectivity.
          _snapshot = null;
          _failed = true;
        });
      }
    } finally {
      if (revision == _revision) _loading = false;
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    final revision = _revision;
    setState(() => _refreshing = true);
    try {
      await widget.onRefresh().timeout(const Duration(seconds: 15));
      if (mounted && revision == _revision) await _load();
    } catch (error) {
      debugPrint('Search status refresh failed: ${error.runtimeType}');
      if (mounted && revision == _revision) {
        setState(() {
          _snapshot = null;
          _failed = true;
        });
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.strings, colors = Theme.of(context).colorScheme;
    final radius = _snapshot?['last_offered_radius_m'];
    final offers = _snapshot?['offers_created'];
    final points = (_snapshot?['approximate_clusters'] as List? ?? [])
        .whereType<Map>();
    final elapsed = widget.searchStarted == null
        ? null
        : DateTime.now()
              .difference(widget.searchStarted!)
              .inSeconds
              .clamp(0, 86400);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.searching),
        leading: IconButton(
          tooltip: l.home,
          onPressed: widget.onHome,
          icon: const Icon(Icons.home_outlined),
        ),
        actions: [
          IconButton(
            tooltip: l.refresh,
            onPressed: _refreshing ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: OpenFreeMapSurface.enabled
                ? OpenFreeMapSurface(
                    center: widget.pickup,
                    points: [
                      widget.pickup,
                      if (widget.destination != null) widget.destination!,
                      for (final c in points)
                        if (c['latitude'] is num &&
                            c['longitude'] is num &&
                            c['count'] is num &&
                            (c['count'] as num) >= 3)
                          LatLng(
                            (c['latitude'] as num).toDouble(),
                            (c['longitude'] as num).toDouble(),
                          ),
                    ],
                  )
                : FlutterMap(
                    options: MapOptions(
                      initialCenter: widget.pickup,
                      initialZoom: 14,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.vetosanya.app',
                      ),
                      if (radius is num && radius > 0 && radius.isFinite)
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: widget.pickup,
                              radius: radius.toDouble(),
                              useRadiusInMeter: true,
                              color: colors.primary.withAlpha(25),
                              borderColor: colors.primary.withAlpha(90),
                              borderStrokeWidth: 1,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: widget.pickup,
                            child: Icon(
                              Icons.my_location,
                              color: colors.primary,
                              size: 32,
                            ),
                          ),
                          if (widget.destination != null)
                            Marker(
                              point: widget.destination!,
                              child: Icon(
                                Icons.flag_outlined,
                                color: colors.onSurface,
                                size: 32,
                              ),
                            ),
                          for (final c in points)
                            if (c['latitude'] is num &&
                                c['longitude'] is num &&
                                (c['latitude'] as num).isFinite &&
                                (c['longitude'] as num).isFinite &&
                                (c['latitude'] as num).abs() <= 90 &&
                                (c['longitude'] as num).abs() <= 180 &&
                                c['count'] is num &&
                                (c['count'] as num).isFinite &&
                                (c['count'] as num) >= 3)
                              Marker(
                                point: LatLng(
                                  (c['latitude'] as num).toDouble(),
                                  (c['longitude'] as num).toDouble(),
                                ),
                                width: 52,
                                height: 36,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: colors.surface,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text('${c['count']} 🚗'),
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
          ),
          Flexible(
            flex: 0,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .43,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (elapsed != null)
                      Text(
                        l.searchElapsed(
                          '${elapsed ~/ 60}:${(elapsed % 60).toString().padLeft(2, '0')}',
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    Text(
                      '${widget.pickupLabel} → ${widget.destinationLabel}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Price is based on the actual persisted trip, not a guess.

                    if (offers is num && offers.isFinite && offers > 0)
                      Text('${l.offersDelivered}: ${offers.toInt()}'),
                    if (radius is num && radius.isFinite && radius > 0)
                      Text(
                        '${l.deliveredSearchRadius}: ${(radius / 1000).toStringAsFixed(1)} km',
                      ),
                    if (_failed)
                      Text(
                        l.bookingStatusUnavailable,
                        style: TextStyle(color: colors.error),
                      ),
                    widget.price,
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('عايز تزود عرضك؟'),
                      subtitle: Text(l.higherOfferHelp,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall),
                      children: [widget.offerControls],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.searchCancelFree,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onCancel,
                          icon: const Icon(Icons.close),
                          label: Text(l.cancel),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _refreshing ? null : _refresh,
                          icon: const Icon(Icons.refresh),
                          label: Text(l.refresh),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
