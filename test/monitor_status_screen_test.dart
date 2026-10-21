import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/services/growth_service.dart';
import 'package:vetosanya/presentation/growth/monitor_status_screen.dart';

void main() {
  testWidgets('Empty worker history never claims successful monitoring', (
    tester,
  ) async {
    final service = GrowthService(
      rpc: (name, args) async {
        expect(name, 'growth_admin_monitor_status_v1');
        return {
          'runs': [],
          'isolated_configured': false,
          'safety_enabled': false,
          'automatic_penalties': false,
        };
      },
    );
    await tester.pumpWidget(
      MaterialApp(home: MonitorStatusScreen(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('لا توجد عمليات فحص مسجلة'), findsOneWidget);
    expect(find.textContaining('المراقبة غير مهيأة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Failed read does not invent a zero-alert successful run', (
    tester,
  ) async {
    final service = GrowthService(
      rpc: (_, __) async => throw StateError('denied'),
    );
    await tester.pumpWidget(
      MaterialApp(home: MonitorStatusScreen(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('تعذر التحقق'), findsOneWidget);
    expect(find.textContaining('تنبيهات جديدة: 0'), findsNothing);
  });
  testWidgets(
    'Verified counts displayed without starting worker or imposing penalties',
    (tester) async {
      var calls = 0;
      final service = GrowthService(
        rpc: (name, _) async {
          expect(name, 'growth_admin_monitor_status_v1');
          calls++;
          return {
            'runs': [
              {
                'started_at': '2026-10-13T12:00:00Z',
                'finished_at': '2026-10-13T12:00:01Z',
                'active_checked': 2,
                'recent_checked': 3,
                'alerts_created': 1,
              },
            ],
            'isolated_configured': true,
            'safety_enabled': true,
            'automatic_penalties': false,
          };
        },
      );
      await tester.pumpWidget(
        MaterialApp(home: MonitorStatusScreen(service: service)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('تنبيهات جديدة: 1'), findsOneWidget);
      expect(calls, 1);
    },
  );
}
