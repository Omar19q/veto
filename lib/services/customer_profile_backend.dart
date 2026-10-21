import 'dart:typed_data';
import 'supabase_service.dart';

/// Testable adapter for the existing profile RPCs. No financial calls or schema changes.
class CustomerProfileBackend {
  String? get accountId => SupabaseService.instance.currentUser?.id;
  Stream<String?> get accountChanges => SupabaseService
      .instance
      .client
      .auth
      .onAuthStateChange
      .map((state) => state.session?.user.id);
  Future<dynamic> profile() => SupabaseService.instance.client
      .rpc('customer_loyalty_profile_v29')
      .timeout(const Duration(seconds: 12));
  Future<Map<String, dynamic>?> customer(String userId) =>
      SupabaseService.instance.getCustomerByUserId(userId);
  Future<dynamic> preferences() => SupabaseService.instance.client
      .rpc('customer_get_preferences_v31')
      .timeout(const Duration(seconds: 8));
  Future<void> chooseFrame(String key) async {
    await SupabaseService.instance.client
        .rpc('customer_select_frame_v29', params: {'p_frame_key': key})
        .timeout(const Duration(seconds: 12));
  }

  Future<void> savePreferences(List<String> values) async {
    await SupabaseService.instance.client
        .rpc('customer_save_preferences_v31', params: {'p_interests': values})
        .timeout(const Duration(seconds: 10));
  }

  Future<void> name(String customerId, String name) =>
      SupabaseService.instance.updateCustomerName(customerId, name);
  Future<void> gender(String customerId, String gender) => SupabaseService
      .instance
      .updateCustomerProfile(customerId, gender: gender);
  Future<String> uploadPhoto(String userId, Uint8List bytes) =>
      SupabaseService.instance.uploadPublicImage(
        path: 'customers/$userId/profile.jpg',
        bytes: bytes,
        contentType: 'image/jpeg',
      );
  Future<void> photo(String customerId, String url) => SupabaseService.instance
      .updateCustomerProfile(customerId, profilePhotoUrl: url);
}
