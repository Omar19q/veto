import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/services/map_data_gateway.dart';
import 'package:vetosanya/services/map_provider_policy.dart';

void main() {
  test('An unavailable Google channel cannot issue an outbound request', () {
    var calls = 0;
    final gateway = MapDataGateway(geoapify: (_) async => null,
      google: (_) async { calls++; return null; },
      policy: const MapProviderPolicy(addresses: MapDataProvider.google));
    expect(() => gateway.call({'operation':'search','query':'Synthetic'}), throwsStateError);
    expect(calls, 0);
  });
  test('Provider failure never activates a paid fallback', () async {
    var paidCalls = 0;
    final gateway = MapDataGateway(geoapify: (_) async => throw StateError('quota_exhausted'),
      google: (_) async { paidCalls++; return null; });
    await expectLater(gateway.call({'operation':'reverse','latitude':30,'longitude':31}), throwsStateError);
    expect(paidCalls, 0);
  });
  test('OpenFreeMap vector style requires a renderer adapter', () {
    expect(() => const MapProviderPolicy(display: MapDisplayProvider.openFreeMap)
        .requireDisplayAvailable(), throwsStateError);
    expect(MapProviderPolicy.openFreeMapStyle, isNot(contains('{z}')));
  });
  test('Approved verified address and route adapters receive separate requests', () async {
    final calls = <String>[];
    final gateway = MapDataGateway(geoapify: (r) async {calls.add('free:${r['operation']}');return [];},
      google: (r) async {calls.add('approved:${r['operation']}');return [];},
      policy: const MapProviderPolicy(routes: MapDataProvider.google,
          googleApproved:true,googleAdapterVerified:true));
    await gateway.call({'operation':'search','query':'Synthetic'});
    await gateway.call({'operation':'route','points':[]});
    expect(calls,['free:search','approved:route']);
  });
}
