import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Additive payment workflow. Only PostgreSQL RPC can submit or review requests;
/// this client never writes customers.wallet_balance or wallet_transactions.
class WalletTopupService {
  WalletTopupService._();
  static final WalletTopupService instance = WalletTopupService._();
  SupabaseClient get _db => SupabaseService.instance.client;

  Future<List<Map<String, dynamic>>> offers({bool admin = false}) async {
    final rows = await _db.from('wallet_topup_offers').select().order('paid_amount');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> methods() async {
    final rows = await _db.from('wallet_topup_methods').select().order('sort_order');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> requests({bool admin = false}) async {
    final rows = await _db.from('wallet_topup_requests').select()
        .order('created_at', ascending: false).limit(admin ? 250 : 80);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> decisions(String requestId) async {
    final rows = await _db.from('wallet_topup_decisions').select()
        .eq('request_id', requestId).order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> submit({required String methodId,
    required double amount, String? offerId, required String sender,
    String? operation}) async {
    final raw = await _db.rpc('create_wallet_topup_request_v1', params: {
      'p_method_id': methodId, 'p_amount': amount, 'p_offer_id': offerId,
      'p_sender_number': sender.trim(), 'p_operation_number': operation?.trim(),
    });
    return Map<String, dynamic>.from(raw as Map);
  }

  Future<Map<String, dynamic>> review(String id, bool approved, String? note) async {
    final raw = await _db.rpc('review_wallet_topup_request_v1', params: {
      'p_request_id': id, 'p_approve': approved, 'p_note': note?.trim(),
    });
    return Map<String, dynamic>.from(raw as Map);
  }

  Future<void> saveOffer(Map<String, dynamic> data, {String? id}) async {
    if (id == null) {
      await _db.from('wallet_topup_offers').insert(data);
    } else {
      await _db.from('wallet_topup_offers').update(data).eq('id', id);
    }
  }

  Future<void> saveMethod(Map<String, dynamic> data, {String? id}) async {
    if (id == null) {
      await _db.from('wallet_topup_methods').insert(data);
    } else {
      await _db.from('wallet_topup_methods').update(data).eq('id', id);
    }
  }

  RealtimeChannel watchRequests(void Function() reload) =>
      _db.channel('topups-${DateTime.now().microsecondsSinceEpoch}')
          .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public',
              table: 'wallet_topup_requests', callback: (_) => reload())
          .subscribe();
}
