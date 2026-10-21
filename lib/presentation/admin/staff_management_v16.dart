import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/staff_access_v16.dart';
import '../../services/growth_service.dart';
import 'verification_shift_editor_v22.dart';

class StaffManagementV16 extends StatefulWidget {
  const StaffManagementV16({super.key});
  @override
  State<StaffManagementV16> createState() => _StaffManagementV16State();
}

class _StaffManagementV16State extends State<StaffManagementV16> {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _audit = [];
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final access = await StaffAccessV16.load();
      if (!access.owner) throw StateError('owner_required');
      final rows = await _db
          .from('staff_v16')
          .select()
          .order('created_at', ascending: false);
      final audit = await _db
          .from('staff_audit_v16')
          .select()
          .order('id', ascending: false)
          .limit(50);
      if (mounted)
        setState(() {
          _rows = rows;
          _audit = audit;
          _error = null;
        });
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'تعذر تحميل الفريق. هذه اللوحة متاحة للأونر فقط.',
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? row]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _StaffEditorV16(row: row),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'إدارة الفريق',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              FilledButton.icon(
                onPressed: _error == null ? () => _edit() : null,
                icon: const Icon(Icons.person_add_alt),
                label: const Text('إضافة موظف'),
              ),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
        if (_error != null)
          Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'الأونر مستمد من صلاحية الإدارة الحالية على السيرفر. اسم الوظيفة لا يمنح صلاحيات تلقائيًا.',
                    ),
                    const SizedBox(height: 12),
                    for (final row in _rows)
                      Card(
                        child: ListTile(
                          isThreeLine: true,
                          leading: Icon(
                            row['active'] == true
                                ? Icons.verified_user_outlined
                                : Icons.person_off,
                          ),
                          title: Text('${row['name']} • ${row['role']}'),
                          subtitle: Text(
                            '${row['phone']}\n${row['active'] == true ? 'نشط' : 'موقوف'} • آخر دخول: ${row['last_login_at'] ?? 'لم يدخل بعد'}',
                          ),
                          trailing: Wrap(
                            children: [
                              if (row['role'] == 'Verification Moderator')
                                IconButton(
                                  tooltip: 'تحديد مواعيد عمل موظف التحقق',
                                  icon: const Icon(Icons.schedule_rounded),
                                  onPressed: () => showDialog<void>(
                                    context: context,
                                    builder: (_) => VerificationShiftEditorV22(
                                      staffId: row['id'].toString(),
                                      staffName: row['name']?.toString() ?? 'الموظف',
                                    ),
                                  ),
                                ),
                              IconButton(
                                tooltip: 'تعديل الصلاحيات والحالة',
                                onPressed: () => _edit(row),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    const Text(
                      'آخر 50 إجراء',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    for (final item in _audit)
                      ListTile(
                        title: Text('${item['action']}'),
                        subtitle: Text(
                          '${item['created_at']}\n${item['detail']}',
                        ),
                      ),
                  ],
                ),
        ),
      ],
    ),
  );
}

class _StaffEditorV16 extends StatefulWidget {
  final Map<String, dynamic>? row;
  const _StaffEditorV16({this.row});
  @override
  State<_StaffEditorV16> createState() => _StaffEditorV16State();
}

class _StaffEditorV16State extends State<_StaffEditorV16> {
  late final TextEditingController _name = TextEditingController(
    text: widget.row?['name'],
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.row?['phone'],
  );
  late String _role = widget.row?['role'] ?? 'Read-only';
  // Verification staff is deliberately limited, including when editing old
  // V16 records that were issued broader Captain/Chat permissions.
  late Set<String> _permissions = widget.row == null || _role == 'Verification Moderator'
      ? StaffAccessV16.preset(_role)
      : Set<String>.from(widget.row!['permissions']);
  late bool _active = widget.row?['active'] ?? true;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_name.text.trim().length < 2 ||
        !RegExp(r'^01[0125]\d{8}$').hasMatch(_phone.text.trim())) {
      setState(() => _error = 'أدخل الاسم ورقم هاتف مصري صحيح.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.rpc(
        _role == 'Verification Moderator' ? 'v21_staff_verification_save' : 'v16_staff_save',
        params: {
          'p_id': widget.row?['id'],
          'p_name': _name.text.trim(),
          'p_phone': _phone.text.trim(),
          'p_role': _role,
          'p_permissions': (_role == 'Verification Moderator'
              ? StaffAccessV16.preset(_role) : _permissions).toList(),
          'p_active': _active,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        setState(
          () => _error = e.toString().contains('phone_role_conflict')
              ? 'الحساب مرتبط بهوية مختلفة. اطلب من الإدارة مراجعة ربط الحساب قبل الإضافة.'
              : 'تعذر الحفظ. تحقق من اتصالك وصلاحيات الأونر وعدم تكرار الرقم.',
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: AlertDialog(
      title: Text(widget.row == null ? 'إضافة موظف' : 'تعديل الموظف'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'اسم الموظف'),
              ),
              TextField(
                controller: _phone,
                enabled: widget.row == null,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم هاتف الموظف — ممكن يكون حساب عميل أو كابتن لموظف التحقق',
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: _role,
                items: StaffAccessV16.roles
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: _saving
                    ? null
                    : (v) => setState(() {
                        _role = v!;
                        _permissions = StaffAccessV16.preset(v);
                      }),
                decoration: const InputDecoration(labelText: 'الوظيفة'),
              ),
              SwitchListTile(
                value: _active,
                onChanged: _saving ? null : (v) => setState(() => _active = v),
                title: const Text('حساب نشط'),
              ),
              const Text('عرض وتنفيذ مستقلان؛ إدارة الموظفين للأونر فقط.'),
              for (final item in StaffAccessV16.resources.entries.where(
                (e) => e.key != 'staff',
              ))
                Row(
                  children: [
                    Expanded(child: Text(item.value)),
                    const Text('عرض'),
                    Checkbox(
                      value: _permissions.contains('${item.key}.view'),
                      onChanged: _saving
                          ? null
                          : (v) => setState(() {
                              v == true
                                  ? _permissions.add('${item.key}.view')
                                  : _permissions.remove('${item.key}.view');
                            }),
                    ),
                    const Text('تنفيذ'),
                    Checkbox(
                      value: _permissions.contains('${item.key}.manage'),
                      onChanged: _saving
                          ? null
                          : (v) => setState(() {
                              v == true
                                  ? _permissions.add('${item.key}.manage')
                                  : _permissions.remove('${item.key}.manage');
                            }),
                    ),
                  ],
                ),
              if (GrowthService.buildEnabled && _role != 'Verification Moderator')
                for (final item in StaffAccessV16.growthPermissions.entries)
                  CheckboxListTile(
                    title: Text(item.value),
                    subtitle: const Text('اختيار صريح مستقل؛ لا يمنح تلقائيًا مع الدور'),
                    value: _permissions.contains(item.key),
                    onChanged: _saving ? null : (v) => setState(() {
                      if (v == true) { _permissions.add(item.key); }
                      else { _permissions.remove(item.key); }
                    }),
                  ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ الصلاحيات'),
        ),
      ],
    ),
  );
}
