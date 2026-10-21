import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Account-scoped local retry receipt. Never submits automatically and never
/// allows dedicated phone, Auth-token or wallet fields, or another account's draft.
class PendingAddressDraft {
  static const _allowed = {'p_city','p_area','p_kind','p_letter','p_number',
    'p_name','p_lat','p_lng','p_request_key','p_address','p_note','p_city_id'};
  static String _key(String account, String? correction) {
    if (account.isEmpty) throw StateError('address_draft_requires_account');
    return 'product.address.pending.$account.${correction ?? 'new'}';
  }
  static Future<Map<String, dynamic>?> load(String account, {String? correction}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(account, correction));
    if (raw == null) return null;
    final value = jsonDecode(raw);
    if (value is! Map || value['version'] != 1 || value['payload'] is! Map) {
      throw StateError('invalid_address_draft');
    }
    final payload = Map<String, dynamic>.from(value['payload']);
    if (payload.keys.any((key) => !_allowed.contains(key))) {
      throw StateError('invalid_address_draft');
    }
    if (payload['p_request_key'] is! String || payload['p_city'] is! String ||
        payload['p_kind'] is! String || payload['p_lat'] is! num || payload['p_lng'] is! num) {
      throw StateError('invalid_address_draft');
    }
    final lat = payload['p_lat'] as num, lng = payload['p_lng'] as num;
    if (!lat.isFinite || !lng.isFinite || lat.abs() > 90 || lng.abs() > 180 ||
        !const ['building', 'area', 'landmark'].contains(payload['p_kind']) ||
        !RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(payload['p_request_key'])) {
      throw StateError('invalid_address_draft');
    }
    return payload;
  }
  static Future<void> save(String account, Map<String, dynamic> payload, {String? correction}) async {
    if (payload.keys.any((key) => !_allowed.contains(key))) {
      throw StateError('address_draft_forbidden_field');
    }
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_key(account, correction), jsonEncode({'version': 1, 'payload': payload}))) {
      throw StateError('address_draft_not_saved');
    }
  }
  static Future<void> clear(String account, {String? correction}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.remove(_key(account, correction))) {
      throw StateError('address_draft_not_cleared');
    }
  }
}
