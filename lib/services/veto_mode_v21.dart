import 'package:go_router/go_router.dart';
import 'supabase_service.dart';

/// Presentation mode is temporary: each fresh application launch starts in
/// captain mode for approved captains. Roles and access are ALWAYS server-owned.
class VetoModeV21 {
  VetoModeV21._();
  static bool customerView = false;
  static bool staffView = false;

  static Future<bool> canUseCustomer(String userId) async {
    final customer = await SupabaseService.instance.getCustomerByUserId(userId);
    return customer != null && customer['is_active'] != false;
  }

  static Future<bool> canUseCaptain(String userId) async {
    final captain = await SupabaseService.instance.getCaptainByUserId(userId);
    return captain != null && captain['captain_status'] == 'active';
  }

  static void reset() {
    customerView = false;
    staffView = false;
  }

  static Future<bool> openCustomer(GoRouter router, String userId) async {
    if (!await canUseCustomer(userId)) return false;
    customerView = true;
    staffView = false;
    router.go('/home-screen');
    return true;
  }

  static Future<bool> openCaptain(GoRouter router, String userId) async {
    if (!await canUseCaptain(userId)) return false;
    customerView = false;
    staffView = false;
    router.go('/captain-dashboard');
    return true;
  }
}
