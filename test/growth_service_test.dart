import 'package:flutter/material.dart';
import 'package:vetosanya/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/services/growth_service.dart';
import 'package:vetosanya/services/staff_access_v16.dart';
import 'package:vetosanya/presentation/growth/growth_screens.dart';

class ReviewGrowthService extends GrowthService {
  ReviewGrowthService()
    : super(
        rpc: (name, params) async => {
          if (name == 'growth_my_profile_v3') 'enabled': true,
          'code': 'C72E4A091BC36',
          'referral_count': 3,
          'due': 65,
          'paid': 0,
          'promotional_available': 20,
          'history': <dynamic>[],
          'windows': <dynamic>[],
          'server_time': '2026-10-13T00:00:00Z',
        },
      );
  @override
  Future<bool> consent() async => false;
  @override
  Future<bool> startupSound() async => false;
}

void main() {
  test(
    'Existing employee role presets do not grant new growth permissions',
    () {
      for (final role in StaffAccessV16.roles) {
        expect(
          StaffAccessV16.preset(role).where((p) => p.startsWith('growth.')),
          isEmpty,
        );
      }
    },
  );
  test('Growth remains disabled in the default production build', () {
    expect(GrowthService.buildEnabled, isFalse);
  });
  test(
    'Ambiguous financial response is propagated without a second RPC',
    () async {
      final calls = <String>[];
      final service = GrowthService(
        rpc: (name, params) async {
          calls.add(name);
          throw StateError('connection_lost_after_commit');
        },
      );
      await expectLater(
        service.payout('claim', 'external-transfer'),
        throwsStateError,
      );
      expect(calls, ['growth_admin_payout_v1']);
    },
  );
  test(
    'Malformed server response is rejected rather than inventing a balance',
    () async {
      final service = GrowthService(rpc: (name, params) async => null);
      await expectLater(service.profile(), throwsStateError);
    },
  );
  test(
    'Missing promotional balance is unavailable rather than fabricated zero',
    () async {
      final service = GrowthService(
        rpc: (_, _) async => {
          'enabled': true,
          'code': '1001',
          'due': 0,
          'paid': 0,
        },
      );
      await expectLater(service.profile(), throwsStateError);
    },
  );
  test('Referral link preserves approved application and encodes the code', () {
    final link = GrowthService.referralLink('1001');
    expect(link.host, 'play.google.com');
    expect(link.queryParameters['id'], 'com.vetosanya.app');
    expect(link.queryParameters['referrer'], 'referral_code=1001');
  });
  for (final width in [320.0, 390.0, 600.0]) {
    testWidgets(
      'Referral account fits $width without losing payable or promotional balances',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(locale:const Locale('ar'),supportedLocales:AppLocalizations.supportedLocales,localizationsDelegates:AppLocalizations.localizationsDelegates,
            home: GrowthReferralScreen(service: ReviewGrowthService()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('C72E4A091BC36'), findsOneWidget);
        await tester.tap(find.text('تفاصيل المكافآت والحالة'));
        await tester.pumpAndSettle();
        expect(find.text('الرصيد الترويجي المتاح (جنيه)'),findsOneWidget);
        expect(find.text('20'),findsWidgets);
        expect(find.text('المكافآت المستحقة (جنيه)'),findsOneWidget);
        expect(find.text('65'),findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
