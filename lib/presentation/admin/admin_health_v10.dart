import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';

class AdminHealthV10 extends StatefulWidget {
  const AdminHealthV10({super.key});
  @override
  State<AdminHealthV10> createState() => _AdminHealthV10State();
}

class _AdminHealthV10State extends State<AdminHealthV10> {
  final db = SupabaseService.instance.client;
  bool busy = false;
  Map<String, dynamic> report = {};
  String database = 'لم يُفحص', socket = 'لم يُفحص', route = 'لم يُفحص';
  int? dbMs, routeMs;
  RealtimeChannel? channel;
  @override
  void dispose() {
    channel?.unsubscribe();
    super.dispose();
  }

  Future<void> check() async {
    if (busy) return;
    setState(() => busy = true);
    final clock = Stopwatch()..start();
    try {
      final raw = await db
          .rpc('admin_system_health_v10')
          .timeout(const Duration(seconds: 8));
      report = Map<String, dynamic>.from(raw as Map);
      database = 'متصل';
      dbMs = clock.elapsedMilliseconds;
    } catch (_) {
      database = 'تعذر الاتصال';
    }
    final ready = Completer<bool>();
    channel?.unsubscribe();
    channel = db
        .channel('health_v10_${DateTime.now().millisecondsSinceEpoch}')
        .subscribe((status, error) {
          if (!ready.isCompleted &&
              status == RealtimeSubscribeStatus.subscribed)
            ready.complete(true);
          if (!ready.isCompleted &&
              status == RealtimeSubscribeStatus.channelError)
            ready.complete(false);
        });
    try {
      socket = await ready.future.timeout(const Duration(seconds: 8))
          ? 'متصل'
          : 'تعذر الاتصال';
    } catch (_) {
      socket = 'انتهت مهلة الاتصال';
    }
    await channel?.unsubscribe();
    channel = null;
    final routing = Stopwatch()..start();
    try {
      final result = await db.functions
          .invoke(
            'get-route',
            body: {
              'from_lat': 29.985,
              'from_lng': 31.117,
              'to_lat': 29.993,
              'to_lng': 31.128,
              'with_geometry': false,
            },
          )
          .timeout(const Duration(seconds: 12));
      route = result.status == 200 ? 'استجاب طلب اختبار' : 'تعذر طلب الاختبار';
      routeMs = routing.elapsedMilliseconds;
    } catch (_) {
      route = 'تعذر الوصول لخدمة الطريق';
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text(
        'صحة النظام',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
      const Text('فحص عند الطلب فقط. مدة الاستجابة تشمل شبكة جهاز الأدمن.'),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: busy ? null : check,
        icon: const Icon(Icons.monitor_heart),
        label: Text(busy ? 'جارٍ الفحص…' : 'فحص الآن'),
      ),
      for (final entry in [
        ('قاعدة البيانات', database, dbMs),
        ('Realtime — اتصال القناة', socket, null),
        ('Edge Functions / Routing', route, routeMs),
        ('Push Notifications', 'يحتاج اختبار وصول على جهاز فعلي', null),
      ])
        Card(
          child: ListTile(
            title: Text(entry.$1),
            subtitle: Text(
              '${entry.$2}${entry.$3 == null ? '' : ' • ${entry.$3}ms'}',
            ),
          ),
        ),
      const Text(
        'أزمنة RPC المسجلة فعليًا على السيرفر',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      for (final e in ((report['rpc_metrics'] as Map?) ?? {}).entries)
        ListTile(
          title: Text('${e.key}'),
          subtitle: Text(
            '${e.value['average_ms']}ms • ${e.value['samples']} عينة',
          ),
        ),
      if (((report['rpc_metrics'] as Map?) ?? {}).isEmpty)
        const Text('لا توجد عينات مسجلة بعد؛ لم نضع أرقامًا تقديرية.'),
    ],
  );
}
