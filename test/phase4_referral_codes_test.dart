import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/services/growth_referral_kind.dart';
import 'package:vetosanya/services/growth_service.dart';

void main() {
  test('Captain, friend and legacy codes have distinct namespaces', () {
    expect(classifyGrowthReferral('1001'), GrowthReferralKind.captain);
    expect(classifyGrowthReferral('10001'), GrowthReferralKind.captain);
    expect(classifyGrowthReferral('F600001'), GrowthReferralKind.friend);
    expect(classifyGrowthReferral(' f600001 '), GrowthReferralKind.friend);
    expect(classifyGrowthReferral('C0123456789AB'), GrowthReferralKind.legacyCustomer);
    expect(classifyGrowthReferral(''), GrowthReferralKind.empty);
    expect(classifyGrowthReferral('999'), GrowthReferralKind.invalid);
    expect(classifyGrowthReferral('TEAM-NORTH'), GrowthReferralKind.invalid);
  });
  test('Friend reward copy states first ride only, not three discounts', () {
    final hint = growthReferralHint(GrowthReferralKind.friend, english: false);
    expect(hint, contains('50%'));
    expect(hint, contains('فقط'));
    expect(hint, isNot(contains('35%')));
  });
  test('Different captain accounts produce different Play referral payloads', () {
    final a = GrowthService.referralLink('1001').queryParameters['referrer'];
    final b = GrowthService.referralLink('1002').queryParameters['referrer'];
    expect(a, 'referral_code=1001');
    expect(b, 'referral_code=1002');
    expect(a, isNot(b));
  });
  test('Read-only report uses own role, owner dashboard uses distinct RPC', () async {
    final calls = <String>[];
    final svc = GrowthService(rpc: (name, args) async {
      calls.add('$name:${args['p_kind'] ?? '-'}');
      return <String, dynamic>{'registrations': 2, 'paid': 15};
    });
    final mine = await svc.referralBreakdown(captain: true);
    final owner = await svc.ownerReferralOverview();
    expect(mine['paid'], 15);
    expect(owner['registrations'], 2);
    expect(calls, ['v55_my_referral_breakdown:captain', 'v55_owner_referral_overview:-']);
  });
}
