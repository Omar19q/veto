import '../../../widgets/booking_area_picker_v19.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../services/zone_pricing_service.dart';
import 'booking_pin_picker_v36.dart';
import '../../../services/product_geocoding_service.dart';

import '../../../l10n/strings.dart';
import '../../../services/place_search_service.dart';
import '../../../services/hybrid_place_search_service.dart';
import '../../../services/supabase_service.dart';
import '../../../services/booking_address_seed.dart';
import '../../../widgets/place_category_icons.dart';
import 'booking_favorites_widget.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/v37_suggest_address_button.dart';
import '../../../widgets/booking_city_places_v39.dart';
import '../../../services/customer_city_scope_v38.dart';

class BookingDestinationSheetWidget extends StatefulWidget {
  final String pickupLabel;
  final String? pickupAreaLetter;
  final double? pickupLat;
  final double? pickupLng;
  final String? customerId;

  final FutureOr<void> Function(
    String label,
    double distance,
    double duration, {
    double? lat,
    double? lng,
    String? areaLetter,
    String? buildingNumber,
    double? fare,
    List<List<double>>? routePoints,
    bool outsideCity,
  })
  onDestinationSelected;

  const BookingDestinationSheetWidget({
    super.key,
    required this.pickupLabel,
    this.pickupAreaLetter,
    this.pickupLat,
    this.pickupLng,
    this.customerId,
    required this.onDestinationSelected,
  });

  @override
  State<BookingDestinationSheetWidget> createState() =>
      _BookingDestinationSheetWidgetState();
}

