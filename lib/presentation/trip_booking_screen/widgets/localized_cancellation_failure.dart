import 'package:flutter/widgets.dart';
import '../../../l10n/strings.dart';
import '../../../services/search_cancellation_coordinator.dart';

/// Presentation adapter only. Reconciliation and error classification continue
/// through the Phase1 coordinator; no cancellation RPC or fee rules change.
String localizedCancellationFailure(BuildContext context, Object error) {
  final message = searchCancellationFailureMessage(error);
  final l = context.strings;
  switch (message) {
    case 'خدمة الإلغاء لم تُحدّث على السيرفر بعد. الطلب لم يتأكد إلغاؤه؛ تواصل مع الدعم.':
      return l.cancelServiceUnavailable;
    case 'الكابتن قبل الرحلة أثناء الإلغاء. راجع حالة الرحلة الجديدة.':
      return l.cancelAcceptanceRace;
    case 'السيرفر أوقف الإلغاء لحماية رصيدك بسبب تعارض مالي. أرسل رقم الرحلة للدعم.':
      return l.cancelFinancialGuard;
    case 'تعذر تأكيد صلاحية الجلسة. سجّل دخولك ثم راجع حالة الطلب.':
      return l.cancelSessionUnavailable;
    default:
      return l.cancelUnconfirmed;
  }
}
