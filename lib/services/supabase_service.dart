import 'phone_identity.dart';
import 'account_scoped_read_pool.dart';
import 'admin_pulse_hub_v15.dart';
import 'scale_metrics_v15.dart';
import 'dart:math';
import 'dart:async';
import 'trip_realtime_v10.dart';
import 'trip_data_v10.dart';
import 'search_cancellation_coordinator.dart';
import 'growth_service.dart';
export 'trip_realtime_v10.dart' show TripRealtimeLease;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();

  SupabaseService._();

  /// UI-only refresh signal. Server read receipts remain authoritative.
  final ValueNotifier<int> karizmaCustomerOpen = ValueNotifier<int>(0);
  final _addressReads = AccountScopedReadPool<List<Map<String, dynamic>>>();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://wbdjvzaomtlojttjnfhp.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_ka2F1Q8N1nE1eqzqK8pcQg_hlPZUllU',
  );

  static Future<void> initialize() async {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw Exception('SUPABASE_URL and SUPABASE_ANON_KEY must be defined.');
    }
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
  }

  SupabaseClient get client => Supabase.instance.client;

  // ─── AUTH ───────────────────────────────────────────────────────────────────

  User? get currentUser => client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  Future<void> signOut() async {
    // Local only: signing out of this device must NOT disconnect the other one.
    await client.auth.signOut(scope: SignOutScope.local);
  }

  /// Server-owned one-device slot. Must be called just after real Auth login,
  /// BEFORE customer/profile/trip requests. No phone, code or device ID is
  /// accepted: the database reads auth.uid() and JWT session_id itself.
  Future<void> activateSessionV25() async {
    final raw = await client.rpc('v25_activate_session');
    final result = Map<String, dynamic>.from(raw as Map);
    if (result['success'] != true) {
      // Never leave a rejected new login half-authenticated on this device.
      try {
        await client.auth.signOut(scope: SignOutScope.local);
      } catch (_) {}
      throw Exception(result['error'] ?? 'session_activation_failed');
    }
    // Supabase Auth revokes other REFRESH TOKENS. The DB slot + table guards
    // independently reject their still-unexpired JWT access tokens.
    try {
      await client.auth.signOut(scope: SignOutScope.others);
    } catch (_) {
      // The DB single-session slot was already activated. The global
      // session checker and DB guards do not rely on refresh-token revocation.
    }
  }

  Future<Map<String, dynamic>> sessionStatusV25() async {
    try {
      final raw = await client
          .rpc('v25_session_status')
          .timeout(const Duration(seconds: 5));
      return Map<String, dynamic>.from(raw as Map);
    } catch (_) {
      return {'active': true, 'registered': true};
    }
  }

  Future<void> adminEndUserSessionV25(String userId) async {
    final raw = await client.rpc(
      'v25_admin_end_user_session',
      params: {'p_user_id': userId},
    );
    final result = Map<String, dynamic>.from(raw as Map);
    if (result['success'] != true) {
      throw Exception(result['error'] ?? 'session_termination_failed');
    }
  }

  // ─── USER PROFILE ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final res = await client
        .from('user_profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return res;
  }

  Future<String?> getUserRole(String userId) async {
    final metadata = currentUser?.id == userId
        ? currentUser?.appMetadata
        : null;
    if (metadata?['role'] == 'staff') return 'staff';
    final res = await client
        .from('user_profiles')
        .select('user_role')
        .eq('id', userId)
        .maybeSingle();
    if (metadata?['v16_applicant'] == true && res?['user_role'] != 'captain')
      return 'applicant';
    return res?['user_role'] as String?;
  }

  // ─── VERIFICATION REQUESTS ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> createVerificationRequest(String phone) async {
    final normalized = _normalizePhone(phone);
    if (!PhoneIdentity.supportsVerificationInput(normalized)) {
      throw StateError('international_phone_not_enabled');
    }

    dynamic response;
    try {
      response = await client.functions.invoke(
        'send-phone-otp',
        body: {'phone': normalized},
      );
      if (response.data is Map && response.data['success'] == true) {
        return Map<String, dynamic>.from(response.data as Map);
      }
    } catch (_) {}

    // Fallback to product-phone-request if send-phone-otp is not deployed yet
    try {
      response = await client.functions.invoke(
        'product-phone-request',
        body: {'phone': normalized},
      );
      final data = response.data;
      if (data is Map && data['success'] == true) {
        return Map<String, dynamic>.from(data);
      }
      if (data is Map && data['error'] != null) {
        throw StateError('${data['error']}');
      }
    } catch (e) {
      if (e is StateError) rethrow;
    }

    final data = response?.data;
    if (data is! Map || data['success'] != true) {
      throw StateError(
        data is Map ? '${data['error']}' : 'verification_request_failed',
      );
    }
    return Map<String, dynamic>.from(data);
  }

  /// Verify a 4-digit OTP code against the server without logging out an existing session
  Future<bool> verifyPhoneOtp(String phone, String code) async {
    final res = await verifyPhoneOtpWithResult(phone, code);
    return res['success'] == true && res['verified'] == true;
  }

  /// Verify a 4-digit OTP code against the server and return full response data
  Future<Map<String, dynamic>> verifyPhoneOtpWithResult(String phone, String code) async {
    final normalized = _normalizePhone(phone);
    if (normalized.isEmpty || code.trim().length != 4) {
      return {'success': false, 'error': 'invalid_code'};
    }

    try {
      final response = await client.functions.invoke(
        'send-phone-otp',
        body: {'phone': normalized, 'code': code.trim(), 'action': 'verify'},
      );
      final data = response.data;
      if (data is Map && data['success'] == true && data['verified'] == true) {
        return {'success': true, 'verified': true};
      }
      if (data is Map && data['error'] != null) {
        return {'success': false, 'error': data['error']};
      }
    } catch (_) {
      try {
        final response = await client.functions.invoke(
          'product-phone-request',
          body: {'phone': normalized, 'code': code.trim(), 'action': 'verify'},
        );
        final data = response.data;
        if (data is Map && data['success'] == true && data['verified'] == true) {
          return {'success': true, 'verified': true};
        }
        if (data is Map && data['error'] != null) {
          return {'success': false, 'error': data['error']};
        }
      } catch (e) {
        return {'success': false, 'error': '$e'};
      }
    }
    return {'success': false, 'error': 'verification_failed'};
  }

  Future<Map<String, dynamic>?> getLatestVerificationRequest(
    String phone,
  ) async {
    // Verification request rows are intentionally hidden from the mobile app.
    return null;
  }

  /// Verifies and consumes a customer code on the trusted backend, then
  /// returns a short-lived Supabase Auth token. The mobile app never reads
  /// verification rows or compares codes locally.
  Future<Map<String, dynamic>> customerCodeLogin(
    String phone,
    String code,
  ) async {
    final normalized = _normalizePhone(phone);
    if (!PhoneIdentity.supportsVerificationInput(normalized)) {
      throw StateError('international_phone_not_enabled');
    }
    final response = await client.functions.invoke(
      normalized.startsWith('+')
          ? 'product-international-login'
          : 'customer-code-login',
      body: {'phone': _normalizePhone(phone), 'code': code.trim()},
    );

    if (response.data == null || response.data is! Map) {
      throw Exception('invalid_server_response');
    }

    return Map<String, dynamic>.from(response.data as Map);
  }

  // ─── CUSTOMERS ───────────────────────────────────────────────────────────────

  /// Checks whether a phone number is available for registration or phone change.
  /// Returns false if the phone is already registered to an existing customer or captain.
  Future<bool> isPhoneAvailable(String phone, {String? excludeCustomerId}) async {
    final normalized = _normalizePhone(phone);
    if (normalized.isEmpty) return false;

    // 1. Check via backend function with service_role permissions
    try {
      final res = await client.functions.invoke(
        'send-phone-otp',
        body: {
          'phone': normalized,
          'action': 'check_availability',
          if (excludeCustomerId != null && excludeCustomerId.isNotEmpty)
            'exclude_customer_id': excludeCustomerId,
        },
      );
      if (res.data is Map && res.data['success'] == true) {
        return res.data['available'] == true;
      }
    } catch (_) {
      try {
        final res = await client.functions.invoke(
          'product-phone-request',
          body: {
            'phone': normalized,
            'action': 'check_availability',
            if (excludeCustomerId != null && excludeCustomerId.isNotEmpty)
              'exclude_customer_id': excludeCustomerId,
          },
        );
        if (res.data is Map && res.data['success'] == true) {
          return res.data['available'] == true;
        }
      } catch (_) {}
    }

    // 2. Fallback to get_login_role_by_phone RPC
    try {
      final role = await getLoginRoleByPhone(normalized);
      if (role != null && role.isNotEmpty) {
        return false;
      }
    } catch (_) {}

    return true;
  }

  Future<Map<String, dynamic>?> getCustomerByPhone(String phone) async {
    final normalized = _normalizePhone(phone);
    final res = await client
        .from('customers')
        .select()
        .eq('phone', normalized)
        .maybeSingle();
    return res;
  }

  Future<Map<String, dynamic>?> getCustomerByUserId(String userId) async {
    final res = await client
        .from('customers')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return res;
  }

  Future<Map<String, dynamic>> createCustomer({
    required String userId,
    required String phone,
    String? fullName,
  }) async {
    final normalized = _normalizePhone(phone);

    // First check if a customer already exists for this user_id or phone
    // to prevent duplicate accounts
    final existing = await getCustomerByUserId(userId);
    if (existing != null) {
      // Already exists — update name if provided
      if (fullName != null && fullName.isNotEmpty) {
        await client
            .from('customers')
            .update({'full_name': fullName})
            .eq('id', existing['id'] as String);
        return {...existing, 'full_name': fullName};
      }
      return existing;
    }

    // Also check by phone
    final existingByPhone = await getCustomerByPhone(normalized);
    if (existingByPhone != null) {
      // Link to this user_id if not already linked
      if (existingByPhone['user_id'] == null) {
        await client
            .from('customers')
            .update({'user_id': userId})
            .eq('id', existingByPhone['id'] as String);
      }
      if (fullName != null && fullName.isNotEmpty) {
        await client
            .from('customers')
            .update({'full_name': fullName})
            .eq('id', existingByPhone['id'] as String);
      }
      return existingByPhone;
    }

    // Create new customer
    final insertData = <String, dynamic>{
      'user_id': userId,
      'phone': normalized,
      // Keep compatibility with databases where full_name is still NOT NULL.
      // The onboarding screen can replace the empty value later.
      'full_name': fullName?.trim() ?? '',
      'wallet_balance': 0,
    };

    final res = await client
        .from('customers')
        .insert(insertData)
        .select()
        .single();
    return res;
  }

  /// Ensure a customer profile exists for an authenticated user (e.g. after Google Sign-In)
  Future<Map<String, dynamic>> ensureCustomerProfile({
    required String userId,
    String? phone,
    String? fullName,
  }) async {
    // 0. Ensure V25 session is active so database triggers will not reject writes
    try {
      await activateSessionV25();
    } catch (_) {}

    // 1. Check if customer already exists for this user_id
    final existing = await getCustomerByUserId(userId);
    if (existing != null) {
      if (fullName != null &&
          fullName.isNotEmpty &&
          (existing['full_name'] == null ||
              existing['full_name'].toString().isEmpty)) {
        await client
            .from('customers')
            .update({'full_name': fullName})
            .eq('id', existing['id'] as String);
        return {...existing, 'full_name': fullName};
      }
      return existing;
    }

    // 2. If phone is provided, check if a customer with this phone exists and link it
    if (phone != null && phone.trim().isNotEmpty) {
      final normalized = _normalizePhone(phone);
      if (normalized.isNotEmpty) {
        final existingByPhone = await getCustomerByPhone(normalized);
        if (existingByPhone != null) {
          if (existingByPhone['user_id'] == null) {
            await client
                .from('customers')
                .update({'user_id': userId})
                .eq('id', existingByPhone['id'] as String);
          }
          if (fullName != null && fullName.isNotEmpty) {
            await client
                .from('customers')
                .update({'full_name': fullName})
                .eq('id', existingByPhone['id'] as String);
          }
          return existingByPhone;
        }
      }
    }

    // 3. Fallback phone generation if empty (Egyptian format: 010 + 8 digits)
    String customerPhone = (phone != null && phone.trim().isNotEmpty)
        ? _normalizePhone(phone)
        : '';
    if (customerPhone.isEmpty) {
      final numericPart = userId.replaceAll(RegExp(r'\D'), '').padRight(8, '0').substring(0, 8);
      customerPhone = '010$numericPart';
    }

    // 4. Insert new customer
    final insertData = <String, dynamic>{
      'user_id': userId,
      'phone': customerPhone,
      'full_name': fullName?.trim() ?? '',
      'wallet_balance': 0,
    };

    try {
      final res = await client
          .from('customers')
          .insert(insertData)
          .select()
          .single();
      if (phone != null && phone.trim().isNotEmpty) {
        try {
          await client.auth.updateUser(
            UserAttributes(data: {'phone_provided': true, 'phone': customerPhone}),
          );
        } catch (_) {}
      }
      return res;
    } catch (e) {
      final timestampSuffix = DateTime.now().millisecondsSinceEpoch.toString();
      final retryPhone = '010${timestampSuffix.substring(timestampSuffix.length - 8)}';
      insertData['phone'] = retryPhone;
      final res = await client
          .from('customers')
          .insert(insertData)
          .select()
          .single();
      return res;
    }
  }

  /// Update and link a real phone number to a customer account (e.g. after Google Sign-In)
  Future<void> linkAndSavePhoneForUser({
    required String userId,
    required String customerId,
    required String phone,
  }) async {
    try {
      await activateSessionV25();
    } catch (_) {}

    final normalized = _normalizePhone(phone);
    if (normalized.isEmpty) return;

    // 1. Check if an existing customer profile already exists with this phone
    final existingByPhone = await getCustomerByPhone(normalized);
    if (existingByPhone != null && existingByPhone['id'] != customerId) {
      // Link the existing customer record to this user_id
      await client
          .from('customers')
          .update({'user_id': userId})
          .eq('id', existingByPhone['id'] as String);

      // Deactivate or remove the temporary placeholder row if it has no trips
      try {
        await client
            .from('customers')
            .delete()
            .eq('id', customerId);
      } catch (_) {}
    } else {
      // Update the current customer row with the real phone
      await client
          .from('customers')
          .update({'phone': normalized})
          .eq('id', customerId);
    }

    // 2. Also update user_profiles if present
    try {
      await client
          .from('user_profiles')
          .update({'phone': normalized})
          .eq('id', userId);
    } catch (_) {}

    // 3. Mark in user metadata that a real phone has been provided
    try {
      await client.auth.updateUser(
        UserAttributes(data: {'phone_provided': true, 'phone': normalized}),
      );
    } catch (_) {}
  }

  /// Link Google OAuth account to the currently logged in user
  Future<AuthResponse> linkGoogleAccount({
    required String idToken,
    String? accessToken,
  }) async {
    final response = await client.auth.linkIdentityWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
    return response;
  }

  /// Check whether the current authenticated user has a linked Google account
  bool isGoogleLinked() {
    final user = currentUser;
    if (user == null) return false;
    final identities = user.identities ?? [];
    final hasGoogle = identities.any((i) => i.provider.toLowerCase() == 'google');
    final providers = user.appMetadata['providers'];
    final hasGoogleInProviders = (providers is List && providers.contains('google')) ||
        (providers is String && providers.contains('google'));
    final isGoogleEmail = user.email != null && user.email!.endsWith('@gmail.com');
    final metadataGoogle = user.userMetadata?['google_linked'] == true;
    return hasGoogle || hasGoogleInProviders || isGoogleEmail || metadataGoogle;
  }

  /// Get the email address of the linked Google account (if any)
  String? getLinkedGoogleEmail() {
    final user = currentUser;
    if (user == null) return null;
    final identities = user.identities ?? [];
    for (final identity in identities) {
      if (identity.provider.toLowerCase() == 'google') {
        final email = identity.identityData?['email'];
        if (email != null && email.toString().isNotEmpty) {
          return email.toString();
        }
      }
    }
    if (user.email != null && user.email!.isNotEmpty) {
      return user.email;
    }
    return user.userMetadata?['google_email']?.toString() ??
        user.userMetadata?['email']?.toString();
  }

  /// Mark that the name onboarding screen was shown (so we don't show it again
  /// even if the customer chose "لاحقًا")
  Future<void> markNameOnboardingShown(String customerId) async {
    await client
        .from('customers')
        .update({'onboarding_shown_at': DateTime.now().toIso8601String()})
        .eq('id', customerId);
  }

  /// Mark name onboarding as completed (name was saved)
  Future<void> markNameOnboardingCompleted(String customerId) async {
    await client
        .from('customers')
        .update({'name_onboarding_completed': true})
        .eq('id', customerId);
  }

  Future<void> updateCustomerName(
    String customerId,
    String fullName, {
    String? userId,
  }) async {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return;

    try {
      await activateSessionV25();
    } catch (_) {}

    await client
        .from('customers')
        .update({'full_name': trimmed, 'name_onboarding_completed': true})
        .eq('id', customerId);

    final resolvedUserId = userId ?? currentUser?.id;
    if (resolvedUserId != null) {
      try {
        await client
            .from('user_profiles')
            .update({'full_name': trimmed})
            .eq('id', resolvedUserId);
      } catch (_) {}
    }

    try {
      await client.auth.updateUser(
        UserAttributes(data: {'full_name': trimmed, 'name': trimmed}),
      );
    } catch (_) {}
  }

  // ─── CAPTAINS ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getCaptainByUserId(String userId) async {
    final res = await client
        .from('captains')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    final photo = res?['profile_photo']?.toString();
    if (res != null && photo != null && photo.startsWith('v16-private://')) {
      try {
        res['profile_photo'] = await client.storage
            .from('v16-captain-documents')
            .createSignedUrl(photo.substring(14), 300);
      } catch (_) {
        res['profile_photo'] = null;
      }
    }
    return res;
  }

  Future<Map<String, dynamic>?> getCaptainByPhone(String phone) async {
    final res = await client
        .from('captains')
        .select()
        .eq('phone', phone)
        .maybeSingle();
    return res;
  }

  /// Resolve the account type by phone before authentication.
  /// Uses a SECURITY DEFINER RPC so an unauthenticated customer/captain
  /// verification request never needs direct RLS access to captains/customers.
  Future<String?> getLoginRoleByPhone(String phone) async {
    final normalized = _normalizePhone(phone);
    final result = await client.rpc(
      'get_login_role_by_phone',
      params: {'p_phone': normalized},
    );
    if (result == null) return null;
    return result.toString();
  }

  Future<void> updateCaptainOnlineStatus(
    String captainId,
    bool isOnline,
  ) async {
    final result = await client.rpc(
      'set_captain_online_v20',
      params: {'p_captain_id': captainId, 'p_online': isOnline},
    );
    final data = Map<String, dynamic>.from((result as Map?) ?? const {});
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'captain_online_update_failed');
    }
  }

  Future<void> updateCaptainLocation(
    String captainId,
    double lat,
    double lng,
  ) async {
    final result = await client.rpc(
      'update_captain_location',
      params: {'p_captain_id': captainId, 'p_lat': lat, 'p_lng': lng},
    );
    final data = Map<String, dynamic>.from((result as Map?) ?? const {});
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'captain_location_update_failed');
    }
  }

  Future<List<Map<String, dynamic>>> getEligibleCaptains(
    String serviceType,
  ) async {
    var query = client
        .from('captains')
        .select()
        .eq('is_online', true)
        .eq('is_available', true)
        .eq('captain_status', 'active');

    switch (serviceType) {
      case 'car_ride':
        query = query.eq('can_do_car_ride', true);
        break;
      case 'motorcycle_ride':
        query = query.eq('can_do_motorcycle_ride', true);
        break;
      case 'package':
        query = query.eq('can_do_package', true);
        break;
      case 'vito_market':
        query = query.eq('can_do_vito_market', true);
        break;
    }

    final res = await query;
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> getAllCaptains() async {
    try {
      final res = await client.rpc(
        'get_admin_captains_v2',
        params: {'p_limit': 500},
      );
      if (res is List) {
        final captains = res
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        // Some older admin RPC versions omit profile_photo. Enrich only this
        // field from the captain table under existing admin RLS permissions.
        try {
          final photoRows = await client
              .from('captains')
              .select('id,profile_photo,custom_commission')
              .inFilter('id', captains.map((c) => c['id']).toList());
          final extras = {
            for (final row in photoRows)
              row['id'].toString(): Map<String, dynamic>.from(row),
          };
          for (final captain in captains) {
            final extra = extras[captain['id']?.toString()];
            if (extra == null) continue;
            captain['profile_photo'] ??= extra['profile_photo'];
            captain['custom_commission'] = extra['custom_commission'];
          }
        } catch (_) {
          /* Keep RPC results and avatar fallback. */
        }
        return captains;
      }
    } catch (_) {}
    final res = await client
        .from('captains')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Admin-only source for the live map. Active/live classification stays in
  /// the UI so an old location is never presented as current by accident.
  Future<List<Map<String, dynamic>>> getCaptainsForLiveMap({
    double south = 29.88,
    double north = 30.08,
    double west = 31.02,
    double east = 31.23,
  }) async {
    final raw = await client.rpc(
      'admin_map_window_scale_v15',
      params: {
        'p_south': south,
        'p_north': north,
        'p_west': west,
        'p_east': east,
      },
    );
    return List<Map<String, dynamic>>.from(raw['captains'] as List);
  }

  // ─── CAPTAIN CREATION VIA EDGE FUNCTION ─────────────────────────────────────

  Future<Map<String, dynamic>> createCaptainViaEdgeFunction({
    required String fullName,
    required String phone,
    required String vehicleType,
    String? vehicleBrand,
    String? vehicleModel,
    String? vehicleYear,
    String? vehicleColor,
    String? vehiclePlate,
    String captainStatus = 'active',
    bool canDoCarRide = false,
    bool canDoMotorcycleRide = false,
    bool canDoPackage = false,
    bool canDoVitoMarket = false,
  }) async {
    try {
      final response = await client.functions.invoke(
        'create-captain',
        body: {
          'full_name': fullName,
          'phone': phone,
          'vehicle_type': vehicleType,
          'vehicle_brand': vehicleBrand,
          'vehicle_model': vehicleModel,
          'vehicle_year': vehicleYear,
          'vehicle_color': vehicleColor,
          'vehicle_plate': vehiclePlate,
          'captain_status': captainStatus,
          'can_do_car_ride': canDoCarRide,
          'can_do_motorcycle_ride': canDoMotorcycleRide,
          'can_do_package': canDoPackage,
          'can_do_vito_market': canDoVitoMarket,
        },
      );
      if (response.data != null) {
        final data = Map<String, dynamic>.from(response.data as Map);
        return data;
      }
      return {'success': false, 'error': 'لا توجد استجابة من الخادم'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Rotates every linked captain's hidden Auth credential. The Edge Function
  /// independently verifies that the caller is an active administrator.
  Future<Map<String, dynamic>> hardenAllCaptainCredentials() async {
    final response = await client.functions.invoke(
      'rotate-captain-credentials',
      body: const <String, dynamic>{},
    );
    if (response.data is! Map) {
      throw Exception('invalid_server_response');
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'captain_credential_rotation_failed');
    }
    return data;
  }

  // ─── OFFER MATCHING VIA SECURITY DEFINER RPC ─────────────────────────────────
  // Calls the backend RPC that enforces all eligibility rules server-side.
  // Returns the number of offers created.
  // Eligibility enforced by RPC (cannot be bypassed by UI):
  //   - service match (can_do_X = true)
  //   - vehicle-type compatibility (car_ride → car, motorcycle_ride → motorcycle)
  //   - captain_status = active
  //   - is_online = true, is_available = true
  //   - not on active trip
  //   - negative settlement balance must stay ABOVE minus the admin debt limit

  Future<int> createTripOffersViaRpc(String tripId) async {
    final result = await client.rpc(
      'start_wave_dispatch',
      params: {'p_trip_id': tripId},
    );
    if (result is num) return result.toInt();
    if (result is String) {
      final parsed = int.tryParse(result);
      if (parsed != null) return parsed;
    }
    throw Exception('matching_invalid_response');
  }

  // ─── PENDING OFFERS FOR CAPTAIN (on startup/restore) ─────────────────────────
  // Loads any still-valid pending offers for a captain from the database.
  // This ensures offers survive app restart/refresh.

  /// Captain-only offer summary. New RPC returns a nested `trips` object; the
  /// normalization also accepts the legacy flattened DTO without guessing a
  /// fare or exposing commission before acceptance.
  Future<List<Map<String, dynamic>>> getPendingOffersForCaptain(
    String captainId,
  ) async {
    final result = await client.rpc(
      'get_captain_pending_offers_v4',
      params: {'p_captain_id': captainId},
    );

    final raw = result is List
        ? result
        : (result is Map && result['offers'] is List
              ? result['offers'] as List
              : const []);
    final normalized = raw.whereType<Map>().map((item) {
      final offer = Map<String, dynamic>.from(item);
      if (offer['trips'] is! Map) {
        offer['trips'] = <String, dynamic>{
          'id': offer['trip_id'],
          'service_type': offer['service_type'],
          'pickup_address': offer['pickup_address'],
          'destination_address': offer['destination_address'],
          'distance_km': offer['distance_km'],
          'customer_note': offer['customer_note'],
          'incentive_amount': offer['incentive_amount'],
        };
      }
      return offer;
    }).toList();

    // One authenticated, read-only, captain-scoped RPC. Never query unassigned
    // trips directly or modify booking/financial records to prepare a preview.
    // Missing migration or offline? Keep offers usable, but omit the price.
    try {
      final response = await client.rpc('get_captain_offer_previews_v1');
      if (response is List) {
        final previews = <String, Map<String, dynamic>>{};
        for (final row in response.whereType<Map>()) {
          final preview = Map<String, dynamic>.from(row);
          final offerId = preview['offer_id']?.toString();
          if (offerId != null) previews[offerId] = preview;
        }
        for (final offer in normalized) {
          final preview = previews[offer['id']?.toString()];
          if (preview == null) continue;
          offer['estimated_fare_min'] = preview['estimated_fare_min'];
          offer['estimated_fare_max'] = preview['estimated_fare_max'];
          final trip = Map<String, dynamic>.from(offer['trips'] as Map);
          trip['incentive_amount'] = preview['incentive_amount'];
          offer['trips'] = trip;
        }
      }
    } on PostgrestException catch (e) {
      // Optional preview migration is not yet installed, or RLS/RPC rejected it.
      debugPrint('Captain offer preview unavailable: ${e.code}');
    } catch (e) {
      debugPrint('Captain offer preview refresh unavailable: $e');
    }
    return normalized;
  }

  // ─── TRIPS ───────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getActiveTrip(String customerId) async {
    final res = await client
        .from('trips')
        .select()
        .eq('customer_id', customerId)
        .inFilter('trip_status', [
          'requested',
          'offer_received',
          'accepted',
          'arriving',
          'arrived',
          'started',
        ])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return res;
  }

  Future<Map<String, dynamic>?> getActiveTripForCaptain(
    String captainId,
  ) async {
    final res = await client
        .from('trips')
        .select()
        .eq('captain_id', captainId)
        .inFilter('trip_status', ['accepted', 'arriving', 'arrived', 'started'])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (res == null) return null;
    final row = Map<String, dynamic>.from(res);
    try {
      return await getTripById(row['id'].toString()) ?? row;
    } catch (_) {}
    return row;
  }

  Future<Map<String, dynamic>> createTrip({
    required String customerId,
    required String serviceType,
    required String pickupAddress,
    required String destinationAddress,
    double? pickupLat,
    double? pickupLng,
    double? destLat,
    double? destLng,
    String? pickupAreaLetter,
    String? pickupBuildingNumber,
    String? destAreaLetter,
    String? destBuildingNumber,
    double? distanceKm,
    int? durationMinutes,
    double? baseFare,
    double incentiveAmount = 0,
    double? totalFare,
    String paymentMethod = 'cash',
    double walletAmount = 0,
    double cashAmount = 0,
    double? packageWeightKg,
    String? deliveryPin,
    String? promoCode,
    double promoDiscount = 0,
    double? expectedGrowthDiscount,
    bool skipEarnedGrowthDiscount = false,
    String customerNote = '',
    String extraRequests = '',
    String? pricingQuoteId,
    String? categoryId,
    List<String> tripPromises = const [],
    bool ladiesTermsAccepted = false,
    double? extraExpectedAmount,
    double customerPreviousDue = 0,
    bool isOutsideCity = false,
  }) async {
    // Financial values are intentionally calculated/validated in Supabase.
    // The legacy numeric arguments remain in the method signature so callers
    // in the current UI do not need a broad refactor in this first fix.
    final result = await client
        .rpc(
          categoryId != null ? 'v3_book_category' : GrowthService.buildEnabled && !skipEarnedGrowthDiscount
              ? 'create_trip_growth_v2'
              : 'create_trip_from_quote_v4',
          params: {
            'p_quote_id': pricingQuoteId,
            'p_extra_expected_amount': extraExpectedAmount,
            'p_extra_requests': extraRequests.trim().isEmpty
                ? null
                : extraRequests.trim(),
            'p_payload': {
              if (categoryId != null) ...{
                'trip_promises_v3': tripPromises,
                'ladies_terms_accepted': ladiesTermsAccepted,
                'skip_growth_v3': skipEarnedGrowthDiscount || !GrowthService.buildEnabled,
              },
              if (GrowthService.buildEnabled &&
                  !skipEarnedGrowthDiscount &&
                  expectedGrowthDiscount != null)
                'p_expected_growth_discount': expectedGrowthDiscount,
              'p_customer_id': customerId,
              'p_service_type': serviceType,
              'p_pickup_address': pickupAddress,
              'p_destination_address': destinationAddress,
              'p_pickup_latitude': pickupLat,
              'p_pickup_longitude': pickupLng,
              'p_destination_latitude': destLat,
              'p_destination_longitude': destLng,
              'p_pickup_area_letter': pickupAreaLetter,
              'p_pickup_building_number': pickupBuildingNumber,
              'p_destination_area_letter': destAreaLetter,
              'p_destination_building_number': destBuildingNumber,
              'p_distance_km': distanceKm,
              'p_duration_minutes': durationMinutes,
              'p_base_fare': baseFare,
              'p_incentive_amount': incentiveAmount,
              'p_payment_method': paymentMethod,
              'p_promo_code': promoCode,
              'p_promo_discount': promoDiscount,
              'p_customer_note': customerNote.trim().isEmpty
                  ? null
                  : customerNote.trim(),
              'p_is_outside_city': isOutsideCity,
            },
          },
        )
        .observeScaleV15('create_trip');

    final data = Map<String, dynamic>.from((result as Map?) ?? const {});
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'create_trip_failed');
    }
    final trip = Map<String, dynamic>.from((data['trip'] as Map?) ?? const {});
    if (trip['id'] == null) {
      throw Exception('trip_id_missing');
    }
    return trip;
  }

  Future<void> updateTripStatus(String tripId, String status) async {
    await advanceTripStatus(tripId, status);
  }

  Future<Map<String, dynamic>> transferChangeToCustomer({
    required String tripId,
    required String amount,
  }) async {
    final normalized = String.fromCharCodes(
      amount.trim().runes.map((rune) {
        if (rune >= 0x0660 && rune <= 0x0669) return rune - 0x0660 + 0x30;
        if (rune >= 0x06f0 && rune <= 0x06f9) return rune - 0x06f0 + 0x30;
        return rune;
      }),
    ).replaceAll(',', '.').replaceAll('٫', '.');
    if (!RegExp(r'^\d{1,9}(\.\d{1,2})?$').hasMatch(normalized) ||
        (double.tryParse(normalized) ?? 0) <= 0) {
      throw const FormatException(
        'أدخل مبلغاً موجباً بمنزلتين عشريتين كحد أقصى',
      );
    }
    final raw = await client.rpc(
      'transfer_change_to_customer',
      params: {'p_trip_id': tripId, 'p_amount': normalized},
    );
    final result = Map<String, dynamic>.from(raw as Map);
    if (result['success'] != true) throw StateError('change_transfer_failed');
    return result;
  }

  Future<List<Map<String, dynamic>>> getCustomerTrips(
    String customerId, {
    int limit = 20,
  }) async {
    final res = await client
        .from('trips')
        .select()
        .eq('customer_id', customerId)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> getCaptainTrips(
    String captainId, {
    int limit = 20,
  }) async {
    final res = await client
        .from('trips')
        .select()
        .eq('captain_id', captainId)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<Map<String, dynamic>?> getTripById(String tripId) async {
    final context = await getTripParticipantContext(tripId);
    if (context == null) return null;
    final trip = normalizeTripV10(context['trip'] as Map);
    trip['customers'] = context['customer'];
    trip['customer_context'] = context['customer'];
    trip['captains'] = context['captain'];
    trip['captain_context'] = context['captain'];
    return normalizeTripV10(trip);
  }

  Future<List<Map<String, dynamic>>> getCaptainMarketHistory({
    int limit = 50,
  }) async {
    final raw = await client.rpc(
      'captain_market_history_v10',
      params: {'p_limit': limit},
    );
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<double> getCaptainWalletBalance(String captainId) async {
    final res = await client
        .from('captains')
        .select('settlement_debt')
        .eq('id', captainId)
        .single();
    return (res['settlement_debt'] as num?)?.toDouble() ?? 0;
  }

  Future<List<Map<String, dynamic>>> getCaptainCompletedTrips(
    String captainId, {
    int limit = 100,
  }) async {
    final res = await client
        .from('trips')
        .select()
        .eq('captain_id', captainId)
        .eq('trip_status', 'completed')
        .order('completed_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> getCaptainPendingOffersRpc(
    String captainId,
  ) => getPendingOffersForCaptain(captainId);

  // ─── TRIP OFFERS ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createTripOffer({
    required String tripId,
    required String captainId,
    double? captainDistanceKm,
    int? etaMinutes,
    String? offerNote,
  }) async {
    final res = await client
        .from('trip_offers')
        .insert({
          'trip_id': tripId,
          'captain_id': captainId,
          'offer_status': 'sent',
          if (captainDistanceKm != null)
            'captain_distance_km': captainDistanceKm,
          if (etaMinutes != null) 'eta_minutes': etaMinutes,
          if (offerNote != null) 'offer_note': offerNote,
        })
        .select()
        .single();
    return res;
  }

  Future<List<Map<String, dynamic>>> getTripOffers(String tripId) async {
    final trip = await client
        .from('trips')
        .select('trip_status, captain_id')
        .eq('id', tripId)
        .maybeSingle();
    if (trip == null ||
        trip['captain_id'] != null ||
        !const {
          'requested',
          'offer_received',
        }.contains(trip['trip_status']?.toString())) {
      return [];
    }
    final res = await client
        .from('trip_offers')
        .select('*, captains(*)')
        .eq('trip_id', tripId)
        .eq('offer_status', 'accepted_by_customer')
        .order('responded_at', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> acceptOffer(
    String offerId,
    String tripId,
    String captainId,
  ) async {
    final result = await client
        .rpc(
          'select_captain_for_trip',
          params: {
            'p_offer_id': offerId,
            'p_trip_id': tripId,
            'p_captain_id': captainId,
          },
        )
        .observeScaleV15('select_captain')
        .timeout(const Duration(seconds: 15));

    final data = Map<String, dynamic>.from((result as Map?) ?? const {});
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'offer_accept_failed');
    }
  }

  /// Informational cancellation preview. The server remains authoritative.
  /// Never mutate pricing, wallet, or trip state while showing a dialog.
  Future<Map<String, dynamic>> getCustomerCancellationPreview(
    String tripId,
  ) async {
    final result = await client.rpc(
      'trip_cancellation_preview_v14',
      params: {'p_trip_id': tripId},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  /// Cancel a trip through the dedicated server RPC so wallet refunds,
  /// cancellation fees and captain availability are updated atomically.
  Future<Map<String, dynamic>> cancelTrip(
    String tripId, {
    String? reason,
  }) async {
    final isSearchCancel = reason == 'customer_cancelled_during_search';
    if (isSearchCancel) return cancelCustomerSearchV37(tripId);
    final result = await client
        .rpc(
          isSearchCancel
              ? 'v48_customer_cancel_search_atomic'
              : 'cancel_trip_v14',
          params: isSearchCancel
              ? {'p_trip_id': tripId}
              : {
                  'p_trip_id': tripId,
                  'p_reason': reason?.trim().isEmpty == true
                      ? null
                      : reason?.trim(),
                },
        )
        .observeScaleV15('cancel_trip')
        .timeout(const Duration(seconds: 15));
    final data = Map<String, dynamic>.from((result as Map?) ?? const {});
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'cancel_trip_failed');
    }
    return data;
  }

  /// V37 search cancellation is serialized against the captain acceptance.
  /// Calls V48 only, with authoritative reconciliation after an ambiguous response.
  /// Never fallback to a generic cancellation after a concurrent acceptance.
  Future<Map<String, dynamic>> cancelCustomerSearchV37(String tripId) async {
    return SearchCancellationCoordinator(
      cancel: () async {
        final result = await client
            .rpc(
              'v48_customer_cancel_search_atomic',
              params: {'p_trip_id': tripId},
            )
            .observeScaleV15('cancel_customer_search')
            .timeout(const Duration(seconds: 15));
        return Map<String, dynamic>.from((result as Map?) ?? const {});
      },
      readTrip: () => getTripById(tripId),
    ).run();
  }

  /// Advance non-cancellation trip status through the server state machine RPC.
  /// Cancellation has its own RPC because it also changes wallet/accounting.
  Future<void> advanceTripStatus(String tripId, String newStatus) async {
    if (newStatus == 'cancelled') {
      await cancelTrip(tripId);
      return;
    }

    final result = await client
        .rpc(
          'advance_trip_status_v13',
          params: {'p_trip_id': tripId, 'p_new_status': newStatus},
        )
        .timeout(const Duration(seconds: 15));

    final data = result as Map<String, dynamic>?;
    if (data == null || data['success'] != true) {
      final err = data?['error'] as String? ?? 'unknown_error';
      throw Exception('status_transition_failed: $err');
    }
  }

  Future<Map<String, dynamic>> finalizeTripFinancials(String tripId) async {
    final result = await client
        .rpc('finalize_trip_financials_v9', params: {'p_trip_id': tripId})
        .observeScaleV15('finalize_trip')
        .timeout(const Duration(seconds: 15));
    final data = Map<String, dynamic>.from((result as Map?) ?? const {});
    if (data['success'] != true) {
      throw Exception(
        'trip_financials_failed: ${data['error'] ?? 'unknown_error'}',
      );
    }
    return data;
  }

  Future<void> acceptCaptainOffer(
    String offerId,
    String tripId,
    String captainId,
  ) async {
    final result = await tripReadWithRetryV10(
      () => client
          .rpc(
            'captain_accept_trip_offer_v6',
            params: {'p_offer_id': offerId, 'p_trip_id': tripId},
          )
          .observeScaleV15('accept_trip'),
    );
    final data = Map<String, dynamic>.from((result as Map?) ?? const {});
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'offer_accept_failed');
    }
  }

  Future<void> declineCaptainTripOffer(String offerId, String captainId) async {
    final result = await client.rpc(
      'captain_decline_trip_offer_v6',
      params: {'p_offer_id': offerId},
    );
    final data = Map<String, dynamic>.from((result as Map?) ?? const {});
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'offer_decline_failed');
    }
  }

  /// Subscribe to trip offers for a trip, enriched with captain data.
  /// Used by the customer to see incoming captain offers in realtime.
  RealtimeChannel subscribeToTripOffersEnriched(
    String tripId,
    void Function(Map<String, dynamic>) onOffer,
  ) {
    Future<void> deliver(Map<String, dynamic> raw) async {
      final status = raw['offer_status']?.toString();
      // A selected captain is represented by the existing enum status.
      if (status != 'accepted_by_customer') return;
      try {
        final trip = await client
            .from('trips')
            .select('trip_status, captain_id')
            .eq('id', tripId)
            .maybeSingle();
        if (trip == null || trip['captain_id'] == null) return;
        final captainId = raw['captain_id']?.toString();
        if (captainId == null || captainId.isEmpty) return;
        final captain = await client
            .from('captains')
            .select()
            .eq('id', captainId)
            .maybeSingle();
        final enriched = Map<String, dynamic>.from(raw);
        enriched['captains'] = captain;
        onOffer(enriched);
      } catch (_) {}
    }

    return client
        .channel('offers_enriched_$tripId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'trip_offers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId,
          ),
          callback: (payload) {
            unawaited(deliver(payload.newRecord));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'trip_offers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId,
          ),
          callback: (payload) {
            unawaited(deliver(payload.newRecord));
          },
        )
        .subscribe();
  }

  /// Fetch existing captain-accepted offers for a trip, enriched with captain data.
  /// Used to restore state when customer reopens the app.
  Future<List<Map<String, dynamic>>> getTripOffersEnriched(
    String tripId,
  ) async {
    final res = await client
        .from('trip_offers')
        .select('*, captains(*)')
        .eq('trip_id', tripId)
        .eq('offer_status', 'accepted_by_customer')
        .order('responded_at', ascending: true);

    return List<Map<String, dynamic>>.from(res);
  }

  /// Get full trip data including captain info (for live trip screen).
  Future<Map<String, dynamic>?> getTripWithCaptain(String tripId) async {
    final res = await client
        .from('trips')
        .select('*, captains(*)')
        .eq('id', tripId)
        .maybeSingle();
    return res;
  }

  // ─── RATINGS ─────────────────────────────────────────────────────────────────

  Future<void> createRating({
    required String tripId,
    required String customerId,
    required String captainId,
    required int stars,
    String? comment,
  }) async {
    final r = await client.rpc(
      'submit_trip_rating',
      params: {'p_trip_id': tripId, 'p_stars': stars, 'p_comment': comment},
    );
    final data = Map<String, dynamic>.from((r as Map?) ?? const {});
    if (data['success'] != true)
      throw Exception(data['error'] ?? 'rating_failed');
  }

  Future<Map<String, dynamic>?> getTripParticipantContext(String tripId) async {
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(tripId))
      throw ArgumentError('trip_not_found');
    final result = await tripReadWithRetryV10(
      () => client.rpc(
        'get_trip_participant_context_v14',
        params: {'p_trip_id': tripId},
      ),
    );
    if (result is Map) {
      final data = Map<String, dynamic>.from(result);
      if (data['success'] == false) {
        throw Exception(data['error'] ?? 'trip_context_failed');
      }
      return data;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getTripChatMessages(
    String tripId, {
    String? before,
    String? beforeId,
    String? after,
    String? afterId,
  }) async {
    final result = await client.rpc(
      'get_trip_chat_page_scale_v15',
      params: {
        'p_trip_id': tripId,
        'p_before': before,
        'p_before_id': beforeId,
        'p_after': after,
        'p_after_id': afterId,
        'p_limit': 100,
      },
    );
    if (result is List) {
      return result
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> sendTripChatMessage({
    required String tripId,
    required String message,
    String? requestId,
  }) async {
    final result = await client.rpc(
      'send_trip_chat_message_v13',
      params: {
        'p_trip_id': tripId,
        'p_message': message,
        'p_request_id': requestId ?? newFinancialRequestId(),
      },
    );
    if (result is! Map || result['success'] != true) {
      throw Exception(
        result is Map
            ? (result['error'] ?? 'chat_send_failed')
            : 'chat_send_failed: invalid_server_response',
      );
    }
    return Map<String, dynamic>.from(result['message'] as Map);
  }

  // ─── CHAT ────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getChatMessages(String tripId) async {
    return getTripChatMessages(tripId);
  }

  Future<void> sendMessage({
    required String tripId,
    required String senderId,
    required String receiverId,
    required String message,
  }) async {
    // senderId/receiverId are retained for API compatibility.
    await sendTripChatMessage(tripId: tripId, message: message);
  }

  RealtimeChannel subscribeToChatMessages(
    String tripId,
    void Function(Map<String, dynamic>) onMessage, {
    void Function()? onReconnect,
  }) {
    return client
        .channel('chat_screen_${currentUser?.id}_$tripId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId,
          ),
          callback: (payload) => onMessage(payload.newRecord),
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) onReconnect?.call();
        });
  }

  // ─── WALLET ──────────────────────────────────────────────────────────────────

  Future<String> getCustomerDebtReason(String customerId) async {
    try {
      final rows = await client
          .from('wallet_transactions')
          .select('tx_type,amount,description,created_at')
          .eq('customer_id', customerId)
          .order('created_at', ascending: false)
          .limit(30);
      for (final row in rows) {
        final type = row['tx_type']?.toString();
        final amount = (row['amount'] as num?)?.toDouble() ?? 0;
        if (amount > 0 &&
            (type == 'penalty' || type == 'debit' || type == 'trip')) {
          final d = row['description']?.toString().trim() ?? '';
          if (d.isNotEmpty) return d;
        }
      }
    } catch (_) {}
    return 'مبلغ مستحق سابق';
  }

  Future<double> getWalletBalance(String customerId) async {
    final res = await client
        .from('customers')
        .select('wallet_balance')
        .eq('id', customerId)
        .single();
    return (res['wallet_balance'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Map<String, dynamic>>> getWalletTransactions(
    String customerId, {
    int limit = 30,
  }) async {
    final res = await client
        .from('wallet_transactions')
        .select()
        .eq('customer_id', customerId)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> getCaptainTransactions(
    String captainId, {
    int limit = 30,
  }) async {
    final res = await client
        .from('captain_transactions')
        .select()
        .eq('captain_id', captainId)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(res);
  }

  // ─── PROFILE / MEDIA / SUPPORT / PROMO / APPLICATIONS ───────────────────────

  Future<void> updateCustomerProfile(
    String customerId, {
    String? fullName,
    String? gender,
    String? profilePhotoUrl,
  }) async {
    final data = <String, dynamic>{};
    if (fullName != null) data['full_name'] = fullName;
    if (gender != null) data['gender'] = gender;
    if (profilePhotoUrl != null) data['profile_photo_url'] = profilePhotoUrl;
    if (data.isEmpty) return;
    await client.from('customers').update(data).eq('id', customerId);
  }

  Future<String> uploadPublicImage({
    required String path,
    required List<int> bytes,
    String contentType = 'image/jpeg',
  }) async {
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    await client.storage
        .from('veto-public')
        .uploadBinary(
          path,
          data,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return client.storage.from('veto-public').getPublicUrl(path);
  }

  Future<List<Map<String, dynamic>>> getActiveBanners() async {
    final rows = await client
        .from('home_banners')
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  RealtimeChannel subscribeToBanners(
    void Function(Map<String, dynamic>) onChange,
  ) => client
      .channel('home_banners_rt')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'home_banners',
        callback: (p) => onChange(p.newRecord),
      )
      .subscribe();

  Future<Map<String, dynamic>> validatePromoCode(
    String code,
    String customerId,
    double amount,
  ) async {
    final r = await client.rpc(
      'validate_promo_v17',
      params: {'p_code': code, 'p_customer_id': customerId, 'p_amount': amount},
    );
    return Map<String, dynamic>.from((r as Map?) ?? const {});
  }

  Future<Map<String, dynamic>> submitCaptainApplication({
    required String name,
    required String phone,
    required int age,
    required String vehicleType,
  }) async {
    final r = await client.rpc(
      'submit_captain_application_v3',
      params: {
        'p_name': name.trim(),
        'p_phone': _normalizePhone(phone),
        'p_age': age,
        'p_vehicle_type': vehicleType,
      },
    );
    return Map<String, dynamic>.from((r as Map?) ?? const {});
  }

  Future<List<Map<String, dynamic>>> getCaptainApplications({
    int limit = 100,
  }) async {
    try {
      final r = await client.rpc(
        'get_admin_captain_applications_v2',
        params: {'p_limit': limit},
      );
      if (r is List) {
        return r
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    final r = await client
        .from('captain_applications')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(r);
  }

  Future<void> updateCaptainApplication(
    String id,
    String status, {
    String? notes,
  }) async {
    await client
        .from('captain_applications')
        .update({
          'status': status,
          if (notes != null) 'notes': notes,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> adminSetTripStatus(String tripId, String status) async {
    const allowed = {
      'requested',
      'offer_received',
      'accepted',
      'arriving',
      'arrived',
      'started',
      'completed',
      'cancelled',
    };
    if (!allowed.contains(status)) {
      throw ArgumentError.value(status, 'status', 'Invalid trip status');
    }

    await client.rpc(
      'admin_force_update_trip_status_v13',
      params: {
        'p_trip_id': tripId,
        'p_new_status': status,
        'p_reason': 'تعديل حالة من لوحة الأدمن',
      },
    );
  }

  Future<Map<String, dynamic>> getAdminReports() async {
    return getAdminPeriodReportV26(DateTime(2020), DateTime.now());
  }

  // ─── HADAYEK AREAS & BUILDINGS ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getHadayekAreas() async {
    final res = await client
        .from('hadayek_areas')
        .select()
        .eq('is_active', true)
        .order('area_letter', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> getBuildingsByArea(
    String areaLetter,
  ) async {
    return searchBuildingsForCustomer(areaLetter: areaLetter, searchQuery: '');
  }

  Future<List<Map<String, dynamic>>> getAllBuildings() async {
    final res = await client
        .from('hadayek_buildings')
        .select('*, hadayek_areas(*)')
        .order('area_letter', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<Map<String, dynamic>> addBuilding({
    required String areaId,
    required String areaLetter,
    required String buildingNumber,
    required String displayAddress,
    double? latitude,
    double? longitude,
  }) async {
    final res = await client
        .from('hadayek_buildings')
        .insert({
          'area_id': areaId,
          'area_letter': areaLetter,
          'building_number': buildingNumber,
          'display_address': displayAddress,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
        })
        .select()
        .single();
    return res;
  }

  Future<void> updateBuilding(
    String buildingId,
    Map<String, dynamic> data,
  ) async {
    await client.from('hadayek_buildings').update(data).eq('id', buildingId);
  }

  // ─── FAMOUS PLACES ───────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getFamousPlaces() async {
    final res = await client
        .from('famous_places')
        .select()
        .eq('is_active', true)
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> getAllFamousPlaces() async {
    final res = await client
        .from('famous_places')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<Map<String, dynamic>> addFamousPlace({
    required String name,
    String? description,
    String? address,
    double? latitude,
    double? longitude,
    String? imageUrl,
    String category = 'other',
    required String createdBy,
  }) async {
    final res = await client
        .from('famous_places')
        .insert({
          'name': name,
          if (description != null) 'description': description,
          if (address != null) 'address': address,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          if (imageUrl != null) 'image_url': imageUrl,
          'category': category,
          'created_by': createdBy,
        })
        .select()
        .single();
    return res;
  }

  Future<void> updateFamousPlace(
    String placeId,
    Map<String, dynamic> data,
  ) async {
    await client.from('famous_places').update(data).eq('id', placeId);
  }

  Future<void> deleteFamousPlace(String placeId) async {
    await client.from('famous_places').delete().eq('id', placeId);
  }

  // ─── V21 PLACE CATEGORIES (managed by admin, rendered by customer) ───────────
  Future<List<Map<String, dynamic>>> getPlaceCategoriesV21({
    bool admin = false,
  }) async {
    var q = client.from('place_categories_v21').select();
    if (!admin) q = q.eq('is_active', true);
    final rows = await q.order('sort_order').order('title');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> savePlaceCategoryV21({
    required String slug,
    required String title,
    required String iconKey,
    required int sortOrder,
    required bool active,
    bool existing = false,
  }) async {
    final data = <String, dynamic>{
      'title': title.trim(),
      'icon_key': iconKey,
      'sort_order': sortOrder,
      'is_active': active,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (existing) {
      await client.from('place_categories_v21').update(data).eq('slug', slug);
    } else {
      await client.from('place_categories_v21').insert({'slug': slug, ...data});
    }
  }

  /// Forward-only, audited correction. Never sets completed/cancelled and
  /// never touches wallet amounts directly; DB verifies the admin on every call.
  Future<void> adminAdvanceTripV21({
    required String tripId,
    required String currentStatus,
    required String nextStatus,
    required String reason,
  }) async {
    final result = await client.rpc(
      'admin_force_update_trip_status_v13',
      params: {
        'p_trip_id': tripId,
        'p_new_status': nextStatus,
        'p_reason': reason,
      },
    );
    final data = Map<String, dynamic>.from((result as Map?) ?? const {});
    if (data['success'] != true)
      throw Exception(data['error'] ?? 'status_update_failed');
  }

  // ─── CUSTOMER ADDRESSES ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCustomerAddresses(
    String customerId,
  ) async {
    final owner = currentUser?.id;
    if (owner == null) throw StateError('authentication_required');
    final rows = await _addressReads.read(
      key: customerId,
      owner: owner,
      currentOwner: () => currentUser?.id,
      load: () async {
        final res = await client
            .from('customer_addresses')
            .select()
            .eq('customer_id', customerId)
            .order('is_default', ascending: false)
            .order('created_at', ascending: false);
        return List<Map<String, dynamic>>.from(res);
      },
    );
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

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
    bool isDefault = false,
    bool isOutsideCity = false,
  }) async {
    // If setting as default, unset others
    if (isDefault) {
      await client
          .from('customer_addresses')
          .update({'is_default': false})
          .eq('customer_id', customerId);
    }
    final res = await client
        .from('customer_addresses')
        .insert({
          'customer_id': customerId,
          'label': label,
          'area_letter': areaLetter,
          'building_number': buildingNumber,
          'floor': floor,
          'apartment': apartment,
          'display_address': displayAddress,
          'latitude': latitude,
          'longitude': longitude,
          'is_default': isDefault,
          'is_outside_city': isOutsideCity,
        })
        .select()
        .single();
    return res;
  }

  Future<void> updateCustomerAddress(
    String addressId,
    Map<String, dynamic> data,
  ) async {
    await client.from('customer_addresses').update(data).eq('id', addressId);
  }

  Future<void> deleteCustomerAddress(String addressId) async {
    await client.from('customer_addresses').delete().eq('id', addressId);
  }

  // ─── ADMIN WALLET ADJUSTMENTS ────────────────────────────────────────────────

  static String newFinancialRequestId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> adminAdjustCustomerWallet({
    required String customerId,
    required double amount,
    required String txType,
    required String reason,
    required String requestId,
  }) async {
    await _adminAdjustWalletV9(
      'customer',
      customerId,
      amount,
      txType,
      reason,
      requestId,
    );
  }

  Future<Map<String, dynamic>> adminAdjustCaptainWallet({
    required String captainId,
    required double amount,
    required String txType,
    required String reason,
    required String requestId,
  }) async {
    return _adminAdjustWalletV9(
      'captain',
      captainId,
      amount,
      txType,
      reason,
      requestId,
    );
  }

  Future<Map<String, dynamic>> _adminAdjustWalletV9(
    String kind,
    String ownerId,
    double amount,
    String action,
    String reason,
    String requestId,
  ) async {
    if (!amount.isFinite || amount <= 0) throw ArgumentError('invalid_amount');
    final result = await client.rpc(
      'admin_adjust_wallet_v9',
      params: {
        'p_owner_kind': kind,
        'p_owner_id': ownerId,
        'p_amount': amount,
        'p_action': action,
        'p_reason': reason.trim().isEmpty ? 'تعديل إداري' : reason.trim(),
        'p_request_id': requestId,
      },
    );
    final data = Map<String, dynamic>.from(result as Map);
    if (data['success'] != true) throw StateError('wallet_adjustment_failed');
    return data;
  }

  // ─── SEARCH BUILDINGS ────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> searchBuildings(
    String areaLetter,
    String query,
  ) async {
    final res = await client
        .from('hadayek_buildings')
        .select()
        .eq('area_letter', areaLetter)
        .eq('is_active', true)
        .ilike('building_number', '%$query%')
        .order('building_number', ascending: true)
        .limit(20);
    return List<Map<String, dynamic>>.from(res);
  }

  // ─── PRICING ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getServicePricing(String serviceType) async {
    final res = await client
        .from('service_pricing')
        .select()
        .eq('service_type', serviceType)
        .maybeSingle();
    return res;
  }

  Future<List<Map<String, dynamic>>> getAllServicePricing() async {
    final res = await client.from('service_pricing').select();
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> updateServicePricing(
    String serviceType,
    Map<String, dynamic> data,
  ) async {
    // Use UPSERT to handle both existing and missing rows
    final upsertData = Map<String, dynamic>.from(data);
    upsertData['service_type'] = serviceType;
    upsertData['updated_at'] = DateTime.now().toIso8601String();
    if (currentUser != null) upsertData['updated_by'] = currentUser!.id;

    final result = await client
        .from('service_pricing')
        .upsert(upsertData, onConflict: 'service_type')
        .select()
        .maybeSingle();

    if (result == null) {
      throw Exception('لم يتم حفظ التسعير — لم تتأثر أي صفوف');
    }
  }

  Future<Map<String, dynamic>?> getAreaPricing(
    String serviceType,
    String originArea,
    String destArea,
  ) async {
    final res = await client
        .from('area_pricing')
        .select()
        .eq('service_type', serviceType)
        .eq('origin_area_letter', originArea)
        .eq('destination_area_letter', destArea)
        .eq('is_active', true)
        .maybeSingle();
    return res;
  }

  Future<List<Map<String, dynamic>>> getAllAreaPricing() async {
    final res = await client
        .from('area_pricing')
        .select()
        .order('origin_area_letter', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  // ─── APP SETTINGS ────────────────────────────────────────────────────────────

  Future<String?> getSetting(String key) async {
    final res = await client
        .from('app_settings')
        .select('value')
        .eq('key', key)
        .maybeSingle();
    return res?['value'] as String?;
  }

  Future<List<Map<String, dynamic>>> getAllSettings() async {
    final res = await client
        .from('app_settings')
        .select()
        .order('key', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> updateSetting(String key, String value) async {
    await client.from('app_settings').upsert({
      'key': key,
      'value': value,
      'updated_at': DateTime.now().toIso8601String(),
      'updated_by': currentUser?.id,
    }, onConflict: 'key');
  }

  // ─── NOTIFICATIONS ───────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getNotifications(String userId) async {
    final res = await client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> markNotificationRead(String notificationId) async {
    await client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  Future<void> createNotification({
    required String userId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await client.from('notifications').insert({
      'user_id': userId,
      'notification_type': type,
      'title': title,
      'body': body,
      if (data != null) 'data': data,
    });
  }

  // ─── SUPERMARKETS & PRODUCTS ─────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getSupermarkets() async {
    final res = await client
        .from('supermarkets')
        .select()
        .eq('is_active', true)
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> getAllSupermarkets() async {
    final res = await client
        .from('supermarkets')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> getProductCategories(
    String supermarketId,
  ) async {
    final res = await client
        .from('product_categories')
        .select()
        .eq('supermarket_id', supermarketId)
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> getProducts(
    String supermarketId, {
    String? categoryId,
  }) async {
    var query = client
        .from('products')
        .select()
        .eq('supermarket_id', supermarketId)
        .eq('is_active', true)
        .eq('is_available', true);

    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }

    final res = await query.order('name', ascending: true);
    return List<Map<String, dynamic>>.from(
      res,
    ).map(_withEffectiveMarketPrice).toList();
  }

  Map<String, dynamic> _withEffectiveMarketPrice(Map<String, dynamic> raw) {
    final product = Map<String, dynamic>.from(raw);
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final starts = DateTime.tryParse(
      product['discount_starts_at']?.toString() ?? '',
    );
    final ends = DateTime.tryParse(
      product['discount_ends_at']?.toString() ?? '',
    );
    final now = DateTime.now().toUtc();
    final active =
        (starts == null || !starts.toUtc().isAfter(now)) &&
        (ends == null || ends.toUtc().isAfter(now));
    final fixed = (product['discount_price'] as num?)?.toDouble();
    final percent = (product['discount_percent'] as num?)?.toDouble();
    var effective = price;
    if (active && fixed != null && fixed > 0 && fixed < price) {
      effective = fixed;
    } else if (active && percent != null && percent > 0 && percent <= 90) {
      effective = price * (100 - percent) / 100;
    }
    product['effective_price'] = double.parse(effective.toStringAsFixed(2));
    product['has_active_discount'] = effective < price;
    return product;
  }

  Future<List<Map<String, dynamic>>> getAllProductCategories(
    String supermarketId,
  ) async {
    final r = await client
        .from('product_categories')
        .select()
        .eq('supermarket_id', supermarketId)
        .order('sort_order');
    return List<Map<String, dynamic>>.from(r);
  }

  Future<void> saveProductCategory({
    String? id,
    required String supermarketId,
    required String name,
    String? imageUrl,
  }) async {
    final d = {
      'supermarket_id': supermarketId,
      'name': name,
      'image_url': imageUrl,
      'is_active': true,
    };
    if (id == null) {
      await client.from('product_categories').insert(d);
    } else {
      await client.from('product_categories').update(d).eq('id', id);
    }
  }

  Future<void> saveProduct({
    String? id,
    required String supermarketId,
    String? categoryId,
    required String name,
    required double price,
    String? unit,
    String? imageUrl,
    bool available = true,
  }) async {
    final d = {
      'supermarket_id': supermarketId,
      'category_id': categoryId,
      'name': name,
      'price': price,
      'unit': unit,
      'image_url': imageUrl,
      'is_available': available,
      'is_active': true,
    };
    if (id == null) {
      await client.from('products').insert(d);
    } else {
      await client.from('products').update(d).eq('id', id);
    }
  }

  Future<void> setProductActive(String id, bool value) async {
    await client.from('products').update({'is_active': value}).eq('id', id);
  }

  Future<void> setCategoryActive(String id, bool value) async {
    await client
        .from('product_categories')
        .update({'is_active': value})
        .eq('id', id);
  }

  // ─── ADMIN ───────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllVerificationRequests() async {
    final res = await client
        .from('verification_requests')
        .select()
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> assignVerificationCode(String requestId, String code) async {
    await client.rpc(
      'v16_assign_verification',
      params: {'p_id': requestId, 'p_code': code},
    );
  }

  Future<void> cancelVerificationRequest(String requestId) async {
    await client.rpc('v16_cancel_verification', params: {'p_id': requestId});
  }

  Future<int> expireStaleVerificationRequests({
    Duration maxAge = const Duration(minutes: 30),
  }) async {
    return (await client.rpc('v16_expire_verification') as num).toInt();
  }

  Future<int> getPendingMarketOrdersCount() async {
    final res = await client
        .from('market_orders')
        .select('id')
        .eq('order_status', 'pending')
        .count(CountOption.exact);
    return res.count;
  }

  Future<List<Map<String, dynamic>>> getEditableHomeBanners() async {
    final rows = await client.from('home_banners').select().order('sort_order');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> saveHomeBanner({
    String? bannerId,
    required String title,
    String? subtitle,
    String? imageUrl,
    required String actionType,
    bool isActive = true,
    int sortOrder = 0,
  }) async {
    final payload = {
      'title': title.trim(),
      'subtitle': subtitle?.trim().isEmpty ?? true ? null : subtitle?.trim(),
      'image_url': imageUrl?.trim().isEmpty ?? true ? null : imageUrl?.trim(),
      'action_type': actionType,
      'is_active': isActive,
      'sort_order': sortOrder,
    };
    if (bannerId == null) {
      await client.from('home_banners').insert(payload);
    } else {
      await client.from('home_banners').update(payload).eq('id', bannerId);
    }
  }

  // ─── V16: Admin customer management (server-calculated statistics) ─────────
  Future<List<Map<String, dynamic>>> getAdminCustomersV16() async {
    final result = await client.rpc('admin_customers_v16');
    return (result as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<Map<String, dynamic>> getAdminCustomerProfileV16(
    String customerId,
  ) async {
    final result = await client.rpc(
      'admin_customer_profile_v16',
      params: {'p_customer_id': customerId},
    );
    final data = Map<String, dynamic>.from(result as Map);
    if (data['success'] != true)
      throw Exception(data['error'] ?? 'customer_not_found');
    return data;
  }

  Future<void> adminEditCustomerV16(
    String customerId, {
    String? fullName,
    String? profilePhotoUrl,
    bool? isActive,
  }) async {
    final result = await client.rpc(
      'admin_edit_customer_v16',
      params: {
        'p_customer_id': customerId,
        'p_full_name': fullName,
        'p_profile_photo_url': profilePhotoUrl,
        'p_is_active': isActive,
      },
    );
    final data = Map<String, dynamic>.from(result as Map);
    if (data['success'] != true)
      throw Exception(data['error'] ?? 'customer_update_failed');
  }

  Future<void> adminUpdateCustomerPhoneV16(
    String customerId,
    String phone,
  ) async {
    final result = await client.functions.invoke(
      'admin-customer-phone',
      body: {'customer_id': customerId, 'new_phone': _normalizePhone(phone)},
    );
    if (result.data is! Map) throw Exception('phone_function_not_deployed');
    final data = Map<String, dynamic>.from(result.data as Map);
    if (data['success'] != true)
      throw Exception(data['error'] ?? 'phone_update_failed');
  }

  Future<Map<String, dynamic>> adminPromoteCustomerV16({
    required String customerId,
    required String fullName,
    required String vehicleType,
    String? vehicleBrand,
    String? vehicleModel,
    int? vehicleYear,
    String? vehicleColor,
    String? vehiclePlate,
    required String captainStatus,
    required bool canDoCarRide,
    required bool canDoMotorcycleRide,
    required bool canDoPackage,
    required bool canDoVitoMarket,
  }) async {
    final result = await client.rpc(
      'admin_promote_customer_v16',
      params: {
        'p_customer_id': customerId,
        'p_full_name': fullName,
        'p_vehicle_type': vehicleType,
        'p_vehicle_brand': vehicleBrand,
        'p_vehicle_model': vehicleModel,
        'p_vehicle_year': vehicleYear,
        'p_vehicle_color': vehicleColor,
        'p_vehicle_plate': vehiclePlate,
        'p_captain_status': captainStatus,
        'p_can_do_car_ride': canDoCarRide,
        'p_can_do_motorcycle_ride': canDoMotorcycleRide,
        'p_can_do_package': canDoPackage,
        'p_can_do_vito_market': canDoVitoMarket,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> getMyAccountAccessV16() async {
    try {
      final result = await client
          .rpc('my_account_access_v16')
          .timeout(const Duration(seconds: 5));
      return Map<String, dynamic>.from(result as Map);
    } catch (_) {
      return {'allowed': true};
    }
  }

  Future<List<Map<String, dynamic>>> getAllCustomers() async {
    final res = await client
        .from('customers')
        .select(
          '*, user_profiles!customers_user_id_fkey(created_at,updated_at,user_role,is_active)',
        )
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<Map<String, dynamic>> getAdminCustomerProfile(
    String customerId,
  ) async {
    final r = await client.rpc(
      'get_admin_customer_profile_v2',
      params: {'p_customer_id': customerId},
    );
    final data = Map<String, dynamic>.from((r as Map?) ?? const {});
    if (data['success'] != true)
      throw Exception(data['error'] ?? 'customer_profile_failed');
    return data;
  }

  Future<List<Map<String, dynamic>>> getAdminCustomerTrips(
    String customerId, {
    int limit = 200,
  }) async {
    final res = await client
        .from('trips')
        .select('*, captains(full_name,phone,profile_photo)')
        .eq('customer_id', customerId)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> getAllTrips({int limit = 50}) async {
    return getAdminTripsPageV9(limit: limit);
  }

  Future<List<Map<String, dynamic>>> getAdminTripsPageV9({
    int limit = 100,
    String? before,
    String? beforeId,
  }) async {
    final result = await client.rpc(
      'admin_list_trips_v14',
      params: {
        'p_limit': limit.clamp(1, 500),
        'p_before': before,
        'p_before_id': beforeId,
      },
    );
    return (result as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<Map<String, dynamic>> getSearchPriceSuggestionV9(String tripId) async {
    final result = await client.rpc(
      'search_price_suggestion_v9',
      params: {'p_trip_id': tripId},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> decideSearchPriceV9(
    String tripId,
    String suggestionId,
    bool useSuggested,
  ) async {
    final result = await client.rpc(
      'decide_search_price_v9',
      params: {
        'p_trip_id': tripId,
        'p_suggestion_id': suggestionId,
        'p_use_suggested': useSuggested,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  /// Exact trip search, including records outside the currently displayed rows.
  Future<Map<String, dynamic>?> findAdminTripV21(String id) async {
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id)) return null;
    final result = await client.rpc(
      'admin_find_trip_v14',
      params: {'p_trip_id': id},
    );
    if (result == null) return null;
    final row = Map<String, dynamic>.from(result as Map);
    return row.isEmpty ? null : row;
  }

  /// Full financial invoice for admin/captain-facing historical views.
  /// All final amounts come from the DB snapshot, not Flutter-side math.
  Future<Map<String, dynamic>> getTripInvoice(String tripId) async {
    final context = await getTripParticipantContext(tripId);
    if (context == null) throw StateError('trip_invoice_failed');
    final trip = normalizeTripV10(context['trip'] as Map);
    return {
      ...context,
      'trip': trip,
      'invoice': trip['financial_preview_v11'] ?? trip,
    };
  }

  Future<Map<String, dynamic>> getAdminDashboardStats() async {
    final result = await client
        .rpc('admin_dashboard_stats_scale_v15')
        .observeScaleV15('dashboard_read');
    if (result is! Map) throw StateError('admin_report_unavailable');
    return Map<String, dynamic>.from(result);
  }

  Future<void> createCaptain({
    required String userId,
    required String phone,
    required String fullName,
    required String vehicleType,
    String? vehicleBrand,
    String? vehicleModel,
    String? vehiclePlate,
    bool canDoCarRide = false,
    bool canDoMotorcycleRide = false,
    bool canDoPackage = false,
    bool canDoVitoMarket = false,
  }) async {
    await client.from('captains').insert({
      'user_id': userId,
      'phone': phone,
      'full_name': fullName,
      'vehicle_type': vehicleType,
      if (vehicleBrand != null) 'vehicle_brand': vehicleBrand,
      if (vehicleModel != null) 'vehicle_model': vehicleModel,
      if (vehiclePlate != null) 'vehicle_plate': vehiclePlate,
      'can_do_car_ride': canDoCarRide,
      'can_do_motorcycle_ride': canDoMotorcycleRide,
      'can_do_package': canDoPackage,
      'can_do_vito_market': canDoVitoMarket,
    });
  }

  Future<void> updateCaptain(
    String captainId,
    Map<String, dynamic> data,
  ) async {
    if (currentUser?.appMetadata['role'] == 'staff') {
      await client.rpc(
        'v16_staff_edit_captain',
        params: {'p_id': captainId, 'p_patch': data},
      );
      return;
    }
    await client.from('captains').update(data).eq('id', captainId);
  }

  Future<void> addAuditLog({
    required String adminId,
    required String action,
    required String entityType,
    String? entityId,
    Map<String, dynamic>? details,
  }) async {
    await client.from('audit_logs').insert({
      'admin_id': adminId,
      'action': action,
      'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (details != null) 'details': details,
    });
  }

  Future<List<Map<String, dynamic>>> getAuditLogs({int limit = 50}) async {
    final res = await client.rpc(
      'admin_audit_log_v10',
      params: {'p_limit': limit},
    );
    return List<Map<String, dynamic>>.from(res);
  }

  // ─── REALTIME ────────────────────────────────────────────────────────────────

  RealtimeChannel subscribeToTripOffers(
    String tripId,
    void Function(Map<String, dynamic>) onOffer,
  ) {
    return client
        .channel('offers_$tripId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'trip_offers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId,
          ),
          callback: (payload) => onOffer(payload.newRecord),
        )
        .subscribe();
  }

  late final TripRealtimeHub _tripHubV10 = TripRealtimeHub(client, getTripById);
  TripRealtimeLease subscribeToTripStatus(
    String tripId,
    void Function(Map<String, dynamic>) onUpdate,
  ) => _tripHubV10.watch(tripId, onUpdate);

  RealtimeChannel subscribeToVerificationRequests(
    void Function(Map<String, dynamic>) onNew,
  ) {
    return client
        .channel('verifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'verification_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'status',
            value: 'pending',
          ),
          callback: (payload) => onNew(payload.newRecord),
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            onNew(const {'_realtime_sync': true});
          }
        });
  }

  RealtimeChannel subscribeToCaptainOffers(
    String captainId,
    void Function(Map<String, dynamic>) onOffer,
  ) {
    return client
        .channel('captain_offers_$captainId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'trip_offers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'captain_id',
            value: captainId,
          ),
          callback: (payload) => onOffer(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'trip_offers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'captain_id',
            value: captainId,
          ),
          callback: (p) => onOffer({...p.newRecord, '_offer_changed': true}),
        )
        .subscribe((status, error) {
          onOffer({'_realtime_connection': status.name});
          if (status == RealtimeSubscribeStatus.subscribed) {
            onOffer(const {'_realtime_sync': true});
          }
        });
  }

  /// Subscribe to offer status changes for a captain.
  /// Used to detect when customer chose another captain (customer_chose_other).
  RealtimeChannel subscribeToCaptainOfferUpdates(
    String captainId,
    void Function(Map<String, dynamic>) onUpdate,
  ) {
    return client
        .channel('captain_offer_updates_$captainId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'trip_offers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'captain_id',
            value: captainId,
          ),
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .subscribe();
  }

  /// Subscribe to wallet balance changes for a customer.
  RealtimeChannel subscribeToCustomerWallet(
    String customerId,
    void Function(Map<String, dynamic>) onUpdate,
  ) {
    return client
        .channel('customer_wallet_$customerId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'customers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: customerId,
          ),
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .subscribe();
  }

  /// Subscribe to new notifications for a user.
  RealtimeChannel subscribeToNotifications(
    String userId,
    void Function(Map<String, dynamic>) onNew,
  ) {
    return client
        .channel('notifications_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => onNew(payload.newRecord),
        )
        .subscribe();
  }

  /// Subscribe to market order status changes.
  RealtimeChannel subscribeToMarketOrder(
    String orderId,
    void Function(Map<String, dynamic>) onUpdate,
  ) {
    return client
        .channel('market_order_$orderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'market_orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: orderId,
          ),
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .subscribe();
  }

  /// Subscribe to new market orders for a captain (vito_market service).
  RealtimeChannel subscribeToNewMarketOrders(
    void Function(Map<String, dynamic>) onNew,
  ) {
    return client
        .channel('market_orders_new')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'market_orders',
          callback: (payload) => onNew(payload.newRecord),
        )
        .subscribe();
  }

  /// Admin screens observe one small, server-throttled invalidation row.
  /// Raw trip/captain/wallet tables are never subscribed to by these helpers.
  late final _scaleAdminHub = AdminPulseHubV15(client);
  TripRealtimeLease subscribeToScaleAdminPulse(void Function() refresh) =>
      _scaleAdminHub.watch(refresh);
  TripRealtimeLease subscribeToAllTrips(
    void Function(Map<String, dynamic>, String) onEvent,
  ) => subscribeToScaleAdminPulse(() => onEvent({}, 'resync'));
  TripRealtimeLease subscribeToCaptainStatus(
    void Function(Map<String, dynamic>) onUpdate,
  ) => subscribeToScaleAdminPulse(() => onUpdate({}));
  TripRealtimeLease subscribeToWalletTransactions(
    void Function(Map<String, dynamic>) onNew,
  ) => subscribeToScaleAdminPulse(() => onNew({}));

  /// Snapshot current pricing into a trip (preserves historical pricing).
  Future<void> snapshotTripPricing(String tripId) async {
    try {
      await client.rpc('snapshot_trip_pricing', params: {'p_trip_id': tripId});
    } catch (_) {
      // Non-critical — don't crash trip creation
    }
  }

  /// Get current pricing for a service from DB (authoritative source).
  Future<Map<String, dynamic>?> getServicePricingFromRpc(
    String serviceType,
  ) async {
    try {
      final r = await client.rpc(
        'get_service_pricing',
        params: {'p_service_type': serviceType},
      );
      if (r is Map && r.isNotEmpty) {
        return Map<String, dynamic>.from(r);
      }
    } catch (_) {
      // Fall through to the service_pricing table.
    }

    final row = await client
        .from('service_pricing')
        .select(
          'service_type,price_per_km_inside,price_per_km_outside,minimum_fare,'
          'commission_percent,free_waiting_minutes,waiting_rate_per_minute,'
          'captain_cancellation_fee,customer_cancellation_fee,'
          'captain_debt_threshold,long_trip_alert_threshold',
        )
        .eq('service_type', serviceType)
        .maybeSingle();

    if (row == null) return null;

    return {
      'service_type': row['service_type'],
      'inside_price_per_km': row['price_per_km_inside'],
      'outside_price_per_km': row['price_per_km_outside'],
      'minimum_fare': row['minimum_fare'],
      'commission_percent': row['commission_percent'],
      'free_waiting_minutes': row['free_waiting_minutes'],
      'waiting_rate_per_minute': row['waiting_rate_per_minute'],
      'captain_cancellation_fee': row['captain_cancellation_fee'],
      'customer_cancellation_fee': row['customer_cancellation_fee'],
      'captain_debt_threshold': row['captain_debt_threshold'],
      'long_trip_alert_threshold': row['long_trip_alert_threshold'],
    };
  }

  // ─── LEADERBOARD ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCustomerLeaderboard({
    int limit = 20,
  }) async {
    final res = await client
        .from('customers')
        .select('full_name, total_completed_trips')
        .order('total_completed_trips', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(res);
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────────

  String _normalizePhone(String phone) {
    try {
      return PhoneIdentity.lookup(phone);
    } catch (_) {
      return PhoneIdentity.normalizeDigits(phone).trim();
    }
  }

  double calculateFare({
    required double distanceKm,
    required double pricePerKm,
    required double minimumFare,
    double incentive = 0,
    double waitingCharge = 0,
  }) {
    final base = distanceKm * pricePerKm;
    final fare = base < minimumFare ? minimumFare : base;
    return fare + incentive + waitingCharge;
  }

  Future<Map<String, dynamic>> setTripIncentiveTargetV13(
    String tripId,
    int targetAmount, {
    String? requestId,
  }) async {
    if (targetAmount <= 0) {
      throw ArgumentError('invalid_boost');
    }
    final raw = await client.rpc(
      'set_trip_incentive_v13',
      params: {
        'p_trip_id': tripId,
        'p_target': targetAmount,
        'p_request_id': requestId ?? newFinancialRequestId(),
      },
    );
    final data = Map<String, dynamic>.from((raw as Map?) ?? const {});
    if (data['success'] != true) {
      throw StateError(data['error']?.toString() ?? 'boost_failed');
    }
    return data;
  }

  Future<void> updateTripIncentive(
    String tripId,
    double incentiveAmount,
  ) async {
    await setTripIncentiveTargetV13(tripId, incentiveAmount.round());
  }

  Future<void> updateTripIncentiveSimple(
    String tripId,
    double incentiveAmount,
    double baseFare,
  ) => updateTripIncentive(tripId, incentiveAmount);

  Future<List<Map<String, dynamic>>> getMarketOrders({
    String? customerId,
    int limit = 20,
  }) async {
    var query = client.from('market_orders').select('*, market_order_items(*)');
    if (customerId != null) {
      query = query.eq('customer_id', customerId);
    }
    final res = await query.order('created_at', ascending: false).limit(limit);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> getAdminMarketOrders({
    int limit = 200,
  }) async {
    final result = await client.rpc(
      'admin_list_market_orders_v2',
      params: {'p_limit': limit},
    );
    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> adminUpdateMarketOrderStatus({
    required String orderId,
    required String status,
  }) async {
    final result = await client.rpc(
      'market_transition_order_v8',
      params: {
        'p_order_id': orderId,
        'p_to_status': status,
        'p_reason': status == 'cancelled' ? 'إلغاء يدوي بواسطة الإدارة' : null,
      },
    );
    final data = Map<String, dynamic>.from((result as Map?) ?? const {});
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'market_status_update_failed');
    }
  }

  Future<List<Map<String, dynamic>>> getVitoMarketDeliveryPricing() async {
    final result = await client.rpc('get_vito_market_delivery_pricing_v2');
    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> upsertVitoMarketDeliveryPricing({
    required String areaLetter,
    required double deliveryFee,
  }) async {
    final result = await client.rpc(
      'admin_upsert_vito_market_delivery_pricing_v2',
      params: {
        'p_area_letter': areaLetter.trim(),
        'p_delivery_fee': deliveryFee,
      },
    );
    final data = Map<String, dynamic>.from((result as Map?) ?? const {});
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'delivery_pricing_update_failed');
    }
  }

  Future<double> getVitoMarketDeliveryFee(String? areaLetter) async {
    final result = await client.rpc(
      'get_vito_market_delivery_fee_v2',
      params: {'p_area_letter': areaLetter?.trim()},
    );
    final data = Map<String, dynamic>.from((result as Map?) ?? const {});
    return (data['delivery_fee'] as num?)?.toDouble() ?? 0;
  }

  Future<void> setSupermarketActive(String supermarketId, bool active) async {
    final ok = await client.rpc(
      'admin_set_supermarket_active_v2',
      params: {'p_supermarket_id': supermarketId, 'p_is_active': active},
    );
    final data = Map<String, dynamic>.from((ok as Map?) ?? const {});
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'supermarket_update_failed');
    }
  }

  Future<Map<String, dynamic>> getMerchantDashboard() async {
    final result = await client.rpc('merchant_dashboard_v6');
    final data = Map<String, dynamic>.from((result as Map?) ?? const {});
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'merchant_dashboard_failed');
    }
    final rawOrders = data['orders'];
    if (rawOrders is List) {
      data['orders'] = rawOrders.whereType<Map>().map((raw) {
        final context = Map<String, dynamic>.from(raw);
        final order = context['order'] is Map
            ? Map<String, dynamic>.from(context['order'] as Map)
            : <String, dynamic>{};
        return <String, dynamic>{
          ...order,
          'items': context['items'] ?? const [],
          'captain': context['captain'],
          'customer': context['customer'],
          'history': context['history'] ?? const [],
        };
      }).toList();
    }
    return data;
  }

  Future<void> updateMerchantPayout({
    required String method,
    required String details,
  }) async {
    final raw = await client.rpc(
      'merchant_update_payout_v3',
      params: {'p_method': method, 'p_details': details},
    );
    final result = Map<String, dynamic>.from((raw as Map?) ?? const {});
    if (result['success'] != true) {
      throw Exception(result['error'] ?? 'payout_update_failed');
    }
  }

  Future<List<Map<String, dynamic>>> getAdminMarketSettlements() async {
    final raw = await client
        .from('market_settlements')
        .select(
          '*, supermarkets(name,settlement_payout_method,settlement_payout_details)',
        )
        .order('business_date', ascending: false)
        .limit(300);
    return List<Map<String, dynamic>>.from(raw);
  }

  Future<void> completeMarketSettlement({
    required String settlementId,
    required String reference,
    String? notes,
  }) async {
    final raw = await client.rpc(
      'admin_complete_market_settlement_v3',
      params: {
        'p_settlement_id': settlementId,
        'p_reference': reference,
        'p_notes': notes,
      },
    );
    final result = Map<String, dynamic>.from((raw as Map?) ?? const {});
    if (result['success'] != true) {
      throw Exception(result['error'] ?? 'settlement_completion_failed');
    }
  }

  Future<List<Map<String, dynamic>>> getMerchantProducts(
    String supermarketId,
  ) async {
    final result = await client
        .from('products')
        .select()
        .eq('supermarket_id', supermarketId)
        .order('name');
    return List<Map<String, dynamic>>.from(
      result,
    ).map(_withEffectiveMarketPrice).toList();
  }

  Future<void> updateMerchantProduct({
    required String productId,
    double? price,
    double? stock,
    bool? trackStock,
    bool? available,
  }) async {
    final values = <String, dynamic>{};
    if (price != null) values['price'] = price;
    if (trackStock != null) values['track_stock'] = trackStock;
    if (trackStock == true) values['stock_quantity'] = stock ?? 0;
    if (trackStock == false) values['stock_quantity'] = null;
    if (available != null) values['is_available'] = available;
    if (values.isEmpty) return;
    await client.from('products').update(values).eq('id', productId);
  }

  Future<void> saveMerchantProduct({
    String? productId,
    required String name,
    String? description,
    String? categoryId,
    String? imageUrl,
    required double price,
    String? unit,
    String? sku,
    String? barcode,
    required bool trackStock,
    double? stock,
    required bool available,
    required bool active,
    double? discountPercent,
    double? discountPrice,
    DateTime? discountStartsAt,
    DateTime? discountEndsAt,
  }) async {
    final raw = await client.rpc(
      'merchant_upsert_product_v6',
      params: {
        'p_product_id': productId,
        'p_name': name.trim(),
        'p_description': description?.trim(),
        'p_category_id': categoryId,
        'p_image_url': imageUrl?.trim(),
        'p_price': price,
        'p_unit': unit?.trim(),
        'p_sku': sku?.trim(),
        'p_barcode': barcode?.trim(),
        'p_track_stock': trackStock,
        'p_stock_quantity': stock,
        'p_is_available': available,
        'p_is_active': active,
        'p_discount_percent': discountPercent,
        'p_discount_price': discountPrice,
        'p_discount_starts_at': discountStartsAt?.toUtc().toIso8601String(),
        'p_discount_ends_at': discountEndsAt?.toUtc().toIso8601String(),
      },
    );
    final result = Map<String, dynamic>.from((raw as Map?) ?? const {});
    if (result['success'] != true) {
      throw Exception(result['error'] ?? 'product_save_failed');
    }
  }

  Future<void> archiveMerchantProduct(String productId) async {
    final raw = await client.rpc(
      'merchant_archive_product_v6',
      params: {'p_product_id': productId},
    );
    final result = Map<String, dynamic>.from((raw as Map?) ?? const {});
    if (result['success'] != true) {
      throw Exception(result['error'] ?? 'product_archive_failed');
    }
  }

  Future<List<Map<String, dynamic>>> getMerchantStaff() async {
    final raw = await client.rpc('merchant_list_staff_v6');
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> saveMerchantStaff({
    String? membershipId,
    required String phone,
    required String fullName,
    required String role,
    required bool canManageProducts,
    required bool canManageOrders,
    required bool canViewFinance,
    required bool active,
  }) async {
    final raw = await client.rpc(
      'merchant_upsert_staff_v6',
      params: {
        'p_membership_id': membershipId,
        'p_phone': phone,
        'p_full_name': fullName,
        'p_role': role,
        'p_can_manage_products': canManageProducts,
        'p_can_manage_orders': canManageOrders,
        'p_can_view_finance': canViewFinance,
        'p_is_active': active,
      },
    );
    final result = Map<String, dynamic>.from((raw as Map?) ?? const {});
    if (result['success'] != true) {
      throw Exception(result['error'] ?? 'staff_save_failed');
    }
  }

  Future<void> transitionMarketOrder({
    required String orderId,
    required String status,
    String? reason,
  }) async {
    final raw = await client.rpc(
      'market_transition_order_v8',
      params: {
        'p_order_id': orderId,
        'p_to_status': status,
        'p_reason': reason,
      },
    );
    final result = Map<String, dynamic>.from((raw as Map?) ?? const {});
    if (result['success'] != true) {
      throw Exception(result['error'] ?? 'market_transition_failed');
    }
  }

  Future<List<Map<String, dynamic>>> getEligibleMarketCaptains(
    String orderId,
  ) async {
    final raw = await client.rpc(
      'admin_market_captains_v8',
      params: {'p_order_id': orderId},
    );
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> assignMarketCaptain({
    required String orderId,
    required String captainId,
  }) async {
    final raw = await client.rpc(
      'admin_assign_market_captain_v8',
      params: {'p_order_id': orderId, 'p_captain_id': captainId},
    );
    final result = Map<String, dynamic>.from((raw as Map?) ?? const {});
    if (result['success'] != true) {
      throw Exception(result['error'] ?? 'market_assignment_failed');
    }
  }

  Future<Map<String, dynamic>> upsertSupermarketWithOwner({
    String? supermarketId,
    required String name,
    required String phone,
    required String address,
    required double latitude,
    required double longitude,
    required String ownerPhone,
    required String ownerName,
    required double commissionPercent,
    required bool active,
    required bool open,
    required int deliveryEstimateMinutes,
    String? logoUrl,
    String? coverUrl,
    String? openingHours,
  }) async {
    final raw = await client.rpc(
      'admin_upsert_supermarket_v4',
      params: {
        'p_supermarket_id': supermarketId,
        'p_name': name,
        'p_phone': phone,
        'p_address': address,
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_owner_phone': ownerPhone,
        'p_owner_name': ownerName,
        'p_commission_percent': commissionPercent,
        'p_is_active': active,
        'p_is_open': open,
        'p_delivery_estimate_minutes': deliveryEstimateMinutes,
        'p_logo_url': logoUrl,
        'p_cover_url': coverUrl,
        'p_opening_hours': openingHours,
      },
    );
    final result = Map<String, dynamic>.from((raw as Map?) ?? const {});
    if (result['success'] != true) {
      throw Exception(result['error'] ?? 'supermarket_save_failed');
    }
    return result;
  }

  Future<Map<String, dynamic>?> getMerchantOwner(String supermarketId) async {
    final result = await client
        .from('merchant_memberships')
        .select('phone,full_name')
        .eq('supermarket_id', supermarketId)
        .eq('merchant_role', 'owner')
        .eq('is_active', true)
        .maybeSingle();
    return result;
  }

  Future<Map<String, dynamic>> getMarketOrderContext(String orderId) async {
    final raw = await client.rpc(
      'market_order_context_v4',
      params: {'p_order_id': orderId},
    );
    final result = Map<String, dynamic>.from((raw as Map?) ?? const {});
    if (result['success'] != true) {
      throw Exception(result['error'] ?? 'market_order_context_failed');
    }
    return result;
  }

  Future<Map<String, dynamic>?> getCaptainMarketAssignment() async {
    final raw = await client.rpc('captain_market_assignment_v8');
    if (raw is! Map || raw.isEmpty) return null;
    return Map<String, dynamic>.from(raw);
  }

  Future<Map<String, dynamic>> respondToMarketAssignment({
    required String assignmentId,
    required bool accept,
    String? reason,
  }) async {
    final raw = await client.rpc(
      'captain_respond_market_assignment_v4',
      params: {
        'p_assignment_id': assignmentId,
        'p_accept': accept,
        'p_reason': reason,
      },
    );
    final result = Map<String, dynamic>.from((raw as Map?) ?? const {});
    if (result['success'] != true) {
      throw Exception(result['error'] ?? 'market_assignment_response_failed');
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> getMarketMessages(String orderId) async {
    final raw = await client.rpc(
      'get_market_messages_v4',
      params: {'p_order_id': orderId},
    );
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<void> markMarketChatNotificationsRead(String orderId) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    await client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('notification_type', 'chat')
        .contains('data', {'market_order_id': orderId});
  }

  Future<void> sendMarketMessage(String orderId, String message) async {
    final raw = await client.rpc(
      'send_market_message_v8',
      params: {'p_order_id': orderId, 'p_message': message.trim()},
    );
    final result = Map<String, dynamic>.from((raw as Map?) ?? const {});
    if (result['success'] != true) {
      throw Exception(result['error'] ?? 'market_message_failed');
    }
  }

  RealtimeChannel subscribeToMarketMessages(
    String orderId,
    void Function() onMessage,
  ) {
    return client
        .channel('market_messages_$orderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'market_order_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'order_id',
            value: orderId,
          ),
          callback: (_) => onMessage(),
        )
        .subscribe();
  }

  // ─── HADAYEK BUILDINGS ───────────────────────────────────────────────────────

  /// Submit customer GPS for an absent pickup building. The server requires a
  /// current V25 session, enforces submission limits and keeps it unverified.
  /// Never write directly to hadayek_buildings from a customer Flutter client.
  Future<Map<String, dynamic>> suggestPickupBuildingV27({
    required String area,
    required int number,
    required double latitude,
    required double longitude,
    required double accuracyMeters,
  }) async {
    final raw = await client.rpc(
      'customer_suggest_pickup_building_v27',
      params: {
        'p_area_letter': area,
        'p_building_number': number,
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_accuracy_m': accuracyMeters,
      },
    );
    final result = Map<String, dynamic>.from(raw as Map);
    if (result['success'] != true) {
      throw Exception(result['error'] ?? 'building_submission_failed');
    }
    // V33 provenance is captured by a database trigger on the actual V27 write.
    return result;
  }

  /// Customer-facing: search active+verified buildings by area + number prefix.
  /// Uses SECURITY DEFINER RPC so customers can only see active/verified buildings.
  Future<List<Map<String, dynamic>>> searchBuildingsGlobalForCustomer({
    required String searchQuery,
  }) async {
    final result = await client.rpc(
      'search_hadayek_buildings_global_v2',
      params: {'p_search_query': searchQuery.trim()},
    );

    if (result is! List) return const <Map<String, dynamic>>[];

    return result
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<List<Map<String, dynamic>>> searchBuildingsForCustomer({
    required String areaLetter,
    String searchQuery = '',
  }) async {
    try {
      final result = await client.rpc(
        'search_hadayek_buildings',
        params: {
          'p_area_letter': areaLetter,
          'p_search_query': searchQuery,
          'p_active_only': true,
        },
      );
      return List<Map<String, dynamic>>.from(result as List);
    } catch (_) {}

    try {
      var q = client
          .from('hadayek_buildings')
          .select()
          .eq('area_letter', areaLetter)
          .eq('is_active', true)
          .eq('verification_status', 'verified')
          .not('verified_by_admin', 'is', null)
          .not('latitude', 'is', null)
          .not('longitude', 'is', null);
      final term = searchQuery.trim();
      if (term.isNotEmpty) {
        final buildingNumber = int.tryParse(term);
        if (buildingNumber == null) return [];
        q = q.eq('building_number', buildingNumber);
      }
      final res = await q.order('building_number', ascending: true).limit(500);
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }

  /// Admin-facing: search all buildings with filters (no active/verified restriction).
  Future<List<Map<String, dynamic>>> adminSearchBuildings({
    String? areaLetter,
    String searchQuery = '',
    String? verificationStatus,
    bool? isActive,
  }) async {
    try {
      final params = <String, dynamic>{'p_search_query': searchQuery};
      if (areaLetter != null) params['p_area_letter'] = areaLetter;
      if (verificationStatus != null) {
        params['p_verification_status'] = verificationStatus;
      }
      if (isActive != null) params['p_is_active'] = isActive;

      final result = await client.rpc(
        'admin_search_hadayek_buildings',
        params: params,
      );
      return List<Map<String, dynamic>>.from(result as List);
    } catch (e) {
      // Fallback: direct query without RPC
      var query = client
          .from('hadayek_buildings')
          .select()
          .order('area_letter', ascending: true)
          .order('building_number', ascending: true)
          .limit(100);
      final res = await query;
      var list = List<Map<String, dynamic>>.from(res);
      if (areaLetter != null) {
        list = list.where((b) => b['area_letter'] == areaLetter).toList();
      }
      if (verificationStatus != null) {
        list = list
            .where((b) => b['verification_status'] == verificationStatus)
            .toList();
      }
      if (isActive != null) {
        list = list
            .where((b) => (b['is_active'] as bool?) == isActive)
            .toList();
      }
      if (searchQuery.isNotEmpty) {
        list = list.where((b) {
          final num = b['building_number']?.toString() ?? '';
          return num.startsWith(searchQuery);
        }).toList();
      }
      return list;
    }
  }

  Future<Map<String, dynamic>?> getBuildingById(String buildingId) async {
    final res = await client
        .from('hadayek_buildings')
        .select()
        .eq('id', buildingId)
        .maybeSingle();
    return res;
  }

  Future<Map<String, dynamic>?> getBuildingByAreaAndNumber(
    String areaLetter,
    int buildingNumber,
  ) async {
    final res = await client
        .from('hadayek_buildings')
        .select()
        .eq('area_letter', areaLetter)
        .eq('building_number', buildingNumber)
        .maybeSingle();
    return res;
  }

  /// Realtime subscription for building changes (admin + customer screens).
  /// Calls [onUpdate] whenever a building record changes.
  RealtimeChannel subscribeToBuildingChanges({
    String? areaLetter,
    required void Function(Map<String, dynamic> building) onUpdate,
  }) {
    final channelName = areaLetter != null
        ? 'buildings_area_$areaLetter'
        : 'buildings_all';
    final channel = client.channel(channelName);
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'hadayek_buildings',
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isNotEmpty) {
              if (areaLetter == null || record['area_letter'] == areaLetter) {
                onUpdate(record);
              }
            }
          },
        )
        .subscribe();
    return channel;
  }

  // ─── MARKET ATOMIC CHECKOUT ────────────────────────────────────────────────

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
    String? notes,
    String? idempotencyKey,
  }) async {
    final result = await client.rpc(
      'veto_market_order_v8',
      params: {
        'p_customer_id': customerId,
        'p_supermarket_id': supermarketId,
        'p_delivery_address': deliveryAddress,
        'p_delivery_area_letter': areaLetter,
        'p_delivery_latitude': latitude,
        'p_delivery_longitude': longitude,
        'p_payment_method': paymentMethod,
        'p_items': items,
        'p_promo_code': promoCode?.trim().isEmpty == true
            ? null
            : promoCode?.trim().toUpperCase(),
        'p_notes': notes,
        'p_idempotency_key': idempotencyKey,
      },
    );

    if (result is! Map) {
      throw Exception('market_order_failed');
    }
    final map = Map<String, dynamic>.from(result);
    if (map['success'] != true) {
      throw Exception(map['error'] ?? 'market_order_failed');
    }
    return map;
  }

  Future<Map<String, dynamic>> validateMarketPromo({
    required String supermarketId,
    required String code,
    required double subtotal,
  }) async {
    final raw = await client.rpc(
      'validate_market_promo_v8',
      params: {
        'p_supermarket_id': supermarketId,
        'p_code': code.trim().toUpperCase(),
        'p_subtotal': subtotal,
      },
    );
    final result = Map<String, dynamic>.from((raw as Map?) ?? const {});
    if (result['success'] != true) {
      throw Exception(result['error'] ?? 'promo_invalid');
    }
    return result;
  }

  Future<Map<String, dynamic>> cancelCaptainMarketOrder({
    required String orderId,
    String reason = 'captain_cancelled',
  }) async {
    final raw = await client.rpc(
      'captain_cancel_market_assignment_v8',
      params: {'p_order_id': orderId, 'p_reason': reason},
    );
    final result = Map<String, dynamic>.from((raw as Map?) ?? const {});
    if (result['success'] != true) {
      throw Exception(result['error'] ?? 'market_cancel_failed');
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> getAdminMarketPromos({
    String? supermarketId,
  }) async {
    final raw = await client.rpc(
      'admin_list_market_promos_v8',
      params: {'p_supermarket_id': supermarketId},
    );
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<void> saveAdminMarketPromo({
    String? id,
    required String supermarketId,
    required String code,
    required String discountType,
    required double discountValue,
    double minimumSubtotal = 0,
    double? maximumDiscount,
    int? maxUses,
    bool active = true,
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    final raw = await client.rpc(
      'admin_save_market_promo_v8',
      params: {
        'p_id': id,
        'p_supermarket_id': supermarketId,
        'p_code': code.trim().toUpperCase(),
        'p_discount_type': discountType,
        'p_discount_value': discountValue,
        'p_minimum_subtotal': minimumSubtotal,
        'p_maximum_discount': maximumDiscount,
        'p_max_uses': maxUses,
        'p_is_active': active,
        'p_starts_at': startsAt?.toUtc().toIso8601String(),
        'p_ends_at': endsAt?.toUtc().toIso8601String(),
      },
    );
    final result = Map<String, dynamic>.from((raw as Map?) ?? const {});
    if (result['success'] != true) {
      throw Exception(result['error'] ?? 'market_promo_save_failed');
    }
  }

  // ─── KARIZMA ────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getKarizmaPosts(String audience) async {
    final result = await client.rpc(
      'v26_karizma_feed',
      params: {'p_audience': audience},
    );
    final posts = (result as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final originalLikes = <String, int>{
      for (final post in posts)
        if (post['id'] != null)
          post['id'].toString(): ((post['likes'] as num?) ?? 0).toInt(),
    };
    // Visual counts may be corrected by owner without mutating real reactions.
    // V34 is additive: the existing feed remains usable before its migration.
    try {
      final overrides = await client.rpc(
        'v34_karizma_like_displays',
        params: {'p_audience': audience},
      );
      if (overrides is List) {
        final shown = <String, int>{};
        for (final value in overrides.whereType<Map>()) {
          final id = value['post_id']?.toString();
          final likes = value['likes'];
          if (id != null && likes is num) shown[id] = likes.toInt();
        }
        for (final post in posts) {
          final override = shown[post['id']?.toString()];
          if (override != null) post['likes'] = override;
        }
      }
    } catch (_) {
      /* Without V34 retain verified native reaction counts. */
    }
    // New additive corrections replace only the edited posts' legacy fixed
    // counts. Each real customer reaction still changes the native feed count.
    try {
      final extra = await client.rpc(
        'v44_karizma_like_boosts',
        params: {'p_audience': audience},
      );
      if (extra is List) {
        final boosts = <String, int>{};
        for (final row in extra.whereType<Map>()) {
          if (row['post_id'] != null && row['boost'] is num) {
            boosts[row['post_id'].toString()] = (row['boost'] as num).toInt();
          }
        }
        if (boosts.isNotEmpty) {
          for (final post in posts) {
            final id = post['id']?.toString();
            if (id != null && boosts.containsKey(id)) {
              post['likes'] = (originalLikes[id] ?? 0) + boosts[id]!;
            }
          }
        }
      }
    } catch (_) {
      /* Earlier V34 feeds remain compatible before the V44 SQL. */
    }
    return posts;
  }

  RealtimeChannel subscribeToKarizmaNewsV26(void Function() onChange) => client
      .channel('karizma_news_${DateTime.now().microsecondsSinceEpoch}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'karizma_posts',
        callback: (_) => onChange(),
      )
      .subscribe();

  Future<int> karizmaUnreadV26(String audience) async {
    final count = await client.rpc(
      'v26_karizma_unread',
      params: {'p_audience': audience},
    );
    return (count as num).toInt();
  }

  Future<void> markKarizmaSeenV26(String audience, DateTime through) async {
    final ok = await client.rpc(
      'v26_karizma_mark_seen',
      params: {
        'p_audience': audience,
        'p_through': through.toUtc().toIso8601String(),
      },
    );
    if (ok != true) throw Exception('تعذر تحديث حالة قراءة كاريزما');
  }

  Future<void> reactKarizmaV26(String id, String audience, int reaction) async {
    final raw = await client.rpc(
      'v26_karizma_react',
      params: {'p_post_id': id, 'p_audience': audience, 'p_reaction': reaction},
    );
    if (raw is! Map || raw['success'] != true) {
      throw Exception('تعذر حفظ التفاعل');
    }
  }

  Future<Map<String, dynamic>> getAdminPeriodReportV26(
    DateTime startDate,
    DateTime endDate,
  ) async {
    String format(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final raw = await client.rpc(
      'admin_period_report_v9',
      params: {
        'p_start_date': format(startDate),
        'p_end_date': format(endDate),
      },
    );
    return Map<String, dynamic>.from(raw as Map);
  }

  Future<List<Map<String, dynamic>>> getAllKarizmaPosts() async {
    final res = await client
        .from('karizma_posts')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> saveKarizmaPost({
    String? id,
    required String title,
    required String body,
    required String audience,
    String? imageUrl,
  }) async {
    final data = <String, dynamic>{
      'title': title,
      'body': body,
      'audience': audience,
      'image_url': imageUrl,
      'is_active': true,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (id == null) {
      data['created_by'] = currentUser?.id;
      await client.from('karizma_posts').insert(data);
    } else {
      await client.from('karizma_posts').update(data).eq('id', id);
    }
  }

  Future<void> deleteKarizmaPost(String id) async =>
      client.from('karizma_posts').delete().eq('id', id);

  // V33: separate social/building audit RPCs; no finance or trip mutations.
  Future<String?> getMyKarizmaNicknameV33() async {
    final value = await client.rpc('v33_my_karizma_nickname');
    return value?.toString();
  }

  Future<void> saveMyKarizmaNicknameV33(String name) async {
    await client.rpc(
      'v33_save_karizma_nickname',
      params: {'p_nickname': name.trim()},
    );
  }

  Future<List<Map<String, dynamic>>> getKarizmaCommentsV33(
    String postId,
    String audience,
  ) async {
    final response = await client.rpc(
      'v33_public_karizma_comments',
      params: {'p_post_id': postId, 'p_audience': audience},
    );
    return (response as List)
        .whereType<Map>()
        .map((x) => Map<String, dynamic>.from(x))
        .toList();
  }

  Future<void> addKarizmaCommentV33(
    String postId,
    String audience,
    String body,
  ) async {
    await client.rpc(
      'v33_add_karizma_comment',
      params: {
        'p_post_id': postId,
        'p_audience': audience,
        'p_body': body.trim(),
      },
    );
  }

  Future<List<Map<String, dynamic>>> ownerKarizmaCommentsV33(
    String postId,
  ) async {
    final response = await client.rpc(
      'v33_owner_karizma_comments',
      params: {'p_post_id': postId},
    );
    return (response as List)
        .whereType<Map>()
        .map((x) => Map<String, dynamic>.from(x))
        .toList();
  }

  Future<List<Map<String, dynamic>>> ownerBuildingSubmissionsV33() async {
    final response = await client.rpc('v33_owner_building_submissions');
    return (response as List)
        .whereType<Map>()
        .map((x) => Map<String, dynamic>.from(x))
        .toList();
  }

  // ─── CUSTOMER FEEDBACK ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> submitCustomerFeedback({
    required String type,
    required String message,
  }) async {
    final result = await client.rpc(
      'submit_customer_feedback_v4',
      params: {'p_type': type, 'p_message': message.trim()},
    );
    if (result is Map) return Map<String, dynamic>.from(result);
    throw Exception('feedback_failed');
  }

  Future<List<Map<String, dynamic>>> getAllCustomerFeedback({
    int limit = 100,
  }) async {
    try {
      final result = await client.rpc(
        'get_admin_customer_feedback_v4',
        params: {'p_limit': limit},
      );
      if (result is List) {
        return result
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {
      // Fallback to the existing table query.
    }

    final result = await client
        .from('customer_feedback')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(result);
  }

  Future<void> updateCustomerFeedbackStatus(
    String id,
    String status, {
    String? adminReply,
  }) async {
    final patch = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (adminReply != null) patch['admin_reply'] = adminReply;
    await client.from('customer_feedback').update(patch).eq('id', id);
  }

  TripRealtimeLease subscribeToCustomerFeedback(
    void Function(Map<String, dynamic>) onChange,
  ) => subscribeToScaleAdminPulse(() => onChange({}));

  // ─── V22: server-authoritative Cairo daily summary and captain rewards ───
  Future<Map<String, dynamic>> getCaptainDailySummaryV22() async {
    final result = await client.rpc('get_captain_daily_summary_v22');
    if (result is! Map) throw Exception('daily_summary_invalid_response');
    final value = Map<String, dynamic>.from(result);
    if (value['success'] != true)
      throw Exception(value['error'] ?? 'daily_summary_failed');
    return value;
  }

  Future<List<Map<String, dynamic>>> getMyCaptainRewardsV22() async {
    final result = await client.rpc('get_my_captain_rewards_v22');
    if (result is! List) throw Exception('reward_list_invalid_response');
    return result.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getAdminRewardParticipantsV22(
    String campaignId,
  ) async {
    final result = await client.rpc(
      'get_admin_reward_participants_v22',
      params: {'p_campaign_id': campaignId},
    );
    if (result is! List)
      throw Exception('reward_participants_invalid_response');
    return result.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<void> markCaptainRewardPaidV22({
    required String claimId,
    required String payoutPhone,
    required String transferReference,
  }) async {
    final result = await client.rpc(
      'mark_captain_reward_paid_v22',
      params: {
        'p_claim_id': claimId,
        'p_payout_phone': payoutPhone,
        'p_transfer_reference': transferReference,
      },
    );
    if (result is! Map || result['success'] != true) {
      throw Exception(
        result is Map ? result['error'] : 'reward_payment_failed',
      );
    }
  }

  Future<int> reconcileCaptainRewardV22(String campaignId) async {
    final result = await client.rpc(
      'reconcile_captain_reward_v22',
      params: {'p_campaign_id': campaignId},
    );
    if (result is! Map || result['success'] != true) {
      throw Exception(
        result is Map ? result['error'] : 'reward_reconciliation_failed',
      );
    }
    return (result['scanned'] as num?)?.toInt() ?? 0;
  }

  Future<int> getUnreadNotificationCount(String userId) async {
    final rows = await client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false)
        .limit(100);
    return rows.length;
  }

  Future<void> markAllNotificationsRead(String userId) async {
    await client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  RealtimeChannel subscribeToNotificationChanges(
    String userId,
    void Function(Map<String, dynamic>) onChange, {
    void Function()? onReconnect,
  }) => client
      .channel('v22_notif_${userId}_${DateTime.now().microsecondsSinceEpoch}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (p) =>
            onChange(p.newRecord.isNotEmpty ? p.newRecord : p.oldRecord),
      )
      .subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) onReconnect?.call();
      });

  RealtimeChannel subscribeToCaptainTripStats(
    String captainId,
    void Function(Map<String, dynamic>) onChange,
  ) => client
      .channel('v22_captain_stats_$captainId')
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'trips',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'captain_id',
          value: captainId,
        ),
        callback: (p) => onChange(p.newRecord),
      )
      .subscribe();
}
