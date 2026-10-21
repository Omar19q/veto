import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> normalizeTripV10(Map raw) {
  final row = Map<String, dynamic>.from(raw);
  for (final key in [
    'pickup_latitude',
    'pickup_longitude',
    'destination_latitude',
    'destination_longitude',
    'current_latitude',
    'current_longitude',
    'distance_km',
    'duration_minutes',
    'base_fare',
    'total_fare',
    'wallet_amount',
    'cash_amount',
    'incentive_amount',
    'promo_discount',
    'waiting_charge',
    'waiting_minutes',
    'free_wait_minutes_used',
    'waiting_rate_used',
    'commission_percent_used',
    'rating',
    'rating_count',
    'total_completed_trips',
  ]) {
    final value = row[key];
    if (value is String) row[key] = num.tryParse(value);
    if (row[key] is num && !(row[key] as num).isFinite) row[key] = null;
  }
  for (final key in [
    'captains',
    'customers',
    'customer_context',
    'captain_context',
    'financial_preview_v11',
  ]) {
    if (row[key] is Map) row[key] = normalizeTripV10(row[key] as Map);
  }
  return row;
}

Future<T> tripReadWithRetryV10<T>(Future<T> Function() request) async {
  for (var attempt = 0; ; attempt++) {
    try {
      return await request().timeout(const Duration(seconds: 8));
    } on PostgrestException catch (e) {
      if (attempt > 0 ||
          ['42501', 'PGRST202', '22P02', '42883'].contains(e.code))
        rethrow;
    } catch (_) {
      if (attempt > 0) rethrow;
    }
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }
}

String tripLoadErrorV10(Object error) {
  final text = error.toString();
  if (text.contains('not_trip_participant') || text.contains('42501'))
    return 'الرحلة غير متاحة لهذا الحساب. ارجع لقائمة الطلبات.';
  if (text.contains('trip_not_found'))
    return 'الرحلة غير موجودة أو لم تعد متاحة.';
  if (text.contains('PGRST202') || text.contains('42883'))
    return 'تحديث الخدمة لم يكتمل. حاول مرة أخرى بعد تحديث النظام.';
  return 'الاتصال اتقطع أثناء تحميل الرحلة. بياناتك محفوظة؛ حاول مرة تانية.';
}
