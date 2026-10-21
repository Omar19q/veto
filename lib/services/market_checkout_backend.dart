import 'supabase_service.dart';

/// Delegates to existing Market V8 methods; the server remains the financial authority.
class MarketCheckoutBackend {
  String? get accountId => SupabaseService.instance.currentUser?.id;
  Stream<String?> get accountChanges => SupabaseService
      .instance
      .client
      .auth
      .onAuthStateChange
      .map((state) => state.session?.user.id);
  Future<Map<String, dynamic>?> getCustomerByUserId(String uid) =>
      SupabaseService.instance.getCustomerByUserId(uid);
  Future<List<Map<String, dynamic>>> getCustomerAddresses(String cid) =>
      SupabaseService.instance.getCustomerAddresses(cid);
  Future<double> getVitoMarketDeliveryFee(String? area) =>
      SupabaseService.instance.getVitoMarketDeliveryFee(area);
  Future<Map<String, dynamic>> validateMarketPromo({
    required String supermarketId,
    required String code,
    required double subtotal,
  }) => SupabaseService.instance.validateMarketPromo(
    supermarketId: supermarketId,
    code: code,
    subtotal: subtotal,
  );
  Future<Map<String, dynamic>> createMarketOrderAtomic({
    required String customerId,
    required String supermarketId,
    required String deliveryAddress,
    String? areaLetter,
    double? latitude,
    double? longitude,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
    String? promoCode,
    String? idempotencyKey,
  }) => SupabaseService.instance.createMarketOrderAtomic(
    customerId: customerId,
    supermarketId: supermarketId,
    deliveryAddress: deliveryAddress,
    areaLetter: areaLetter,
    latitude: latitude,
    longitude: longitude,
    paymentMethod: paymentMethod,
    items: items,
    promoCode: promoCode,
    idempotencyKey: idempotencyKey,
  );
  Future<Map<String, dynamic>> addCustomerAddress({
    required String customerId,
    required String label,
    String? areaLetter,
    String? buildingNumber,
    String? floor,
    String? apartment,
    required String displayAddress,
    double? latitude,
    double? longitude,
  }) => SupabaseService.instance.addCustomerAddress(
    customerId: customerId,
    label: label,
    areaLetter: areaLetter,
    buildingNumber: buildingNumber,
    floor: floor,
    apartment: apartment,
    displayAddress: displayAddress,
    latitude: latitude,
    longitude: longitude,
  );
}
