import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_service.dart';
import 'admin_captain_actions_v10.dart';

class AdminIncidentsV10 extends StatefulWidget {
  const AdminIncidentsV10({super.key});
  @override
  State<AdminIncidentsV10> createState() => _AdminIncidentsV10State();
}

class _AdminIncidentsV10State extends State<AdminIncidentsV10> {
  final db = SupabaseService.instance.client;
  List<Map<String, dynamic>> rows = [];
  TripRealtimeLease? channel;
  Timer? debounce;
  String? error;
  bool busy = false;
  final analyzing = <String>{};
  @override
  void initState() {
    super.initState();
    load();
    channel = SupabaseService.instance.subscribeToScaleAdminPulse(load);
  }

  @override
  void dispose() {
    debounce?.cancel();
    channel?.unsubscribe();
    super.dispose();
  }

  Future<void> load() async {
    if (busy) return;
    busy = true;
    try {
      final data = await db
          .rpc('admin_incidents_list_v10')
          .timeout(const Duration(seconds: 10));
      if (mounted)
        setState(() {
          rows = List<Map<String, dynamic>>.from(data);
          error = null;
        });
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر تحميل الحالات');
    } finally {
      busy = false;
    }
  }

  void detail(Map<String, dynamic> r) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'مستوى المخاطرة: ${r['risk_level'] == 'high'
                  ? 'مرتفع'
                  : r['risk_level'] == 'medium'
                  ? 'متوسط'
                  : 'منخفض'} • ${r['risk_score']}/100',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              'الرحلة: ${r['trip_id']}\nالكابتن: ${r['captain_name'] ?? r['captain_id']}\nالعميل: ${r['customer_name'] ?? r['customer_id']}\n${r['created_at']}',
            ),
            const Divider(),
            for (final e in ((r['evidence'] as Map?) ?? {}).entries.where(
              (e) => ![
                'method',
                'automatic_penalty',
                'missing_metrics',
                'route_comparison',
              ].contains(e.key),
            ))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '${{'rating': 'تقييم العميل', 'reasons': 'الأسباب', 'comment': 'التعليق', 'arrival_delay_minutes': 'تأخر الوصول بالدقائق', 'eta_minutes': 'الوقت المتوقع للوصول', 'low_ratings_last_20': 'تقييمات منخفضة في آخر 20 رحلة', 'captain_cancellations_last_20': 'إلغاءات الكابتن الأخيرة', 'recent_trips': 'حجم سجل الرحلات', 'route_deviation_km': 'انحراف المسار', 'stops_minutes': 'مدة التوقف بالدقائق', 'observed_minutes': 'دقائق التتبع المسجلة', 'tracked_distance_km': 'المسافة المرصودة', 'suspicious_movement_samples': 'عينات حركة غير معتادة', 'acceptance_rate_last_20': 'نسبة القبول الأخيرة', 'previous_incidents': 'حالات سابقة', 'route_comparison': 'طريقة مقارنة المسار', 'route_deviation_is_estimate': 'انحراف تقديري'}[e.key] ?? e.key}: ${e.value == true
                      ? 'نعم'
                      : e.value == false
                      ? 'لا'
                      : e.value ?? 'غير مسجل'}',
                ),
              ),
            const Text(
              'التوصية: مراجعة يدوية، ثم لا إجراء أو تنبيه أو إنذار أو إيقاف مؤقت. لا توجد عقوبة تلقائية.',
            ),
            const SizedBox(height: 12),
            if (r['ai_analysis'] is Map)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    (r['ai_analysis'] as Map)['summary']?.toString() ?? '',
                  ),
                ),
              ),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(sheet);
                context.push('/admin/trip-details?tripId=${r['trip_id']}');
              },
              child: const Text('تفاصيل الرحلة والتايملاين'),
            ),
            FilledButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => AdminCaptainActionsV10(
                  captainId: r['captain_id'].toString(),
                  name: 'صاحب الرحلة',
                ),
              ),
              child: const Text('اتخاذ إجراء إداري'),
            ),
            OutlinedButton(
              onPressed: () async {
                final id = r['trip_id'].toString();
                if (!analyzing.add(id)) return;
                ScaffoldMessenger.of(sheet).showSnackBar(
                  const SnackBar(content: Text('جارٍ تحليل المؤشرات…')),
                );
                try {
                  final result = await db.functions
                      .invoke('analyze-trip-risk', body: {'trip_id': id})
                      .timeout(const Duration(seconds: 45));
                  final raw = result.data;
                  if (raw is! Map || raw['analysis'] is! Map)
                    throw StateError('analysis_unavailable');
                  final analysis = Map<String, dynamic>.from(
                    raw['analysis'] as Map,
                  );
                  if (sheet.mounted)
                    showDialog(
                      context: sheet,
                      builder: (_) => AlertDialog(
                        title: const Text('التحليل الذكي'),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(analysis['summary']?.toString() ?? ''),
                              const SizedBox(height: 12),
                              for (final e
                                  in analysis['evidence'] as List? ?? [])
                                Text('• $e'),
                              const SizedBox(height: 12),
                              Text(
                                'التوصية: ${{'no_action': 'لا إجراء', 'notice': 'تنبيه', 'formal_warning': 'مراجعة إنذار رسمي', 'temporary_pause_review': 'مراجعة إيقاف مؤقت', 'manual_review': 'مراجعة يدوية'}[analysis['recommendation']] ?? 'مراجعة يدوية'}',
                              ),
                              const Text(
                                'القرار للإدارة. لم يتم تنفيذ أي عقوبة.',
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(sheet),
                            child: const Text('تم'),
                          ),
                        ],
                      ),
                    );
                } catch (_) {
                  if (sheet.mounted)
                    ScaffoldMessenger.of(sheet).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'خدمة التحليل الذكي لم تُفعّل أو تعذر الاتصال بها. تقرير القواعد متاح.',
                        ),
                      ),
                    );
                } finally {
                  analyzing.remove(id);
                }
              },
              child: const Text('طلب تحليل ذكي أعمق'),
            ),
            TextButton(
              onPressed: () async {
                await db.rpc(
                  'admin_review_incident_v10',
                  params: {'p_trip_id': r['trip_id'], 'p_status': 'closed'},
                );
                if (sheet.mounted) Navigator.pop(sheet);
                load();
              },
              child: const Text('إغلاق بعد المراجعة'),
            ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: load,
    child: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'الحالات والمخاطر',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const Text('الأرقام من الرحلات والتقييمات؛ الإدارة هي صاحبة القرار.'),
        if (error != null) Text(error!),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Text('لا توجد حالات مسجلة'),
          ),
        for (final r in rows)
          Card(
            child: ListTile(
              leading: Icon(
                Icons.warning_amber,
                color: r['risk_level'] == 'high' ? Colors.red : Colors.amber,
              ),
              title: Text('رحلة ${r['trip_id']}'),
              subtitle: Text(
                '${r['risk_level']} • ${r['risk_score']} • ${r['status']}',
              ),
              onTap: () => detail(r),
            ),
          ),
      ],
    ),
  );
}
