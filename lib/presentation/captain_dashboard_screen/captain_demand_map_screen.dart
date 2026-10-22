import '../../l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/zone_pricing_service.dart';
import '../../services/foreground_refresh_loop.dart';
import '../../theme/app_theme.dart';

class CaptainDemandMapScreen extends StatefulWidget {
  const CaptainDemandMapScreen({super.key});
  @override
  State<CaptainDemandMapScreen> createState() => _CaptainDemandMapScreenState();
}

class _CaptainDemandMapScreenState extends State<CaptainDemandMapScreen>
    with WidgetsBindingObserver {
  List<PricingZone> zones = [];
  Map<String, int> hotDemand = const {};
  RealtimeChannel? channel;
  late final ForegroundRefreshLoop _refreshLoop;
  final MapController map = MapController();
  bool busy = false, ready = false;
  String? error;
  DateTime? updated;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshLoop = ForegroundRefreshLoop(
      refresh: _load, interval: const Duration(seconds: 60));
    _refreshLoop.setForeground(WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);
    channel = ZonePricingService.instance.db
        .channel('zone-pressure-${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'pricing_zones',
          callback: (_) => _refreshLoop.notifyChanged(),
        )
        .subscribe();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _refreshLoop.setForeground(state == AppLifecycleState.resumed);
  }

  Future<void> _load() async {
    if (!mounted || busy) return;
    busy = true;
    try {
      final result = await ZonePricingService.instance.zones();
      final alerts = await ZonePricingService.instance.activeDemandAlerts();
      final nextDemand = <String, int>{};
      for (final alert in alerts) {
        final id = alert['zone_id']?.toString();
        if (id != null) nextDemand[id] = (alert['waiting_count'] as num?)?.toInt() ?? 0;
      }
      if (mounted)
        setState(() {
          zones = result;
          hotDemand = nextDemand;
          ready = true;
          error = null;
          updated = DateTime.now();
        });
    } catch (_) {
      if (mounted)
        setState(() => error = 'تعذر تحديث الضغط. اسحب للتحديث أو حاول تاني.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  bool fresh(PricingZone z) {
    final time = DateTime.tryParse('${z.row['surge_updated_at']}');
    return time != null &&
        DateTime.now().toUtc().difference(time.toUtc()).inSeconds < 120;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshLoop.dispose();
    channel?.unsubscribe();
    map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hot =
        zones
            .where(
              (z) =>
                  !z.global && z.center != null &&
              (hotDemand.containsKey(z.id) || (z.multiplier > 1 && fresh(z))),
            )
            .toList()
          ..sort((a, b) => b.multiplier.compareTo(a.multiplier));
    final best = hot.isEmpty ? null : hot.first;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: Directionality.of(context),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(context.strings.demandMapTitle,
            style: TextStyle( fontWeight: FontWeight.w800)),
          actions: [
            IconButton(onPressed: _refreshLoop.request, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: ready
                  ? FlutterMap(
                      mapController: map,
                      options: MapOptions(
                        initialCenter:
                            best?.center ?? const LatLng(29.974, 31.101),
                        initialZoom: 13.5,
                      ),
                      children: [
                        ColorFiltered(colorFilter: const ColorFilter.matrix([
                  -.53, 0, 0, 0, 125,
                  0, -.53, 0, 0, 137,
                  0, 0, -.53, 0, 155,
                  0, 0, 0, 1, 0,
                ]),
                          child: TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.vetosanya.app',
                          )),
                        PolygonLayer(
                          polygons: [
                            for (final z
                                in hot.where((z) => z.ring.length >= 3))
                              Polygon(
                                points: z.ring,
                                color: Color.lerp(
                                  const Color(0x22FFAA44),
                                  const Color(0x44EF4D47),
                                  (z.multiplier - 1).clamp(0.0, 1.0).toDouble(),
                                )!,
                                borderColor: const Color(0x88EF8B53),
                                borderStrokeWidth: 1,
                              ),
                          ],
                        ),
                        CircleLayer(
                          circles: [
                            for (final z in hot)
                              CircleMarker(
                                point: z.center!,
                                radius: (44 +
                                        ((z.multiplier - 1).clamp(0.0, 1.0) * 26))
                                    .toDouble(),
                                color: Color.lerp(
                                  const Color(0x55FFAA44),
                                  const Color(0x99EF4D47),
                                  (z.multiplier - 1).clamp(0.0, 1.0).toDouble(),
                                )!,
                                borderColor: const Color(0xAAFF8A3D),
                                borderStrokeWidth: 2,
                              ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            for (final z in hot)
                              Marker(
                                point: z.center!,
                                width: 64,
                                height: 64,
                                child: Tooltip(
                                  message:
                                      '${z.name} • ${hotDemand.containsKey(z.id) ? context.strings.demandHigh : context.strings.demandMultiplier(z.multiplier.toStringAsFixed(2))}',
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Color(0xFFFF8A3D),
                                    size: 34,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        RichAttributionWidget(
                          attributions: [
                            TextSourceAttribution('© OpenStreetMap contributors'),
                          ],
                        ),
                      ],
                    )
                  : Center(child: CircularProgressIndicator()),
            ),
            Positioned(
              top: 16,
              right: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xED142239),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 24),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: AppTheme.gold,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          context.strings.demandNow,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.strings.demandExplanation,
                      style: TextStyle(color: Color(0xFFB9C6D8), fontSize: 12),
                    ),
                    if (error != null)
                      Text(
                        error!,
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 10),
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0x55FFAA44),
                            Color(0x99FF7838),
                            Color(0xCCEF4D47),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.strings.demandLower,
                          style: TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                        Text(
                          updated == null ? context.strings.demandUpdating : context.strings.demandEveryMinute,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          context.strings.demandHigher,
                          style: TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 22,
              right: 16,
              left: 16,
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? const [Color(0xFF25324B), Color(0xFF152137)]
                          : [
                              colorScheme.surface,
                              colorScheme.surfaceContainerHighest,
                            ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.gold.withAlpha(100)
                          : colorScheme.outlineVariant,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 28,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        best == null
                            ? context.strings.demandNone
                            : hotDemand.containsKey(best.id)
                                ? context.strings.demandHighArea(best.name)
                                : context.strings.demandAreaMultiplier(best.name, best.multiplier.toStringAsFixed(2)),
                        style: const TextStyle(
                          
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        best == null
                            ? context.strings.demandStayAvailable
                            : hotDemand.containsKey(best.id)
                                ? context.strings.demandWaiting(hotDemand[best.id]?.toString() ?? '—')
                                : context.strings.demandSnapshot(best.row['demand']?.toString() ?? '—',best.row['supply']?.toString() ?? '—'),
                        style: const TextStyle(
                          
                          color: Color(0xFFB9C6D8),
                          fontSize: 12,
                        ),
                      ),
                      if (best != null) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.gold,
                              foregroundColor: AppTheme.primary,
                            ),
                            onPressed: () async {
                              final point = best.center!;
                              map.move(point, 14);
                              final uri =
                                  Uri.https('www.google.com', '/maps/dir/', {
                                    'api': '1',
                                    'destination':
                                        '${point.latitude},${point.longitude}',
                                    'travelmode': 'driving',
                                  });
                              if (!await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  ) &&
                                  context.mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(context.strings.demandDirectionsFailed),
                                  ),
                                );
                            },
                            icon: const Icon(Icons.near_me_outlined),
                            label: Text(
                              context.strings.demandDirections,
                              style: TextStyle(
                                
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
