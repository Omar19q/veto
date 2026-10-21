import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/services/growth_referral_kind.dart';

void main() {
  test('Captain code 1022 is accepted as captain format', () {
    expect(classifyGrowthReferral('1022'), GrowthReferralKind.captain);
    expect(classifyGrowthReferral('1000'), GrowthReferralKind.invalid);
  });
  test('Friend codes are separate from captain and team codes', () {
    expect(classifyGrowthReferral('F000001'), GrowthReferralKind.friend);
    expect(classifyGrowthReferral(' TEAM-42 '), GrowthReferralKind.invalid);
    expect(classifyGrowthReferral(''), GrowthReferralKind.empty);
  });
}
