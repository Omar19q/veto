import '../../../l10n/strings.dart';
import '../../../widgets/booking_area_picker_v19.dart';
import '../../../services/customer_city_scope_v38.dart';
import '../../../services/zone_pricing_service.dart';
import '../../../widgets/customer_city_selector_v38.dart';
import '../../../widgets/v37_suggest_address_button.dart';
import '../../../widgets/booking_city_places_v39.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'booking_pin_picker_v36.dart';
import '../../../services/product_geocoding_service.dart';

import '../../../services/supabase_service.dart';
import '../../../widgets/place_category_icons.dart';
import 'booking_favorites_widget.dart';
import '../../../theme/app_theme.dart';
import 'booking_building_suggestion_dialog.dart';

class BookingPickupSheetWidget extends StatefulWidget {
  final void Function(String area, String building, {double? lat, double? lng})
  onPickupSelected;

  final VoidCallback? onUseCurrentLocation;
  final ValueChanged<String>? onNoteChanged;
  final String? prefilledLabel;
  final String? initialNote;
  final bool descriptionRequired;
  final VoidCallback? onConfirmPrefilled;
  const BookingPickupSheetWidget({
    super.key,
    required this.onPickupSelected,
    this.onUseCurrentLocation,
    this.onNoteChanged,
    this.prefilledLabel,
    this.initialNote,
    this.descriptionRequired = false,
    this.onConfirmPrefilled,
  });

  @override
  State<BookingPickupSheetWidget> createState() =>
      _BookingPickupSheetWidgetState();
}

class _BookingPickupSheetWidgetState extends State<BookingPickupSheetWidget> {
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
    _pickupNoteController.text = widget.initialNote ?? '';
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

  final TextEditingController _pickupNoteController = TextEditingController();
  final TextEditingController _buildingSearchController =
      TextEditingController();
  Timer? _buildingDebounce;
  int _buildingSearchSequence = 0;

  String? _cityChoiceV38 = CustomerCityScopeV38.name;
  int _mode = -1; // Start by showing all pickup types, not the building search
  String _category = 'all';
  String? _selectedArea;
  Map<String, dynamic>? _selectedPlace;
  Map<String, dynamic>? _selectedBuilding;

  bool _loadingPlaces = false;
  bool _loadingBuildings = false;

  List<Map<String, dynamic>> _places = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _buildings = <Map<String, dynamic>>[];

  String? _error;
  bool _selectionSubmitted = false;

  @override
  void dispose() {
    _buildingDebounce?.cancel();
    _buildingSearchController.dispose();
    _pickupNoteController.dispose();
    super.dispose();
  }

  void _setMode(int mode) {
    ++_buildingSearchSequence;
    _buildingDebounce?.cancel();
    setState(() {
      _mode = mode;
      _error = null;
      _selectedPlace = null;
      _selectedBuilding = null;
      if (mode != 2) {
        _selectedArea = null;
        _buildingSearchController.clear();
        _buildings = <Map<String, dynamic>>[];
      }
    });

    if (mode == 1 && _places.isEmpty) {
      _loadFamousPlaces();
    }
  }

  void _setModeAfterCityV38() {
    _mode = -1;
    _selectedArea = null;
    _selectedBuilding = null;
    _buildings = <Map<String, dynamic>>[];
    _buildingSearchController.clear();
  }

