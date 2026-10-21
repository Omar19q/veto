import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

typedef GrowthRpc =
    Future<dynamic> Function(String name, Map<String, dynamic> params);

/// New operations use server policies. They never retry a financial mutation
/// through a different RPC after an ambiguous response.
class GrowthService {
  static final eventDeliveryFailures = ValueNotifier<int>(0);
  Future<void> observe(
    String name, {
    Map<String, dynamic> properties = const {},
  }) async {
    try {
      await event(name, properties: properties);
    } catch (_) {
      eventDeliveryFailures.value++;
      debugPrint('Growth event delivery failed: $name');
    }
  }

  GrowthService({GrowthRpc? rpc})
    : _rpc =
          rpc ??
          ((name, params) =>
              SupabaseService.instance.client.rpc(name, params: params));
  final GrowthRpc _rpc;
  static const requested = bool.fromEnvironment(
    'VETO_GROWTH_ENABLED',
    defaultValue: false,
  );
  static const stagingProject = String.fromEnvironment(
    'SUPABASE_STAGING_PROJECT_REF',
  );
  // This second build-time approval must be passed deliberately for a release
  // AFTER server migrations, permissions and financial regressions are signed off.
  // Never activate production Growth only because a generic flag is enabled.
  static const productionApproved = bool.fromEnvironment(
    'VETO_GROWTH_PRODUCTION_APPROVED',
    defaultValue: false,
  );
  static bool get buildEnabled {
    final host = Uri.tryParse(SupabaseService.supabaseUrl)?.host.toLowerCase();
    if (host == 'wujynritxanyzrkdyamt.supabase.co') return true;
    if (!requested) return false;
    if (host == 'wbdjvzaomtlojttjnfhp.supabase.co') {
      return productionApproved;
    }
    return const {'localhost', '127.0.0.1', '10.0.2.2', '::1'}.contains(host) ||
        (stagingProject.isNotEmpty &&
            stagingProject != 'wbdjvzaomtlojttjnfhp' &&
            host == '$stagingProject.supabase.co');
  }

