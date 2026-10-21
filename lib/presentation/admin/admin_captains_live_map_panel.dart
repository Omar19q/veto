import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/supabase_service.dart';
import '../../theme/admin_theme.dart';

enum _CaptainMapFilter { all, car, motorcycle, available, busy, market, trips }

class AdminCaptainsLiveMapPanel extends StatefulWidget {
  const AdminCaptainsLiveMapPanel({super.key});

  @override
  State<AdminCaptainsLiveMapPanel> createState() =>
      _AdminCaptainsLiveMapPanelState();
}

class _AdminCaptainsLiveMapPanelState extends State<AdminCaptainsLiveMapPanel> {
  static final _freshFor = Duration(minutes: 2);
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _captains = [];
  _CaptainMapFilter _filter = _CaptainMapFilter.all;
  TripRealtimeLease? _channel;
  Timer? _clock;
  bool _loading = true;
  String? _error;
  LatLngBounds? _bounds;
  Timer? _windowDebounce;
  bool _inFlight = false;
  bool _dirty = false;
  void _scheduleWindow() {
    _windowDebounce ??= Timer(const Duration(seconds: 2), () {
      _windowDebounce = null;
      if (mounted) _load();
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
    _channel = SupabaseService.instance.subscribeToCaptainStatus(
      (_) => _scheduleWindow(),
    );
    _clock = Timer.periodic(Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _clock?.cancel();
    _windowDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_inFlight) {
      _dirty = true;
      return;
    }
    _inFlight = true;
    try {
      final data = await SupabaseService.instance.getCaptainsForLiveMap(
        south: _bounds?.south ?? 29.88,
        north: _bounds?.north ?? 30.08,
        west: _bounds?.west ?? 31.02,
        east: _bounds?.east ?? 31.23,
      );
      if (!mounted) return;
      setState(() {
        _captains = data;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل مواقع الكباتن. تأكد من صلاحيات حساب الأدمن.';
      });
    } finally {
      _inFlight = false;
      if (_dirty && mounted) {
        _dirty = false;
        _scheduleWindow();
      }
    }
  }

  double? _number(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');

  DateTime? _updatedAt(Map<String, dynamic> captain) => DateTime.tryParse(
    captain['location_updated_at']?.toString() ?? '',
  )?.toLocal();

  bool _validCoordinates(Map<String, dynamic> captain) {
    final lat = _number(captain['current_latitude']);
    final lng = _number(captain['current_longitude']);
    return lat != null &&
        lng != null &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180 &&
        !(lat == 0 && lng == 0);
  }

  bool _isLive(Map<String, dynamic> captain) {
    final updated = _updatedAt(captain);
    return captain['captain_status']?.toString() == 'active' &&
        captain['is_online'] == true &&
        _validCoordinates(captain) &&
        updated != null &&
        DateTime.now().difference(updated) <= _freshFor;
  }

  bool _matchesFilter(Map<String, dynamic> captain) {
    switch (_filter) {
      case _CaptainMapFilter.all:
        return true;
      case _CaptainMapFilter.car:
        return captain['vehicle_type']?.toString() == 'car';
      case _CaptainMapFilter.motorcycle:
        return captain['vehicle_type']?.toString() == 'motorcycle';
      case _CaptainMapFilter.available:
        return captain['is_available'] == true;
      case _CaptainMapFilter.busy:
        return captain['is_available'] != true;
      case _CaptainMapFilter.market:
        return captain['can_do_vito_market'] == true;
      case _CaptainMapFilter.trips:
        return captain['can_do_car_ride'] == true ||
            captain['can_do_motorcycle_ride'] == true ||
            captain['can_do_package'] == true;
    }
  }

  List<Map<String, dynamic>> get _visible {
    final query = _searchController.text.trim().toLowerCase();
    return _captains.where((captain) {
      if (!_validCoordinates(captain) || !_matchesFilter(captain)) return false;
      if (captain['captain_status']?.toString() != 'active' ||
          captain['is_online'] != true) {
        return false;
      }
      if (query.isEmpty) return true;
      final haystack = '${captain['full_name'] ?? ''} ${captain['phone'] ?? ''}'
          .toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  String _ageLabel(Map<String, dynamic> captain) {
    final updated = _updatedAt(captain);
    if (updated == null) return 'لا يوجد تحديث صالح';
    final age = DateTime.now().difference(updated);
    if (age.isNegative || age.inSeconds < 10) return 'الآن';
    if (age.inMinutes < 1) return 'منذ ${age.inSeconds} ثانية';
    if (age.inHours < 1) return 'منذ ${age.inMinutes} دقيقة';
    if (age.inDays < 1) return 'منذ ${age.inHours} ساعة';
    return 'منذ ${age.inDays} يوم';
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final liveCount = visible.where(_isLive).length;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              _header(liveCount, visible.length - liveCount),
              SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
                decoration: InputDecoration(
                  hintText: 'بحث باسم الكابتن أو رقم الهاتف',
                  prefixIcon: Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: Icon(Icons.close_rounded),
                        ),
                ),
              ),
              SizedBox(height: 10),
              _filters(),
              SizedBox(height: 10),
              Expanded(child: _map(visible)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(int live, int stale) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'خريطة الكباتن الحيّة',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AdminTheme.ink,
              ),
            ),
            Text(
              'نشط الآن: $live  •  موقع قديم: $stale',
              style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.muted),
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'تحديث',
        onPressed: _load,
        icon: Icon(Icons.refresh_rounded, color: AdminTheme.goldDark),
      ),
    ],
  );

  Widget _filters() {
    final labels = {
      _CaptainMapFilter.all: 'الكل',
      _CaptainMapFilter.car: 'سيارة',
      _CaptainMapFilter.motorcycle: 'موتوسيكل',
      _CaptainMapFilter.available: 'متاح',
      _CaptainMapFilter.busy: 'مشغول',
      _CaptainMapFilter.market: 'Market',
      _CaptainMapFilter.trips: 'رحلات',
    };
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: labels.entries
            .map(
              (entry) => Padding(
                padding: EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(
                  label: Text(
                    entry.value,
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                  selected: _filter == entry.key,
                  onSelected: (_) => setState(() => _filter = entry.key),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _map(List<Map<String, dynamic>> visible) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: AdminTheme.goldDark),
      );
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Cairo', color: Colors.redAccent),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(29.9811, 31.1328),
              initialZoom: 12.5,
              onPositionChanged: (camera, _) {
                _bounds = camera.visibleBounds;
                _scheduleWindow();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.vetosanya.app',
              ),
              MarkerLayer(
                markers: visible.map((captain) {
                  final live = _isLive(captain);
                  final motorcycle =
                      captain['vehicle_type']?.toString() == 'motorcycle';
                  return Marker(
                    point: LatLng(
                      _number(captain['current_latitude'])!,
                      _number(captain['current_longitude'])!,
                    ),
                    width: 132,
                    height: 66,
                    child: GestureDetector(
                      onTap: () => _showCaptain(captain),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: live
                                  ? AdminTheme.goldDark
                                  : Colors.blueGrey.shade700,
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: [
                                BoxShadow(color: Colors.black38, blurRadius: 5),
                              ],
                            ),
                            child: Text(
                              captain['full_name']?.toString() ?? 'كابتن',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0B0F1A),
                              ),
                            ),
                          ),
                          Icon(
                            motorcycle
                                ? Icons.two_wheeler_rounded
                                : Icons.directions_car_rounded,
                            size: 32,
                            color: live
                                ? AdminTheme.goldDark
                                : Colors.blueGrey.shade400,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 4),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          if (visible.isEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: EdgeInsets.all(14),
                    color: AdminTheme.surface.withAlpha(230),
                    child: Text(
                      'لا توجد نتائج مطابقة',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: AdminTheme.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showCaptain(Map<String, dynamic> captain) {
    final live = _isLive(captain);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AdminTheme.surface,
      showDragHandle: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  captain['full_name']?.toString() ?? 'كابتن',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AdminTheme.ink,
                  ),
                ),
                SizedBox(height: 10),
                _detail('الهاتف', captain['phone']?.toString() ?? '—'),
                _detail(
                  'المركبة',
                  captain['vehicle_type']?.toString() == 'motorcycle'
                      ? 'موتوسيكل'
                      : 'سيارة',
                ),
                _detail('الحالة', live ? 'Live' : 'الموقع غير حي'),
                _detail(
                  'التوفر',
                  captain['is_available'] == true ? 'متاح' : 'مشغول',
                ),
                _detail('آخر تحديث', _ageLabel(captain)),
                _detail(
                  'Market',
                  captain['can_do_vito_market'] == true ? 'مفعّل' : 'غير مفعّل',
                ),
                _detail(
                  'الرحلات',
                  (captain['can_do_car_ride'] == true ||
                          captain['can_do_motorcycle_ride'] == true)
                      ? 'مفعّلة'
                      : 'غير مفعّلة',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.muted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w700,
              color: AdminTheme.ink,
            ),
          ),
        ),
      ],
    ),
  );
}
