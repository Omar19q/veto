import 'package:flutter/material.dart';
import '../../services/growth_service.dart';

/// Reads verified worker history; opening this screen never runs the worker.
class MonitorStatusScreen extends StatefulWidget {
  const MonitorStatusScreen({super.key, this.service});
  final GrowthService? service;
  @override
  State<MonitorStatusScreen> createState() => _MonitorStatusScreenState();
}

class _MonitorStatusScreenState extends State<MonitorStatusScreen> {
  Map<String, dynamic>? report;
  bool loading = false, failed = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (loading) return;
    setState(() {
      loading = true;
      failed = false;
      report = null;
    });
    try {
      final value = await (widget.service ?? GrowthService()).call(
        'growth_admin_monitor_status_v1',
      );
      if (value['automatic_penalties'] != false ||
          value['runs'] is! List ||
          value['isolated_configured'] is! bool ||
          value['safety_enabled'] is! bool) {
        throw StateError('invalid_monitor_status');
      }
      for (final row in value['runs'] as List) {
        if (row is! Map ||
            DateTime.tryParse('${row['started_at']}') == null ||
            DateTime.tryParse('${row['finished_at']}') == null)
          throw StateError('invalid_monitor_run');
        for (final key in [
          'active_checked',
          'recent_checked',
          'alerts_created',
        ]) {
          final count = row[key];
          if (count is! num ||
              !count.isFinite ||
              count < 0 ||
              count != count.roundToDouble()) {
            throw StateError('invalid_monitor_count');
          }
        }
      }
      if (mounted) setState(() => report = value);
    } catch (error) {
      debugPrint('Monitor status failed: ${error.runtimeType}');
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('المراقبة الدورية للرحلات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'تنبيهات للمراجعة البشرية؛ لا تُفرض غرامات تلقائية. فتح الصفحة لا يشغّل الفحص.',
          ),
          if (loading) const LinearProgressIndicator(),
          if (failed)
            const Text(
              'تعذر التحقق من سجل التشغيل. يلزم إعداد البيئة المعزولة وصلاحية Growth Safety.',
            ),
          if (report != null) ...[
            if (report!['isolated_configured'] != true ||
                report!['safety_enabled'] != true)
              const Text(
                'المراقبة غير مهيأة أو معطلة؛ لا يعني ذلك أن الرحلات خالية من التنبيهات.',
              ),
            if ((report!['runs'] as List).isEmpty)
              const Text(
                'لا توجد عمليات فحص مسجلة. لا يمكن تأكيد تشغيل العامل الدوري.',
              ),
            for (final row in report!['runs'] as List)
              Card(
                child: ListTile(
                  title: Text('${row['started_at']}'),
                  subtitle: Text(
                    'رحلات نشطة: ${row['active_checked']} · مكتملة: ${row['recent_checked']} · تنبيهات جديدة: ${row['alerts_created']}',
                  ),
                ),
              ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: loading ? null : load,
            icon: const Icon(Icons.refresh),
            label: const Text('تحديث السجل'),
          ),
        ],
      ),
    ),
  );
}
