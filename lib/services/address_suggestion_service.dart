import 'dart:math';
import 'supabase_service.dart';

typedef SuggestionRpc =
    Future<dynamic> Function(String name, Map<String, dynamic> params);

class AddressSuggestionService {
  AddressSuggestionService({SuggestionRpc? rpc})
    : _rpc =
          rpc ??
          ((name, params) =>
              SupabaseService.instance.client.rpc(name, params: params));
  final SuggestionRpc _rpc;
  static String requestKey() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<String> submit(Map<String, dynamic> params) async {
    final result = await _rpc(
      'v51_customer_suggest_address',
      params,
    ).timeout(const Duration(seconds: 15));
    if (result is! String || result.isEmpty)
      throw StateError('invalid_suggestion_receipt');
    return result;
  }

  Future<String> correct(Map<String, dynamic> params) async {
    final result = await _rpc(
      'v51_customer_correct_address',
      params,
    ).timeout(const Duration(seconds: 15));
    if (result is! String || result.isEmpty)
      throw StateError('invalid_suggestion_receipt');
    return result;
  }

  Future<List<Map<String, dynamic>>> history() async {
    final raw = await _rpc(
      'v51_my_address_suggestions',
      {},
    ).timeout(const Duration(seconds: 15));
    if (raw is! List) throw StateError('invalid_suggestion_history');
    return raw
        .whereType<Map>()
        .map((v) => Map<String, dynamic>.from(v))
        .toList();
  }
}
