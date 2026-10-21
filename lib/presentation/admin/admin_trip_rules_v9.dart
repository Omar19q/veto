import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';

class AdminTripRulesV9 extends StatefulWidget {
  const AdminTripRulesV9({super.key});
  @override
  State<AdminTripRulesV9> createState() => _AdminTripRulesV9State();
}

class _AdminTripRulesV9State extends State<AdminTripRulesV9> {
  final _form = GlobalKey<FormState>();
  final _values = List.generate(5, (_) => TextEditingController());
  bool _loading = true, _saving = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await SupabaseService.instance.client
          .from('trip_rules_v9')
          .select()
          .single();
      if (!mounted) return;
      final values = [
        (r['cancellation_grace_seconds'] as num) / 60,
        r['customer_compensation'],
        r['captain_compensation'],
        (r['search_offer_seconds'] as num) / 60,
        r['search_improvement_percent'],
      ];
      for (var i = 0; i < 5; i++) {
        _values[i].text = values[i].toString();
      }
      setState(() => _loading = false);
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _message = 'تعذر تحميل إعدادات الرحلات. تأكد من تطبيق تحديث V9.';
        });
    }
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await SupabaseService.instance.client.rpc(
        'admin_save_trip_rules_v9',
        params: {
          'p_grace': (double.parse(_values[0].text) * 60).round(),
          'p_customer': double.parse(_values[1].text),
          'p_captain': double.parse(_values[2].text),
          'p_offer_seconds': (double.parse(_values[3].text) * 60).round(),
          'p_percent': double.parse(_values[4].text),
        },
      );
      if (mounted)
        setState(
          () => _message =
              'تم الحفظ. مهلة الإلغاء والتعويض يُثبّتان عند قبول كل رحلة جديدة.',
        );
    } catch (_) {
      if (mounted)
        setState(
          () => _message = 'تعذر الحفظ. راجع القيم وصلاحية حساب الإدارة.',
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'قواعد الرحلات والتعويض',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'الإلغاء أثناء البحث مجاني دائمًا. التعويض مستقل عن العمولة، ويُحوّل بالكامل للطرف الآخر بعد المهلة.',
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < 5; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: _values[i],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: [
                            'مهلة الإلغاء بعد القبول (دقائق)',
                            'تعويض الكابتن عند إلغاء العميل (ج)',
                            'تعويض العميل عند إلغاء الكابتن (ج)',
                            'ظهور السعر المقترح بعد البحث (دقائق)',
                            'نسبة تحسين السعر — للإدارة فقط %',
                          ][i],
                        ),
                        validator: (value) {
                          final v = double.tryParse(value ?? '');
                          final max = [
                            1440.0,
                            10000.0,
                            10000.0,
                            60.0,
                            100.0,
                          ][i];
                          final min = i == 3 ? 0.5 : 0.0;
                          return v == null || !v.isFinite || v < min || v > max
                              ? 'اكتب قيمة بين $min و$max'
                              : null;
                        },
                      ),
                    ),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_message!),
                    ),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ قواعد الرحلات'),
                  ),
                ],
              ),
            ),
    ),
  );
}
