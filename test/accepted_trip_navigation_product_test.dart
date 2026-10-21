import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/services/accepted_trip_navigation_coordinator.dart';

void main() {
  test(
    'Confirmed captain acceptance navigates immediately without a decorative timer',
    () async {
      var opened = 0;
      final result = await AcceptedTripNavigationCoordinator().confirm(
        readTrip: () async => {
          'trip_status': 'accepted',
          'captain_id': 'synthetic-captain',
        },
        isCurrent: () => true,
        onConfirmed: () => opened++,
      );
      expect(result, isTrue);
      expect(opened, 1);
    },
  );
  for (final cause in [
    'cancelled',
    'account changed',
    'different trip',
    'route already left',
  ]) {
    test('Late accepted snapshot cannot navigate after $cause', () async {
      var current = true, opened = 0;
      final reply = Completer<Map<String, dynamic>?>();
      final pending = AcceptedTripNavigationCoordinator().confirm(
        readTrip: () => reply.future,
        isCurrent: () => current,
        onConfirmed: () => opened++,
      );
      current = false;
      reply.complete({
        'trip_status': 'accepted',
        'captain_id': 'synthetic-captain',
      });
      expect(await pending, isFalse);
      expect(opened, 0);
    });
  }
  test(
    'Concurrent confirmation reads do not open the same trip twice',
    () async {
      var reads = 0, opened = 0;
      final reply = Completer<Map<String, dynamic>?>();
      final gate = AcceptedTripNavigationCoordinator();
      Future<Map<String, dynamic>?> read() {
        reads++;
        return reply.future;
      }

      final first = gate.confirm(
        readTrip: read,
        isCurrent: () => true,
        onConfirmed: () => opened++,
      );
      expect(
        await gate.confirm(
          readTrip: read,
          isCurrent: () => true,
          onConfirmed: () => opened++,
        ),
        isFalse,
      );
      reply.complete({
        'trip_status': 'arriving',
        'captain_id': 'synthetic-captain',
      });
      expect(await first, isTrue);
      expect(reads, 1);
      expect(opened, 1);
    },
  );
  test(
    'Cancelled or captainless server snapshots never become accepted navigation',
    () async {
      var opened = 0;
      for (final row in [
        {'trip_status': 'cancelled', 'captain_id': 'synthetic-captain'},
        {'trip_status': 'accepted', 'captain_id': null},
        {'trip_status': 'searching', 'captain_id': 'synthetic-captain'},
      ]) {
        expect(
          await AcceptedTripNavigationCoordinator().confirm(
            readTrip: () async => row,
            isCurrent: () => true,
            onConfirmed: () => opened++,
          ),
          isFalse,
        );
      }
      expect(opened, 0);
    },
  );
  test(
    'Read failure keeps the gate reusable without claiming acceptance',
    () async {
      var opened = 0;
      final gate = AcceptedTripNavigationCoordinator();
      expect(
        await gate.confirm(
          readTrip: () async => throw StateError('synthetic-offline'),
          isCurrent: () => true,
          onConfirmed: () => opened++,
        ),
        isFalse,
      );
      expect(
        await gate.confirm(
          readTrip: () async => {
            'trip_status': 'started',
            'captain_id': 'synthetic-captain',
          },
          isCurrent: () => true,
          onConfirmed: () => opened++,
        ),
        isTrue,
      );
      expect(opened, 1);
    },
  );
}
