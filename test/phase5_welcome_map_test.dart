import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/services/growth_service.dart';
import 'package:vetosanya/services/growth_referral_kind.dart';
import 'package:vetosanya/services/hybrid_place_search_service.dart';
import 'package:vetosanya/services/place_search_service.dart';

const approved = PlaceSearchResult(name: 'بوابة 4', address: 'حدائق الأهرام',
    latitude: 29.974, longitude: 31.102);
const other = PlaceSearchResult(name: 'ميدان الرماية', address: 'الجيزة',
    latitude: 29.980, longitude: 31.101);
void main() {
  test('new account welcome takes eligibility only from server', () async {
    final service = GrowthService(rpc: (name, params) async =>
        {'show': name == 'growth_claim_onboarding_v1'});
    expect(await service.claimOnboarding(), isTrue);
  });
  test('server can suppress welcome for an existing account', () async {
    final service = GrowthService(rpc: (_, __) async => {'show': false});
    expect(await service.claimOnboarding(), isFalse);
  });
  test('captain and friend invitations are distinct', () {
    expect(classifyGrowthReferral('1001'), GrowthReferralKind.captain);
    expect(classifyGrowthReferral('F123456'), GrowthReferralKind.friend);
    expect(classifyGrowthReferral('TEAM123'), GrowthReferralKind.invalid);
  });
  test('approved places survive an external map outage', () async {
    final search = HybridPlaceSearchService(
      approved: (_) async => [approved],
      external: (_) async => throw StateError('no_key'),
    );
    final result = await search.search('بوابة');
    expect(result.externalUnavailable, isTrue);
    expect(result.approvedUnavailable, isFalse);
    expect(result.results.length, 1);
  });
  test('same approved and external place appears only once', () async {
    final search = HybridPlaceSearchService(
      approved: (_) async => [approved],
      external: (_) async => [approved, other],
    );
    final result = await search.search('بوابة');
    expect(result.results.length, 2);
    expect(result.results.first.name, 'بوابة 4');
  });
  test('invalid referral is not promoted as an offer', () {
    expect(growthReferralHint(GrowthReferralKind.invalid, english: false),
        contains('غير صالح'));
  });
}
