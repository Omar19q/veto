import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';

/// Informational area-demand alerts ONLY. No trip prices are modified here.
class AdminHotZonesV35 extends StatefulWidget {
  const AdminHotZonesV35({super.key});

  @override
  State<AdminHotZonesV35> createState() => _AdminHotZonesV35State();
}

class _AdminHotZonesV35State extends State<AdminHotZonesV35> {
  final _count = TextEditingController(text: '4');
  final _wait = TextEditingController(text: '60');
  final _duration = TextEditingController(text: '15');
  List<Map<String, dynamic>> _zones = [];
  String? _selected;
  String? _notice;
  bool _loading = false;
  bool _enabled = true;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    _count.dispose(); _wait.dispose(); _duration.dispose();
    super.dispose();
  }

  void _choose(String? id) {
    final matches = _zones.where((z) => z['zone_id']?.toString() == id);
    if (matches.isEmpty) return;
    final row = matches.first;
    setState(() {
      _selected = id;
      _enabled = row['enabled'] == true;
      _count.text = '${row['min_requests'] ?? 4}';
      _wait.text = '${row['wait_seconds'] ?? 60}';
      _duration.text = '${row['show_minutes'] ?? 15}';
      _notice = null;
    });
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() { _loading = true; _notice = null; });
    try {
      final result = await SupabaseService.instance.client.rpc(
        'v35_list_zone_alert_settings',
      ).timeout(const Duration(seconds: 12));
      if (!mounted) return;
      final rows = (result is List ? result : const <dynamic>[])
        .whereType<Map>().map((r) => Map<String, dynamic>.from(r)).toList();
      setState(() { _zones = rows; _loading = false; });
      if (rows.isNotEmpty) _choose(
        rows.any((r) => r['zone_id']?.toString() == _selected)
          ? _selected : rows.first['zone_id']?.toString(),
      );
    } catch (_) {
      if (mounted) setState(() {
        _loading = false;
        _notice = 'إعدادات ضغط الطلبات لسه محتاجة SQL V35 أو صلاحية أدمن.';
      });
    }
  }

  Future<void> _save() async {
    final requests = int.tryParse(_count.text.trim());
    final seconds = int.tryParse(_wait.text.trim());
    final minutes = int.tryParse(_duration.text.trim());
    if (_selected == null || requests == null || seconds == null || minutes == null ||
        requests < 2 || requests > 100 || seconds < 30 || seconds > 600 ||
        minutes < 1 || minutes > 60) {
      setState(() => _notice = 'راجع الأرقام: الطلبات 2–100، الانتظار 30–600 ثانية، الظهور 1–60 دقيقة.');
      return;
    }
    setState(() { _loading = true; _notice = null; });
    try {
      await SupabaseService.instance.client.rpc('v35_save_zone_alert_settings',
        params: {
          'p_zone_id': _selected,
          'p_enabled': _enabled,
          'p_min_requests': requests,
          'p_wait_seconds': seconds,
          'p_show_minutes': minutes,
        },
      );
      if (!mounted) return;
      setState(() { _loading = false; _notice = 'اتحفظت إعدادات المنطقة. الأسعار مش هتتغير.'; });
      for (final zone in _zones) {
        if (zone['zone_id']?.toString() == _selected) {
          zone.addAll({'enabled': _enabled, 'min_requests': requests,
            'wait_seconds': seconds, 'show_minutes': minutes});
          break;
        }
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _notice = 'تعذر الحفظ. راجع صلاحياتك واتصال الإنترنت.'; });
    }
  }

  Widget _number(String title, String hint, TextEditingController controller) =>
    Padding(padding: const EdgeInsets.only(bottom: 12),
      child: TextField(controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: title, helperText: hint,
          helperMaxLines: 2, border: const OutlineInputBorder()),
      ),
    );

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('أماكن عليها طلبات كتير',
          style: TextStyle(fontFamily: 'Cairo', fontSize: 18,
            fontWeight: FontWeight.w900)),
        const Text('تنبيه للكابتن بس، مش زيادة في سعر المشوار.',
          style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
        const SizedBox(height: 12),
        if (_zones.isNotEmpty) DropdownButtonFormField<String>(
          initialValue: _selected,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'اختار المنطقة',
            border: OutlineInputBorder()),
          items: _zones.map((r) => DropdownMenuItem(
            value: r['zone_id']?.toString(),
            child: Text('${r['zone_name']}', overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: _loading ? null : _choose,
        ),
        if (_zones.isNotEmpty) ...[
          SwitchListTile(title: const Text('إظهار تنبيه الزحمة للكباتن'),
            subtitle: const Text('التنبيه بيختفي لو مدته خلصت'),
            value: _enabled,
            onChanged: _loading ? null : (v) => setState(() => _enabled = v)),
          _number('كام طلب منتظر؟', 'مثال: 4 طلبات أو أكتر', _count),
          _number('مستنيين بقالهم كام ثانية؟', 'مثال: 60 ثانية', _wait),
          _number('التنبيه يفضل ظاهر كام دقيقة؟', 'مثال: 15 دقيقة', _duration),
          FilledButton.icon(onPressed: _loading ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('حفظ تنبيه المنطقة')),
        ],
        if (_loading) const LinearProgressIndicator(),
        if (_notice != null) Padding(padding: const EdgeInsets.only(top: 10),
          child: Text(_notice!, style: const TextStyle(fontFamily: 'Cairo'))),
        TextButton.icon(onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh), label: const Text('تحديث المناطق')),
      ])),
  );
}
