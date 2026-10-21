import 'booking_performance.dart';

class BookingAddressSeed {
  const BookingAddressSeed({
    required this.label,
    required this.latitude,
    required this.longitude,
    this.areaLetter,
    this.buildingNumber,
    this.city,
    this.defaultPickup = false,
    this.outsideCity = false,
  });
  final String label;
  final double latitude, longitude;
  final String? areaLetter, buildingNumber, city;
  final bool defaultPickup;
  final bool outsideCity;
  static BookingAddressSeed? saved(Map<String, dynamic> row) {
    final lat = _number(row['latitude']), lng = _number(row['longitude']);
    final label = (row['display_address'] ?? row['label'] ?? '')
        .toString()
        .trim();
    if (lat == null ||
        lng == null ||
        lat.abs() > 90 ||
        lng.abs() > 180 ||
        label.isEmpty)
      return null;
    return BookingAddressSeed(
      label: label,
      latitude: lat,
      longitude: lng,
      areaLetter: row['area_letter']?.toString(),
      buildingNumber: row['building_number']?.toString(),
      defaultPickup: row['is_default'] == true,
      outsideCity: row['is_outside_city'] == true,
    );
  }

  static BookingAddressSeed? recent(Map<String, dynamic> row) {
    final lat = _number(row['destination_latitude']),
        lng = _number(row['destination_longitude']);
    final label = (row['destination_address'] ?? '').toString().trim();
    if (lat == null ||
        lng == null ||
        lat.abs() > 90 ||
        lng.abs() > 180 ||
        label.isEmpty)
      return null;
    return BookingAddressSeed(
      label: label,
      latitude: lat,
      longitude: lng,
      areaLetter: row['destination_area_letter']?.toString(),
      buildingNumber: row['destination_building_number']?.toString(),
      outsideCity: row['is_outside_city'] == true,
    );
  }

  static double? _number(dynamic value) {
    final n = value is num ? value.toDouble() : double.tryParse('$value');
    return n != null && n.isFinite ? n : null;
  }
}

class BookingAddressSelection {
  const BookingAddressSelection({this.pickup, this.destination, this.attempt});
  final BookingAddressSeed? pickup, destination;
  final BookingPerformanceAttempt? attempt;
}
