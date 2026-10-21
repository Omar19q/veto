import 'package:flutter/material.dart';
import '../../services/growth_service.dart';

class CaptainCodeCapacityScreen extends StatefulWidget {
  const CaptainCodeCapacityScreen({super.key, this.service});
  final GrowthService? service;
  @override
  State<CaptainCodeCapacityScreen> createState() =>
      _CaptainCodeCapacityScreenState();
}

class _CaptainCodeCapacityScreenState extends State<CaptainCodeCapacityScreen> {
  Map<String, dynamic>? report;
  bool busy = false, failed = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (busy) return;
    setState(() {
      busy = true;
      failed = false;
      report = null;
    });
    try {
      final result = await (widget.service ?? GrowthService()).call(
        'growth_admin_code_capacity_v1',
      );
      final expanded =
          result['policy'] == 'sequential_variable_digits' &&
          result['automatic_expansion'] == true;
      for (final key
          in expanded
              ? ['issued', 'next_code']
              : ['capacity', 'issued', 'remaining_slots', 'next_code']) {
        if (result[key] is! num ||
            !(result[key] as num).isFinite ||
            (result[key] as num) < 0)
          throw StateError('invalid_capacity_report');
      }
      if ((!expanded && result['automatic_expansion'] != false) ||
          result['allocation_paused'] is! bool ||
          result['near_limit'] is! bool) {
        throw StateError('invalid_capacity_policy');
      }
      if (mounted) setState(() => report = result);
    } catch (error) {
      debugPrint('Captain code capacity read failed: ${error.runtimeType}');
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('سعة أكواد الكباتن')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            report?['automatic_expansion'] == true
                ? 'الأكواد تبدأ من 1001 وتستمر إلى خمسة أرقام وما بعدها؛ الأكواد الحالية ثابتة.'
                : 'تقرير السياسة القديمة؛ يلزم تطبيق ترحيل التوسع المعتمد على بيئة الاختبار.',
          ),
          if (busy) const LinearProgressIndicator(),
          if (failed)
            const Text(
              'تعذر تحميل التقرير. يلزم تحديث بيئة الاختبار وصلاحية Growth View. لم نفترض أي عدد.',
            ),
          if (report != null) ...[
            ListTile(
              title: const Text('سياسة التخصيص'),
              trailing: Text(
                report!['capacity'] == null
                    ? 'متسلسل دون حد 9999'
                    : '${report!['capacity']}',
              ),
            ),
            ListTile(
              title: const Text('الأكواد المصروفة'),
              trailing: Text('${report!['issued']}'),
            ),
            ListTile(
              title: const Text('الكود التالي المرشح'),
              trailing: Text('${report!['next_code']}'),
            ),
            if (report!['near_limit'] == true)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'اقترب نفاد السعة. يلزم اعتماد خطة الخمسة أرقام قبل تفعيلها. الأكواد الحالية لا تتغير.',
                  ),
                ),
              ),
            if (report!['allocation_paused'] == true)
              const Text(
                'تخصيص أكواد جديدة متوقف حتى اعتماد التوسع. لا يؤثر ذلك على الرحلات أو المحاسبة أو الأكواد المصروفة.',
              ),
          ],
          const Text(
            'المواضع المتاحة تراعي فجوات التسلسل؛ الأكواد المحجوزة سابقًا لا يعاد استخدامها.',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: busy ? null : load,
            icon: const Icon(Icons.refresh),
            label: const Text('تحديث'),
          ),
        ],
      ),
    ),
  );
}
