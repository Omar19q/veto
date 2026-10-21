import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';

class AdminPricingEngineV10 extends StatefulWidget {
  const AdminPricingEngineV10({super.key});
  @override
  State<AdminPricingEngineV10> createState() => _AdminPricingEngineV10State();
}

class _AdminPricingEngineV10State extends State<AdminPricingEngineV10> {
  final fields = <String, TextEditingController>{};
  bool enabled = true, busy = false;
  String? error;
  final labels = {
    'max_multiplier': 'أعلى سعر ممكن للرحلة (مثلاً 1.3 = زيادة 30%)',
    'pressure_weight': 'تأثير عدد الطلبات على السعر',
    'waiting_weight': 'تأثير طول الانتظار وقلة قبول الطلبات',
    'peak_weight': 'تأثير ساعات الزحمة',
    'proximity_weight': 'تأثير بُعد الكباتن عن العميل',
    'congestion_weight': 'تأثير زحمة الطريق',
  };
  final help = <String, String>{
    'max_multiplier': '1 يعني السعر عادي، و1.3 يعني زيادة 30%. التغيير على الرحلات الجديدة بس.',
    'pressure_weight': 'كل ما عدد الطلبات يزيد عن الكباتن المتاحين، تأثير الرقم ده بيزيد.',
    'waiting_weight': 'لو العميل مستني كتير ومفيش كابتن قبل، السعر ممكن يتأثر.',
    'peak_weight': 'بيحدد تأثير أوقات الذروة، زي بداية ونهاية مواعيد الشغل.',
    'proximity_weight': 'لما أقرب كابتن يكون بعيد عن مكان العميل.',
    'congestion_weight': 'بيحدد تأثير بطء الطريق على السعر المقترح.',
  };

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await SupabaseService.instance.client
          .from('pricing_engine_rules_v10')
          .select()
          .single();
      if (mounted)
        setState(() {
          enabled = r['enabled'] == true;
          for (final k in labels.keys) {
            final controller = fields[k];
            if (controller == null) {
              fields[k] = TextEditingController(text: '${r[k]}');
            } else {
              controller.text = '${r[k]}';
            }
          }
        });
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر تحميل إعدادات التسعير');
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'السعر وقت الزحمة',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SwitchListTile(
            title: const Text('تشغيل تغيير السعر حسب الزحمة'),
            value: enabled,
            onChanged: busy ? null : (v) => setState(() => enabled = v),
          ),
          for (final k in fields.keys)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: fields[k],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: labels[k],
                  helperText: help[k],
                  helperMaxLines: 3,
                  suffixIcon: Tooltip(
                    message: help[k] ?? '',
                    child: const Icon(Icons.help_outline_rounded, size: 20),
                  ),
                ),
              ),
            ),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    final rules = <String, dynamic>{'enabled': enabled};
                    for (final k in fields.keys) {
                      final n = double.tryParse(fields[k]!.text);
                      if (n == null || !n.isFinite) {
                        setState(() => error = 'راجع الأرقام');
                        return;
                      }
                      rules[k] = n;
                    }
                    setState(() => busy = true);
                    try {
                      await SupabaseService.instance.client.rpc(
                        'admin_save_pricing_rules_v10',
                        params: {'p_rules': rules},
                      );
                      if (mounted)
                        setState(
                          () => error =
                              'اتحفظت الإعدادات. الرحلات الجديدة بس هتستخدمها.',
                        );
                    } catch (_) {
                      if (mounted)
                        setState(
                          () => error = 'القيم خارج النطاق أو تعذر الحفظ.',
                        );
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
            child: const Text('حفظ إعدادات السعر'),
          ),
        ],
      ),
    ),
  );
}