  Future<void> _loadFamousPlaces() async {
    setState(() {
      _loadingPlaces = true;
      _error = null;
    });

    try {
      var result = await SupabaseService.instance.getFamousPlaces();
      // Places without a reliable area cannot be associated with another city.
      final selected = CustomerCityScopeV38.name;
      if (selected == null) {
        result = <Map<String, dynamic>>[];
      } else if (!CustomerCityScopeV38.isHadayek) {
        try {
          final candidates = await ZonePricingService.instance.zones();
          final chosen = candidates
              .where(
                (zone) => zone.active && !zone.global && zone.name == selected,
              )
              .toList();
          result = chosen.isEmpty
              ? <Map<String, dynamic>>[]
              : result.where((place) {
                  final lat = double.tryParse(
                    place['latitude']?.toString() ?? '',
                  );
                  final lng = double.tryParse(
                    place['longitude']?.toString() ?? '',
                  );
                  return lat != null &&
                      lng != null &&
                      chosen.first.contains(lat, lng);
                }).toList();
        } catch (_) {
          result = <Map<String, dynamic>>[];
        }
      }
      if (!mounted) return;

      setState(() {
        _places = result;
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
    final sequence = ++_buildingSearchSequence;
    _buildingDebounce?.cancel();
    _buildingSearchController.clear();
    setState(() {
      _selectedArea = area;
      _selectedBuilding = null;
      _buildings = <Map<String, dynamic>>[];
      _loadingBuildings = true;
      _error = null;
    });

    try {
      final result = await SupabaseService.instance.searchBuildingsForCustomer(
        areaLetter: area,
        searchQuery: '',
      );

      if (!mounted || sequence != _buildingSearchSequence) return;

      setState(() {
        _buildings = result;
        _loadingBuildings = false;
      });
    } catch (_) {
      if (!mounted || sequence != _buildingSearchSequence) return;

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
    final sequence = ++_buildingSearchSequence;

    // A number exists in many Hadayek areas. Search must be scoped to the
    // chosen letter or a different area's result could hide the add button.
    if (_selectedArea == null) {
      if (mounted)
        setState(() {
          _buildings = <Map<String, dynamic>>[];
          _selectedBuilding = null;
          _loadingBuildings = false;
          _error = context.strings.ui5c6fddf6;
        });
      return;
    }

    if (query.isEmpty) {
      if (_selectedArea != null) {
        await _loadBuildings(_selectedArea!);
      } else if (mounted) {
        setState(() {
          _buildings = <Map<String, dynamic>>[];
        });
      }
      return;
    }

    final number = int.tryParse(query);
    if (number == null || number < 1 || number > 590) {
      if (mounted) {
        setState(() {
          _error = context.strings.uiec4369bc;
          _buildings = <Map<String, dynamic>>[];
          _loadingBuildings = false;
        });
      }
      return;
    }

    final area = _selectedArea!;
    setState(() {
      _loadingBuildings = true;
      _error = null;
      _selectedBuilding = null;
    });

    try {
      final result = await SupabaseService.instance.searchBuildingsForCustomer(
        areaLetter: area,
        searchQuery: number.toString(),
      );

      if (!mounted || sequence != _buildingSearchSequence) return;

      setState(() {
        _buildings = result;
        _loadingBuildings = false;
      });
    } catch (_) {
      if (!mounted || sequence != _buildingSearchSequence) return;

      setState(() {
        _loadingBuildings = false;
        _error = context.strings.ui39c9c0fc;
      });
    }
  }

  Future<void> _openManualMapV36() async {
    final point = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(builder: (_) => const BookingPinPickerV36()),
    );
    if (!mounted || point == null || _selectionSubmitted) return;
    _selectionSubmitted = true;
    widget.onPickupSelected(
      point is ConfirmedMapPoint ? point.address : context.strings.ui2acdce12,
      '',
      lat: point.latitude,
      lng: point.longitude,
    );
  }

  void _confirmFamousPlace() {
    if (_selectionSubmitted) return;
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

    _selectionSubmitted = true;
    widget.onPickupSelected(
      (place['name'] ?? context.strings.ui46d9c9af).toString(),
      '',
      lat: lat,
      lng: lng,
    );
  }

  void _confirmBuilding() {
    if (_selectionSubmitted) return;
    final building = _selectedBuilding;
    if (building == null || _selectedArea == null) return;

    final lat = _number(building['latitude']);
    final lng = _number(building['longitude']);

    if (lat == null || lng == null) {
      setState(() {
        _error = context.strings.ui5f74518a;
      });
      return;
    }

    _selectionSubmitted = true;
    widget.onPickupSelected(
      _selectedArea!,
      (building['building_number'] ?? '').toString(),
      lat: lat,
      lng: lng,
    );
  }

  Future<void> _suggestMissingPickupBuilding() async {
    final area = _selectedArea;
    final term = _buildingSearchController.text.trim();
    final number = int.tryParse(term);
    if (area == null) {
      setState(() => _error = context.strings.ui3ccabf1f);
      return;
    }
    if (number == null || number < 1 || number > 590) {
      setState(() => _error = context.strings.ui8e451470);
      return;
    }
    final suggestion = await showDialog<PickupBuildingSuggestion>(
      context: context,
      builder: (_) => BookingBuildingSuggestionDialog(
        initialArea: area,
        initialNumber: term,
      ),
    );
    if (!mounted || suggestion == null) return;

    // The GPS reading is usable for this pickup immediately. It does not
    // publicly verify the area/number pairing for other customers.
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          context.strings.ui5dd6c786,
          style: TextStyle(),
        ),
      ),
    );
    widget.onPickupSelected(
      suggestion.area,
      suggestion.number.toString(),
      lat: suggestion.latitude,
      lng: suggestion.longitude,
    );
  }

