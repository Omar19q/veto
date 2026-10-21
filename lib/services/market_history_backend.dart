import 'supabase_service.dart';

/// Existing read-only catalog/history methods. Reorder still uses current prices
/// and passes through the existing atomic checkout workflow.
class MarketHistoryBackend {
  String? get accountId => SupabaseService.instance.currentUser?.id;
  Stream<String?> get accountChanges => SupabaseService
      .instance
      .client
      .auth
      .onAuthStateChange
      .map((event) => event.session?.user.id);
  Future<Map<String, dynamic>?> getCustomer(String uid) =>
      SupabaseService.instance.getCustomerByUserId(uid);
  Future<List<Map<String, dynamic>>> getOrders(String cid) =>
      SupabaseService.instance.getMarketOrders(customerId: cid, limit: 50);
  Future<List<Map<String, dynamic>>> getStores() =>
      SupabaseService.instance.getSupermarkets();
  Future<List<Map<String, dynamic>>> getProducts(String sid) =>
      SupabaseService.instance.getProducts(sid);
}
