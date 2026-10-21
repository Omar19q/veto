import 'package:flutter/material.dart';
import '../../services/growth_service.dart';

/// Consented client timing only; server trip acceptance metrics stay separate.
class BookingPerformanceScreen extends StatefulWidget {
  const BookingPerformanceScreen({super.key});
  @override
  State<BookingPerformanceScreen> createState() =>
      _BookingPerformanceScreenState();
}

class _BookingPerformanceScreenState extends State<BookingPerformanceScreen> {
  Map<String, dynamic>? _report;
  bool _loading = false;
  String? _error;
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _report = null;
    });
    try {
      final result = await GrowthService()
          .call('v52_booking_performance_report', {
            'p_from': _range.start.toUtc().toIso8601String(),
            'p_to': DateTime(_range.end.year, _range.end.month,
                    _range.end.day + 1).toUtc().toIso8601String(),
          });
      if (mounted) setState(() => _report = result);
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'تعذر تحميل القياسات. تحقق من صلاحية Growth View وتحديث بيئة الاختبار.',
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String seconds(dynamic value) => value is num
      ? '${(value / 1000).toStringAsFixed(2)} ثانية'
      : 'لا توجد عينات مكتملة';
  String percent(dynamic value) =>
      value is num ? '${(value * 100).toStringAsFixed(1)}%' : 'لا توجد عينات';
  Future<void> _dates() async {
    final chosen = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 89)),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (chosen == null || !mounted) return;
    _range = DateTimeRange(
      start: chosen.start,
      end: chosen.end,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('سرعة إنشاء طلب الرحلة'),
      actions: [
        IconButton(
          tooltip: 'الفترة',
          onPressed: _loading ? null : _dates,
          icon: const Icon(Icons.date_range),
        ),
        IconButton(
          tooltip: 'تحديث',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'القياس يبدأ من دخول الحجز وينتهي عند تأكيد إنشاء الطلب من الخادم. زمن قبول الكابتن مستقل وغير مشمول.',
        ),
        const SizedBox(height: 8),
        const Text(
          'العينات من المستخدمين الذين وافقوا على القياس فقط؛ الأزمنة مقاسة بساعة التطبيق المتزايدة وليست مؤشرًا ماليًا أو دليل مخالفة.',
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (_report != null) ...[
          ListTile(
            title: const Text('عدد المحاولات المقاسة'),
            trailing: Text('${_report!['attempts']}'),
          ),
          ListTile(
            title: const Text('طلبات مؤكدة من الخادم'),
            trailing: Text('${_report!['created']}'),
          ),
          const Text('الفتح محسوب من دخول Dart أو العودة للتطبيق؛ لا يشمل الزمن السابق الذي يقضيه نظام الهاتف في تشغيله.'),
          ListTile(title: const Text('عينات الفتح حتى تأكيد السيرفر'),
            trailing: Text('${_report!['app_to_ack_samples']}')),
          ListTile(title: const Text('الفتح حتى تأكيد السيرفر · P50 / P95'),
            subtitle: Text('${seconds(_report!['app_to_ack_p50_ms'])} / ${seconds(_report!['app_to_ack_p95_ms'])}')),
          ListTile(title: const Text('ظهور الرئيسية · P50 / P95'),
            subtitle: Text('${seconds(_report!['home_visible_p50_ms'])} / ${seconds(_report!['home_visible_p95_ms'])}')),
          ListTile(title: const Text('اختيار الانطلاق / الوجهة · P50 من بدء الحجز'),
            subtitle: Text('${seconds(_report!['pickup_p50_ms'])} / ${seconds(_report!['destination_p50_ms'])}')),
          ListTile(title: const Text('ظهور السعر / تأكيد العميل · P50 من بدء الحجز'),
            subtitle: Text('${seconds(_report!['price_p50_ms'])} / ${seconds(_report!['confirm_p50_ms'])}')),
          ListTile(
            title: const Text('P50 · زمن الحجز'),
            subtitle: Text(seconds(_report!['booking_p50_ms'])),
          ),
          ListTile(
            title: const Text('P95 · زمن الحجز'),
            subtitle: Text(seconds(_report!['booking_p95_ms'])),
          ),
          ListTile(
            title: const Text('P50 · إرسال الطلب حتى تأكيده'),
            subtitle: Text(seconds(_report!['request_p50_ms'])),
          ),
          ListTile(
            title: const Text('P95 · إرسال الطلب حتى تأكيده'),
            subtitle: Text(seconds(_report!['request_p95_ms'])),
          ),
          ListTile(
            title: const Text('الرفض المؤكد من الخادم'),
            subtitle: Text(percent(_report!['failure_rate'])),
          ),
          ListTile(
            title: const Text('استجابة غير مؤكدة أو اتصال منقطع'),
            subtitle: Text(percent(_report!['uncertain_rate'])),
          ),
        ],
      ],
    ),
  );
}
