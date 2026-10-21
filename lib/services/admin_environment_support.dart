import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Non-secret environment diagnostics for privileged admin screens.
/// Never silently switch projects or bypass owner/staff permissions.
class AdminEnvironmentSupport {
  static const String production = 'wbdjvzaomtlojttjnfhp';
  static const String staging = 'wujynritxanyzrkdyamt';

  static String get projectRef {
    final host = Uri.tryParse(SupabaseService.supabaseUrl)?.host ?? '';
    if (!host.endsWith('.supabase.co')) return 'unknown';
    return host.split('.').first;
  }

  static bool get isStaging => projectRef == staging;
  static bool get isProduction => projectRef == production;
  static String get environmentText => isStaging
      ? 'Staging – نسخة اختبار'
      : isProduction ? 'PRODUCTION – قاعدة الإنتاج' : 'مشروع غير معروف';

  static String explain(Object error, String rpcName) {
    if (error is PostgrestException) {
      final code = error.code ?? '';
      final msg = error.message.toLowerCase();
      if (code == 'PGRST202' || code == '42883') {
        return 'الدالة $rpcName غير موجودة في قاعدة ${environmentText}. '
            'راجع المشروع الصحيح وترتيب SQL V58. الرمز: $code';
      }
      if (code == '42501' || msg.contains('owner_required') ||
          msg.contains('reports_access_required') || msg.contains('permission denied')) {
        return 'الحساب الحالي ليست له صلاحية المالك أو التقارير على ${environmentText}. '
            'سجّل بحساب المالك، ولا تُلغِ فحص الصلاحيات. الرمز: $code';
      }
      if (code.startsWith('PGRST3') || code == '401' || code == '403') {
        return 'جلسة الدخول غير صالحة أو انتهت. أعد تسجيل الدخول على ${environmentText}. الرمز: $code';
      }
      return 'تعذر تحميل $rpcName من ${environmentText}. رمز الخادم: '
          '${code.isEmpty ? 'غير متاح' : code}. افتح سجلات Supabase لمعرفة السبب.';
    }
    return 'تعذر الاتصال أثناء تحميل $rpcName من ${environmentText}. '
        'تحقق من الإنترنت ثم حاول مرة أخرى. لم تُحذف أية سجلات.';
  }
}

class AdminEnvironmentBanner extends StatefulWidget {
  const AdminEnvironmentBanner({super.key});
  @override
  State<AdminEnvironmentBanner> createState() => _AdminEnvironmentBannerState();
}

class _AdminEnvironmentBannerState extends State<AdminEnvironmentBanner> {
  late final Future<bool> _isOwner;

  @override
  void initState() {
    super.initState();
    _isOwner = _loadOwner();
  }

  Future<bool> _loadOwner() async {
    final value = await SupabaseService.instance.client.rpc('v16_is_owner');
    return value == true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AdminEnvironmentSupport.isStaging
        ? theme.colorScheme.primary : theme.colorScheme.error;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(AdminEnvironmentSupport.isStaging ? Icons.science_outlined
            : Icons.storage_outlined, size: 17, color: color),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${AdminEnvironmentSupport.environmentText} • Project: '
              '${AdminEnvironmentSupport.projectRef}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          FutureBuilder<bool>(
            future: _isOwner,
            builder: (_, snap) => Text(
              snap.hasError ? 'تعذر فحص صلاحية المالك' : !snap.hasData
                ? 'جاري التحقق من صلاحية المالك…'
                : snap.data == true ? 'صلاحية المالك: متاحة لهذا الحساب'
                                     : 'صلاحية المالك: غير متاحة لهذا الحساب',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ])),
      ]),
    );
  }
}
