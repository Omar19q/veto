import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/services/home_read_coordinator.dart';

void main() {
  test('Slow market lookup cannot delay the active-trip safety result', () async {
    final market = Completer<String>();String? marketValue;
    final active = await HomeReadCoordinator.load(
      essential:Future.value('existing-trip'),ancillary:market.future,
      onAncillary:(value)=>marketValue=value,onAncillaryError:(e)=>fail('$e'));
    expect(active,'existing-trip');expect(marketValue,isNull);
    market.complete('existing-market-order');await Future<void>.delayed(Duration.zero);
    expect(marketValue,'existing-market-order');
  });
  test('Market failure remains an explicit error without erasing active-trip result', () async {
    Object? failure;
    final active=await HomeReadCoordinator.load(
      essential:Future.value('existing-trip'),ancillary:Future<String>.error(StateError('market-unavailable')),
      onAncillary:(_)=>fail('No fake empty success'),onAncillaryError:(error)=>failure=error);
    await Future<void>.delayed(Duration.zero);
    expect(active,'existing-trip');expect(failure,isA<StateError>());
  });
}
