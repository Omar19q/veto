import 'admin_city_catalog_v37.dart';
import 'package:flutter/material.dart';
import '../categories/admin_categories_screen.dart';
import '../../services/ride_categories.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/admin_theme.dart';


/// V28 main entry: normal zone tariffs here, legacy operational controls remain accessible.
class AdminPricingPanel extends StatefulWidget {
  final bool showCityDrafts;
  const AdminPricingPanel({super.key, this.showCityDrafts = false});

  @override
  State<AdminPricingPanel> createState() => _AdminPricingPanelEntryState();
}

class _AdminPricingPanelEntryState extends State<AdminPricingPanel> {
  bool _advancedOpen = false;
  bool _cityDraftsOpen = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('المدن والمناطق والأسعار',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                    color: AdminTheme.ink)),
                const SizedBox(height: 8),
                const Text('إدارة مناطق الخريطة وأسعار السيارة والموتوسيكل والطرد '
                  'والحد الأدنى وفتح العداد والكيلومتر والانتظار من مكان واحد.'),
                const SizedBox(height: 10),
                FilledButton.icon(onPressed:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const AdminCategoriesScreen())),icon:const Icon(Icons.directions_car_rounded),label:Text(categoryCopy(context,'إدارة فئات الرحلات','Ride category control'))),
                const SizedBox(height:8),
                FilledButton.icon(
                  onPressed: () => context.push('/admin/pricing-zones'),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('فتح التسعير المعتمد على المناطق'),
                ),
                if (widget.showCityDrafts) ...[
                  const SizedBox(height: 5),
                  OutlinedButton.icon(
                    onPressed: () => setState(() { _cityDraftsOpen = !_cityDraftsOpen; if (_cityDraftsOpen) _advancedOpen = false; }),
                    icon: const Icon(Icons.location_city_outlined),
                    label: Text(_cityDraftsOpen ? 'رجوع للتسعير' : 'مدن جديدة لسه تحت التجهيز'),
                  ),
                ],
                const SizedBox(height: 5),
                TextButton.icon(
                  onPressed: () => setState(() { _advancedOpen = !_advancedOpen; if (_advancedOpen) _cityDraftsOpen = false; }),
                  icon: Icon(_advancedOpen ? Icons.expand_less : Icons.tune),
                  label: Text(_advancedOpen
                    ? 'إخفاء الإعدادات العامة المتقدمة'
                    : 'الإعدادات العامة والعمولات وفيتو ماركت (متقدمة)'),
                ),
              ],
            ),
          ),
        ),
      ),
      Expanded(
        child: _cityDraftsOpen
          ? const AdminCityCatalogV37()
          : _advancedOpen
          ? const _LegacyPricingPanelV28()
          : const Center(child: Text(
              'سعر المشوار حسب المنطقة ونوع الخدمة بيتحدد من شاشة الخريطة بالأعلى',
              textAlign: TextAlign.center,
            )),
      ),
    ],
  );
}

class _LegacyPricingPanelV28 extends StatefulWidget {
  const _LegacyPricingPanelV28();

  @override
  State<_LegacyPricingPanelV28> createState() => _LegacyPricingPanelV28State();
}

