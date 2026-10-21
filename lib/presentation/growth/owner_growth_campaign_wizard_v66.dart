import 'package:flutter/material.dart';
import '../../services/growth_service.dart';

/// V66: An owner-friendly front end to the existing permission-checked RPCs.
/// Creating a campaign never switches it on or credits anybody automatically.
class OwnerGrowthCampaignWizardV66 extends StatefulWidget {
  const OwnerGrowthCampaignWizardV66({super.key});

  @override
  State<OwnerGrowthCampaignWizardV66> createState() =>
      _OwnerGrowthCampaignWizardV66State();
}

class _OwnerGrowthCampaignWizardV66State
    extends State<OwnerGrowthCampaignWizardV66> {
  final _form = GlobalKey<FormState>();
  final _service = GrowthService();
  final _title = TextEditingController(text: 'هدية أول مشوار من فيتو ثانية');
  final _budget = TextEditingController();
  final _cap = TextEditingController();
  final _discounts = [
    TextEditingController(text: '50'),
    TextEditingController(text: '35'),
    TextEditingController(text: '15'),
  ];
  final _captainRewards = [
    TextEditingController(text: '25'),
    TextEditingController(text: '25'),
    TextEditingController(text: '15'),
  ];
  final _services = <String>{'car_ride', 'motorcycle_ride'};
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _budget.dispose();
    _cap.dispose();
    for (final c in [..._discounts, ..._captainRewards]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _moneyValidator(String? raw, {required double max, bool zero = false}) {
    final value = double.tryParse(raw?.trim() ?? '');
    if (value == null || !value.isFinite || value > max ||
        value < (zero ? 0 : 0.01)) {
      return 'اكتب رقم صحيح من ${zero ? 0 : '0.01'} لحد $max';
    }
    if (((value * 100) - (value * 100).round()).abs() > 0.000001) {
      return 'مسموح برقمين فقط بعد العلامة العشرية';
    }
    return null;
  }

  Widget _numberField(TextEditingController controller, String label,
      {required double max, bool zero = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) => _moneyValidator(value, max: max, zero: zero),
    );
  }

  Future<void> _selectEnd() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _endDate,
      helpText: 'اختار آخر يوم في العرض',
    );
    if (!mounted || selected == null) return;
    setState(() => _endDate = selected);
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (_services.isEmpty) {
      setState(() => _error = 'اختار خدمة واحدة على الأقل.');
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('تأكيد إنشاء العرض'),
        content: const Text('هنحفظ الحملة كمسودة متوقفة. مش هيتم احتساب خصم أو مكافأة لأي عميل بمجرد الحفظ. التفعيل من لوحة الإدارة بعد مراجعة الميزانية والشروط.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false),
              child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(c, true),
              child: const Text('حفظ مسودة العرض')),
        ],
      ),
    );
    if (!mounted || approved != true) return;
    setState(() { _saving = true; _error = null; });
    String? newId;
    try {
      final starts = DateTime.now();
      final ends = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
      if (!ends.isAfter(starts)) throw StateError('date_expired');
      final created = await _service.execute('growth_admin_campaign_v1', {
        'p_title': _title.text.trim(),
        'p_budget': double.parse(_budget.text.trim()),
        'p_cap': double.parse(_cap.text.trim()),
        'p_starts': starts.toUtc().toIso8601String(),
        'p_ends': ends.toUtc().toIso8601String(),
        'p_services': _services.toList(),
        'p_active': false,
      });
      if (created is! String || created.isEmpty) {
        throw StateError('invalid_campaign_id');
      }
      newId = created;
      await _service.execute('growth_admin_campaign_policy_v1', {
        'p_id': created,
        'p_policy': {
          'discounts': _discounts.map((c) => double.parse(c.text.trim())).toList(),
          'captain_rewards': _captainRewards.map((c) => double.parse(c.text.trim())).toList(),
        },
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم حفظ الحملة كمسودة متوقفة. راجعها واعتمدها من إدارة الدعوات والعروض.'),
      ));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = newId == null
        ? 'ما قدرناش ننشئ الحملة. راجع صلاحياتك وميزانيتك والاتصال.'
        : 'اتحفظت مسودة رقم $newId، لكن تفاصيل الخصم ما اتحفظتش. راجع المسودة في الإدارة، وما تفعّلهاش قبل تصحيح الشروط.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('عرض جديد لعملاء فيتو ثانية')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text('خلّي أول مشوار أحلى 🎁',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('حدد الميزانية ونسب الخصم قبل التشغيل. الكود يُقبل مرة واحدة للحساب المؤهل، والصرف الفعلي بعد شروط الرحلة على الخادم.'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _title,
              maxLength: 150,
              decoration: const InputDecoration(
                labelText: 'اسم الحملة', border: OutlineInputBorder()),
              validator: (s) => (s?.trim().isEmpty ?? true) ? 'اكتب اسم الحملة' : null,
            ),
            const SizedBox(height: 12),
            _numberField(_budget, 'إجمالي ميزانية العرض بالجنيه', max: 100000000),
            const SizedBox(height: 12),
            _numberField(_cap, 'أقصى خصم على المشوار الواحد بالجنيه', max: 100000),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _saving ? null : _selectEnd,
              icon: const Icon(Icons.calendar_month),
              label: Text('آخر يوم للعرض: ${_endDate.day}/${_endDate.month}/${_endDate.year}'),
            ),
            const Divider(height: 30),
            const Text('خصومات الرحلات المؤهلة (%)',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (var i = 0; i < 3; i++) ...[
              _numberField(_discounts[i], 'خصم الرحلة رقم ${i + 1} (%)', max: 100, zero: true),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 6),
            const Text('مكافآت الكابتن المؤهلة بالجنيه',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (var i = 0; i < 3; i++) ...[
              _numberField(_captainRewards[i], 'مكافأة الرحلة رقم ${i + 1} (جنيه)', max: 1000, zero: true),
              const SizedBox(height: 12),
            ],
            const Text('الخدمات اللي ينطبق عليها العرض',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            CheckboxListTile(
              title: const Text('فيتو كار'),
              value: _services.contains('car_ride'),
              onChanged: _saving ? null : (v) => setState(() {
                if (v == true) { _services.add('car_ride'); }
                else { _services.remove('car_ride'); }
              }),
            ),
            CheckboxListTile(
              title: const Text('فيتو موتوسيكل'),
              value: _services.contains('motorcycle_ride'),
              onChanged: _saving ? null : (v) => setState(() {
                if (v == true) { _services.add('motorcycle_ride'); }
                else { _services.remove('motorcycle_ride'); }
              }),
            ),
            CheckboxListTile(
              title: const Text('فيتو طرود'),
              value: _services.contains('package'),
              onChanged: _saving ? null : (v) => setState(() {
                if (v == true) { _services.add('package'); }
                else { _services.remove('package'); }
              }),
            ),
            const SizedBox(height: 8),
            const Text('ملحوظة: مكافأة دعوة الصديق منفصلة عن مكافآت الكابتن، وتخضع لسياسة الخادم. إنشاء الحملة لا يفتح صفر العمولة ولا يغيّر محافظ قديمة.'),
            if (_error != null) Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving ? const SizedBox(height: 16, width: 16,
                child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
              label: const Text('احفظ الحملة كمسودة'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}
