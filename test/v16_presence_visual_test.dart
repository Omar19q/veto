import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/presentation/captain_dashboard_screen/widgets/captain_presence_card.dart';

void main() {
  testWidgets('six presence states fit a small RTL phone', (tester) async {
    final font = FontLoader('Cairo')
      ..addFont(rootBundle.load('assets/fonts/Cairo.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    await tester.binding.setSurfaceSize(const Size(320, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Cairo'),
        ),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: const Color(0xFF0D1320),
            body: RepaintBoundary(
              key: const ValueKey('presence-gallery'),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    const Text(
                      'VETO SANYA • V16',
                      style: TextStyle(color: Color(0xFFE5BE6B), fontSize: 20),
                    ),
                    for (final state in CaptainPresence.values)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: CaptainPresenceCard(
                          state: state,
                          online:
                              state == CaptainPresence.ready ||
                              state == CaptainPresence.busy,
                          reason: state == CaptainPresence.unavailable
                              ? 'راجع فريق التشغيل لمعرفة سبب عدم الإتاحة.'
                              : null,
                          onToggle: () {},
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey('presence-gallery')),
      matchesGoldenFile('goldens/v16_presence.png'),
    );
  });
}
