import 'package:flutter_map/flutter_map.dart' as fm;
import 'admin_city_catalog_v37.dart';
import 'admin_trip_rules_v9.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:flutter/material.dart';
import '../../services/zone_pricing_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/admin_theme.dart';
import '../../widgets/city_zone_icons.dart';

class AdminPricingZonesScreen extends StatefulWidget {
  const AdminPricingZonesScreen({super.key});
  @override
  State<AdminPricingZonesScreen> createState() =>
      _AdminPricingZonesScreenState();
}

class _AdminPricingZonesScreenState extends State<AdminPricingZonesScreen> {
  final api = ZonePricingService.instance;
  List<PricingZone> zones = [];
  List<Map<String, dynamic>> cityDrafts = [];
  String? cityLoadError;
  String cityGovernorate = 'الجيزة';
  List<Map<String, dynamic>> captains = [];
  List<ll.LatLng> points = [];
  PricingZone? editing;
  final map = fm.MapController();
  bool busy = false, global = false, active = true;
  String selectedIconKey = 'city';
  String? error, captainId;
  String selectedService = 'car_ride';
  Map<String, Map<String, dynamic>> tariffs = {};
  bool tariffBusy = false;
  final minimumFare = TextEditingController();
  final serviceKm = TextEditingController();
  final serviceOpening = TextEditingController();
  final serviceWaiting = TextEditingController();
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      km = TextEditingController(),
      opening = TextEditingController(),
      waiting = TextEditingController(),
      priority = TextEditingController(text: '0'),
      commission = TextEditingController();
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final fetched = await api.zones();
      final drivers = await SupabaseService.instance.getAllCaptains();
      if (!mounted) return;
      setState(() {
        zones = fetched;
        captains = drivers;
        // Tariffs are loaded separately after the parent zone list.

      });
      await _loadTariffs();
      try {
        final result = await SupabaseService.instance.client.rpc('v37_admin_city_catalog');
        final raw = (result as Map)['cities'] as List? ?? const [];
        if (mounted) setState(() {
          cityDrafts = raw.whereType<Map>().map((e) => Map<String,dynamic>.from(e)).toList();
          cityLoadError = null;
        });
      } catch (_) {
        if (mounted) setState(() { cityLoadError = 'قائمة المدن مش متاحة. تأكد من SQL V37.'; });
      }
    } catch (_) {
      if (mounted)
        setState(
          () => error = 'تعذر تحميل المناطق. تأكد من تثبيت SQL والاتصال.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    map.dispose();
    for (final controller in [
      name,
      km,
      opening,
      waiting,
      priority,
      commission,
      minimumFare, serviceKm, serviceOpening, serviceWaiting,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _edit(PricingZone? zone) {
    setState(() {
      editing = zone;
      global = zone?.global ?? false;
      active = zone?.active ?? true;
      points = zone == null ? [] : List<ll.LatLng>.from(zone.ring);
      if (points.length > 1 && points.first == points.last) points.removeLast();
      name.text = zone?.name ?? '';
      km.text = zone == null
          ? ''
          : zone.number('price_per_km').toStringAsFixed(2);
      opening.text = zone == null
          ? ''
          : zone.number('opening_fee').toStringAsFixed(2);
      waiting.text = zone == null
          ? ''
          : zone.number('waiting_per_minute').toStringAsFixed(2);
      priority.text = zone == null ? '0' : '${zone.row['priority']}';
      selectedIconKey = zone?.iconKey ?? 'city';
    });
    _fillTariff();
    final center = zone?.center;
    if (center != null)
      map.move(ll.LatLng(center.latitude, center.longitude), 14);
  }

  Future<void> _loadTariffs() async {
    try {
      final rows = await api.serviceTariffs();
      if (!mounted) return;
      setState(() {
        tariffs = {
          for (final row in rows)
            '${row['zone_id']}:${row['service_type']}': row,
        };
      });
      _fillTariff();
    } catch (_) {
      if (mounted) setState(() => error =
        'تعذر تحميل تسعيرات الخدمات. ثبّت SQL V28 بعد مراجعة الإنتاج.');
    }
  }

  void _fillTariff() {
    final zone = editing;
    final row = zone == null ? null : tariffs['${zone.id}:$selectedService'];
    serviceKm.text = (row?['price_per_km'] ?? zone?.number('price_per_km') ?? 0).toString();
    serviceOpening.text = (row?['opening_fee'] ?? zone?.number('opening_fee') ?? 0).toString();
    serviceWaiting.text = (row?['waiting_per_minute'] ?? zone?.number('waiting_per_minute') ?? 0).toString();
    minimumFare.text = (row?['minimum_fare'] ?? 0).toString();
  }

  Future<void> _saveServiceTariff() async {
    if (editing == null || tariffBusy || busy) return;
    final values = [minimumFare, serviceOpening, serviceKm, serviceWaiting]
        .map((c) => double.tryParse(c.text.trim())).toList();
    if (values.any((v) => v == null || !v.isFinite || v < 0 || v > 10000)) {
      setState(() => error = 'راجع الحد الأدنى وفتح العداد والكيلومتر والانتظار.');
      return;
    }
    setState(() { tariffBusy = true; error = null; });
    try {
      await api.saveServiceTariff(
        zoneId: editing!.id,
        service: selectedService,
        minimum: values[0]!, opening: values[1]!,
        km: values[2]!, waiting: values[3]!,
      );
      await _loadTariffs();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ تسعيرة الخدمة على السيرفر')));
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر حفظ التسعيرة. لا يوجد تغيير على حسابات الرحلات.');
    } finally {
      if (mounted) setState(() => tariffBusy = false);
    }
  }

  Widget _serviceTariffEditor() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Divider(),
      const Text('تسعيرة كل خدمة داخل المنطقة',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 5),
      const Text('هذه التسعيرة تُستخدم في عرض السعر الصادر من السيرفر. '
        'الخارج عن المدن هو المنطقة العامة. الأسعار القديمة أدناه احتياطية فقط.'),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: selectedService,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'نوع الخدمة'),
        items: const [
          DropdownMenuItem(value: 'car_ride', child: Text('🚗 سيارة')),
          DropdownMenuItem(value: 'motorcycle_ride', child: Text('🛵 موتوسيكل')),
          DropdownMenuItem(value: 'package', child: Text('📦 طرد')),
        ],
        onChanged: (v) {
          if (v == null) return;
          setState(() => selectedService = v);
          _fillTariff();
        },
      ),
      const SizedBox(height: 12),
      _field(minimumFare, 'الحد الأدنى لبدء الرحلة — جنيه'),
      _field(serviceOpening, 'فتح العداد — جنيه'),
      _field(serviceKm, 'الكيلومتر — جنيه'),
      _field(serviceWaiting, 'دقيقة الانتظار — جنيه'),
      FilledButton.icon(
        onPressed: editing == null || busy || tariffBusy ? null : _saveServiceTariff,
        icon: const Icon(Icons.save), label: const Text('حفظ تسعيرة هذه الخدمة')),
      if (editing == null)
        const Text('احفظ المنطقة على الخريطة أولًا، ثم احفظ أسعار كل خدمة.'),
      const SizedBox(height: 18),
    ],
  );

  String? _money(String? input) {
    final amount = double.tryParse((input ?? '').trim());
    return amount == null || !amount.isFinite || amount < 0 || amount > 10000
        ? 'اكتب سعرًا من 0 إلى 10000'
        : null;
  }

  Future<void> _save() async {
    if (busy || !form.currentState!.validate()) return;
    if (!global && points.length < 3) {
      setState(() => error = 'اضغط على الخريطة وحدد ٣ نقاط على الأقل.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await api.save(
        id: editing?.id,
        name: name.text,
        vertices: points,
        global: global,
        km: double.parse(km.text.trim()),
        opening: double.parse(opening.text.trim()),
        waiting: double.parse(waiting.text.trim()),
        priority: int.parse(priority.text.trim()),
        active: active,
        iconKey: selectedIconKey,
      );
      if (!mounted) return;
      _edit(null);
      await _load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('اتحفظت المنطقة والأسعار بنجاح')),
        );
    } catch (_) {
      if (mounted)
        setState(
          () => error =
              'تعذر الحفظ. تأكد أن حدود المنطقة لا تتقاطع، وأن هناك تسعيرًا عامًا واحدًا فقط.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool money = true,
  }) => Padding(
    padding: EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: money
          ? TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      validator: money
          ? _money
          : (value) =>
                (value ?? '').trim().length < 2 ? 'اكتب اسم المنطقة' : null,
    ),
  );
  @override
  Widget build(BuildContext context) => Theme(
    data: AdminTheme.theme,
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
      backgroundColor: AdminTheme.background,
      appBar: AppBar(
        backgroundColor: AdminTheme.surface,
        foregroundColor: AdminTheme.ink,
        title: Text('المدن والمناطق والأسعار'),
        actions: [
          IconButton(
            onPressed: busy ? null : _load,
            icon: Icon(Icons.refresh),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final editor = Form(
            key: form,
            child: ListView(
              padding: EdgeInsets.all(18),
              children: [
                if (busy) LinearProgressIndicator(),
                if (error != null)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      error!,
                      style: TextStyle(color: AdminTheme.error),
                    ),
                  ),
                Card(
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    leading: const Icon(Icons.location_city_outlined),
                    title: const Text('مدن القاهرة والجيزة — تحديد الحدود على الخريطة'),
                    subtitle: Text(cityLoadError ?? '${cityDrafts.length} مدينة مسجلة، والمدن الجديدة غير مفعّلة حتى اعتمادها'),
                    children: [
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'الجيزة', label: Text('الجيزة')),
                          ButtonSegment(value: 'القاهرة', label: Text('القاهرة')),
                        ],
                        selected: {cityGovernorate},
                        onSelectionChanged: (selected) => setState(() => cityGovernorate = selected.first),
                      ),
                      Padding(padding: const EdgeInsets.all(10), child: Wrap(spacing: 7, runSpacing: 6,
                        children: [
                          for (final city in cityDrafts.where((c) => c['governorate'] == cityGovernorate))
                            ActionChip(
                              avatar: Icon(city['is_enabled'] == true ? Icons.check_circle : Icons.edit_location_alt_outlined,
                                color: city['is_enabled'] == true ? Colors.green : Colors.amber, size: 18),
                              label: Text(city['name']?.toString() ?? 'مدينة'),
                              onPressed: () async {
                                await Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => AdminCityCatalogV37(initialCityId: city['id']?.toString())));
                                if (mounted) await _load();
                              },
                            ),
                        ],
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Card(child: ExpansionTile(
                  leading: Icon(Icons.timer_outlined),
                  title: Text('الإلغاء والتعويض بعد قبول الكابتن'),
                  subtitle: Text('تحديد مدة السماح والتعويض من قواعد الرحلات الحالية'),
                  children: [AdminTripRulesV9()],
                )),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      label: Text('منطقة جديدة'),
                      avatar: Icon(Icons.add),
                      onPressed: () => _edit(null),
                    ),
                    for (final zone in zones)
                      ActionChip(
                        avatar: Icon(
                          zone.global
                              ? Icons.public_rounded
                              : cityZoneIcon(zone.iconKey),
                          size: 18,
                          color: AdminTheme.goldDark,
                        ),
                        label: Text(
                          '${zone.name}${zone.active ? '' : ' • متوقفة'}',
                        ),
                        onPressed: () => _edit(zone),
                      ),
                  ],
                ),
                SizedBox(height: 18),
                Text(
                  editing == null ? 'إضافة مدينة أو منطقة' : 'تعديل ${editing!.name}',
                  style: TextStyle(
                    fontSize: 20,
                    color: AdminTheme.goldDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('تسعير عام خارج المناطق'),
                  subtitle: Text(
                    'يُستخدم هذا التسعير تلقائيًا عندما تكون نقطة الالتقاط خارج أي مدينة محددة.',
                  ),
                  value: global,
                  onChanged: busy
                      ? null
                      : (value) => setState(() => global = value),
                ),
                if (!global)
                  Text(
                    'اضغط على الخريطة لتحديد الحدود • ${points.length} نقاط',
                    style: TextStyle(color: AdminTheme.goldDark),
                  ),
                if (!global)
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: points.isEmpty
                            ? null
                            : () => setState(() => points.removeLast()),
                        icon: Icon(Icons.undo),
                        label: Text('تراجع'),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() => points.clear()),
                        icon: Icon(Icons.clear),
                        label: Text('مسح الحدود'),
                      ),
                    ],
                  ),
                SizedBox(height: 12),
                _field(name, 'اسم المدينة أو المنطقة', money: false),
                if (!global) ...[
                  SizedBox(height: 2),
                  Text(
                    'أيقونة المدينة',
                    style: TextStyle(
                      color: AdminTheme.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'اختر العلامة التي ستظهر للعميل بجوار اسم المدينة.',
                    style: TextStyle(color: AdminTheme.muted, fontSize: 11),
                  ),
                  SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in cityZoneIconOptions)
                        ChoiceChip(
                          selected: selectedIconKey == option.keyName,
                          onSelected: busy
                              ? null
                              : (_) => setState(
                                    () => selectedIconKey = option.keyName,
                                  ),
                          avatar: Icon(
                            option.icon,
                            size: 18,
                            color: selectedIconKey == option.keyName
                                ? AdminTheme.goldDark
                                : AdminTheme.muted,
                          ),
                          label: Text(option.label),
                        ),
                    ],
                  ),
                  SizedBox(height: 14),
                ],
                _serviceTariffEditor(),
                const Divider(),
                const Text('تسعير احتياطي قديم (للتوافق فقط)'),
                _field(km, 'الكيلومتر الاحتياطي — جنيه'),
                _field(opening, 'رسوم فتح العداد — جنيه'),
                _field(waiting, 'دقيقة الانتظار — جنيه'),
                TextFormField(
                  controller: priority,
                  keyboardType: TextInputType.numberWithOptions(
                    signed: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'الأولوية عند تداخل المناطق',
                  ),
                  validator: (v) => int.tryParse(v ?? '') == null
                      ? 'اكتب رقمًا صحيحًا'
                      : null,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('المنطقة مفعلة'),
                  value: active,
                  onChanged: global ? null : (v) => setState(() => active = v),
                ),
                FilledButton.icon(
                  onPressed: busy ? null : _save,
                  icon: Icon(Icons.save_outlined),
                  label: Text('حفظ المنطقة والأسعار'),
                ),
                SizedBox(height: 26),
                Divider(),
                Text(
                  'عمولة مخصصة للكابتن',
                  style: TextStyle(
                    color: AdminTheme.goldDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'تُحفظ النسبة عند قبول الرحلة. اتركها فارغة لاستخدام عمولة الخدمة الافتراضية.',
                ),
                SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: captainId,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: 'الكابتن'),
                  items: captains
                      .map(
                        (c) => DropdownMenuItem(
                          value: c['id'].toString(),
                          child: Text(
                            '${c['full_name']} • ${c['phone']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (id) {
                    final c = captains.firstWhere(
                      (c) => c['id'].toString() == id,
                    );
                    setState(() {
                      captainId = id;
                      commission.text =
                          c['custom_commission']?.toString() ?? '';
                    });
                  },
                ),
                SizedBox(height: 12),
                TextField(
                  controller: commission,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'نسبة العمولة % — فارغ = الافتراضية',
                  ),
                ),
                SizedBox(height: 12),
                OutlinedButton(
                  onPressed: busy || captainId == null
                      ? null
                      : () async {
                          final raw = commission.text.trim(),
                              percent = double.tryParse(commission.text.trim());
                          if (raw.isNotEmpty &&
                              (percent == null ||
                                  !percent.isFinite ||
                                  percent < 0 ||
                                  percent > 100)) {
                            setState(() => error = 'العمولة من 0 إلى 100%');
                            return;
                          }
                          setState(() {
                            busy = true;
                            error = null;
                          });
                          try {
                            await api.commission(
                              captainId!,
                              raw.isEmpty ? null : percent,
                            );
                            await _load();
                            if (mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('اتحفظت عمولة الكابتن'),
                                ),
                              );
                          } catch (_) {
                            if (mounted)
                              setState(
                                () => error =
                                    'تعذر حفظ العمولة. اكتب رقمين عشريين بحد أقصى.',
                              );
                          } finally {
                            if (mounted) setState(() => busy = false);
                          }
                        },
                  child: Text('حفظ عمولة الكابتن'),
                ),
              ],
            ),
          );
          final canvas = fm.FlutterMap(
            mapController: map,
            options: fm.MapOptions(
              initialCenter: ll.LatLng(29.974, 31.101),
              initialZoom: 13.5,
              onTap: (_, point) {
                if (!global && !busy && points.length < 499)
                  setState(
                    () => points.add(ll.LatLng(point.latitude, point.longitude)),
                  );
              },
            ),
            children: [
              fm.TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.vetosanya.app',
              ),
              fm.PolygonLayer(
                polygons: [
                  for (final z in zones.where(
                    (z) =>
                        !z.global && z.id != editing?.id && z.ring.length >= 3,
                  ))
                    fm.Polygon(
                      points: z.ring
                          .map((p) => ll.LatLng(p.latitude, p.longitude))
                          .toList(),
                      color: AdminTheme.gold.withAlpha(28),
                      borderColor: AdminTheme.gold.withAlpha(150),
                      borderStrokeWidth: 2,
                    ),
                  if (!global && points.length >= 3)
                    fm.Polygon(
                      points: points
                          .map((p) => ll.LatLng(p.latitude, p.longitude))
                          .toList(),
                      color: AdminTheme.gold.withAlpha(42),
                      borderColor: AdminTheme.goldDark,
                      borderStrokeWidth: 3,
                    ),
                ],
              ),
              fm.MarkerLayer(
                markers: [
                  for (var i = 0; i < points.length && !global; i++)
                    fm.Marker(
                      point: ll.LatLng(points[i].latitude, points[i].longitude),
                      width: 30,
                      height: 30,
                      child: GestureDetector(
                        onTap: () => setState(() => points.removeAt(i)),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AdminTheme.goldDark,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              fm.RichAttributionWidget(
                attributions: [
                  fm.TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          );
          if (constraints.maxWidth >= 850)
            return Row(
              children: [
                Expanded(flex: 3, child: canvas),
                SizedBox(width: 390, child: editor),
              ],
            );
          return Column(
            children: [
              SizedBox(height: constraints.maxHeight * .42, child: canvas),
              Expanded(child: editor),
            ],
          );
        },
      ),
    ),
    ),
  );
}
