import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../l10n/strings.dart';

String localizedQuoteFailure(BuildContext context, Object failure) {
  final raw = failure.toString();
  if (raw.contains('quote_rate_limit')) return context.strings.quoteRateLimited;
  if (raw.contains('city_not_active') || raw.contains('service_unavailable')) {
    return context.strings.bookingCoverageUnavailable;
  }
  if (raw.contains('booking_coordinates_required') || raw.contains('invalid_coordinates')) {
    return context.strings.quoteCoordinatesRequired;
  }
  if (failure is FunctionException && const [401, 403].contains(failure.status)) {
    return context.strings.bookingSessionUnavailable;
  }
  return context.strings.quoteUnavailableRetry;
}

/// Presentation only. Unknown responses stay uncertain; no alternate mutation
/// or payment retry is performed by this adapter.
String localizedBookingFailure(BuildContext context, Object error,
    {bool alreadyCreated = false}) {
  final l = context.strings;
  if (alreadyCreated) return l.bookingCreatedDistributionFailed;
  final raw = error.toString();
  const codes = [
    'promo_expired', 'promo_total_limit', 'promo_people_limit',
    'promo_user_limit', 'promo_inactive', 'promo_not_started',
    'promo_invalid', 'promo_legacy_people_unknown',
  ];
  final messages = [
    l.bookingPromoExpired, l.bookingPromoTotalLimit, l.bookingPromoPeopleLimit,
    l.bookingPromoUserLimit, l.bookingPromoInactive, l.bookingPromoNotStarted,
    l.bookingPromoInvalid, l.bookingPromoReview,
  ];
  for (var i = 0; i < codes.length; i++) {
    if (raw.contains(codes[i])) return messages[i];
  }
  if (raw.contains('city_not_active')) return l.bookingCoverageUnavailable;
  if (error is PostgrestException &&
      const ['42501', 'PGRST301', 'PGRST302', 'PGRST303'].contains(error.code)) {
    return l.bookingSessionUnavailable;
  }
  return error is PostgrestException
      ? l.bookingCreateRejected
      : l.bookingCreateUnconfirmed;
}
