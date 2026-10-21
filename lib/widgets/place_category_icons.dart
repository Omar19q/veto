import 'package:flutter/material.dart';

/// Icon keys are stored as short names, never Flutter code sent by the server.
/// Unknown keys gracefully render a pin without breaking existing places.
class PlaceCategoryIcons {
  PlaceCategoryIcons._();

  static const Map<String, IconData> icons = <String, IconData>{
    'place': Icons.place_rounded,
    'apps': Icons.apps_rounded,
    'gate': Icons.fence_rounded,
    'cafe': Icons.local_cafe_rounded,
    'medical': Icons.local_hospital_rounded,
    'station': Icons.directions_bus_rounded,
    'bank': Icons.account_balance_rounded,
    'school': Icons.school_rounded,
    'church': Icons.church_rounded,
    'club': Icons.sports_soccer_rounded,
    'restaurant': Icons.restaurant_rounded,
    'mosque': Icons.mosque_rounded,
    'market': Icons.storefront_rounded,
    'shop': Icons.store_rounded,
    'pharmacy': Icons.local_pharmacy_rounded,
    'street': Icons.signpost_rounded,
    'home': Icons.home_rounded,
    'building': Icons.apartment_rounded,
    'hospital': Icons.medical_services_rounded,
    'university': Icons.school_outlined,
    'park': Icons.park_rounded,
    'gym': Icons.fitness_center_rounded,
    'hotel': Icons.hotel_rounded,
    'fuel': Icons.local_gas_station_rounded,
    'shopping': Icons.shopping_bag_rounded,
    'work': Icons.business_center_rounded,
    'star': Icons.star_rounded,
  };

  static IconData get(String? key) => icons[key] ?? Icons.place_rounded;
}
