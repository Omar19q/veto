import 'dart:async';

/// A lost response is ambiguous. Read server state without issuing another write.
class SearchCancellationCoordinator {
  final Future<Map<String, dynamic>> Function() cancel;
  final Future<Map<String, dynamic>?> Function() readTrip;

  const SearchCancellationCoordinator({
    required this.cancel,
    required this.readTrip,
  });

  Future<Map<String, dynamic>> run() async {
    try {
      final result = await cancel();
      if (result['success'] != true ||
          _amount(result['cancellation_fee']) != 0) {
        throw StateError(
          result['error']?.toString() ?? 'search_cancel_not_confirmed',
        );
      }
      return result;
    } catch (original, stack) {
      Map<String, dynamic>? trip;
      try {
        trip = await readTrip().timeout(const Duration(seconds: 10));
      } catch (_) {
        // Preserve the original server failure when reconciliation also fails.
      }
      if (trip?['trip_status'] == 'cancelled' &&
          _amount(trip?['cancellation_fee_used']) == 0 &&
          _amount(trip?['cancellation_fee']) == 0 &&
          trip?['captain_id'] == null &&
          trip?['accepted_at'] == null) {
        return {
          'success': true,
          'already_cancelled': true,
          'recovered_from_server': true,
          'cancellation_fee': 0,
        };
      }
      if (trip?['captain_id'] != null &&
          const {
            'accepted',
            'arriving',
            'arrived',
            'started',
          }.contains(trip?['trip_status'])) {
        throw StateError('captain_assigned_refresh');
      }
      Error.throwWithStackTrace(original, stack);
    }
  }

  static num? _amount(dynamic value) =>
      value is num ? value : num.tryParse(value?.toString() ?? '');
}

String searchCancellationFailureMessage(Object error) {
  final failure = error.toString();
  if (failure.contains('PGRST202') || failure.contains('42883')) {
    return 'خدمة الإلغاء لم تُحدّث على السيرفر بعد. الطلب لم يتأكد إلغاؤه؛ تواصل مع الدعم.';
  }
  if (failure.contains('captain_assigned_refresh')) {
    return 'الكابتن قبل الرحلة أثناء الإلغاء. راجع حالة الرحلة الجديدة.';
  }
  if (failure.contains('financial_guard') ||
      failure.contains('financial_conflict') ||
      failure.contains('receipt_fee_mismatch')) {
    return 'السيرفر أوقف الإلغاء لحماية رصيدك بسبب تعارض مالي. أرسل رقم الرحلة للدعم.';
  }
  if (failure.contains('42501') ||
      failure.contains('authentication') ||
      failure.contains('session_ended_by_new_login')) {
    return 'تعذر تأكيد صلاحية الجلسة. سجّل دخولك ثم راجع حالة الطلب.';
  }
  return 'السيرفر لم يؤكد الإلغاء. تحقق من الإنترنت وحالة الطلب ثم حاول مرة أخرى.';
}
