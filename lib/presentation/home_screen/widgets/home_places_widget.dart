import '../../../l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../services/supabase_service.dart';
import '../../../services/booking_address_seed.dart';
import '../../../theme/app_theme.dart';

class HomePlacesWidget extends StatefulWidget {
  final void Function(String placeId) onPlaceTap;
  final double? latitude;
  final double? longitude;
  final ValueChanged<BookingAddressSeed>? onAddressSelected;

  const HomePlacesWidget({
    super.key,
    required this.onPlaceTap,
    this.latitude,
    this.longitude,
    this.onAddressSelected,
  });

  @override
  State<HomePlacesWidget> createState() => _HomePlacesWidgetState();
}

class _HomePlacesWidgetState extends State<HomePlacesWidget> {
  List<Map<String, dynamic>> _places = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    try {
      final places = await SupabaseService.instance.getFamousPlaces();
      if (mounted) {
        setState(() {
          _places = places;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double? _distanceMeters(Map<String, dynamic> place) {
    if (widget.latitude == null || widget.longitude == null) return null;
    final lat = double.tryParse(place['latitude']?.toString() ?? '');
    final lng = double.tryParse(place['longitude']?.toString() ?? '');
    if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180)
      return null;
    return Geolocator.distanceBetween(
      widget.latitude!,
      widget.longitude!,
      lat,
      lng,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sorted = List<Map<String, dynamic>>.from(_places);
    if (widget.latitude != null && widget.longitude != null) {
      sorted.removeWhere((p) {
        final distance = _distanceMeters(p);
        return distance == null || distance > 15000;
      });
      sorted.sort(
        (a, b) => (_distanceMeters(a) ?? double.infinity).compareTo(
          _distanceMeters(b) ?? double.infinity,
        ),
      );
    } else {
      // No reliable GPS => never pretend that distant places are 'nearby'.
      sorted.clear();
    }
    if (_isLoading) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: AppTheme.gold,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (sorted.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Row(
          children: [
            Icon(
              Icons.place_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              context.strings.ui741126d6,
              style: TextStyle(
                
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            context.strings.ui228e7f21,
            style: TextStyle(
              
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sorted.length > 15 ? 15 : sorted.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final place = sorted[index];
              final meters = _distanceMeters(place);
              return GestureDetector(
                onTap: () {
                  final address = BookingAddressSeed.saved({
                    ...place,
                    'display_address': place['name'],
                  });
                  if (address != null && widget.onAddressSelected != null) {
                    widget.onAddressSelected!(address);
                  } else {
                    widget.onPlaceTap(place['id'] as String);
                  }
                },
                child: Container(
                  width: 120,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.place_rounded,
                        color: AppTheme.gold,
                        size: 24,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        (place['name'] as String?) ?? '',
                        style: TextStyle(
                          
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      if (meters != null)
                        Text(
                          meters < 1000
                              ? '${meters.round()} م'
                              : '${(meters / 1000).toStringAsFixed(1)} كم',
                          style: TextStyle(
                            
                            fontSize: 10,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
