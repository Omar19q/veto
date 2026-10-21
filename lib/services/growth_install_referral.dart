import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GrowthInstallReferral {
  static const channel = MethodChannel('veto_sanya/install_referral');
  static Future<String?> read() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android)
      return null;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('growth_install_referral_read') == true)
      return prefs.getString('growth_install_referral_code');
    final result = await channel
        .invokeMapMethod<String, dynamic>('read')
        .timeout(const Duration(seconds: 9));
    // A sideloaded APK or a store without Play Install Referrer has no code.
    // This is an optional convenience, not a registration failure.
    if (result == null || result['status'] != 'ready') return null;
    final code = result['code'] as String?;
    if (code != null &&
        RegExp(r'^(?:[0-9]{4,19}|F[0-9]{6,12}|C(?:[a-fA-F0-9]{12}|[a-fA-F0-9]{32}))$').hasMatch(code)) {
      if (!await prefs.setString('growth_install_referral_code', code))
        throw StateError('referral_storage_failed');
    }
    if (!await prefs.setBool('growth_install_referral_read', true))
      throw StateError('referral_storage_failed');
    return code;
  }
}
