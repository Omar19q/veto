import 'package:geolocator/geolocator.dart';
import 'supabase_service.dart';

/// Maintains the existing V27 reviewed-building submission contract.
class PickupBuildingSuggestionBackend {
  String? get accountId => SupabaseService.instance.currentUser?.id;
  Stream<String?> get accountChanges => SupabaseService
      .instance
      .client
      .auth
      .onAuthStateChange
      .map((event) => event.session?.user.id);
  Future<bool> locationEnabled() => Geolocator.isLocationServiceEnabled();
  Future<LocationPermission> permission() => Geolocator.checkPermission();
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();
  Future<Position> locate() => Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 25),
    ),
  );
  Future<void> submit({
    required String area,
    required int number,
    required Position position,
  }) => SupabaseService.instance.suggestPickupBuildingV27(
    area: area,
    number: number,
    latitude: position.latitude,
    longitude: position.longitude,
    accuracyMeters: position.accuracy,
  );
}
