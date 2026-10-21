import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/services/growth_service.dart';
import 'package:vetosanya/services/captain_application_v16.dart';

void main() {
  test('Short friend code comes from authenticated server, never locally invented', () async {
    final calls = <String>[];
    final service = GrowthService(rpc: (name, params) async {
      calls.add(name);
      switch (name) {
        case 'growth_my_profile_v3':
          return <String, dynamic>{
            'enabled': true,
            'code': 'C0123456789AB',
            'due': 0,
            'paid': 0,
            'promotional_available': 0,
          };
        case 'v54_my_friend_code':
          return <String, dynamic>{'code': 'F600001'};
        case 'v54_my_friend_invites':
          return <String, dynamic>{'registrations': 1, 'reward_total': 15};
        default:
          throw StateError('unexpected_rpc');
      }
    });
    final profile = await service.profile();
    expect(profile['code'], 'F600001');
    expect(profile['friend_reward_v54'], true);
    expect((profile['friend_invites_v54'] as Map)['reward_total'], 15);
    expect(calls, ['growth_my_profile_v3', 'v54_my_friend_code', 'v54_my_friend_invites']);
    expect(GrowthService.referralLink('F600001').queryParameters['referrer'], 'referral_code=F600001');
  });

  test('Staging fallback retains old codes when the V54 RPC is not deployed yet', () async {
    final service = GrowthService(rpc: (name, params) async {
      if (name == 'growth_my_profile_v3') {
        return <String, dynamic>{
          'enabled': true,
          'code': 'C0123456789AB',
          'due': 0,
          'paid': 0,
          'promotional_available': 0,
        };
      }
      throw StateError('rpc_not_deployed');
    });
    final profile = await service.profile();
    expect(profile['code'], 'C0123456789AB');
    expect(profile['friend_reward_v54'], isNull);
  });

  test('Captain intake asks for an actual vehicle photo, separate from its licence', () {
    expect(CaptainApplicationV16.documentLabels.containsKey('vehicle_photo'), isTrue);
    expect(CaptainApplicationV16.documentLabels.containsKey('vehicle_front'), isTrue);
    expect(CaptainApplicationV16.documentLabels.containsKey('vehicle_back'), isTrue);
  });
}
