import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/supabase_service.dart';
import 'admin_place_pin_picker_v39.dart';

/// Owner-only RPCs retain the existing V16 owner gate; no staff permission expansion.
class AdminAddressSuggestions extends StatefulWidget {
  const AdminAddressSuggestions({super.key});
  @override
  State<AdminAddressSuggestions> createState() =>
      _AdminAddressSuggestionsState();
}

class _AdminAddressSuggestionsState extends State<AdminAddressSuggestions> {
  List<Map<String, dynamic>> _items = [];
  bool _busy = true;
  bool _more = false;
  String? _error, _filter;
  final api = SupabaseService.instance.client;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool append = false}) async {
    setState(() => _busy = true);
    try {
      final raw = await api
          .rpc(
            'v51_owner_address_suggestions',
            params: {
              'p_status': _filter,
              'p_offset': append ? _items.length : 0,
              'p_limit': 100,
            },
          )
          .timeout(const Duration(seconds: 15));
      if (raw is! List) throw StateError('invalid_suggestion_response');
      if (mounted)
        setState(() {
          final page = raw
              .whereType<Map>()
              .map((v) => Map<String, dynamic>.from(v))
              .toList();
          _items = append ? [..._items, ...page] : page;
          _more = page.length == 100;
          _error = null;
        });
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'تعذر تحميل الاقتراحات. تحقق من صلاحية الأونر وتحديث بيئة الاختبار.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(Map<String, dynamic> item, String status) async {
    final reason = TextEditingController();
    try {
      final approved = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            status == 'published'
                ? 'اعتماد عنوان بعد التحقق'
                : status == 'rejected'
                ? 'سبب الرفض'
                : 'المعلومة المطلوبة',
          ),
          content: TextField(controller: reason, maxLength: 500),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('رجوع'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('متابعة'),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;
      if (reason.text.trim().length < 2) {
        throw StateError('reason_required');
      }
      String? cityId = item['selected_city_id']?.toString(), parentId;
      LatLng? pin;
      if (status == 'published') {
        final catalog = await api
            .rpc('v37_admin_city_catalog')
            .timeout(const Duration(seconds: 15));
        final cities = catalog is Map ? catalog['cities'] : null;
        if (!mounted) return;
        if (cities is! List) throw StateError('cities_unavailable');
        final available = cities
            .whereType<Map>()
            .where((c) => c['is_enabled'] == true)
            .toList();
        cityId = await showDialog<String>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: const Text('اختار مدينة معتمدة للنشر'),
            children: [
              for (final c in available)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, c['id'].toString()),
                  child: Text('${c['name']} — ${c['governorate']}'),
                ),
            ],
          ),
        );
        if (cityId == null || !mounted) return;
        final entries = await api
            .rpc('v49_owner_city_places', params: {'p_city': cityId})
            .timeout(const Duration(seconds: 15));
        if (!mounted) return;
        if (entries is! List) throw StateError('areas_unavailable');
        final areas = entries
            .whereType<Map>()
            .where(
              (v) =>
                  v['parent_id'] == null &&
                  v['is_verified'] == true &&
                  v['is_visible'] == true,
            )
            .toList();
        if (item['address_kind'] == 'building') {
          parentId = await showDialog<String>(
            context: context,
            builder: (ctx) => SimpleDialog(
              title: const Text('اربط العمارة بمنطقة منشورة'),
              children: [
                for (final a in areas)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, a['id'].toString()),
                    child: Text('${a['name']}'),
                  ),
              ],
            ),
          );
          if (parentId == null || !mounted) return;
        }
        pin = await Navigator.push<LatLng>(
          context,
          MaterialPageRoute(
            builder: (_) => AdminPlacePinPickerV39(
              initialLat: double.tryParse('${item['latitude']}'),
              initialLng: double.tryParse('${item['longitude']}'),
              requireFreshTap: true,
            ),
          ),
        );
        if (pin == null || !mounted) return;
      }
      await api
          .rpc(
            'v51_owner_review_address',
            params: {
              'p_id': item['id'],
              'p_status': status,
              'p_reason': reason.text.trim(),
              'p_city': cityId,
              'p_parent': parentId,
              'p_lat': pin?.latitude,
              'p_lng': pin?.longitude,
            },
          )
          .timeout(const Duration(seconds: 15));
      if (mounted) await _load();
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'تعذر تأكيد المراجعة. يلزم سبب واضح ومدينة فعالة ودبوس داخل التغطية للنشر؛ أعد تحميل الحالة قبل المحاولة.',
        );
    } finally {
      reason.dispose();
    }
  }

  Future<void> _history(Map<String, dynamic> item) async {
    try {
      final raw = await api
          .rpc('v51_owner_address_review_history', params: {'p_id': item['id']})
          .timeout(const Duration(seconds: 15));
      if (raw is! List) throw StateError('invalid_review_history');
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('سجل مراجعة العنوان'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (raw.isEmpty)
                    const Text(
                      'لا توجد عمليات مسجلة منذ إضافة سجل المراجعة. تفاصيل الاقتراح القديم محفوظة في الصفحة.',
                    ),
                  for (final row in raw.whereType<Map>())
                    ListTile(
                      title: Text('${row['action']} · ${row['created_at']}'),
                      subtitle: Text(
                        'المراجع: ${row['actor']}\nالحالة السابقة: ${row['previous_state']?['review_status']}\nالمدينة: ${row['previous_state']?['city_label']}\nالعمارة: ${row['previous_state']?['building_number']}\nالملاحظة: ${row['previous_state']?['customer_note'] ?? ''}',
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted)
        setState(() => _error = 'تعذر تحميل سجل المراجعة. أعد المحاولة.');
    }
  }

  void _map(Map<String, dynamic> item) {
    final lat = double.tryParse('${item['latitude']}'),
        lng = double.tryParse('${item['longitude']}');
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180)
      return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('دبوس العميل — غير معتمد حتى المراجعة'),
        content: SizedBox(
          width: 560,
          height: 360,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(lat, lng),
              initialZoom: 16,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.vetosanya.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(lat, lng),
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.amber,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('اقتراحات العناوين — جميع المدن'),
      actions: [
        IconButton(
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: DropdownButtonFormField<String>(
            initialValue: _filter,
            decoration: const InputDecoration(labelText: 'حالة المراجعة'),
            items: const [
              DropdownMenuItem(
                value: null,
                child: Text('جميع الحالات بما فيها الاقتراحات القديمة'),
              ),
              DropdownMenuItem(value: 'pending', child: Text('قيد المراجعة')),
              DropdownMenuItem(
                value: 'needs_information',
                child: Text('معلومات إضافية'),
              ),
              DropdownMenuItem(value: 'published', child: Text('منشور')),
              DropdownMenuItem(value: 'rejected', child: Text('مرفوض')),
              DropdownMenuItem(value: 'reviewed', child: Text('مراجع سابقًا')),
            ],
            onChanged: _busy
                ? null
                : (v) {
                    _filter = v;
                    _load();
                  },
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_busy) const LinearProgressIndicator(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (_items.isEmpty && !_busy && _error == null)
                const Text('لا توجد اقتراحات مطابقة.'),
              for (final s in _items)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${s['city_label']} — ${s['place_label']}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        SelectableText(
                          'صاحب الحساب: ${s['account_name'] ?? 'غير متاح'}\nمعرّف الحساب: ${s['user_id']}\nالهاتف للأونر فقط: ${s['account_phone'] ?? 'غير متاح'}',
                        ),
                        Text(
                          'المنطقة: ${s['area_label'] ?? ''} • الحرف: ${s['building_letter'] ?? ''} • العمارة: ${s['building_number'] ?? ''}\nالعنوان: ${s['written_address'] ?? ''}\nالملاحظة: ${s['customer_note'] ?? ''}\nالإرسال: ${s['created_at']}\nالحالة: ${s['review_status']} • اقتراحات مشابهة: ${s['similar_count']}\nسبب المراجعة: ${s['review_reason'] ?? ''}',
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton.icon(
                              onPressed: () => _history(s),
                              icon: const Icon(Icons.history),
                              label: const Text('سجل المراجعة'),
                            ),
                            TextButton.icon(
                              onPressed: () => _map(s),
                              icon: const Icon(Icons.map_outlined),
                              label: const Text('معاينة الدبوس'),
                            ),
                            if (![
                              'published',
                              'reviewed',
                              'rejected',
                            ].contains(s['review_status'])) ...[
                              FilledButton(
                                onPressed: () => _review(s, 'published'),
                                child: const Text('تحقق ثم نشر'),
                              ),
                              OutlinedButton(
                                onPressed: () =>
                                    _review(s, 'needs_information'),
                                child: const Text('طلب تصحيح'),
                              ),
                              TextButton(
                                onPressed: () => _review(s, 'rejected'),
                                child: const Text('رفض مع السبب'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (_more)
                TextButton(
                  onPressed: _busy ? null : () => _load(append: true),
                  child: const Text('تحميل اقتراحات أقدم'),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