class _LegacyPricingPanelV28State extends State<_LegacyPricingPanelV28>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, Map<String, dynamic>> _pricingMap = {};
  List<Map<String, dynamic>> _areaPricing = [];
  String? _errorMessage;

  final List<String> _services = [
    'car_ride',
    'motorcycle_ride',
    'package',
    'vito_market',
  ];

  final Map<String, String> _serviceLabels = {
    'car_ride': '🚗 مشوار سيارة',
    'motorcycle_ride': '🛵 مشوار موتوسيكل',
    'package': '📦 طرد',
    'vito_market': '🛒 فيتو ماركت',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final allPricing = await SupabaseService.instance.getAllServicePricing();
      final areaPricing = await SupabaseService.instance.getAllAreaPricing();
      final map = <String, Map<String, dynamic>>{};
      for (final p in allPricing) {
        final type = p['service_type'] as String? ?? '';
        if (type.isNotEmpty) map[type] = Map<String, dynamic>.from(p);
      }
      if (mounted) {
        setState(() {
          _pricingMap = map;
          _areaPricing = areaPricing;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'تعذر تحميل بيانات التسعير: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Row(
            children: [
              Text(
                'إدارة التسعير',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AdminTheme.ink,
                ),
              ),
              Spacer(),
              OutlinedButton.icon(
                onPressed: () => context.push('/admin/pricing-zones'),
                icon: Icon(Icons.map_rounded),
                label: Text('المدن والمناطق'),
              ),
              SizedBox(width: 8),
              IconButton(
                onPressed: _load,
                icon: Icon(Icons.refresh_rounded, color: AdminTheme.goldDark),
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AdminTheme.goldDark,
          unselectedLabelColor: AdminTheme.muted,
          indicatorColor: AdminTheme.goldDark,
          labelStyle: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          tabs: [
            Tab(text: 'سيارة'),
            Tab(text: 'موتوسيكل'),
            Tab(text: 'طرد'),
            Tab(text: 'ماركت'),
            Tab(text: 'أسعار المناطق'),
          ],
        ),
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: AdminTheme.goldDark),
                )
              : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: AdminTheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _load,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminTheme.goldDark,
                          foregroundColor: AppTheme.primary,
                        ),
                        child: Text(
                          'إعادة المحاولة',
                          style: TextStyle(fontFamily: 'Cairo'),
                        ),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    ..._services.map(
                      (s) => _ServicePricingEditor(
                        serviceType: s,
                        serviceLabel: _serviceLabels[s] ?? s,
                        pricing: _pricingMap[s] ?? {},
                        onSaved: _load,
                      ),
                    ),
                    _AreaPricingEditor(
                      areaPricing: _areaPricing,
                      onSaved: _load,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

// ─── SERVICE PRICING EDITOR ──────────────────────────────────────────────────

class _ServicePricingEditor extends StatefulWidget {
  final String serviceType;
  final String serviceLabel;
  final Map<String, dynamic> pricing;
  final VoidCallback onSaved;

  const _ServicePricingEditor({
    required this.serviceType,
    required this.serviceLabel,
    required this.pricing,
    required this.onSaved,
  });

  @override
  State<_ServicePricingEditor> createState() => _ServicePricingEditorState();
}

class _ServicePricingEditorState extends State<_ServicePricingEditor> {
  late Map<String, TextEditingController> _controllers;
  bool _isSaving = false;
  String? _saveMessage;
  bool _saveSuccess = false;

  final List<_PricingField> _fields = [
    _PricingField(
      'price_per_km_inside',
      'سعر الكم داخل المنطقة (ج)',
      TextInputType.numberWithOptions(decimal: true),
    ),
    _PricingField(
      'price_per_km_outside',
      'سعر الكم خارج المنطقة (ج)',
      TextInputType.numberWithOptions(decimal: true),
    ),
    _PricingField(
      'minimum_fare',
      'الحد الأدنى للأجرة (ج)',
      TextInputType.numberWithOptions(decimal: true),
    ),
    _PricingField(
      'commission_percent',
      'نسبة العمولة (%)',
      TextInputType.numberWithOptions(decimal: true),
    ),
    _PricingField(
      'free_waiting_minutes',
      'دقائق الانتظار المجاني',
      TextInputType.number,
    ),
    _PricingField(
      'waiting_rate_per_minute',
      'سعر الانتظار بالدقيقة (ج)',
      TextInputType.numberWithOptions(decimal: true),
    ),
    _PricingField(
      'cancellation_grace_minutes',
      'مهلة الإلغاء المجاني من إنشاء الرحلة (دقيقة)',
      TextInputType.number,
    ),
    _PricingField(
      'captain_cancellation_fee',
      'رسوم إلغاء الكابتن (ج)',
      TextInputType.numberWithOptions(decimal: true),
    ),
    _PricingField(
      'customer_cancellation_fee',
      'رسوم إلغاء العميل بعد انتهاء المهلة (ج)',
      TextInputType.numberWithOptions(decimal: true),
    ),
    _PricingField(
      'captain_debt_threshold',
      'حد الدين للكابتن (ج)',
      TextInputType.numberWithOptions(decimal: true),
    ),
    _PricingField(
      'long_trip_alert_threshold',
      'حد تنبيه الرحلة الطويلة (كم)',
      TextInputType.numberWithOptions(decimal: true),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controllers = {};
    for (final f in _fields) {
      final val = widget.pricing[f.key];
      _controllers[f.key] = TextEditingController(
        text: val != null ? val.toString() : '',
      );
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _saveMessage = null;
    });
    try {
      final data = <String, dynamic>{};
      for (final f in _fields) {
        final text = _controllers[f.key]?.text.trim() ?? '';
        if (text.isNotEmpty) {
          if (f.inputType == TextInputType.number) {
            data[f.key] = int.tryParse(text) ?? double.tryParse(text) ?? 0;
          } else {
            data[f.key] = double.tryParse(text) ?? 0;
          }
        }
      }
      data['updated_at'] = DateTime.now().toIso8601String();

      // Use upsert — creates row if missing, updates if exists
      await SupabaseService.instance.updateServicePricing(
        widget.serviceType,
        data,
      );

      // Reload from DB to confirm persistence
      final saved = await SupabaseService.instance.getServicePricing(
        widget.serviceType,
      );

      if (mounted) {
        if (saved != null) {
          // Update controllers with confirmed DB values
          for (final f in _fields) {
            final val = saved[f.key];
            if (val != null) {
              _controllers[f.key]?.text = val.toString();
            }
          }
          setState(() {
            _isSaving = false;
            _saveMessage = 'تم حفظ التسعير بنجاح ✓';
            _saveSuccess = true;
          });
        } else {
          setState(() {
            _isSaving = false;
            _saveMessage = 'تعذر التحقق من الحفظ — لم يُعثر على السجل';
            _saveSuccess = false;
          });
        }
        widget.onSaved();
        Future.delayed(Duration(seconds: 3), () {
          if (mounted) setState(() => _saveMessage = null);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveMessage = 'تعذر حفظ البيانات: $e';
          _saveSuccess = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.serviceLabel,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AdminTheme.goldDark,
            ),
          ),
          SizedBox(height: 20),
          ...(_fields.map(
            (f) => Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: _buildField(f),
            ),
          )),
          SizedBox(height: 8),
          if (_saveMessage != null)
            Container(
              padding: EdgeInsets.all(12),
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: _saveSuccess
                    ? AppTheme.successLight.withAlpha(26)
                    : AdminTheme.error.withAlpha(26),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _saveSuccess
                      ? AppTheme.successLight.withAlpha(77)
                      : AdminTheme.error.withAlpha(77),
                ),
              ),
              child: Text(
                _saveMessage!,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: _saveSuccess
                      ? AppTheme.successLight
                      : AdminTheme.error,
                  fontSize: 13,
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.goldDark,
                foregroundColor: AppTheme.primary,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primary,
                      ),
                    )
                  : Text(
                      'حفظ التسعير',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(_PricingField f) {
    return TextField(
      controller: _controllers[f.key],
      keyboardType: f.inputType,
      style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
      decoration: InputDecoration(
        labelText: f.label,
        labelStyle: TextStyle(
          fontFamily: 'Cairo',
          color: AdminTheme.muted,
          fontSize: 13,
        ),
        filled: true,
        fillColor: AdminTheme.surfaceSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AdminTheme.borderSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AdminTheme.borderSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AdminTheme.goldDark, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }
}

class _PricingField {
  final String key;
  final String label;
  final TextInputType inputType;
  _PricingField(this.key, this.label, this.inputType);
}

// ─── AREA PRICING EDITOR ─────────────────────────────────────────────────────

class _AreaPricingEditor extends StatefulWidget {
  final List<Map<String, dynamic>> areaPricing;
  final VoidCallback onSaved;

  const _AreaPricingEditor({required this.areaPricing, required this.onSaved});

  @override
  State<_AreaPricingEditor> createState() => _AreaPricingEditorState();
}

class _AreaPricingEditorState extends State<_AreaPricingEditor> {
  final List<String> _areaLetters = [
    'أ',
    'ب',
    'ج',
    'د',
    'هـ',
    'و',
    'ز',
    'ح',
    'ط',
    'ك',
    'ل',
    'م',
    'ن',
    'ع',
    'س',
    'ص',
  ];

  String _selectedService = 'car_ride';
  String _originArea = 'أ';
  String _destArea = 'ن';
  final TextEditingController _priceCtrl = TextEditingController();
  bool _isSaving = false;
  String? _saveMessage;
  bool _saveSuccess = false;

  final Map<String, String> _serviceLabels = {
    'car_ride': 'سيارة',
    'motorcycle_ride': 'موتوسيكل',
    'package': 'طرد',
    'vito_market': 'ماركت',
  };

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final price = double.tryParse(_priceCtrl.text.trim());
    if (price == null || price <= 0) {
      setState(() {
        _saveMessage = 'من فضلك أدخل سعراً صحيحاً';
        _saveSuccess = false;
      });
      return;
    }
    setState(() {
      _isSaving = true;
      _saveMessage = null;
    });
    try {
      await SupabaseService.instance.client
          .from('area_pricing')
          .upsert({
            'service_type': _selectedService,
            'origin_area_letter': _originArea,
            'destination_area_letter': _destArea,
            'fixed_price': price,
            'is_active': true,
          }, onConflict: 'service_type,origin_area_letter,destination_area_letter');
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveMessage = 'تم حفظ سعر المنطقة بنجاح ✓';
          _saveSuccess = true;
        });
        widget.onSaved();
        _priceCtrl.clear();
        Future.delayed(Duration(seconds: 3), () {
          if (mounted) setState(() => _saveMessage = null);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveMessage = 'تعذر حفظ البيانات: $e';
          _saveSuccess = false;
        });
      }
    }
  }

  Future<void> _toggleActive(String id, bool current) async {
    try {
      await SupabaseService.instance.client
          .from('area_pricing')
          .update({'is_active': !current})
          .eq('id', id);
      widget.onSaved();
    } catch (_) {}
  }

  Future<void> _delete(String id) async {
    try {
      await SupabaseService.instance.client
          .from('area_pricing')
          .delete()
          .eq('id', id);
      widget.onSaved();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إضافة سعر منطقة إلى منطقة',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AdminTheme.ink,
            ),
          ),
          SizedBox(height: 16),
          // Service selector
          _buildDropdown(
            label: 'الخدمة',
            value: _selectedService,
            items: _serviceLabels.entries
                .map(
                  (e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(
                      e.value,
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _selectedService = v!),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: 'من منطقة',
                  value: _originArea,
                  items: _areaLetters
                      .map(
                        (l) => DropdownMenuItem(
                          value: l,
                          child: Text(
                            'منطقة $l',
                            style: TextStyle(fontFamily: 'Cairo'),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _originArea = v!),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildDropdown(
                  label: 'إلى منطقة',
                  value: _destArea,
                  items: _areaLetters
                      .map(
                        (l) => DropdownMenuItem(
                          value: l,
                          child: Text(
                            'منطقة $l',
                            style: TextStyle(fontFamily: 'Cairo'),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _destArea = v!),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          TextField(
            controller: _priceCtrl,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontFamily: 'Cairo',
              color: AdminTheme.ink,
            ),
            decoration: InputDecoration(
              labelText: 'السعر الثابت (جنيه)',
              labelStyle: TextStyle(
                fontFamily: 'Cairo',
                color: AdminTheme.muted,
              ),
              filled: true,
              fillColor: AdminTheme.surfaceSoft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AdminTheme.borderSoft),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AdminTheme.borderSoft),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AdminTheme.goldDark, width: 2),
              ),
            ),
          ),
          SizedBox(height: 12),
          if (_saveMessage != null)
            Container(
              padding: EdgeInsets.all(10),
              margin: EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: _saveSuccess
                    ? AppTheme.successLight.withAlpha(26)
                    : AdminTheme.error.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _saveMessage!,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: _saveSuccess
                      ? AppTheme.successLight
                      : AdminTheme.error,
                  fontSize: 13,
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.goldDark,
                foregroundColor: AppTheme.primary,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primary,
                      ),
                    )
                  : Text(
                      'حفظ السعر',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'أسعار المناطق المحفوظة',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AdminTheme.ink,
            ),
          ),
          SizedBox(height: 12),
          if (widget.areaPricing.isEmpty)
            Center(
              child: Text(
                'لا توجد أسعار مناطق محفوظة',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: AdminTheme.mutedLight,
                ),
              ),
            )
          else
            ...widget.areaPricing.map((ap) {
              final isActive = (ap['is_active'] as bool?) ?? false;
              return Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AdminTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AdminTheme.borderSoft),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_serviceLabels[ap['service_type']] ?? ap['service_type']} — منطقة ${ap['origin_area_letter']} → منطقة ${ap['destination_area_letter']}',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AdminTheme.ink,
                            ),
                          ),
                          Text(
                            '${ap['fixed_price']} جنيه',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AdminTheme.goldDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: isActive,
                      onChanged: (_) =>
                          _toggleActive(ap['id'] as String, isActive),
                      activeThumbColor: AdminTheme.goldDark,
                    ),
                    IconButton(
                      onPressed: () => _delete(ap['id'] as String),
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: AdminTheme.error,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: 'Cairo',
          color: AdminTheme.muted,
          fontSize: 13,
        ),
        filled: true,
        fillColor: AdminTheme.surfaceSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AdminTheme.borderSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AdminTheme.borderSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AdminTheme.goldDark, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      dropdownColor: AdminTheme.surface,
      style: TextStyle(
        fontFamily: 'Cairo',
        color: AdminTheme.ink,
        fontSize: 13,
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}