class _BookingDestinationSheetWidgetState
    extends State<BookingDestinationSheetWidget> {
  static const List<String> _areas = <String>[
    'أ',
    'ب',
    'ج',
    'د',
    'هـ',
    'و',
    'ز',
    'ح',
    'ط',
    'ك',
    'ل',
    'م',
    'ن',
    'ع',
    'س',
    'ص',
  ];

  List<Map<String, dynamic>> _categories = [
    {'slug': 'all', 'title': 'الكل', 'icon_key': 'apps'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadRecents();
  }

  Future<void> _loadCategories() async {
    try {
      final rows = await SupabaseService.instance.getPlaceCategoriesV21();
      if (!mounted) return;
      setState(
        () => _categories = [
          {'slug': 'all', 'title': 'الكل', 'icon_key': 'apps'},
          ...rows,
        ],
      );
    } catch (_) {
      if (mounted) setState(() => _error = context.strings.ui74cafc32);
    }
  }

  List<BookingAddressSeed> _recentDestinations = [];
  Future<void> _loadRecents() async {
    final id = widget.customerId;
    if (id == null) return;
    try {
      final trips = await SupabaseService.instance.getCustomerTrips(id, limit: 12);
      if (!mounted || id != widget.customerId) return;
      final seen = <String>{};
      setState(() => _recentDestinations = trips
        .map(BookingAddressSeed.recent)
        .whereType<BookingAddressSeed>()
        .where((a) => seen.add('${a.latitude},${a.longitude}'))
        .take(3).toList());
    } catch (_) { /* Recent destinations are an optional convenience. */ }
  }

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _buildingSearchController =
      TextEditingController();
  Timer? _debounce;
  int _searchRevision = 0;
  Timer? _buildingDebounce;

  int _mode = 0; // Search immediately; secondary choices are compact shortcuts.
  String _category = 'all';
  String? _selectedArea;
  String? _selectedBuilding;
  double? _selectedBuildingLat;
  double? _selectedBuildingLng;
  Map<String, dynamic>? _selectedPlace;

  bool _loadingSearch = false;
  bool _loadingPlaces = false;
  bool _loadingBuildings = false;
  bool _calculatingRoute = false;

  List<PlaceSearchResult> _searchResults = <PlaceSearchResult>[];
  List<Map<String, dynamic>> _famousPlaces = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _buildings = <Map<String, dynamic>>[];

  String? _error;

  @override
  void dispose() {
    ++_searchRevision;
    _debounce?.cancel();
    _buildingDebounce?.cancel();
    _searchController.dispose();
    _buildingSearchController.dispose();
    super.dispose();
  }

  void _setMode(int mode) {
    ++_searchRevision;
    _debounce?.cancel();
    setState(() {
      _mode = mode;
      _loadingSearch = false;
      _error = null;
      _selectedPlace = null;
      _selectedBuilding = null;
      _selectedBuildingLat = null;
      _selectedBuildingLng = null;
      _searchResults = <PlaceSearchResult>[];
      if (mode != 2) {
        _selectedArea = null;
        _buildingSearchController.clear();
        _buildings = <Map<String, dynamic>>[];
      }
      if (mode != 0 && mode != 3) {
        _searchController.clear();
      }
    });

    if (mode == 1 && _famousPlaces.isEmpty) {
      _loadFamousPlaces();
    }
  }

  void _onSearchChanged(String value) {
    ++_searchRevision;
    setState(() {
      _searchResults = [];
      _error = null;
      _loadingSearch = value.trim().length >= 2;
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 550), _runSearch);
  }

  Future<void> _runSearch() async {
    final revision = _searchRevision;
    final query = _searchController.text.trim();

    if (query.length < 2) {
      if (mounted) {
        setState(() {
          _searchResults = <PlaceSearchResult>[];
          _loadingSearch = false;
        });
      }
      return;
    }

    setState(() {
      _loadingSearch = true;
      _error = null;
    });

    try {
      final response = await HybridPlaceSearchService().search(
        query,
        onApproved: (rows) {
          if (mounted && revision == _searchRevision)
            setState(() => _searchResults = rows);
        },
      );
      if (!mounted || revision != _searchRevision) return;
      setState(() {
        _searchResults = response.results;
        _error = response.approvedUnavailable || response.externalUnavailable
            ? context.strings.addressSearchPartial
            : null;
      });
    } catch (_) {
      if (mounted && revision == _searchRevision)
        setState(() {
          _searchResults = [];
          _error = context.strings.addressSearchFailed;
        });
    } finally {
      if (mounted && revision == _searchRevision)
        setState(() => _loadingSearch = false);
    }
  }

  Future<void> _loadFamousPlaces() async {
    setState(() {
      _loadingPlaces = true;
      _error = null;
    });

    try {
      var result = await SupabaseService.instance.getFamousPlaces();
      if (widget.pickupLat != null && widget.pickupLng != null) {
        result = result.where((place) {
          final lat = double.tryParse(place['latitude']?.toString() ?? '');
          final lng = double.tryParse(place['longitude']?.toString() ?? '');
          return lat != null &&
              lng != null &&
              Geolocator.distanceBetween(
                    widget.pickupLat!,
                    widget.pickupLng!,
                    lat,
                    lng,
                  ) <=
                  15000;
        }).toList();
      } else {
        result = <Map<String, dynamic>>[];
      }
      if (!mounted) return;

      setState(() {
        _famousPlaces = result;
        _loadingPlaces = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadingPlaces = false;
        _error = context.strings.ui15cd2781;
      });
    }
  }

  Future<void> _loadBuildings(String area) async {
    setState(() {
      _selectedArea = area;
      _selectedBuilding = null;
      _selectedBuildingLat = null;
      _selectedBuildingLng = null;
      _buildings = <Map<String, dynamic>>[];
      _loadingBuildings = true;
      _error = null;
    });

    try {
      final result = await SupabaseService.instance.searchBuildingsForCustomer(
        areaLetter: area,
        searchQuery: '',
      );

      if (!mounted) return;

      setState(() {
        _buildings = result;
        _loadingBuildings = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadingBuildings = false;
        _error = context.strings.ui02609bec;
      });
    }
  }

  void _onBuildingSearchChanged(String value) {
    _buildingDebounce?.cancel();
    _buildingDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _runBuildingSearch(value),
    );
  }

  Future<void> _runBuildingSearch(String value) async {
    final query = value.trim();

    if (query.isEmpty) {
      if (_selectedArea != null) {
        await _loadBuildings(_selectedArea!);
      } else if (mounted) {
        setState(() => _buildings = <Map<String, dynamic>>[]);
      }
      return;
    }

    if (!RegExp(r'^\d+$').hasMatch(query)) {
      if (mounted) {
        setState(() {
          _error = 'اكتب رقم العمارة فقط في خانة البحث.';
          _buildings = <Map<String, dynamic>>[];
        });
      }
      return;
    }

    setState(() {
      _loadingBuildings = true;
      _error = null;
      _selectedBuilding = null;
      _selectedBuildingLat = null;
      _selectedBuildingLng = null;
    });

    try {
      final area = _selectedArea;
      final result = area == null
          ? await SupabaseService.instance.searchBuildingsGlobalForCustomer(
              searchQuery: query,
            )
          : await SupabaseService.instance.searchBuildingsForCustomer(
              areaLetter: area,
              searchQuery: query,
            );

      if (!mounted) return;

      setState(() {
        _buildings = result;
        _loadingBuildings = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingBuildings = false;
        _error = context.strings.ui39c9c0fc;
      });
    }
  }

  void _selectBuilding(Map<String, dynamic> building) {
    if (_calculatingRoute) return;
    setState(() {
      final area = building['area_letter']?.toString();
      if(area!=null && _areas.contains(area)) _selectedArea=area;
      _selectedBuilding = building['building_number']?.toString();
      _selectedBuildingLat = _number(building['latitude']);
      _selectedBuildingLng = _number(building['longitude']);
    });
    _confirmBuilding();
  }

  Future<void> _openManualMapV36() async {
    final point = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => BookingPinPickerV36(
          isDestination: true,
          initialLat: widget.pickupLat,
          initialLng: widget.pickupLng,
        ),
      ),
    );
    if (!mounted || point == null) return;
    // Server geometry decides the tariff; only the UI outside-city label is
    // derived here, never any locally calculated fare.
    bool outside = true;
    try {
      final zones = await Future.wait([
        ZonePricingService.instance.resolveCity(
          widget.pickupLat!,
          widget.pickupLng!,
        ),
        ZonePricingService.instance.resolveCity(
          point.latitude,
          point.longitude,
        ),
      ]);
      outside = zones[0]?.id != zones[1]?.id;
    } catch (_) {}
    if (!mounted) return;
    await _confirmWithRoute(
      label: point is ConfirmedMapPoint
          ? point.address
          : 'الموقع المحدد على الخريطة',
      lat: point.latitude,
      lng: point.longitude,
      outsideCity: outside,
    );
  }

  Future<void> _confirmSearchResult(PlaceSearchResult result) async {
    await _confirmWithRoute(
      label: result.name,
      lat: result.latitude,
      lng: result.longitude,
      areaLetter: result.areaLetter,
      buildingNumber: result.buildingNumber,
      outsideCity: _mode == 3,
    );
  }

  Future<void> _confirmFamousPlace() async {
    final place = _selectedPlace;
    if (place == null) return;

    final lat = _number(place['latitude']);
    final lng = _number(place['longitude']);

    if (lat == null || lng == null) {
      setState(() {
        _error = context.strings.ui0282b8e7;
      });
      return;
    }

    await _confirmWithRoute(
      label: (place['name'] ?? context.strings.ui46d9c9af).toString(),
      lat: lat,
      lng: lng,
      outsideCity: false,
    );
  }

  Future<void> _confirmBuilding() async {
    if (_selectedArea == null ||
        _selectedBuilding == null ||
        _selectedBuildingLat == null ||
        _selectedBuildingLng == null) {
      setState(() {
        _error = context.strings.ui700ee7bb;
      });
      return;
    }

    await _confirmWithRoute(
      label: context.strings.areaBuilding(
        _selectedArea ?? '',
        _selectedBuilding ?? '',
      ),
      lat: _selectedBuildingLat!,
      lng: _selectedBuildingLng!,
      areaLetter: _selectedArea,
      buildingNumber: _selectedBuilding,
      outsideCity: false,
    );
  }

  Future<void> _confirmWithRoute({
    required String label,
    required double lat,
    required double lng,
    String? areaLetter,
    String? buildingNumber,
    required bool outsideCity,
  }) async {
    if (_calculatingRoute) return;
    final pickupLat = widget.pickupLat;
    final pickupLng = widget.pickupLng;

    if (pickupLat == null || pickupLng == null) {
      setState(() {
        _error = context.strings.ui566d62bb;
      });
      return;
    }

    setState(() {
      _calculatingRoute = true;
      _error = null;
    });

    try {
      // Server quote computes real distance and price from these coordinates.
      // Avoid a redundant client route request before the same server operation.
      await widget.onDestinationSelected(
        label,
        0,
        0,
        lat: lat,
        lng: lng,
        areaLetter: areaLetter,
        buildingNumber: buildingNumber,
        outsideCity: outsideCity,
      );
    } catch (_) {
      if (mounted) setState(() => _error = context.strings.quoteFailed);
    } finally {
      if (mounted) setState(() => _calculatingRoute = false);
    }
  }

  double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  List<Map<String, dynamic>> get _filteredFamousPlaces {
    // Nearby picks only: avoid showing Hadayek landmarks as local to a
    // different city. Remote destinations remain available through search.
    final pickupLat = widget.pickupLat;
    final pickupLng = widget.pickupLng;
    final nearby = _famousPlaces.where((place) {
      if (pickupLat == null || pickupLng == null) return true;
      final lat = _number(place['latitude']);
      final lng = _number(place['longitude']);
      if (lat == null || lng == null) return false;
      return const Distance().as(
            LengthUnit.Meter,
            LatLng(pickupLat, pickupLng),
            LatLng(lat, lng),
          ) <=
          12000;
    }).toList();
    if (_category == 'all') {
      final visible = _categories.map((c) => c['slug']?.toString()).toSet();
      return nearby
          .where(
            (place) =>
                visible.contains(place['category']?.toString() ?? 'other'),
          )
          .toList();
    }

    return nearby.where((place) {
      return (place['category']?.toString() ?? 'other') == _category;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF212B40),
                borderRadius: BorderRadius.circular(19),
                border: Border.all(color: const Color(0xFFFFC642), width: 1.3),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFFFC642),
                    child: Icon(Icons.flag_rounded, color: Color(0xFF111725)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.strings.uic714374d,
                          style: TextStyle(
                            
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          context.strings.fromPickup(widget.pickupLabel),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            if (_mode == 0) ...[
              Wrap(spacing: 6, runSpacing: 5, children: [
                ActionChip(avatar: const Icon(Icons.map_outlined, size: 17),
                  label: const Text('الخريطة'), onPressed: _openManualMapV36),
                ActionChip(avatar: const Icon(Icons.star_border, size: 17),
                  label: const Text('المفضلة'), onPressed: () => _setMode(4)),
                ActionChip(avatar: const Icon(Icons.place_outlined, size: 17),
                  label: const Text('أماكن معروفة'), onPressed: () => _setMode(1)),
                if (CustomerCityScopeV38.isHadayek)
                  ActionChip(avatar: const Icon(Icons.apartment_outlined, size: 17),
                    label: const Text('العمارات'), onPressed: () => _setMode(2)),
                ActionChip(avatar: const Icon(Icons.public, size: 17),
                  label: const Text('مدينة تانية'), onPressed: () => _setMode(3)),
              ]),
              if (_recentDestinations.isNotEmpty && _searchController.text.isEmpty) ...[
                const SizedBox(height: 6),
                const Text('آخر وجهاتك', style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700)),
                ..._recentDestinations.take(2).map((a) => ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: const Icon(Icons.history, size: 19),
                  title: Text(a.label, maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                  onTap: _calculatingRoute ? null : () => _confirmWithRoute(
                    label: a.label, lat: a.latitude, lng: a.longitude,
                    areaLetter: a.areaLetter, buildingNumber: a.buildingNumber,
                    outsideCity: a.outsideCity,
                  ),
                )),
              ],
            ],
            if (_mode == -1) ...[
              Text(
                context.strings.uib70a4633,
                style: TextStyle(
                  
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              _buildModes(),
            ] else ...[
              if (_mode != 0) Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _setMode(0),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(
                    context.strings.uif36f493e,
                    style: TextStyle(
                      
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.gold),
                ),
              ),
              const SizedBox(height: 8),
              if (_mode == 0 || _mode == 3) _buildSearchMode(),
              if (_mode == 1) _buildFamousMode(),
              if (_mode == 2) _buildBuildingMode(),
              if (_mode == 4)
                BookingFavoritesWidget(
                  onSelected: (item) async {
                    final lat = _number(item['latitude']);
                    final lng = _number(item['longitude']);
                    if (lat == null || lng == null) return;
                    await _confirmWithRoute(
                      label:
                          item['display_address']?.toString() ??
                          context.strings.ui72de3382,
                      lat: lat,
                      lng: lng,
                      areaLetter: item['area_letter']?.toString(),
                      buildingNumber: item['building_number']?.toString(),
                      outsideCity: item['is_outside_city'] == true,
                    );
                  },
                ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  
                  color: AppTheme.errorLight,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DestinationOption(
          icon: Icons.map_rounded,
          label: context.strings.ui42f90d2d,
          subtitle: context.strings.ui3d03e800,
          onTap: () => _openManualMapV36(),
        ),
        const SizedBox(height: 10),
        if (const {
          'أ',
          'ب',
          'ج',
          'د',
          'هـ',
          'و',
          'ز',
          'ح',
          'ط',
          'ك',
          'ل',
          'م',
          'ن',
          'ع',
          'س',
          'ص',
        }.contains(widget.pickupAreaLetter))
          _DestinationOption(
            icon: Icons.location_city_rounded,
            label: context.strings.ui2a038421,
            subtitle: context.strings.ui018f341c,
            onTap: () => _setMode(2),
          ),
        const SizedBox(height: 10),
        _DestinationOption(
          icon: Icons.place_rounded,
          label: context.strings.ui947ac162,
          subtitle: context.strings.ui4f301aa9,
          onTap: () => _setMode(1),
        ),
        const SizedBox(height: 10),
        _DestinationOption(
          icon: Icons.star_rounded,
          label: context.strings.ui9f290894,
          subtitle: context.strings.uie2a404ff,
          onTap: () => _setMode(4),
        ),
        const SizedBox(height: 10),
        _DestinationOption(
          icon: Icons.public_rounded,
          label: context.strings.uif8b22ed8,
          subtitle: context.strings.ui955024f3,
          onTap: () => _setMode(3),
        ),
        if (!CustomerCityScopeV38.isHadayek)
          BookingCityPlacesV39(
            onSelected: (name, lat, lng) async {
              if (widget.pickupLat == null || widget.pickupLng == null) return;
              bool outside = true;
              try {
                final zones = await Future.wait([
                  ZonePricingService.instance.resolveCity(
                    widget.pickupLat!,
                    widget.pickupLng!,
                  ),
                  ZonePricingService.instance.resolveCity(lat, lng),
                ]);
                outside = zones[0]?.id != zones[1]?.id;
              } catch (_) {}
              if (!mounted) return;
              await _confirmWithRoute(
                label: name,
                lat: lat,
                lng: lng,
                outsideCity: outside,
              );
            },
          ),
        if (!CustomerCityScopeV38.isHadayek) ...[
          const SizedBox(height: 8),
          V37SuggestAddressButton(
            cityHint: CustomerCityScopeV38.name,
            isDestination: true,
          ),
        ],
      ],
    );
  }

  Widget _buildSearchMode() {
    final outside = _mode == 3;

    return Column(
      children: [
        if (outside)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppTheme.gold.withAlpha(18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.gold.withAlpha(70)),
            ),
            child: Text(
              context.strings.ui1e33ffb8,
              textAlign: TextAlign.center,
              style: TextStyle(
                
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          textDirection: Directionality.of(context),
          style: TextStyle(
            
            color: Theme.of(context).colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: outside
                ? context.strings.ui5ed8eb3d
                : context.strings.uidde5f7a4,
            hintStyle: TextStyle(
              
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_loadingSearch && _searchResults.isEmpty)
          const Padding(
            padding: EdgeInsets.all(18),
            child: CircularProgressIndicator(color: AppTheme.gold),
          )
        else if (_searchResults.isEmpty &&
            _searchController.text.trim().length >= 2)
          Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              context.strings.uib8818d2d,
              textAlign: TextAlign.center,
              style: TextStyle(
                
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          )
        else
          ..._searchResults.map(_searchTile),
      ],
    );
  }

  Widget _searchTile(PlaceSearchResult result) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        onTap: _calculatingRoute ? null : () => _confirmSearchResult(result),
        leading: const Icon(Icons.location_on_rounded, color: AppTheme.gold),
        title: Text(
          result.name,
          style: TextStyle(
            
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          result.address,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildFamousMode() {
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 126,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            mainAxisExtent: 88,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final cat = _categories[index];
            final slug = cat['slug']?.toString() ?? 'all';
            final selected = _category == slug;
            return Material(
              borderRadius: BorderRadius.circular(13),
              color: selected
                  ? AppTheme.gold
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: () => setState(() => _category = slug),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: selected
                          ? AppTheme.gold
                          : Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 5,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        PlaceCategoryIcons.get(cat['icon_key']?.toString()),
                        color: selected ? AppTheme.primary : AppTheme.gold,
                        size: 22,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        cat['title']?.toString() ?? slug,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          
                          fontSize: 11,
                          color: selected
                              ? AppTheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        if (_loadingPlaces)
          const Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(color: AppTheme.gold),
          )
        else if (_filteredFamousPlaces.isEmpty)
          Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              context.strings.ui19896675,
              textAlign: TextAlign.center,
              style: TextStyle(
                
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ..._filteredFamousPlaces.map(_famousTile),
      ],
    );
  }

  Widget _famousTile(Map<String, dynamic> place) {
    final selected = _selectedPlace?['id'] == place['id'];

    return GestureDetector(
      onTap: () {
        if (_calculatingRoute) return;
        setState(() => _selectedPlace = place);
        _confirmFamousPlace();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.gold.withAlpha(30)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected
                ? AppTheme.gold
                : Theme.of(context).colorScheme.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.place_rounded, color: AppTheme.gold),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (place['name'] ?? '').toString(),
                    style: TextStyle(
                      
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (place['address'] != null)
                    Text(
                      place['address'].toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        
                        fontSize: 9,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: context.strings.uibff694c6,
              icon: const Icon(Icons.star_border_rounded, color: AppTheme.gold),
              onPressed: () => saveBookingFavorite(
                context,
                name: place['name']?.toString() ?? context.strings.ui46d9c9af,
                displayAddress:
                    place['address']?.toString() ??
                    place['name']?.toString() ??
                    '',
                lat: _number(place['latitude']),
                lng: _number(place['longitude']),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: AppTheme.gold),
          ],
        ),
      ),
    );
  }

  Widget _areaPicker() => BookingAreaPickerV19(
    selected: _selectedArea,
    areas: _areas,
    placeLabel: context.strings.ui90754ad6,
    onSelected: (value) {
      if (value != _selectedArea) _loadBuildings(value);
    },
  );

  Widget _buildBuildingMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.strings.uide6f5aba,
          textAlign: TextAlign.right,
          style: TextStyle(
            
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),

        _areaPicker(),
        const SizedBox(height: 13),

        Text(
          context.strings.ui9ba6e611,
          textAlign: TextAlign.right,
          style: TextStyle(
            
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),

        TextField(
          controller: _buildingSearchController,
          onChanged: _onBuildingSearchChanged,
          keyboardType: TextInputType.number,
          textDirection: Directionality.of(context),
          textAlign: TextAlign.right,
          style: TextStyle(
            
            color: Theme.of(context).colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            hintText: context.strings.ui7af87c25,
            hintStyle: TextStyle(
              
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            suffixIcon: Icon(
              Icons.search_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
          ),
        ),

        const SizedBox(height: 12),

        if (_loadingBuildings)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.gold),
            ),
          )
        else if (_buildings.isEmpty &&
            _buildingSearchController.text.trim().isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text(
              context.strings.ui498edaea,
              textAlign: TextAlign.center,
              style: TextStyle(
                
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else if (_selectedArea != null && _buildings.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text(
              context.strings.ui23e4b967,
              textAlign: TextAlign.center,
              style: TextStyle(
                
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else if (_buildingSearchController.text.trim().isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              context.strings.ui533b3b9d,
              style: TextStyle(
                
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else ...[
          Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              context.strings.ui5d77e042,
              style: TextStyle(
                
                fontWeight: FontWeight.w800,
                color: AppTheme.gold,
              ),
            ),
          ),
          ..._buildings.take(30).map(_buildingTile),
          if (_buildings.length > 30)
            Text(
              context.strings.ui6b9fed40,
              style: TextStyle(
                
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
        ],
        if (!_loadingBuildings &&
            _buildings.isEmpty &&
            _buildingSearchController.text.trim().isNotEmpty) ...[
          const SizedBox(height: 5),
          V37SuggestAddressButton(
            cityHint: _selectedArea == null
                ? 'حدائق الأهرام'
                : 'حدائق الأهرام - منطقة $_selectedArea',
            buildingHint: _buildingSearchController.text,
            isDestination: true,
          ),
        ],
      ],
    );
  }

  Widget _buildingTile(Map<String, dynamic> building) {
    final selected =
        _selectedBuilding == building['building_number']?.toString();

    return GestureDetector(
      onTap: () => _selectBuilding(building),
      child: Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.gold.withAlpha(30)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppTheme.gold
                : Theme.of(context).colorScheme.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.apartment_rounded, color: AppTheme.gold),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                context.strings.buildingName(
                  '${building['building_number'] ?? ''}',
                ),
                style: TextStyle(
                  
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: context.strings.ui85c938bf,
              icon: const Icon(Icons.star_border_rounded, color: AppTheme.gold),
              onPressed: () => saveBookingFavorite(
                context,
                name: context.strings.buildingName(
                  '${building['building_number'] ?? ''}',
                ),
                displayAddress:
                    building['display_address']?.toString() ??
                    context.strings.areaBuilding(
                      _selectedArea ?? '',
                      '${building['building_number'] ?? ''}',
                    ),
                areaLetter: _selectedArea,
                buildingNumber: building['building_number']?.toString(),
                lat: _number(building['latitude']),
                lng: _number(building['longitude']),
              ),
            ),
            if (building['display_address'] != null)
              Flexible(
                child: Text(
                  building['display_address'].toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    
                    fontSize: 9,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DestinationOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _DestinationOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.gold.withAlpha(24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.gold, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
