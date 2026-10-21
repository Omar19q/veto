import 'package:flutter/material.dart';
import '../../services/ride_categories.dart';
import '../../widgets/ride_category_card.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});
  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  late Future<Map<String, dynamic>> _data;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _data = RideCategories.instance.admin();
  }

  Future<void> _save(String type, Map<String, dynamic> row) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await RideCategories.instance.save(type, row);
      if (mounted) setState(_reload);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              categoryCopy(
                context,
                'تعذر الحفظ. راجع القيم والصلاحيات.',
                'Unable to save. Check values and permissions.',
              ),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editCategory(Map<String, dynamic> row) async {
    final keys = [
      'name_ar',
      'name_en',
      'description_ar',
      'description_en',
      'sort_order',
      'accent',
    ];
    final labels = [
      categoryCopy(context, 'الاسم العربي', 'Arabic name'),
      'English name',
      categoryCopy(context, 'الوصف العربي', 'Arabic description'),
      'English description',
      categoryCopy(context, 'ترتيب العرض', 'Display order'),
      categoryCopy(context, 'اللون #RRGGBB', 'Accent #RRGGBB'),
    ];
    final controls = {
      for (final k in keys) k: TextEditingController(text: '${row[k] ?? ''}'),
    };
    var inherit = row['inherit_lower'] == true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => _DialogInputScope(
          controllers: controls.values.toList(),
          child: AlertDialog(
            title: Text(
              categoryCopy(context, 'بيانات الفئة', 'Category details'),
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < keys.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextField(
                          controller: controls[keys[i]],
                          decoration: InputDecoration(labelText: labels[i]),
                        ),
                      ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        categoryCopy(
                          context,
                          'السماح للفئات الأعلى باستقبال الفئة',
                          'Allow higher tiers to receive this category',
                        ),
                      ),
                      value: inherit,
                      onChanged: (v) => setState(() => inherit = v),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(categoryCopy(context, 'رجوع', 'Back')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(categoryCopy(context, 'حفظ', 'Save')),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      await _save('category', {
        ...row,
        for (final k in keys)
          k: k == 'sort_order'
              ? int.tryParse(controls[k]!.text)
              : controls[k]!.text.trim(),
        'inherit_lower': inherit,
      });
    }
  }

  Future<void> _editPrice(
    RideCategory c,
    List<dynamic> prices,
    List<dynamic> zones,
  ) async {
    final row = prices
        .whereType<Map>()
        .where((p) => p['category_id'] == c.id && p['zone_id'] == null)
        .firstOrNull;
    final keys = ['opening', 'per_km', 'minimum', 'waiting', 'free_wait'];
    final labels = [
      categoryCopy(context, 'فتح العداد', 'Starting fare'),
      categoryCopy(context, 'سعر الكيلومتر', 'Per km'),
      categoryCopy(context, 'الحد الأدنى', 'Minimum fare'),
      categoryCopy(context, 'دقيقة الانتظار', 'Waiting per minute'),
      categoryCopy(context, 'دقائق الانتظار المجانية', 'Free waiting minutes'),
    ];
    final fields = {
      for (final k in keys)
        k: TextEditingController(text: row?[k]?.toString() ?? ''),
    };
    String? zoneId;
    String? validation;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => _DialogInputScope(
          controllers: fields.values.toList(),
          child: AlertDialog(
            title: Text(c.name(context)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    categoryCopy(
                      context,
                      'EGP — الأسعار الجديدة للطلبات الجديدة فقط.',
                      'EGP — new prices apply to new quotes only.',
                    ),
                  ),
                  for (var i = 0; i < keys.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: TextField(
                        controller: fields[keys[i]],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(labelText: labels[i]),
                      ),
                    ),
                  DropdownButtonFormField<String>(
                    initialValue: 'default',
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: categoryCopy(context, 'المنطقة', 'Zone'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'default',
                        child: Text(
                          categoryCopy(context, 'السعر العام', 'Default price'),
                        ),
                      ),
                      for (final zone in zones.whereType<Map>())
                        DropdownMenuItem(
                          value: '${zone['id']}',
                          child: Text(
                            '${zone['name']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      zoneId = value == 'default' ? null : value;
                      final selected = prices
                          .whereType<Map>()
                          .where(
                            (p) =>
                                p['category_id'] == c.id &&
                                p['zone_id'] == zoneId,
                          )
                          .firstOrNull;
                      for (final k in keys)
                        fields[k]!.text = selected?[k]?.toString() ?? '';
                    },
                  ),
                  if (validation != null)
                    Text(
                      validation!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(categoryCopy(context, 'رجوع', 'Back')),
              ),
              FilledButton(
                onPressed: () {
                  final valid = keys.every((k) {
                    final v = parseCategoryNumber(fields[k]!.text);
                    return v != null &&
                        v.isFinite &&
                        v >= 0 &&
                        (k != 'per_km' || v > 0) &&
                        (k != 'free_wait' || v <= 60 && v == v.round());
                  });
                  if (!valid) {
                    setState(
                      () => validation = categoryCopy(
                        context,
                        'أدخل أرقام صحيحة غير سالبة.',
                        'Enter valid nonnegative numbers.',
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context, true);
                },
                child: Text(categoryCopy(context, 'حفظ السعر', 'Save price')),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true)
      await _save('price', {
        'category_id': c.id,
        'zone_id': zoneId,
        for (final k in keys) k: parseCategoryNumber(fields[k]!.text)!,
        'enabled': true,
      });
  }

  Future<void> _approve(
    Map<String, dynamic> captain,
    Map<String, dynamic>? old,
    List<RideCategory> categories,
  ) async {
    var rank = (old?['highest_tier'] as num?)?.toInt() ?? 0;
    final toggles = {
      for (final k in [
        'documents_approved',
        'insurance_approved',
        'female_verified',
        'ladies_approved',
        'child_seat_approved',
      ])
        k: old?[k] == true,
    };
    final blocked = Set<String>.from(old?['blocked'] ?? []),
        allowed = Set<String>.from(old?['allowed'] ?? []);
    final reason = TextEditingController(
      text: old?['reason']?.toString() ?? '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => _DialogInputScope(
          controllers: [reason],
          child: AlertDialog(
            title: Text('${captain['name']}'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      categoryCopy(
                        context,
                        'راجع الهوية والعربية والمستندات والتأمين قبل الموافقة.',
                        'Review identity, vehicle, documents and insurance before approval.',
                      ),
                    ),
                    DropdownButtonFormField<int>(
                      initialValue: rank,
                      decoration: InputDecoration(
                        labelText: categoryCopy(
                          context,
                          'أعلى فئة عربية معتمدة',
                          'Highest approved car tier',
                        ),
                      ),
                      items: [
                        for (var i = 0; i <= 3; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text(
                              ['—', 'Economy', 'Comfort', 'Premium'][i],
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => rank = v ?? 0),
                    ),
                    for (final k in toggles.keys)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          {
                            'documents_approved': 'المستندات / Documents',
                            'insurance_approved': 'التأمين / Insurance',
                            'female_verified':
                                'تم التحقق من السائقة / Woman driver verified',
                            'ladies_approved':
                                'موافقة السيدات / Ladies approval',
                            'child_seat_approved':
                                'كرسي طفل معتمد / Approved child seat',
                          }[k]!,
                        ),
                        value: toggles[k],
                        onChanged: (v) =>
                            setState(() => toggles[k] = v == true),
                      ),
                    for (final c in categories)
                      Column(
                        children: [
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${c.name(context)} — ${categoryCopy(context, 'استثناء مسموح', 'Allowed exception')}',
                            ),
                            value: allowed.contains(c.id),
                            onChanged: (v) => setState(
                              () => v == true
                                  ? allowed.add(c.id)
                                  : allowed.remove(c.id),
                            ),
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${c.name(context)} — ${categoryCopy(context, 'منع', 'Block')}',
                            ),
                            value: blocked.contains(c.id),
                            onChanged: (v) => setState(
                              () => v == true
                                  ? blocked.add(c.id)
                                  : blocked.remove(c.id),
                            ),
                          ),
                        ],
                      ),
                    TextField(
                      controller: reason,
                      minLines: 2,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: categoryCopy(
                          context,
                          'سبب القرار (مطلوب)',
                          'Decision reason (required)',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(categoryCopy(context, 'رجوع', 'Back')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  categoryCopy(context, 'حفظ المراجعة', 'Save review'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true)
      await _save('approval', {
        'captain_id': captain['id'],
        'highest_tier': rank,
        ...toggles,
        'allowed': allowed.toList(),
        'blocked': blocked.toList(),
        'reason': reason.text.trim(),
      });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        categoryCopy(context, 'إدارة فئات الرحلات', 'Ride category control'),
      ),
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _data,
      builder: (context, s) {
        if (s.hasError)
          return Center(
            child: FilledButton(
              onPressed: () => setState(_reload),
              child: Text(
                categoryCopy(
                  context,
                  'تعذر التحميل — إعادة المحاولة',
                  'Unable to load — retry',
                ),
              ),
            ),
          );
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final data = s.data!,
            categories = (data['categories'] as List)
                .map((r) => RideCategory(Map<String, dynamic>.from(r)))
                .toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_saving) const LinearProgressIndicator(),
            for (final c in categories)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      RideCategoryCard(
                        category: c,
                        status: c.id == 'veto_market'
                            ? categoryCopy(
                                context,
                                'تدار الطلبات والأسعار من إعدادات فيتو ماركت',
                                'Orders and pricing use the existing Market settings',
                              )
                            : c.enabled
                            ? categoryCopy(
                                context,
                                'استقبال الطلبات مفعّل',
                                'New requests enabled',
                              )
                            : categoryCopy(
                                context,
                                'استقبال الطلبات متوقف',
                                'New requests paused',
                              ),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: _saving
                                ? null
                                : () => _editCategory(c.row),
                            child: Text(
                              categoryCopy(context, 'بيانات الفئة', 'Details'),
                            ),
                          ),
                          if (c.id != 'veto_market')
                            TextButton(
                              onPressed: _saving
                                  ? null
                                  : () => _editPrice(
                                      c,
                                      data['prices'] as List,
                                      data['zones'] as List? ?? [],
                                    ),
                              child: Text(
                                categoryCopy(
                                  context,
                                  'الأسعار والمناطق',
                                  'Prices and zones',
                                ),
                              ),
                            ),
                          if (c.id != 'veto_market')
                            TextButton(
                              onPressed: _saving
                                  ? null
                                  : () => _save('category', {
                                      ...c.row,
                                      'enabled': !c.enabled,
                                    }),
                              child: Text(
                                categoryCopy(
                                  context,
                                  c.enabled ? 'إيقاف الطلبات' : 'تفعيل الطلبات',
                                  c.enabled
                                      ? 'Pause requests'
                                      : 'Enable requests',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ExpansionTile(
              title: Text(
                categoryCopy(
                  context,
                  'مراجعة أهلية الكباتن',
                  'Captain eligibility',
                ),
              ),
              children: [
                for (final cap in (data['captains'] as List).whereType<Map>())
                  ListTile(
                    title: Text('${cap['name']}'),
                    subtitle: Text('${cap['vehicle']}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _saving
                        ? null
                        : () => _approve(
                            Map<String, dynamic>.from(cap),
                            (data['approvals'] as List)
                                .whereType<Map>()
                                .where((a) => a['captain_id'] == cap['id'])
                                .map((a) => Map<String, dynamic>.from(a))
                                .firstOrNull,
                            categories,
                          ),
                  ),
              ],
            ),
            ExpansionTile(
              title: Text(categoryCopy(context, 'وعد المشوار', 'Trip Promise')),
              children: [
                for (final p in (data['promises'] as List).whereType<Map>())
                  SwitchListTile(
                    title: Text(
                      '${p[categoryArabic(context) ? 'name_ar' : 'name_en']}',
                    ),
                    value: p['enabled'] == true,
                    onChanged: _saving
                        ? null
                        : (v) =>
                              _save('promise', {'id': p['id'], 'enabled': v}),
                  ),
              ],
            ),
            ExpansionTile(
              title: Text(
                categoryCopy(
                  context,
                  'آخر تغييرات الأسعار والصلاحيات',
                  'Recent price and authorization changes',
                ),
              ),
              children: [
                for (final a in (data['audit'] as List).whereType<Map>())
                  ListTile(
                    title: Text('${a['entity']}'),
                    subtitle: Text('${a['created_at']}\n${a['actor'] ?? ''}'),
                    onTap: () => showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('${a['entity']}'),
                        content: SingleChildScrollView(
                          child: SelectableText(
                            '${a['old_value']}\n→\n${a['new_value']}',
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

/// Controllers belong to the dialog route and survive its closing animation.
class _DialogInputScope extends StatefulWidget {
  const _DialogInputScope({required this.controllers, required this.child});
  final List<TextEditingController> controllers;
  final Widget child;
  @override
  State<_DialogInputScope> createState() => _DialogInputScopeState();
}

class _DialogInputScopeState extends State<_DialogInputScope> {
  @override
  void dispose() {
    for (final c in widget.controllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
