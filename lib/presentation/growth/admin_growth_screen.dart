import 'monitor_status_screen.dart';
import 'admin_badge_activation_screen.dart';
import 'dart:convert';
import 'booking_performance_screen.dart';
import 'captain_code_capacity_screen.dart';
import 'package:flutter/material.dart';
import '../../services/growth_service.dart';
import '../../services/staff_access_v16.dart';
import 'growth_screens.dart';
import 'owner_growth_campaign_wizard_v66.dart';

class AdminGrowthScreen extends StatefulWidget {
  const AdminGrowthScreen({super.key});
  @override
  State<AdminGrowthScreen> createState() => _AdminGrowthScreenState();
}

class _AdminGrowthScreenState extends State<AdminGrowthScreen> {
  final service = GrowthService();
  DateTimeRange? period;
  Future<Map<String, dynamic>> fetch() => service.overview(
    since: period?.start,
    until: period == null ? null : period!.end.add(const Duration(days: 1)),
  );
  late Future<Map<String, dynamic>> data = fetch();
  StaffAccessV16 access = const StaffAccessV16();
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    StaffAccessV16.load().then((v) {
      if (mounted) setState(() => access = v);
    });
  }

  Future<void> act(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      if (mounted) setState(() => data = fetch());
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'تعذر تنفيذ العملية. تحقق من الصلاحية والمدخلات والاتصال؛ لا تعِد التحويل المالي.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  static String _statusName(Map<String, dynamic> data, String key) {
    final flags = data['flags'];
    if (flags is List) {
      for (final item in flags) {
        if (item is Map && item['key'] == key) {
          return item['enabled'] == true ? 'شغال' : 'متوقف';
        }
      }
    }
    return 'غير معروف';
  }

  static String _flagLabel(String key) {
    const labels = {
      'referrals': 'دعوات الأصدقاء والكباتن',
      'discounts': 'خصومات الرحلات',
      'badge': 'البادجات وأكواد الكباتن',
      'startup': 'رسالة الترحيب عند بداية الاستخدام',
      'zero_commission': 'عرض العمولة الصفرية للكباتن',
      'events': 'متابعة إحصائيات الاستخدام',
      'safety': 'فحص سلامة الرحلات',
      'booking_ui': 'عرض خصومات الحجز',
    };
    return labels[key] ?? key;
  }

  Future<bool> confirmTurnOn(String key) async {
    final answer = await showDialog<bool>(context: context, builder: (c) =>
      AlertDialog(
        title: Text('تأكيد تشغيل ${_flagLabel(key)}'),
        content: Text(key == 'discounts' || key == 'referrals'
            ? 'العروض لا تعمل إلا بوجود حملة مؤهلة ونسخة تطبيق تدعم Growth. المكافآت والخصومات المالية تُحسب على الخادم بعد استيفاء الشروط؛ اتأكد من اختبار الرحلة والتسوية قبل التشغيل للعملاء.'
            : 'هيتم حفظ القرار على الخادم وتسجيله في سجل التغييرات. هل متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('أوافق على التشغيل')),
        ],
      ),
    );
    return answer == true;
  }

  Future<String?> input(String title, {String value = ''}) async {
    final controller = TextEditingController(text: value);
    final result = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, maxLines: 4),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text),
            child: const Text('اعتماد'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> campaign() async {
    final title = await input('اسم الحملة');
    if (title == null) return;
    final budget = await input('ميزانية الحملة بالجنيه');
    if (budget == null) return;
    final cap = await input('الحد الأقصى لخصم الرحلة بالجنيه');
    if (cap == null) return;
    final dates = await input(
      'البداية والنهاية UTC بصيغة ISO، كل تاريخ في سطر',
    );
    if (dates == null) return;
    final selected = <String>{'car_ride', 'motorcycle_ride', 'package'};
    if (!mounted) return;
    final services = await showDialog<List<String>>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: const Text('الخدمات المؤهلة للحملة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in const {
                'car_ride': 'مشوار سيارة',
                'motorcycle_ride': 'مشوار موتوسيكل',
                'package': 'توصيل طرد',
                'vito_market': 'فيتو ماركت',
              }.entries)
                CheckboxListTile(
                  title: Text(entry.value),
                  value: selected.contains(entry.key),
                  onChanged: (v) => update(() {
                    if (v == true) {
                      selected.add(entry.key);
                    } else {
                      selected.remove(entry.key);
                    }
                  }),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(c, selected.toList()),
              child: const Text('متابعة'),
            ),
          ],
        ),
      ),
    );
    if (services == null) return;
    await act(() async {
      final parts = dates.trim().split('\n');
      if (parts.length != 2) throw StateError('invalid_dates');
      await service.execute('growth_admin_campaign_v1', {
        'p_title': title,
        'p_budget': double.parse(budget),
        'p_cap': double.parse(cap),
        'p_starts': DateTime.parse(parts[0]).toUtc().toIso8601String(),
        'p_ends': DateTime.parse(parts[1]).toUtc().toIso8601String(),
        'p_services': services,
        'p_active': false,
      });
    });
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: growthBackground,
      appBar: AppBar(
        title: const Text('إدارة الدعوات والعروض'),
        actions: [
          IconButton(
            tooltip: 'فترة تقرير الحجز',
            icon: const Icon(Icons.date_range),
            onPressed: busy
                ? null
                : () async {
                    final chosen = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: period,
                      helpText: 'اختر فترة لا تتجاوز سنة',
                    );
                    if (!mounted || chosen == null) return;
                    if (chosen.duration.inDays > 365) {
                      setState(() => error = 'اختر فترة لا تتجاوز سنة.');
                      return;
                    }
                    setState(() {
                      period = chosen;
                      data = fetch();
                    });
                  },
          ),
          IconButton(
            onPressed: busy ? null : () => setState(() => data = fetch()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: data,
        builder: (c, s) {
          if (s.hasError) {
            return const Center(
              child: Text('تعذر تحميل البيانات أو لا توجد صلاحية growth.view'),
            );
          }
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = s.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                period == null
                    ? 'الحجز: آخر 30 يومًا · الحملات والإحالات: منذ بداية الحملة'
                    : 'الحجز: ${period!.start.toLocal().toString().split(' ').first} إلى ${period!.end.toLocal().toString().split(' ').first} · الحملات والإحالات: منذ البداية',
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('عروض أول مشوار ودعوة صديق',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                      const SizedBox(height: 8),
                      const Text('ابدأ بإنشاء حملة بميزانية وحد خصم، بعدها اعتمد تشغيل الحملة ثم فعّل الدعوات والخصومات من المفاتيح تحت. مش هنحسب للعميل أي خصم قبل ما يوافق الخادم.'),
                      const SizedBox(height: 8),
                      Text(GrowthService.buildEnabled
                        ? 'النسخة الحالية تدعم تسعير الرحلات بعروض Growth.'
                        : 'تنبيه: النسخة الحالية غير مبنية بخيارات تشغيل Growth للإنتاج. تفعيل المفاتيح وحده مش هيضيف الخصم لمسار الحجز في النسخة دي.',
                        style: TextStyle(color: GrowthService.buildEnabled
                          ? Colors.greenAccent : Colors.orangeAccent)),
                      const SizedBox(height: 12),
                      if (access.can('growth.manage'))
                        FilledButton.icon(
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('إنشاء عرض جديد بخطوات سهلة'),
                          onPressed: busy ? null : () async {
                            final created = await Navigator.push<bool>(context,
                              MaterialPageRoute(builder: (_) => const OwnerGrowthCampaignWizardV66()));
                            if (created == true && mounted) setState(() => data = fetch());
                          },
                        ),
                      const SizedBox(height: 8),
                      Text('الدعوات: ${_statusName(d, 'referrals')}   •   الخصومات: ${_statusName(d, 'discounts')}'),
                    ],
                  ),
                ),
              ),
              if (access.owner)
                Card(child: ListTile(
                  leading: const Icon(Icons.qr_code_scanner_rounded),
                  title: const Text('تفعيل بادجات الكباتن والفرق'),
                  subtitle: const Text('نقطة شيل أوت · اعتماد التركيب · مكافآت الإحالة · عروض ساعتين بلا عمولة'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const AdminBadgeActivationScreen())),
                )),
              if (access.can('growth.safety'))
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => act(() async {
                          await service.execute(
                            'growth_admin_scan_active_v1',
                            {},
                          );
                        }),
                  icon: const Icon(Icons.radar),
                  label: const Text('فحص تحديث الموقع للرحلات النشطة'),
                ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.orange)),
              Text(
                'المسجلون في الهدية: ${d['enrollments']} · الدعوات المعتمدة: ${d['referrals']}',
              ),
              Text('تكلفة التقريب: ${d['rounding_cost']} ج'),
              Text(
                'تجاوز سقف إعفاء العمولة للرحلات المستحقة: ${d['zero_overspend'] ?? 0} ج',
              ),
              for (final cost in Map<String, dynamic>.from(
                d['costs'] ?? {},
              ).entries)
                Text('${cost.key}: ${cost.value} ج'),
              const Text(
                'رصيد الصديق الممنوح واستخدامه يظهران مستقلين؛ الاستخدام ليس تكلفة حملة إضافية فوق الرصيد الممنوح.',
              ),
              const Text(
                'البيانات من السجلات الفعلية. صفر يعني عدم وجود أحداث، وليس تقديرًا.',
              ),
              for (final flag in (d['flags'] as List? ?? []))
                SwitchListTile(
                  title: Text(_flagLabel(flag['key'].toString())),
                  subtitle: Text(flag['enabled'] == true ? 'مفعّل' : 'متوقف'),
                  value: flag['enabled'] == true,
                  onChanged: busy || !access.can('growth.manage')
                      ? null
                      : (enabled) async {
                          final key = flag['key'].toString();
                          if (enabled && !await confirmTurnOn(key)) return;
                          await act(() => service.setFlag(key, enabled,
                              Map<String, dynamic>.from(flag['settings'] ?? {})));
                        },
                  secondary: IconButton(
                    icon: const Icon(Icons.tune),
                    onPressed: !access.can('growth.manage')
                        ? null
                        : () async {
                            final value = await input(
                              'إعدادات ${flag['key']} JSON',
                              value: jsonEncode(flag['settings']),
                            );
                            if (value == null) return;
                            await act(
                              () => service.setFlag(
                                flag['key'],
                                flag['enabled'] == true,
                                Map<String, dynamic>.from(jsonDecode(value)),
                              ),
                            );
                          },
                  ),
                ),
              if (access.can('growth.manage'))
                OutlinedButton(
                  onPressed: busy ? null : campaign,
                  child: const Text('إنشاء حملة متوقفة للمراجعة'),
                ),
              for (final campaign in (d['campaigns'] as List? ?? []))
                Card(
                  child: ListTile(
                    title: Text(campaign['title']),
                    onTap: !access.can('growth.manage') || busy
                        ? null
                        : () async {
                            final policy = await input(
                              'سياسة الرحلات الثلاث: JSON discounts وcaptain_rewards. الحجوزات القائمة تحتفظ بقيمها.',
                              value: jsonEncode(campaign['benefit_policy']),
                            );
                            if (policy == null) return;
                            await act(() async {
                              await service
                                  .execute('growth_admin_campaign_policy_v1', {
                                    'p_id': campaign['id'],
                                    'p_policy': jsonDecode(policy),
                                  });
                            });
                          },
                    subtitle: Text(
                      'الميزانية ${campaign['budget']} · محجوز ${campaign['committed']} · مصروف ${campaign['spent']}\nاضغط لمراجعة نسب الخصم وقيم المكافآت',
                    ),
                    trailing: access.can('growth.manage')
                        ? TextButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    if (campaign['active'] != true &&
                                        !await confirmTurnOn('discounts')) return;
                                    await act(() async {
                                    await service.execute(
                                      campaign['active'] == true
                                          ? 'growth_admin_pause_campaign_v1'
                                          : 'growth_admin_activate_campaign_v1',
                                      {'p_id': campaign['id']},
                                    );
                                    });
                                  },
                            child: Text(
                              campaign['active'] == true ? 'إيقاف' : 'تفعيل',
                            ),
                          )
                        : null,
                  ),
                ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MonitorStatusScreen(),
                  ),
                ),
                icon: const Icon(Icons.monitor_heart_outlined),
                label: const Text('سجل تشغيل المراقبة الدورية'),
              ),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CaptainCodeCapacityScreen(),
                  ),
                ),
                icon: const Icon(Icons.numbers),
                label: const Text('سعة أكواد الكباتن وخطة التوسع'),
              ),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BookingPerformanceScreen(),
                  ),
                ),
                icon: const Icon(Icons.speed),
                label: const Text('قياسات إنشاء الطلب · P50 / P95'),
              ),
              const Text(
                'مؤشرات الحجز من سجلات الرحلات',
                style: TextStyle(fontSize: 20, color: growthGold),
              ),
              for (final metric in Map<String, dynamic>.from(
                d['booking_metrics'] ?? {},
              ).entries)
                ListTile(
                  title: Text(metric.key),
                  trailing: Text('${metric.value ?? 'غير متاح'}'),
                ),
              const Text(
                'أحداث الاستخدام الاختيارية لا تمثل كل العملاء. بيانات الرحلات المعتمدة تظهر مستقلة.',
              ),
              for (final campaign in (d['campaign_metrics'] as List? ?? []))
                Card(
                  child: ListTile(
                    title: Text('${campaign['title']}'),
                    subtitle: Text(
                      'متبقي ${campaign['remaining_budget']} ج · عملاء مؤهلون ${campaign['qualified_customers']} · رحلات ${campaign['completed_trips']}\nهامش مباشر ${campaign['actual_company_margin']} ج · عمولة معفاة ${campaign['foregone_commission']} ج',
                    ),
                  ),
                ),
              const Text(
                'الهامش المباشر قبل تكاليف التشغيل ومكافآت الأنظمة القديمة غير المنسوبة للحملة؛ العمولة المعفاة إيراد متروك، ولا تُخصم مرتين.',
              ),
              const Text(
                'ترتيب أداء الإحالات',
                style: TextStyle(fontSize: 20, color: growthGold),
              ),
              for (final referrer in (d['referrer_ranking'] as List? ?? []))
                ListTile(
                  title: Text('كود ${referrer['code']}'),
                  subtitle: Text(
                    'مسجلون ${referrer['registrations']} · مؤهلون ${referrer['qualified_customers']} · رحلات ${referrer['completed_trips']}\nمستحق ${referrer['due']} ج · مدفوع ${referrer['paid']} ج · رصيد صديق ممنوح ${referrer['promotional_awarded']} ج',
                  ),
                ),
              const Text(
                'مسار التحويل',
                style: TextStyle(fontSize: 20, color: growthGold),
              ),
              for (final entry in Map<String, dynamic>.from(
                d['funnel'] ?? {},
              ).entries)
                ListTile(
                  title: Text(entry.key),
                  trailing: Text('${entry.value}'),
                ),
              const Text(
                'المكافآت المستحقة',
                style: TextStyle(fontSize: 20, color: growthGold),
              ),
              for (final claim in (d['claims'] as List? ?? []))
                ListTile(
                  title: Text('${claim['amount']} ج · ${claim['kind']}'),
                  subtitle: Text(claim['operation_key']),
                  trailing: access.can('growth.finance')
                      ? TextButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  final reference = await input(
                                    'سجّل مرجع التحويل الذي تم فعليًا؛ هذا الزر لا يحوّل أموالًا',
                                  );
                                  if (reference == null) return;
                                  await act(
                                    () =>
                                        service.payout(claim['id'], reference),
                                  );
                                },
                          child: const Text('توثيق دفع'),
                        )
                      : null,
                ),
              const Text(
                'مراجعة الحالات التشغيلية',
                style: TextStyle(fontSize: 20, color: growthGold),
              ),
              for (final i in (d['incidents'] as List? ?? []))
                Card(
                  child: ListTile(
                    title: Text(
                      '${i['kind']} · ${i['severity']} · ${i['status']}',
                    ),
                    subtitle: Text(jsonEncode(i['evidence'])),
                    trailing: access.can('growth.safety')
                        ? PopupMenuButton<String>(
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'dismissed',
                                child: Text('استبعاد'),
                              ),
                              const PopupMenuItem(
                                value: 'confirmed',
                                child: Text('تأكيد للمراجعة فقط'),
                              ),
                            ],
                            onSelected: (status) async {
                              final note = await input(
                                'سبب القرار؛ لا تُطبق غرامة تلقائيًا',
                              );
                              if (note != null) {
                                await act(
                                  () => service.review(i['id'], status, note),
                                );
                              }
                            },
                          )
                        : null,
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
