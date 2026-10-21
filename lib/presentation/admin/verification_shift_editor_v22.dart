import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Only the owner can edit schedules. The server RPC rechecks ownership.
class VerificationShiftEditorV22 extends StatefulWidget {
  final String staffId;
  final String staffName;
  const VerificationShiftEditorV22({super.key, required this.staffId, required this.staffName});
  @override
  State<VerificationShiftEditorV22> createState() => _VerificationShiftEditorV22State();
}

class _VerificationShiftEditorV22State extends State<VerificationShiftEditorV22> {
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 17, minute: 0);
  Set<int> _days = {1, 2, 3, 4, 5, 6};
  bool _enabled = true;
  bool _busy = false;
  String? _error;
  static const _names = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
  @override
  void initState() { super.initState(); _load(); }

  TimeOfDay _parse(String? text, TimeOfDay fallback) {
    final parts = (text ?? '').split(':');
    if (parts.length < 2) return fallback;
    return TimeOfDay(hour: int.tryParse(parts[0]) ?? fallback.hour,
      minute: int.tryParse(parts[1]) ?? fallback.minute);
  }
  String _dbTime(TimeOfDay value) => '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00';
  String _uiTime(TimeOfDay value) => '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    try {
      final rows = await Supabase.instance.client.from('staff_verification_shifts_v22')
        .select('enabled,start_time,end_time,days_of_week')
        .eq('staff_id', widget.staffId).limit(1);
      if (!mounted || rows.isEmpty) return;
      final row = rows.first;
      setState(() {
        _enabled = row['enabled'] == true;
        _start = _parse(row['start_time']?.toString(), _start);
        _end = _parse(row['end_time']?.toString(), _end);
        _days = Set<int>.from((row['days_of_week'] as List).map((e) => (e as num).toInt()));
      });
    } catch (_) { if (mounted) setState(() => _error = 'لم تتوفر مواعيد سابقة؛ اختر المواعيد واحفظها.'); }
  }
  Future<void> _save() async {
    if (_busy) return;
    if (_days.isEmpty || (_start.hour == _end.hour && _start.minute == _end.minute)) {
      setState(() => _error = 'حدد يوم عمل واحدًا على الأقل ووقت بداية ونهاية مختلفين.'); return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await Supabase.instance.client.rpc('v22_save_verification_shift', params: {
        'p_staff_id': widget.staffId, 'p_enabled': _enabled,
        'p_start': _dbTime(_start), 'p_end': _dbTime(_end),
        'p_days': _days.toList()..sort(),
      });
      if (mounted) Navigator.of(context).pop();
    } catch (_) { if (mounted) setState(() => _error = 'تعذر الحفظ. تأكد من تنفيذ SQL V22 وصلاحية الأونر.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: AlertDialog(
      title: Text('ساعات عمل ${widget.staffName}', style: const TextStyle(fontFamily: 'Cairo')),
      content: SizedBox(width: 440, child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('حدد أيام ووقت عمل الموظف بتوقيت القاهرة. يستطيع الموظف رؤية الوقت المتبقي من ورديته.'),
          SwitchListTile(title: const Text('الوردية مفعلة'), value: _enabled,
            onChanged: (v) => setState(() => _enabled = v)),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(onPressed: () async {
              final v = await showTimePicker(context: context, initialTime: _start);
              if (v != null) setState(() => _start = v);
            }, icon: const Icon(Icons.login_rounded), label: Text('من ${_uiTime(_start)}')),
            OutlinedButton.icon(onPressed: () async {
              final v = await showTimePicker(context: context, initialTime: _end);
              if (v != null) setState(() => _end = v);
            }, icon: const Icon(Icons.logout_rounded), label: Text('إلى ${_uiTime(_end)}')),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 5, children: [
            for (var i = 1; i <= 7; i++) FilterChip(
              label: Text(_names[i - 1]), selected: _days.contains(i),
              onSelected: (v) => setState(() => v ? _days.add(i) : _days.remove(i)),
            ),
          ]),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
      ))),
      actions: [TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'جارٍ الحفظ' : 'حفظ مواعيد العمل'))],
    ),
  );
}
