import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/services/booking_performance.dart';
import 'package:vetosanya/services/product_session_timing.dart';

void main() {
  test('Startup and milestones are captured separately without fabricating missing GPS steps', () {
    var appElapsed=0,bookingElapsed=0;
    final session=ProductSessionTiming(elapsedMilliseconds:()=>appElapsed);
    expect(session.snapshot(),isEmpty);
    session.start(observeLifecycle:false);
    appElapsed=2500;session.markHomeVisible();
    appElapsed=4000;
    final attempt=BookingPerformanceAttempt(elapsedMilliseconds:()=>bookingElapsed,session:session);
    bookingElapsed=1000;attempt.mark(BookingMilestone.destinationSelected);
    bookingElapsed=2200;attempt.mark(BookingMilestone.priceVisible);
    bookingElapsed=5000;final request=attempt.confirm();
    bookingElapsed=6500;final result=request.finish('created',tripId:'synthetic-trip')!;
    expect(result['p_app_to_booking_ms'],4000);
    expect(result['p_home_visible_ms'],2500);
    expect(result['p_request_ms'],1500);
    final trace=result['p_milestones'] as Map;
    expect(trace['server_ack'],6500);
    expect(trace['destination_selected'],1000);
    expect(trace.containsKey('pickup_selected'),isFalse);
    expect(trace.containsKey('captain_accepted'),isFalse);
  });
  test('Unconfirmed request never gains a server ACK milestone', () {
    var elapsed=0;
    final attempt=BookingPerformanceAttempt(elapsedMilliseconds:()=>elapsed);
    final request=attempt.confirm();elapsed=8000;
    final result=request.finish('uncertain')!;
    expect((result['p_milestones'] as Map).containsKey('server_ack'),isFalse);
  });
  test('Long booking attempts are measured honestly, without clipping them to a target', () {
    var elapsed=0;
    final attempt=BookingPerformanceAttempt(elapsedMilliseconds:()=>elapsed);
    final request=attempt.confirm();elapsed=900000;
    expect(request.finish('uncertain')?['p_duration_ms'],900000);
  });
  test('Booking ends at server ACK, while request transport is separately measured', () {
    var elapsed=0;
    final attempt=BookingPerformanceAttempt(elapsedMilliseconds:()=>elapsed);
    elapsed=12000;
    final request=attempt.confirm();
    elapsed=15000;
    final result=request.finish('created',tripId:'synthetic-trip');
    expect(result?['p_duration_ms'],15000);
    expect(result?['p_request_ms'],3000);
    elapsed=90000; // Later captain acceptance must never change booking time.
    expect(request.finish('created',tripId:'synthetic-trip'),isNull);
  });
  test('Uncertain response is not misreported as rejected; retry uses an independent measurement', () {
    var elapsed=0;
    final attempt=BookingPerformanceAttempt(elapsedMilliseconds:()=>elapsed);
    final first=attempt.confirm();elapsed=8000;
    expect(first.finish('uncertain')?['p_outcome'],'uncertain');
    final retry=attempt.confirm();elapsed=10000;
    final ack=retry.finish('created',tripId:'synthetic-trip');
    expect(ack?['p_request_ms'],2000);
    expect(ack?['p_duration_ms'],10000);
    expect(ack?['p_key'],isNot(first.key));
  });
}
