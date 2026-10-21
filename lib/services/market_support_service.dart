import 'package:url_launcher/url_launcher.dart';

import 'supabase_service.dart';

class MarketSupportService {
  MarketSupportService._();

  static Future<bool> openWhatsApp({
    required String orderId,
    dynamic storeOrderNumber,
    required String actorLabel,
  }) async {
    final service = SupabaseService.instance;
    var phone =
        (await service.getSetting('customer_service_whatsapp'))?.trim() ?? '';
    if (phone.isEmpty) {
      phone = (await service.getSetting('support_phone'))?.trim() ?? '';
    }
    if (phone.isEmpty) phone = '01031517830';

    var digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) digits = '20${digits.substring(1)}';
    if (digits.isEmpty) return false;

    final number = _displayNumber(storeOrderNumber, orderId);
    final message =
        'مرحبًا، أنا $actorLabel وأحتاج مساعدة في طلب '
        'فيتو ماركت رقم $number.\nمعرّف الطلب: $orderId';
    return launchUrl(
      Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(message)}'),
      mode: LaunchMode.externalApplication,
    );
  }

  static String _displayNumber(dynamic raw, String orderId) {
    final number = (raw as num?)?.toInt() ?? int.tryParse('$raw');
    if (number != null) return 'شباك ${number.toString().padLeft(2, '0')}';
    final end = orderId.length < 8 ? orderId.length : 8;
    return '#${orderId.substring(0, end).toUpperCase()}';
  }
}
