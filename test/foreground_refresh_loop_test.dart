import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/services/foreground_refresh_loop.dart';

void main() {
  testWidgets('Background and disposal stop polling; resume refreshes once', (tester) async {
    var calls = 0;
    final loop = ForegroundRefreshLoop(
      refresh: () async { calls++; }, interval: const Duration(seconds: 60));
    loop.setForeground(true);
    await tester.pump();
    expect(calls, 1);
    await tester.pump(const Duration(seconds: 60));
    expect(calls, 2);
    loop.setForeground(false);
    loop.notifyChanged();
    await tester.pump(const Duration(minutes: 10));
    expect(calls, 2);
    loop.setForeground(true);
    loop.setForeground(true);
    await tester.pump();
    expect(calls, 3);
    loop.dispose();
    await tester.pump(const Duration(minutes: 10));
    await loop.request();
    expect(calls, 3);
  });

  testWidgets('Slow requests do not overlap and realtime bursts coalesce', (tester) async {
    var calls = 0;
    final pending = Completer<void>();
    final loop = ForegroundRefreshLoop(refresh: () {
      calls++;
      return calls == 1 ? pending.future : Future<void>.value();
    }, interval: const Duration(seconds: 60));
    loop.setForeground(true);
    await tester.pump(const Duration(minutes: 3));
    expect(calls, 1);
    pending.complete();
    await tester.pump();
    for (var i = 0; i < 50; i++) { loop.notifyChanged(); }
    await tester.pump(const Duration(milliseconds: 799));
    expect(calls, 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(calls, 2);
    loop.notifyChanged();
    loop.setForeground(false);
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 2);
    loop.dispose();
  });
}
