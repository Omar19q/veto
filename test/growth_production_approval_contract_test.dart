import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/services/growth_referral_kind.dart';

void main() {
  test('captain code is distinct from friend and partner codes', () {
    expect(classifyGrowthReferral('1001'), GrowthReferralKind.captain);
    expect(classifyGrowthReferral('F123456'), GrowthReferralKind.friend);
    expect(classifyGrowthReferral('TEAM2026'), GrowthReferralKind.invalid);
    expect(classifyGrowthReferral(''), GrowthReferralKind.empty);
  });
}
