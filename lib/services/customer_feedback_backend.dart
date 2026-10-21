import 'supabase_service.dart';

class CustomerFeedbackBackend {
  String? get accountId => SupabaseService.instance.currentUser?.id;
  Stream<String?> get accountChanges => SupabaseService
      .instance
      .client
      .auth
      .onAuthStateChange
      .map((event) => event.session?.user.id);
  Future<Map<String, dynamic>> submit({
    required String type,
    required String message,
  }) => SupabaseService.instance.submitCustomerFeedback(
    type: type,
    message: message,
  );
}
