import 'package:flutter/material.dart';
import '../../services/growth_service.dart';

class GrowthIncidentsScreen extends StatefulWidget {
  const GrowthIncidentsScreen({super.key, required this.service});
  final GrowthService service;
  @override
  State<GrowthIncidentsScreen> createState() => _GrowthIncidentsScreenState();
}

class _GrowthIncidentsScreenState extends State<GrowthIncidentsScreen> {
  static const kinds = {
    'pickup_distance': 'بدء الرحلة بعيدًا عن نقطة الركوب',
    'destination_distance': 'إنهاء الرحلة بعيدًا عن الوجهة',
    'gps_jump': 'تغيّر كبير يحتاج مراجعة في الموقع',
    'active_gps_stale': 'تحديث الموقع منقطع أثناء رحلة نشطة',
    'gps_unavailable': 'لم يتوفر موقع حديث للمراجعة',
    'state_sequence': 'تسلسل الرحلة يحتاج مراجعة',
    'repeat_pair': 'رحلات متكررة تحتاج مراجعة',
    'repeat_cancel': 'إلغاء متكرر بعد القبول',
    'repeated_gps': 'تغيرات موقع متكررة تحتاج مراجعة',
    'duration_difference': 'فرق في مدة الرحلة يحتاج مراجعة',
    'short_duration': 'مدة رحلة قصيرة تحتاج مراجعة',
  };
  static const statuses = {
    'open': 'قيد المراجعة',
    'dismissed': 'حُفظت الملاحظة',
    'confirmed': 'تمت مراجعة الملاحظة',
    'appealed': 'طلب المراجعة مسجل',
  };
  late Future<dynamic> data = widget.service.execute(
    'growth_my_incidents_v1',
    {},
  );
  Future<void> appeal(String id) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('طلب مراجعة بشرية'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          maxLength: 2000,
          decoration: const InputDecoration(labelText: 'وضح ظروف الرحلة'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(c, controller.text.trim());
              }
            },
            child: const Text('إرسال للمراجعة'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note == null) return;
    try {
      await widget.service.appeal(id, note);
      if (mounted) {
        setState(
          () => data = widget.service.execute('growth_my_incidents_v1', {}),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر تسجيل طلب المراجعة. راجع الحالة قبل إعادة المحاولة.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('مراجعة ملاحظات الرحلات')),
      body: FutureBuilder<dynamic>(
        future: data,
        builder: (_, s) {
          if (s.hasError) {
            return Center(
              child: TextButton(
                onPressed: () => setState(
                  () => data = widget.service.execute(
                    'growth_my_incidents_v1',
                    {},
                  ),
                ),
                child: const Text('تعذر التحميل؛ إعادة المحاولة'),
              ),
            );
          }
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = s.data as List;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'هذه ملاحظات تحتاج مراجعة بشرية. لا تفرض غرامة تلقائية أو توقف الحساب.',
              ),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('لا توجد ملاحظات مسجلة'),
                ),
              for (final item in items)
                Card(
                  child: ListTile(
                    title: Text(kinds[item['kind']] ?? 'ملاحظة تحتاج مراجعة'),
                    subtitle: Text(
                      'الحالة: ${statuses[item['status']] ?? 'قيد المراجعة'}',
                    ),
                    trailing: TextButton(
                      onPressed: () => appeal('${item['id']}'),
                      child: const Text('طلب مراجعة'),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
