import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/services/hybrid_place_search_service.dart';
import 'package:vetosanya/services/place_search_service.dart';

PlaceSearchResult point(String name) => PlaceSearchResult(
  name: name,
  address: name,
  latitude: 29.98,
  longitude: 31.1,
);
void main() {
  test(
    'Approved addresses have priority; exact external duplicate removed; original name retained',
    () async {
      final s = HybridPlaceSearchService(
        approved: (_) async => [point('عمارة أ 25')],
        external: (_) async => [
          point('عمارة أ 25'),
          point('Original external place'),
        ],
      );
      final r = await s.search('عمارة');
      expect(r.results.map((p) => p.name), [
        'عمارة أ 25',
        'Original external place',
      ]);
      expect(r.approvedUnavailable, false);
      expect(r.externalUnavailable, false);
    },
  );
  test(
    'External failure leaves approved addresses available and marks partial failure',
    () async {
      final s = HybridPlaceSearchService(
        approved: (_) async => [point('المنزل')],
        external: (_) async => throw StateError('quota'),
      );
      final r = await s.search('المنزل');
      expect(r.results.single.name, 'المنزل');
      expect(r.externalUnavailable, true);
    },
  );
  test(
    'Approved source failure leaves external candidates without claiming approved coverage',
    () async {
      final s = HybridPlaceSearchService(
        approved: (_) async => throw StateError('city_not_active'),
        external: (_) async => [point('External candidate')],
      );
      final r = await s.search('مكان');
      expect(r.approvedUnavailable, true);
      expect(r.results.single.name, 'External candidate');
    },
  );
  test(
    'Both sources failing is an error rather than false no-results',
    () async {
      final s = HybridPlaceSearchService(
        approved: (_) async => throw StateError('auth'),
        external: (_) async => throw StateError('offline'),
      );
      await expectLater(s.search('مكان'), throwsStateError);
    },
  );
  test(
    'Short input makes no calls and invalid coordinates are discarded',
    () async {
      var calls = 0;
      final s = HybridPlaceSearchService(
        approved: (_) async {
          calls++;
          return [
            PlaceSearchResult(
              name: 'Invalid',
              address: 'x',
              latitude: double.nan,
              longitude: 31,
            ),
          ];
        },
        external: (_) async {
          calls++;
          return [];
        },
      );
      expect((await s.search('ا')).results, isEmpty);
      expect(calls, 0);
      expect((await s.search('مكان')).results, isEmpty);
      expect(calls, 2);
    },
  );
}
