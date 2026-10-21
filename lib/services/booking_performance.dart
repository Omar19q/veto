import 'package:flutter/foundation.dart';
import 'growth_service.dart';
import 'product_session_timing.dart';

enum BookingMilestone { pickupSelected, destinationSelected, priceVisible }

/// Monotonic client timing. No captain acceptance time, addresses or phone data.
class BookingPerformanceAttempt {
  BookingPerformanceAttempt({int Function()? elapsedMilliseconds,
      ProductSessionTiming? session})
    : _elapsed =
          elapsedMilliseconds ??
          (Stopwatch()..start()).elapsedMillisecondsGetter,
      _session = (session ?? ProductSessionTiming.instance).snapshot();
  final int Function() _elapsed;
  final Map<String, int?> _session;
  final Map<String, int> _milestones = {'booking_started':0};
  void mark(BookingMilestone milestone) {
    final key = switch(milestone) {
      BookingMilestone.pickupSelected => 'pickup_selected',
      BookingMilestone.destinationSelected => 'destination_selected',
      BookingMilestone.priceVisible => 'price_visible',
    };
    _milestones.putIfAbsent(key, _elapsed);
  }
  BookingRequestMeasurement confirm() {
    final now = _elapsed();
    return BookingRequestMeasurement(_elapsed, now,
      {..._milestones, 'confirm_pressed':now}, _session);
  }
}

extension on Stopwatch {
  int elapsedMillisecondsGetter() => elapsedMilliseconds;
}

class BookingRequestMeasurement {
  BookingRequestMeasurement(this._elapsed, this._requestStarted,
      this._milestones, this._session);
  final int Function() _elapsed;
  final int _requestStarted;
  final Map<String, int> _milestones;
  final Map<String, int?> _session;
  final String key = GrowthService.uuid();
  bool _finished = false;
  Map<String, dynamic>? finish(String outcome, {String? tripId}) {
    if (_finished) return null;
    if (!const ['created', 'rejected', 'uncertain'].contains(outcome))
      throw ArgumentError.value(outcome);
    final now = _elapsed();
    _finished = true;
    return {
      'p_key': key,
      'p_outcome': outcome,
      'p_trip': tripId,
      'p_duration_ms': now,
      'p_request_ms': now - _requestStarted,
      'p_consent': true,
      'p_milestones': {..._milestones, 'request_finished':now,
        if(outcome == 'created') 'server_ack':now},
      'p_app_to_booking_ms': _session['app_to_booking_ms'],
      'p_home_visible_ms': _session['home_visible_ms'],
    };
  }

  Future<void> deliver(String outcome, {String? tripId}) async {
    final params = finish(outcome, tripId: tripId);
    if (params == null || !GrowthService.buildEnabled) return;
    try {
      final growth = GrowthService();
      if (!await growth.consent()) return;
      await growth.call('v52_booking_measurement', params);
    } catch (_) {
      GrowthService.eventDeliveryFailures.value++;
      debugPrint('Booking timing delivery failed');
    }
  }
}
