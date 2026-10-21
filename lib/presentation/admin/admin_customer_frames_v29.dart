import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../widgets/customer_identity_v29.dart';

/// Owner-only frame/loyalty controls. Every mutation is authenticated by
/// owner_save_customer_frame_v29 on the server, with an audit record.
class AdminCustomerFramesV29 extends StatefulWidget {
  const AdminCustomerFramesV29({super.key});
  @override
  State<AdminCustomerFramesV29> createState() => _AdminCustomerFramesV29State();
}

class _AdminCustomerFramesV29State extends State<AdminCustomerFramesV29> {
  List<Map<String, dynamic>> _frames = [];
  bool _busy = false;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final result = await SupabaseService.instance.client.rpc(
        'owner_list_customer_frames_v29',
      ).timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() => _frames = (result as List)
        .whereType<Map>().map((r) => Map<String, dynamic>.from(r)).toList());
    } catch (_) {
      if (mounted) setState(() => _error =
        'تعذر تحميل الرتب. تأكد من SQL V29 وصلاحية الأونر.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? initial]) async {
    final key = TextEditingController(text: initial?['frame_key']?.toString() ?? '');
    final title = TextEditingController(text: initial?['title']?.toString() ?? '');
    final required = TextEditingController(text: '${initial?['min_trips'] ?? 0}');
    final accent = TextEditingController(text: initial?['accent_hex']?.toString() ?? '#EFC043');
    final order = TextEditingController(text: '${initial?['sort_order'] ?? 0}');
    var glyph = initial?['glyph']?.toString() ?? 'star';
    var enabled = initial?['is_enabled'] != false;
    var saving = false;
    final wasExisting = initial != null;
    try {
      await showModalBottomSheet<void>(
        context: context, isScrollControlled: true, useSafeArea: true,
        backgroundColor: const Color(0xFF151C30),
        builder: (sheetContext) => StatefulBuilder(builder: (context, update) {
          Future<void> save() async {
            if (saving) return;
            final minTrips = int.tryParse(required.text.trim());
            final sort = int.tryParse(order.text.trim());
            final code = accent.text.trim().toUpperCase();
            if (!RegExp(r'^[a-z0-9_]{2,32}$').hasMatch(key.text.trim()) ||
              title.text.trim().length < 2 || minTrips == null ||
              minTrips < 0 || minTrips > 100000 || sort == null ||
              !RegExp(r'^#[0-9A-F]{6}$').hasMatch(code)) {
              ScaffoldMessenger.of(sheetContext).showSnackBar(
                const SnackBar(content: Text('راجع الاسم والكود واللون وعدد الرحلات.')));
              return;
            }
            update(() => saving = true);
            try {
              await SupabaseService.instance.client.rpc(
                'owner_save_customer_frame_v29', params: {
                  'p_key': key.text.trim(), 'p_title': title.text.trim(),
                  'p_min_trips': minTrips, 'p_accent': code,
                  'p_glyph': glyph, 'p_enabled': enabled, 'p_sort_order': sort,
                },
              ).timeout(const Duration(seconds: 15));
              if (sheetContext.mounted) Navigator.pop(sheetContext);
              await _load();
            } catch (_) {
              if (sheetContext.mounted) ScaffoldMessenger.of(sheetContext)
                .showSnackBar(const SnackBar(content:
                  Text('لم يتم الحفظ. راجع صلاحية الأونر أو قيود السيرفر.')));
            } finally { if (sheetContext.mounted) update(() => saving = false); }
          }

          Widget field(TextEditingController c, String label,
              {TextInputType type = TextInputType.text, bool readOnly = false}) =>
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(
              controller: c, readOnly: readOnly, keyboardType: type,
              style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'),
              decoration: InputDecoration(labelText: label,
                labelStyle: const TextStyle(color: Colors.white70, fontFamily: 'Cairo'),
                filled: true, fillColor: const Color(0xFF222D47),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ));
          return Directionality(textDirection: TextDirection.rtl,
            child: Padding(padding: EdgeInsets.fromLTRB(18, 18, 18,
              24 + MediaQuery.viewInsetsOf(context).bottom),
              child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(wasExisting ? 'تعديل الإطار' : 'إطار جديد',
                    style: const TextStyle(fontFamily:'Cairo', fontSize:20,
                      fontWeight:FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 18),
                  field(key, 'كود الإطار بالإنجليزية', readOnly: wasExisting),
                  field(title, 'اسم الإطار المعروض'),
                  field(required, 'عدد الرحلات المطلوبة',type: TextInputType.number),
                  field(accent, 'لون الإطار #RRGGBB'),
                  field(order, 'ترتيب العرض',type: TextInputType.number),
                  DropdownButtonFormField<String>(value: glyph,
                    dropdownColor: const Color(0xFF202940),
                    style: const TextStyle(color: Colors.white, fontFamily:'Cairo'),
                    decoration: const InputDecoration(labelText: 'شكل الشارة',
                      labelStyle: TextStyle(color: Colors.white70)),
                    items: const [
                      DropdownMenuItem(value:'star',child:Text('نجمة')),
                      DropdownMenuItem(value:'shield',child:Text('درع')),
                      DropdownMenuItem(value:'crown',child:Text('تاج')),
                      DropdownMenuItem(value:'diamond',child:Text('ماسة')),
                      DropdownMenuItem(value:'sparkles',child:Text('بريق')),
                    ], onChanged: saving ? null : (v) {
                      if (v != null) update(() => glyph = v);
                    }),
                  SwitchListTile.adaptive(title: const Text('الإطار متاح',
                      style: TextStyle(color: Colors.white, fontFamily:'Cairo')),
                    value: enabled, onChanged: saving ? null : (v) => update(() => enabled = v)),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: saving ? null : save,
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFC440),
                      foregroundColor: Colors.black, minimumSize: const Size(0, 52)),
                    child: Text(saving ? 'جارٍ الحفظ...' : 'حفظ الإطار',
                      style: const TextStyle(fontFamily:'Cairo', fontWeight: FontWeight.w900))),
                ]))));
        }));
    } finally { key.dispose(); title.dispose(); required.dispose(); accent.dispose(); order.dispose(); }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Container(color: const Color(0xFF0B1122), child: Column(children: [
      Padding(padding: const EdgeInsets.all(14), child: Row(children: [
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text('إطارات ورتب العملاء',style: TextStyle(fontFamily:'Cairo',
            color: Colors.white,fontSize: 20,fontWeight:FontWeight.w900)),
            Text('الإطارات تُفتح تلقائيًا بعد الرحلات المكتملة فقط',
            style: TextStyle(color:Colors.white60,fontSize:11,fontFamily:'Cairo'))])),
        IconButton(onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh,color: Colors.amber)),
        IconButton(onPressed: _busy ? null : () => _edit(),
          icon: const Icon(Icons.add_circle,color: Colors.amber)),
      ])),
      if (_error != null) Padding(padding: const EdgeInsets.all(8),
        child: Text(_error!, style: const TextStyle(color: Colors.amber))),
      Expanded(child: _busy && _frames.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(itemCount: _frames.length,
          itemBuilder:(context,i) {
            final row=_frames[i];
            final accent=CustomerFrameAvatarV29.parseColor(row['accent_hex']?.toString());
            return Card(color: const Color(0xFF172039), margin: const EdgeInsets.all(7),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: accent.withValues(alpha:.2),
                  child: Icon(CustomerFrameAvatarV29.iconFor(row['glyph']?.toString()),color: accent)),
                title: Text(row['title']?.toString() ?? '',
                  style: const TextStyle(color: Colors.white,fontFamily:'Cairo')),
                subtitle: Text('بعد ${row['min_trips']} رحلة • ${row['is_enabled']==true ? 'مفعل' : 'موقوف'}',
                  style: const TextStyle(color: Colors.white60,fontFamily:'Cairo')),
                trailing: const Icon(Icons.edit_outlined,color: Colors.amber),
                onTap: _busy ? null : () => _edit(row),
              ));
          }))
    ])),
  );
}
