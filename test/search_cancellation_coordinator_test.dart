import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/services/search_cancellation_coordinator.dart';

void main() {
  test(
    'Missing RPC explains server deployment gap without exposing technical details',
    () {
      expect(
        searchCancellationFailureMessage(
          StateError('PGRST202 private-details'),
        ),
        contains('لم تُحدّث على السيرفر'),
      );
      expect(
        searchCancellationFailureMessage(
          StateError('PGRST202 private-details'),
        ),
        isNot(contains('private-details')),
      );
    },
  );
  test(
    'Confirmed free cancellation does not issue extra reads or writes',
    () async {
      var writes = 0;
      final c = SearchCancellationCoordinator(
        cancel: () async {
          writes++;
          return {'success': true, 'cancellation_fee': 0};
        },
        readTrip: () async => throw StateError('unexpected_read'),
      );
      expect((await c.run())['success'], true);
      expect(writes, 1);
    },
  );
  test(
    'Lost response recovers committed search cancellation from server',
    () async {
      var writes = 0;
      final c = SearchCancellationCoordinator(
        cancel: () async {
          writes++;
          throw TimeoutException('lost_response');
        },
        readTrip: () async => {
          'trip_status': 'cancelled',
          'cancellation_fee_used': '0.00',
          'cancellation_fee': 0,
        },
      );
      expect((await c.run())['recovered_from_server'], true);
      expect(writes, 1);
    },
  );
  test(
    'Offline reconciliation preserves original failure and never retries write',
    () async {
      var writes = 0;
      final c = SearchCancellationCoordinator(
        cancel: () async {
          writes++;
          throw TimeoutException('offline');
        },
        readTrip: () async => throw StateError('offline_read'),
      );
      await expectLater(c.run(), throwsA(isA<TimeoutException>()));
      expect(writes, 1);
    },
  );
  test(
    'Captain accepted during cancellation is surfaced without paid fallback',
    () async {
      final c = SearchCancellationCoordinator(
        cancel: () async => {
          'success': false,
          'error': 'captain_assigned_refresh',
        },
        readTrip: () async => {
          'trip_status': 'accepted',
          'captain_id': 'captain',
        },
      );
      await expectLater(c.run(), throwsA(isA<StateError>()));
    },
  );
  for (final fee in [5, null]) {
    test(
      'Cancelled server state with fee $fee does not prove free cancellation',
      () async {
        final c = SearchCancellationCoordinator(
          cancel: () async => throw TimeoutException('lost'),
          readTrip: () async => {
            'trip_status': 'cancelled',
            'cancellation_fee_used': fee,
            'cancellation_fee': fee,
          },
        );
        await expectLater(c.run(), throwsA(isA<TimeoutException>()));
      },
    );
  }
  test(
    'Malformed or paid RPC result is not accepted as free cancellation',
    () async {
      final c = SearchCancellationCoordinator(
        cancel: () async => {'success': true, 'cancellation_fee': 5},
        readTrip: () async => null,
      );
      await expectLater(c.run(), throwsA(isA<StateError>()));
    },
  );
}
