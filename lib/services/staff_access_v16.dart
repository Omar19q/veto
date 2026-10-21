import 'package:supabase_flutter/supabase_flutter.dart';

class StaffAccessV16 {
  final bool owner;
  final bool active;
  final Set<String> permissions;
  const StaffAccessV16({
    this.owner = false,
    this.active = false,
    this.permissions = const {},
  });
  bool can(String permission) =>
      active && (owner || permissions.contains(permission));
  static Future<StaffAccessV16> load() async {
    final raw = await Supabase.instance.client.rpc('v16_access');
    return StaffAccessV16(
      owner: raw['owner'] == true,
      active: raw['active'] == true,
      permissions: Set<String>.from(raw['permissions'] ?? []),
    );
  }

  static const resources = <String, String>{
    'trips': 'الرحلات',
    'captains': 'الكباتن وطلبات التسجيل',
    'customers': 'العملاء',
    'verification': 'أكواد التحقق',
    'complaints': 'الشكاوى',
    'finance': 'المحافظ والتسويات',
    'pricing': 'الأسعار والمناطق',
    'reports': 'التقارير',
    'notifications': 'الإشعارات',
    'settings': 'إعدادات النظام',
    'staff': 'الموظفون',
    'chat': 'المحادثات الداخلية',
  };
  // Separate from resources so existing role presets never gain growth powers.
  static const growthPermissions = <String, String>{
    'growth.view': 'عرض تقارير التسويق',
    'growth.manage': 'إدارة الحملات والميزانيات',
    'growth.finance': 'إثبات صرف مكافآت النمو',
    'growth.safety': 'مراجعة ملاحظات الرحلات',
  };
  static const roles = [
    'Admin',
    'Operations Manager',
    'Captain Manager',
    'Customer Support',
    'Verification Moderator',
    'Finance',
    'Read-only',
    'Custom',
  ];
  static Set<String> preset(String role) {
    const assigned = <String, List<String>>{
      'Operations Manager': [
        'trips',
        'captains',
        'pricing',
        'complaints',
        'chat',
      ],
      'Captain Manager': ['captains', 'chat'],
      'Customer Support': ['customers', 'complaints', 'chat'],
      'Verification Moderator': ['verification'],
      'Finance': ['finance', 'reports', 'chat'],
    };
    if (role == 'Custom') return {};
    if (role == 'Read-only')
      return resources.keys
          .where((r) => r != 'staff')
          .map((r) => '$r.view')
          .toSet();
    final keys = role == 'Admin'
        ? resources.keys.where((r) => r != 'staff')
        : assigned[role] ?? <String>[];
    return {
      ...keys.expand((r) => ['$r.view', '$r.manage']),
      'notifications.view',
    };
  }
}