  double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  List<Map<String, dynamic>> get _filteredPlaces {
    if (_category == 'all') {
      final visible = _categories.map((c) => c['slug']?.toString()).toSet();
      return _places
          .where(
            (place) =>
                visible.contains(place['category']?.toString() ?? 'other'),
          )
          .toList();
    }

    return _places.where((place) {
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
            const SizedBox(height: 5),
            Text(
              context.strings.ui91aff234,
              style: TextStyle(
                
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.strings.ui5bdfac2b,
              style: TextStyle(
                
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 7),
            OutlinedButton.icon(
              onPressed: () => showCustomerCitySelectorV38(
                context,
                onSelected: (name) {
                  if (!mounted) return;
                  setState(() {
                    _cityChoiceV38 = name.isEmpty ? null : name;
                    _setModeAfterCityV38();
                  });
                },
              ),
              icon: const Icon(Icons.location_city_outlined),
              label: Text(
                _cityChoiceV38 ??
                    CustomerCityScopeV38.name ??
                    context.strings.uia1f24fc1,
                style: const TextStyle(),
              ),
            ),
            const SizedBox(height: 7),
            if (_mode == -1) ...[
              if (widget.prefilledLabel != null &&
                  widget.onConfirmPrefilled != null) ...[
                Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(13),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 9),
                    child: Row(children: [
                      const Icon(Icons.person_pin_circle_outlined,
                        color: AppTheme.gold, size: 22),
                      const SizedBox(width: 8),
                      Expanded(child: Text(widget.prefilledLabel!, maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700))),
                    ]),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _pickupNoteController,
                  maxLength: 100,
                  maxLines: 1,
                  onChanged: (value) {
                    widget.onNoteChanged?.call(value);
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.edit_location_alt_outlined,
                      size: 20),
                    labelText: widget.descriptionRequired
                      ? 'اكتب وصف مكانك للكابتن' : 'وصف إضافي للكابتن (اختياري)',
                    hintText: 'مثال: جنب الصيدلية أو بوابة 1',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(height: 48, child: FilledButton.icon(
                  onPressed: widget.descriptionRequired &&
                      _pickupNoteController.text.trim().isEmpty
                      ? null : widget.onConfirmPrefilled,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: Text(Localizations.localeOf(context).languageCode=='ar'?'تأكيد مكان الركوب':'Confirm pickup'),
                )),
                const SizedBox(height: 8),
              ],
              Wrap(spacing: 7, runSpacing: 5, children: [
                if (widget.onUseCurrentLocation != null)
                  ActionChip(
                    avatar: const Icon(Icons.my_location_rounded, size: 18),
                    label: const Text('موقعي الحالي'),
                    onPressed: widget.onUseCurrentLocation,
                  ),
                ActionChip(
                  avatar: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('تحديد على الخريطة'),
                  onPressed: _openManualMapV36,
                ),
                if (CustomerCityScopeV38.isHadayek)
                  ActionChip(
                    avatar: const Icon(Icons.apartment_outlined, size: 18),
                    label: const Text('العمارات'),
                    onPressed: () => _setMode(2),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.place_outlined, size: 18),
                  label: const Text('أماكن معروفة'),
                  onPressed: () => _setMode(1),
                ),
                ActionChip(
                  avatar: const Icon(Icons.star_border_rounded, size: 18),
                  label: const Text('المفضلة'),
                  onPressed: () => _setMode(3),
                ),
              ]),
              if (!CustomerCityScopeV38.isHadayek) ...[
                BookingCityPlacesV39(
                  onSelected: (name, lat, lng) {
                    if (_selectionSubmitted) return;
                    _selectionSubmitted = true;
                    widget.onPickupSelected(
                      '${CustomerCityScopeV38.name ?? ''} - $name',
                      '', lat: lat, lng: lng,
                    );
                  },
                ),
                V37SuggestAddressButton(cityHint: _cityChoiceV38),
              ],
            ] else ...[
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _setMode(-1),
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
              const SizedBox(height: 10),
              if (_mode == 1) _buildFamousMode(),
              if (_mode == 2) _buildBuildingMode(),
              if (_mode == 3)
                BookingFavoritesWidget(
                  allowOutsideCity: false,
                  onSelected: (item) async {
                    final lat = _number(item['latitude']);
                    final lng = _number(item['longitude']);
                    if (lat == null || lng == null) return;
                    final area = item['area_letter']?.toString();
                    widget.onPickupSelected(
                      area != null && area.isNotEmpty
                          ? area
                          : item['display_address']?.toString() ??
                                context.strings.ui72de3382,
                      item['building_number']?.toString() ?? '',
                      lat: lat,
                      lng: lng,
                    );
                  },
                ),
            ],
            const SizedBox(height: 7),
            if (_mode != -1) TextField(
              controller: _pickupNoteController,
              maxLength: 100,
              maxLines: 1,
              onChanged: widget.onNoteChanged,
              style: TextStyle(
                
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  Icons.edit_location_alt_rounded,
                  color: AppTheme.gold,
                ),
                labelText: 'وصف المكان للكابتن (لو العنوان مش واضح)',
                hintText: 'مثال: قدام البوابة أو جنب الصيدلية',
                labelStyle: const TextStyle(),
                hintStyle: const TextStyle(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  
                  fontSize: 12,
                  color: AppTheme.errorLight,
                ),
              ),
            ],
          ],
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
        else if (_filteredPlaces.isEmpty)
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
          ..._filteredPlaces.map(_placeTile),
      ],
    );
  }

  Widget _areaPicker() => BookingAreaPickerV19(
    selected: _selectedArea,
    areas: _areas,
    placeLabel: context.strings.uiae7ae56d,
    onSelected: (value) {
      if (value != _selectedArea) _loadBuildings(value);
    },
  );

  Widget _buildBuildingMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.strings.uie0d502ff,
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
          context.strings.uieca4806f,
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
              context.strings.ui99bef41e,
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
              context.strings.ui09d5b8ff,
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
              context.strings.ui42ebe4b5,
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

        // Always show the missing-building action, including empty results,
        // temporary search errors and the initial state. It must never be
        // hidden by the result count or a transient error message.
        const SizedBox(height: 16),
        Material(
          color: AppTheme.gold.withAlpha(22),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _suggestMissingPickupBuilding,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.gold, width: 1.8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.add_location_alt_rounded,
                    color: AppTheme.gold,
                    size: 36,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.strings.uifc5bae31,
                          style: TextStyle(
                            
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          context.strings.ui8616aae5,
                          style: TextStyle(
                            
                            fontSize: 12,
                            height: 1.5,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left_rounded, color: AppTheme.gold),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeTile(Map<String, dynamic> place) {
    final selected = _selectedPlace?['id'] == place['id'];

    return GestureDetector(
      onTap: () {
        if (_selectionSubmitted) return;
        setState(() => _selectedPlace = place);
        _confirmFamousPlace();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
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
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                (place['name'] ?? '').toString(),
                style: TextStyle(
                  
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
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

  Widget _buildingTile(Map<String, dynamic> building) {
    final selected = _selectedBuilding?['id'] == building['id'];

    return GestureDetector(
      onTap: () {
        if (_selectionSubmitted) return;
        setState(() => _selectedBuilding = building);
        _confirmBuilding();
      },
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
