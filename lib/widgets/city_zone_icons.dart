import 'package:flutter/material.dart';

class CityZoneIconOption {
  final String keyName;
  final String label;
  final IconData icon;
  const CityZoneIconOption(this.keyName, this.label, this.icon);
}

/// A focused icon library for city/zone branding. Keeping keys stable in the
/// database avoids storing Material code points that may change across builds.
const cityZoneIconOptions = <CityZoneIconOption>[
  CityZoneIconOption('city', 'مدينة', Icons.location_city_rounded),
  CityZoneIconOption('pyramid', 'هرم', Icons.change_history_rounded),
  CityZoneIconOption('apartments', 'عمارات', Icons.apartment_rounded),
  CityZoneIconOption('residential', 'سكني', Icons.home_work_rounded),
  CityZoneIconOption('landmark', 'معلم', Icons.account_balance_rounded),
  CityZoneIconOption('park', 'حدائق', Icons.park_rounded),
  CityZoneIconOption('palm', 'نخيل', Icons.park_outlined),
  CityZoneIconOption('beach', 'ساحل', Icons.beach_access_rounded),
  CityZoneIconOption('mosque', 'مسجد', Icons.mosque_rounded),
  CityZoneIconOption('market', 'تجاري', Icons.storefront_rounded),
  CityZoneIconOption('mall', 'مول', Icons.local_mall_rounded),
  CityZoneIconOption('school', 'مدارس', Icons.school_rounded),
  CityZoneIconOption('hospital', 'طبي', Icons.local_hospital_rounded),
  CityZoneIconOption('restaurant', 'مطاعم', Icons.restaurant_rounded),
  CityZoneIconOption('hotel', 'فندق', Icons.hotel_rounded),
  CityZoneIconOption('airport', 'مطار', Icons.flight_rounded),
  CityZoneIconOption('factory', 'صناعي', Icons.factory_rounded),
  CityZoneIconOption('office', 'أعمال', Icons.business_center_rounded),
  CityZoneIconOption('sports', 'نادي', Icons.sports_soccer_rounded),
  CityZoneIconOption('road', 'طريق', Icons.add_road_rounded),
  CityZoneIconOption('mountain', 'طبيعة', Icons.landscape_rounded),
  CityZoneIconOption('star', 'مميزة', Icons.star_rounded),
  CityZoneIconOption('pin', 'موقع', Icons.location_on_rounded),
  CityZoneIconOption('explore', 'منطقة', Icons.travel_explore_rounded),
  CityZoneIconOption('domain', 'مجمع', Icons.domain_rounded),
  CityZoneIconOption('castle', 'بوابة/معلم', Icons.castle_rounded),
];

IconData cityZoneIcon(String? key) {
  final target = key?.trim();
  for (final option in cityZoneIconOptions) {
    if (option.keyName == target) return option.icon;
  }
  return Icons.location_city_rounded;
}
