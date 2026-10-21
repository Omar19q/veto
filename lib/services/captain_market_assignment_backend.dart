import 'supabase_service.dart';

/// Existing assignment read; no dispatch or financial changes.
class CaptainMarketAssignmentBackend {
  String? get accountId => SupabaseService.instance.currentUser?.id;
  Stream<String?> get accountChanges => SupabaseService
      .instance
      .client
      .auth
      .onAuthStateChange
      .map((event) => event.session?.user.id);
  Future<Map<String, dynamic>?> getAssignment() =>
      SupabaseService.instance.getCaptainMarketAssignment();
}
