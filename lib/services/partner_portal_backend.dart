import 'supabase_service.dart';

/// Existing partnership RPCs; preserves V39/V40 payout rules and permissions.
class PartnerPortalBackend {
  String? get accountId => SupabaseService.instance.currentUser?.id;
  Stream<String?> get accountChanges => SupabaseService
      .instance
      .client
      .auth
      .onAuthStateChange
      .map((event) => event.session?.user.id);
  Future<dynamic> report() => SupabaseService.instance.client
      .rpc('v40_partner_report')
      .timeout(const Duration(seconds: 12));
  Future<dynamic> monthlyReport() => SupabaseService.instance.client
      .rpc('v43_partner_monthly_report')
      .timeout(const Duration(seconds: 10));
  Future<dynamic> saveWallet(String wallet) => SupabaseService.instance.client
      .rpc('v40_partner_save_wallet', params: {'p_wallet': wallet})
      .timeout(const Duration(seconds: 12));
}
