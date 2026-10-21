import '../l10n/strings.dart';
import 'package:flutter/material.dart';

import '../services/customer_city_scope_v38.dart';
import '../services/supabase_service.dart';

/// V50: City -> area -> optional building letter -> building number.
/// Hadayek Al Ahram intentionally keeps its existing letter/building flow.
/// All coordinates come from owner-approved Supabase entries; no guessed pins.
class BookingCityPlacesV39 extends StatefulWidget {
  final void Function(String name, double lat, double lng) onSelected;
  const BookingCityPlacesV39({super.key, required this.onSelected});

  @override
  State<BookingCityPlacesV39> createState() => _BookingCityPlacesV39State();
}

class _BookingCityPlacesV39State extends State<BookingCityPlacesV39> {
  List<Map<String, dynamic>> _places = const [];
  final _search = TextEditingController();
  String? _city;
  String? _areaId;
  String? _letter;
  bool _busy = false;
  String? _error;
  int _requestSerial = 0;

  static const _gold = Color(0xFFFFCB4A);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant BookingCityPlacesV39 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_city != CustomerCityScopeV38.name) _reload();
  }

  @override
  void dispose() {
    _requestSerial++;
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final requestedCity = CustomerCityScopeV38.name;
    final serial = ++_requestSerial;
    _city = requestedCity;
    _areaId = null;
    _letter = null;
    _search.clear();
    if (requestedCity == null || CustomerCityScopeV38.isHadayek) {
      if (mounted) setState(() { _places = []; _busy = false; });
      return;
    }
    if (mounted) setState(() { _busy = true; _error = null; });
    try {
      // V50 RPC keeps the original V39 keys so previously released clients work.
      final data = await SupabaseService.instance.client.rpc(
        'v39_customer_city_places',
        params: {'p_city': requestedCity},
      ).timeout(const Duration(seconds: 12));
      if (!mounted || serial != _requestSerial ||
          CustomerCityScopeV38.name != requestedCity) return;
      setState(() {
        _places = (data as List? ?? const [])
            .whereType<Map>()
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
      });
    } catch (_) {
      if (mounted && serial == _requestSerial) {
        setState(() {
          _places = [];
          _error = 'places_load_failed';
        });
      }
    } finally {
      if (mounted && serial == _requestSerial) setState(() => _busy = false);
    }
  }

  String _name(Map<String, dynamic> e) =>
      (e['short_name'] ?? e['name'] ?? '').toString();
  String _id(Map<String, dynamic> e) => (e['id'] ?? '').toString();
  String? _parent(Map<String, dynamic> e) => e['parent_id']?.toString();
  bool _isBuilding(Map<String, dynamic> e) => e['kind'] == 'building';
  String _letterOf(Map<String, dynamic> e) =>
      (e['building_letter'] ?? '').toString().trim();

  void _choose(Map<String, dynamic> entry) {
    final lat = double.tryParse('${entry['latitude']}');
    final lng = double.tryParse('${entry['longitude']}');
    if (lat == null || lng == null || lat < -90 || lat > 90 ||
        lng < -180 || lng > 180 || (lat == 0 && lng == 0)) return;
    widget.onSelected((entry['name'] ?? _name(entry)).toString(), lat, lng);
  }

  Widget _entry(Map<String, dynamic> place) => ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: Icon(
          _isBuilding(place) ? Icons.apartment_rounded : Icons.place_rounded,
          color: _gold,
          size: 21,
        ),
        title: Text(_name(place),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle( fontSize: 13)),
        subtitle: (place['address'] ?? '').toString().trim().isEmpty
            ? null
            : Text('${place['address']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle( fontSize: 10)),
        onTap: () => _choose(place),
      );

  @override
  Widget build(BuildContext context) {
    if (_city == null || CustomerCityScopeV38.isHadayek) {
      return const SizedBox.shrink();
    }
    final text = _search.text.trim().toLowerCase();
    final areas = _places.where((p) => _parent(p) == null && !_isBuilding(p)).toList();
    final selectedArea = areas.where((p) => _id(p) == _areaId).firstOrNull;
    final children = _areaId == null
        ? <Map<String, dynamic>>[]
        : _places.where((p) => _parent(p) == _areaId).toList();
    final letters = children.map(_letterOf).where((s) => s.isNotEmpty).toSet().toList()..sort();
    final searched = text.isNotEmpty
        ? _places.where((p) => (p['name']?.toString().toLowerCase().contains(text) ?? false) ||
            _name(p).toLowerCase().contains(text) ||
            (p['parent_name']?.toString().toLowerCase().contains(text) ?? false)).toList()
        : <Map<String, dynamic>>[];
    final displayed = text.isNotEmpty
        ? searched
        : _areaId == null
            ? _places.where((p) => _parent(p) == null && _isBuilding(p)).toList()
            : children.where((p) => _letter == null ||
                (_letter!.isEmpty ? _letterOf(p).isEmpty : _letterOf(p) == _letter)).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Text(context.strings.placesCityTitle(_city ?? ''),
              style: const TextStyle( fontSize: 14,
                  fontWeight: FontWeight.w800, color: _gold))),
          IconButton(tooltip: context.strings.placesRefresh, onPressed: _busy ? null : _reload,
              icon: const Icon(Icons.refresh_rounded, color: _gold)),
        ]),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: context.strings.placesSearchHint,
          ),
        ),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        if (_error != null)
          Text(context.strings.placesLoadFailed, style: const TextStyle(
              color: Colors.orangeAccent, fontSize: 12)),
        if (text.isEmpty) ...[
          if (_areaId != null) TextButton.icon(
            onPressed: () => setState(() { _areaId = null; _letter = null; }),
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text(context.strings.placesCityAreas(_city ?? '')),
          ),
          if (_areaId == null) ...[
            if (areas.isNotEmpty)
              Padding(padding: EdgeInsets.only(top: 8),
                child: Text(context.strings.placesChooseAreaFirst, style: TextStyle(
                     fontWeight: FontWeight.w700))),
            for (final area in areas.take(70)) ListTile(
              dense: true,
              leading: const Icon(Icons.location_city_rounded, color: _gold),
              title: Text(_name(area), style: const TextStyle()),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => setState(() { _areaId = _id(area); _letter = null; }),
            ),
            if (displayed.isNotEmpty)
              Text(context.strings.placesIndependent, style: TextStyle(
                 fontWeight: FontWeight.w700)),
          ] else ...[
            if (selectedArea != null) ListTile(
              dense: true,
              leading: const Icon(Icons.my_location_rounded, color: _gold),
              title: Text(context.strings.placesUseArea(_name(selectedArea))),
              onTap: () => _choose(selectedArea),
            ),
            if (letters.isNotEmpty) ...[
              Text(context.strings.placesBuildingLetter,
                  style: TextStyle( fontWeight: FontWeight.w700)),
              Wrap(spacing: 7, runSpacing: 6, children: [
                ChoiceChip(label: Text(context.strings.placesAll), selected: _letter == null,
                    onSelected: (_) => setState(() => _letter = null)),
                for (final letter in letters)
                  ChoiceChip(label: Text(letter), selected: _letter == letter,
                      onSelected: (_) => setState(() => _letter = letter)),
                if (children.any((p) => _letterOf(p).isEmpty))
                  ChoiceChip(label: Text(context.strings.placesNoLetter), selected: _letter == '',
                      onSelected: (_) => setState(() => _letter = '')),
              ]),
            ],
            const SizedBox(height: 8),
            Text(context.strings.placesChooseBuilding,
                style: TextStyle( fontWeight: FontWeight.w700)),
          ],
        ],
        for (final place in displayed.take(50)) _entry(place),
        if (!_busy && _places.isEmpty)
          Padding(padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(context.strings.placesNoApproved,
                style: TextStyle( fontSize: 12))),
        if (text.isNotEmpty && displayed.isEmpty)
          Padding(padding: EdgeInsets.all(8),
            child: Text(context.strings.placesSuggestionHelp,
                style: TextStyle( fontSize: 12))),
      ]),
    );
  }
}