  static const downloadUrl =
      'https://play.google.com/store/apps/details?id=com.vetosanya.app';
  static Uri referralLink(String code) => Uri.parse(downloadUrl).replace(
    queryParameters: {
      'id': 'com.vetosanya.app',
      'referrer': 'referral_code=$code',
    },
  );
  static String shareMessage(String code) =>
      'جرّب فيتو ثانية 🚗\nكود الدعوة: $code\nاكتب الكود عند التسجيل لمعرفة العرض المتاح لحسابك.\n${referralLink(code)}';

  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> params = const {},
  ]) async {
    final raw = await _rpc(name, params).timeout(const Duration(seconds: 15));
    if (raw is! Map) throw StateError('growth_response_invalid');
    return Map<String, dynamic>.from(raw);
  }

  Future<dynamic> execute(String name, Map<String, dynamic> params) =>
      _rpc(name, params).timeout(const Duration(seconds: 15));

  Future<Map<String, dynamic>> flags() async {
    final result = await call('growth_flags_v1');
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool('growth_ui_startup', result['startup'] == true)) {
      throw StateError('growth_ui_settings_not_saved');
    }
    return result;
  }

  Future<Map<String, dynamic>> profile({bool captain = false}) async {
    final result = await call('growth_my_profile_v3', {
      'p_kind': captain ? 'captain' : 'customer',
    });
    if (result['enabled'] == true && !captain) {
      try {
        final simple = await call('v54_my_friend_code');
        final easyCode = simple['code']?.toString() ?? '';
        if (RegExp(r'^F[0-9]{6,12}$').hasMatch(easyCode)) {
          result['code'] = easyCode;
          result['friend_reward_v54'] = true;
          result['reward_for_first_completed_trip'] = simple['reward_for_first_completed_trip'];
          result['invitee_first_discount_percent'] = simple['invitee_first_discount_percent'];
          final metrics = await call('v54_my_friend_invites');
          result['friend_invites_v54'] = metrics;
        }
      } catch (error) {
        // An older staging database may not yet have V54; keep the previous
        // existing invitation code rather than blocking the entire profile.
        debugPrint('V54 friend code not available: ${error.runtimeType}');
      }
    }
    if (result['enabled'] == true) {
      if (!RegExp(
        r'^(?:[0-9]{4,19}|F[0-9]{6,12}|C(?:[0-9a-fA-F]{12}|[0-9a-fA-F]{32}))$',
      ).hasMatch(result['code']?.toString() ?? '')) {
        throw StateError('growth_profile_code_invalid');
      }
      for (final field in ['due', 'paid', 'promotional_available']) {
        final value = num.tryParse(result[field]?.toString() ?? '');
        if (value == null || !value.isFinite || value < 0)
          throw StateError('growth_profile_amount_unavailable');
      }
    }
    return result;
  }

  /// Financial and referral summaries are computed by authenticated server RPCs.
  /// This call NEVER credits a wallet or creates/consumes a voucher.
  Future<Map<String, dynamic>> referralBreakdown({bool captain = false}) =>
      call('v55_my_referral_breakdown', {
        'p_kind': captain ? 'captain' : 'customer',
      });

  /// Owner-only totals. The database checks v16_is_owner() again.
  Future<Map<String, dynamic>> ownerReferralOverview() =>
      call('v55_owner_referral_overview');

  Future<bool> claimOnboarding() async =>
      (await call('growth_claim_onboarding_v1'))['show'] == true;
  /// Binding is atomic on the server. An existing decision must NOT be
  /// interpreted as a newly accepted code or a second reward.
  Future<Map<String, dynamic>> bindDecision(String? code) async {
    final result = await call('growth_bind_referral_v1', {'p_code': code});
    if (result['success'] != true) throw StateError('growth_binding_failed');
    return result;
  }

  Future<void> bind(String? code) async {
    final result = await bindDecision(code);
    if (result['already_decided'] == true) {
      throw StateError('growth_onboarding_already_decided');
    }
  }

  Future<Map<String, dynamic>> overview({DateTime? since, DateTime? until}) =>
      call('growth_admin_overview_v2', {
        if (since != null) 'p_since': since.toUtc().toIso8601String(),
        if (until != null) 'p_until': until.toUtc().toIso8601String(),
      });
  Future<void> setFlag(
    String key,
    bool enabled,
    Map<String, dynamic> settings,
  ) => _rpc('growth_admin_flag_v1', {
    'p_key': key,
    'p_enabled': enabled,
    'p_settings': settings,
  }).then((_) {});
  Future<void> review(String id, String status, String note) => _rpc(
    'growth_review_incident_v1',
    {'p_id': id, 'p_status': status, 'p_note': note},
  ).then((_) {});
  Future<void> appeal(String id, String note) => _rpc(
    'growth_appeal_incident_v1',
    {'p_id': id, 'p_note': note},
  ).then((_) {});
  Future<void> payout(String id, String reference) async {
    final result = await call('growth_admin_payout_v1', {
      'p_claim': id,
      'p_reference': reference,
    });
    if (result['success'] != true) throw StateError('growth_payout_failed');
  }

  static String uuid() {
    final random = Random.secure();
    final b = List.generate(16, (_) => random.nextInt(256));
    b[6] = (b[6] & 15) | 64;
    b[8] = (b[8] & 63) | 128;
    final hex = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  String get _consentKey =>
      'growth_analytics_consent_${SupabaseService.instance.currentUser?.id}';
  Future<bool> consent() async =>
      (await SharedPreferences.getInstance()).getBool(_consentKey) ?? false;
  Future<bool> startupSound() async =>
      (await SharedPreferences.getInstance()).getBool('growth_startup_sound') ??
      true;
  Future<void> setStartupSound(bool enabled) async {
    if (!await (await SharedPreferences.getInstance()).setBool(
      'growth_startup_sound',
      enabled,
    ))
      throw StateError('startup_sound_not_saved');
  }

  Future<void> setConsent(bool value) async {
    if (!await (await SharedPreferences.getInstance()).setBool(
      _consentKey,
      value,
    )) {
      throw StateError('analytics_consent_not_saved');
    }
  }

  Future<void> event(
    String name, {
    Map<String, dynamic> properties = const {},
    String? key,
  }) async {
    if (!buildEnabled || !await consent()) return;
    // Analytics is optional. Report failures to its own caller; never block a trip.
    await _rpc('growth_event_v1', {
      'p_key': key ?? uuid(),
      'p_name': name,
      'p_properties': properties,
      'p_consent': true,
    }).timeout(const Duration(seconds: 15));
  }
}
