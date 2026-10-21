import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:vetosanya/presentation/captain_dashboard_screen/widgets/captain_presence_card.dart';

void main() {
  testWidgets('Online with stale GPS never claims readiness in the captain card', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CaptainPresenceCard(
      state: CaptainPresence.ready, online: true, locationFresh: false,
      onToggle: () {},
    ))));
    expect(find.text('متصل — موقعك محتاج تحديث'), findsOneWidget);
    expect(find.text('متصل وجاهز لاستقبال الرحلات'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  test('Ready requires recent confirmed GPS, with future-clock protection', () {
    final now = DateTime.utc(2026, 10, 14, 5);
    expect(isConfirmedCaptainGpsFresh(null, now: now), isFalse);
    expect(isConfirmedCaptainGpsFresh(now, now: now), isTrue);
    expect(
      isConfirmedCaptainGpsFresh(
        now.subtract(const Duration(seconds: 91)),
        now: now,
      ),
      isFalse,
    );
    expect(
      isConfirmedCaptainGpsFresh(now.add(const Duration(seconds: 6)), now: now),
      isFalse,
    );
    expect(
      resolveCaptainPresence(
        online: true,
        changing: false,
        disconnected: false,
        busy: false,
        unavailable: false,
      ),
      CaptainPresence.ready,
    );
    expect(
      resolveCaptainPresence(
        online: true,
        changing: false,
        disconnected: false,
        busy: true,
        unavailable: false,
      ),
      CaptainPresence.busy,
    );
    expect(
      resolveCaptainPresence(
        online: false,
        changing: false,
        disconnected: false,
        busy: false,
        unavailable: false,
      ),
      CaptainPresence.offline,
    );
  });
}
