import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/presentation/captain_dashboard_screen/widgets/captain_presence_card.dart';

void main() {
  test(
    'expired and withdrawn offers cannot remain actionable after reload',
    () {
      final now = DateTime.utc(2026, 10, 8);
      expect(
        isLiveCaptainOffer({
          'offer_status': 'sent',
          'expires_at': now.toIso8601String(),
        }, now: now),
        isFalse,
      );
      expect(
        isLiveCaptainOffer({'offer_status': 'declined'}, now: now),
        isFalse,
      );
      expect(isLiveCaptainOffer({'offer_status': 'sent'}, now: now), isTrue);
      expect(
        isLiveCaptainOffer({
          'offer_status': 'sent',
          'expires_at': now.add(const Duration(seconds: 1)).toIso8601String(),
        }, now: now),
        isTrue,
      );
    },
  );
  test(
    'presence distinguishes server busy, disconnected, unavailable and pending',
    () {
      CaptainPresence resolve({
        bool online = false,
        bool changing = false,
        bool disconnected = false,
        bool busy = false,
        bool unavailable = false,
      }) => resolveCaptainPresence(
        online: online,
        changing: changing,
        disconnected: disconnected,
        busy: busy,
        unavailable: unavailable,
      );
      expect(resolve(), CaptainPresence.offline);
      expect(resolve(online: true), CaptainPresence.ready);
      expect(resolve(online: true, busy: true), CaptainPresence.busy);
      expect(
        resolve(online: true, disconnected: true),
        CaptainPresence.disconnected,
      );
      expect(resolve(unavailable: true), CaptainPresence.unavailable);
      expect(
        resolve(changing: true, disconnected: true),
        CaptainPresence.connecting,
      );
    },
  );
  testWidgets(
    'compact RTL card supports large text and pending blocks duplicate actions',
    (tester) async {
      var taps = 0;
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Future<void> show(CaptainPresence state) => tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(1.5),
              disableAnimations: true,
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: SingleChildScrollView(
                  child: CaptainPresenceCard(
                    state: state,
                    online: false,
                    onToggle: () => taps++,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await show(CaptainPresence.offline);
      await tester.tap(find.byType(FilledButton));
      expect(taps, 1);
      await show(CaptainPresence.connecting);
      await tester.tap(find.byType(FilledButton));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('expired offer calls expiry once without network polling', (
    tester,
  ) async {
    var expired = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CaptainOfferDeadline(
          expiresAt: DateTime.now().subtract(const Duration(seconds: 2)),
          onExpired: () => expired++,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 4));
    expect(expired, 1);
    expect(find.text('انتهى العرض'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
