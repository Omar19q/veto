import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/admin_theme.dart';

class AdminBuildingsPanel extends StatefulWidget {
  const AdminBuildingsPanel({super.key});

  @override
  State<AdminBuildingsPanel> createState() => _AdminBuildingsPanelState();
}

class _AdminBuildingsPanelState extends State<AdminBuildingsPanel> {
  List<Map<String, dynamic>> _buildings = [];
  List<Map<String, dynamic>> _areas = [];
  bool _isLoading = false;
  int _totalBuildingCount = 0;
  int _visibleBuildingCount = 0;
  String? _selectedAreaFilter;
  String? _verificationFilter;
  bool? _activeFilter;
  bool _onlyCustomerGpsPending = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  dynamic _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadAreas();
    _searchCtrl.addListener(_onSearchChanged);
    _subscribeToChanges();
    _search();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeToChanges() {
    _realtimeChannel = SupabaseService.instance.subscribeToBuildingChanges(
      onUpdate: (building) {
        if (mounted) _search();
      },
    );
  }

  Future<void> _loadAreas() async {
    // Keep the 16 Hadayek areas available even when the admin-area
    // table has missing/inactive rows. Building records are keyed by
    // area_letter, so the picker must not disappear because of that.
    final letters = <String>[
      'أ', 'ب', 'ج', 'د', 'هـ', 'و', 'ز', 'ح',
      'ط', 'ك', 'ل', 'م', 'ن', 'ع', 'س', 'ص',
    ];

    try {
      final dbAreas = await SupabaseService.instance.getHadayekAreas();
      final byLetter = <String, Map<String, dynamic>>{
        for (final area in dbAreas)
          if ((area['area_letter'] as String?) != null)
            area['area_letter'] as String: area,
      };

      final areas = letters
          .map((letter) => byLetter[letter] ?? {'area_letter': letter})
          .toList();

      if (mounted) setState(() => _areas = areas);
    } catch (_) {
      if (mounted) {
        setState(() {
          _areas = [
            for (final letter in letters) {'area_letter': letter},
          ];
        });
      }
    }
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim();
    if (q != _searchQuery) {
      setState(() => _searchQuery = q);
      _search();
    }
  }

  Future<void> _search() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final service = SupabaseService.instance;

      // The previous admin RPC/fallback was capped at 100 rows, which made
      // the panel look as if only one area / 100 buildings existed.
      // Load the real 590-building directory per area directly, then apply
      // the admin filters locally. This keeps all numbered records through 590 available.
      final areas = _selectedAreaFilter != null
          ? <String>[_selectedAreaFilter!]
          : <String>[
              'أ', 'ب', 'ج', 'د', 'هـ', 'و', 'ز', 'ح',
              'ط', 'ك', 'ل', 'م', 'ن', 'ع', 'س', 'ص',
            ];

      final chunks = await Future.wait(
        areas.map(
          (area) => service.client
              .from('hadayek_buildings')
              .select()
              .eq('area_letter', area)
              .order('building_number', ascending: true)
              .range(0, 589),
        ),
      );

      var buildings = <Map<String, dynamic>>[
        for (final chunk in chunks)
          ...List<Map<String, dynamic>>.from(chunk),
      ];

      _totalBuildingCount = buildings.length;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.trim();
        buildings = buildings.where((b) {
          final n = b['building_number']?.toString() ?? '';
          return n.startsWith(q);
        }).toList();
      }

      if (_verificationFilter != null) {
        buildings = buildings.where((b) {
          return b['verification_status'] == _verificationFilter;
        }).toList();
      }

      if (_activeFilter != null) {
        buildings = buildings.where((b) {
          return (b['is_active'] as bool?) == _activeFilter;
        }).toList();
      }

      if (_onlyCustomerGpsPending) {
        buildings = buildings.where((b) =>
          b['gps_submitted_at'] != null &&
          b['verification_status'] != 'verified').toList();
      }

      buildings.sort((a, b) {
        final areaA = a['area_letter']?.toString() ?? '';
        final areaB = b['area_letter']?.toString() ?? '';
        final areaCompare = areaA.compareTo(areaB);
        if (areaCompare != 0) return areaCompare;

        final numA = int.tryParse(a['building_number']?.toString() ?? '') ?? 0;
        final numB = int.tryParse(b['building_number']?.toString() ?? '') ?? 0;
        return numA.compareTo(numB);
      });

      if (mounted) {
        setState(() {
          _buildings = buildings;
          _visibleBuildingCount = buildings.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _buildings = [];
          _visibleBuildingCount = 0;
        });
      }
    }
  }

  Future<void> _showSubmissionHistoryV33() async {
    try {
      final rows = await SupabaseService.instance.ownerBuildingSubmissionsV33();
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('سجل إضافات العمارات — حساب صاحب الطلب',
          style: TextStyle(fontFamily: 'Cairo')),
        content: SizedBox(width: 700, height: 480, child: rows.isEmpty
          ? const Center(child: Text('لا توجد إضافات مسجلة في V33 بعد'))
          : ListView.separated(itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (_, i) {
                final r = rows[i];
                return ListTile(
                  leading: Icon(Icons.location_on_outlined,
                    color: AdminTheme.goldDark),
                  title: Text('منطقة ${r['area'] ?? ''} — عمارة ${r['number'] ?? ''}',
                    style: const TextStyle(fontFamily: 'Cairo')),
                  subtitle: SelectableText(
                    'العميل: ${r['name'] ?? 'بدون اسم'} • ${r['phone'] ?? '—'}\n'
                    'معرف الحساب: ${r['user_id'] ?? '—'}\n'
                    'وقت الاقتراح: ${r['submitted_at'] ?? ''}',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                );
              })),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('إغلاق'))],
      ));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('سجل الإضافات غير متاح. تحقق من SQL V33.')));
    }
  }

  Future<void> _openBuilding(Map<String, dynamic> building) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _BuildingEditDialog(building: building),
    );
    if (result == true) _search();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Row(
            children: [
              Text(
                'إدارة عمارات حدائق الأهرام',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AdminTheme.ink,
                ),
              ),
              Spacer(),
              IconButton(
                onPressed: _showSubmissionHistoryV33,
                icon: Icon(Icons.manage_search_rounded, color: AdminTheme.goldDark),
                tooltip: 'مَن أضاف العمارات؟',
              ),
              IconButton(
                onPressed: _search,
                icon: Icon(Icons.refresh_rounded, color: AdminTheme.goldDark),
                tooltip: 'تحديث',
              ),
            ],
          ),
        ),
        // Filters row
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Area filter
              _FilterDropdown<String?>(
                value: _selectedAreaFilter,
                hint: 'كل المناطق',
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      'كل المناطق',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                  ),
                  ..._areas.map(
                    (a) => DropdownMenuItem<String?>(
                      value: a['area_letter'] as String?,
                      child: Text(
                        'منطقة ${a['area_letter']}',
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                  ),
                ],
                onChanged: (v) {
                  setState(() => _selectedAreaFilter = v);
                  _search();
                },
              ),
              // Verification filter
              _FilterDropdown<String?>(
                value: _verificationFilter,
                hint: 'كل الحالات',
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      'كل الحالات',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'verified',
                    child: Text('محقق', style: TextStyle(fontFamily: 'Cairo')),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'needs_verification',
                    child: Text(
                      'يحتاج تحقق',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                  ),
                ],
                onChanged: (v) {
                  setState(() => _verificationFilter = v);
                  _search();
                },
              ),
              // Active filter
              _FilterDropdown<bool?>(
                value: _activeFilter,
                hint: 'نشط / غير نشط',
                items: [
                  DropdownMenuItem<bool?>(
                    value: null,
                    child: Text('الكل', style: TextStyle(fontFamily: 'Cairo')),
                  ),
                  DropdownMenuItem<bool?>(
                    value: true,
                    child: Text('نشط', style: TextStyle(fontFamily: 'Cairo')),
                  ),
                  DropdownMenuItem<bool?>(
                    value: false,
                    child: Text(
                      'غير نشط',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                  ),
                ],
                onChanged: (v) {
                  setState(() => _activeFilter = v);
                  _search();
                },
              ),
              FilterChip(
                label: Text('مواقع أرسلها العملاء · تحتاج مراجعة',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                selected: _onlyCustomerGpsPending,
                onSelected: (value) {
                  setState(() {
                    _onlyCustomerGpsPending = value;
                    if (value) {
                      _verificationFilter = null;
                      _activeFilter = null;
                    }
                  });
                  _search();
                },
                selectedColor: AdminTheme.goldDark.withAlpha(45),
                checkmarkColor: AdminTheme.goldDark,
              ),
              // Search field
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _searchCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: AdminTheme.ink,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'ابحث برقم العمارة...',
                    hintStyle: TextStyle(
                      fontFamily: 'Cairo',
                      color: AdminTheme.mutedLight,
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AdminTheme.muted,
                      size: 18,
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
                      borderSide: BorderSide(
                        color: AdminTheme.goldDark,
                        width: 2,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            _isLoading
                ? 'جاري تحميل دليل العمارات...'
                : _selectedAreaFilter == null && _searchQuery.isEmpty &&
                        _verificationFilter == null && _activeFilter == null &&
                        !_onlyCustomerGpsPending
                    ? 'إجمالي الدليل: ${_totalBuildingCount} عمارة'
                    : 'المعروض: $_visibleBuildingCount عمارة',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              color: AdminTheme.mutedLight,
            ),
          ),
        ),
        SizedBox(height: 8),
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: AdminTheme.goldDark),
                )
              : _buildings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_city_rounded,
                        color: AdminTheme.mutedLight,
                        size: 48,
                      ),
                      SizedBox(height: 12),
                      Text(
                        _selectedAreaFilter == null && _searchQuery.isEmpty
                            ? 'اختر منطقة أو ابحث برقم العمارة'
                            : 'لا توجد عمارات مطابقة',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: AdminTheme.mutedLight,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _buildings.length,
                  itemBuilder: (context, index) {
                    final b = _buildings[index];
                    final isActive = (b['is_active'] as bool?) ?? false;
                    final isVerified = b['verified_by_admin'] != null;
                    final fromCustomerGps =
                        b['gps_submitted_at'] != null && !isVerified;
                    final hasCoords =
                        b['latitude'] != null && b['longitude'] != null;
                    return GestureDetector(
                      onTap: () => _openBuilding(b),
                      child: Container(
                        margin: EdgeInsets.only(bottom: 6),
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AdminTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive
                                ? AdminTheme.goldDark.withAlpha(77)
                                : AdminTheme.borderSoft,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AdminTheme.goldDark.withAlpha(31)
                                    : AdminTheme.surfaceSoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  b['area_letter'] as String? ?? '',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isActive
                                        ? AdminTheme.goldDark
                                        : AdminTheme.muted,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'عمارة ${b['building_number']}',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AdminTheme.ink,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      _StatusChip(
                                        label: isVerified
                                            ? 'محقق'
                                            : 'يحتاج تحقق',
                                        color: isVerified
                                            ? AppTheme.successLight
                                            : AdminTheme.goldDark,
                                      ),
                                      SizedBox(width: 4),
                                      if (hasCoords)
                                        _StatusChip(
                                          label: 'إحداثيات ✓',
                                          color: Color(0xFF64B5F6),
                                        ),
                                      if (fromCustomerGps)
                                        _StatusChip(
                                          label: 'GPS من عميل · راجع الموقع',
                                          color: AdminTheme.goldDark,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppTheme.successLight.withAlpha(26)
                                    : AdminTheme.surfaceSoft,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isActive ? 'نشط' : 'غير نشط',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11,
                                  color: isActive
                                      ? AppTheme.successLight
                                      : AdminTheme.mutedLight,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.chevron_left_rounded,
                              color: AdminTheme.muted,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final T value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;

  const _FilterDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AdminTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminTheme.borderSoft),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(
            hint,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: AdminTheme.muted,
              fontSize: 13,
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
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── BUILDING EDIT DIALOG ────────────────────────────────────────────────────

class _BuildingEditDialog extends StatefulWidget {
  final Map<String, dynamic> building;

  const _BuildingEditDialog({required this.building});

  @override
  State<_BuildingEditDialog> createState() => _BuildingEditDialogState();
}

class _BuildingEditDialogState extends State<_BuildingEditDialog> {
  late TextEditingController _addressCtrl;
  late TextEditingController _sourceMapCtrl;
  late TextEditingController _sourceUrlCtrl;
  double? _lat;
  double? _lng;
  bool _isActive = false;
  bool _isVerified = false;
  bool _isSaving = false;
  String? _message;
  bool _messageSuccess = false;
  bool _showMapPicker = false;

  @override
  void initState() {
    super.initState();
    final b = widget.building;
    _addressCtrl = TextEditingController(
      text: b['display_address'] as String? ?? '',
    );
    _sourceMapCtrl = TextEditingController(
      text: b['source_map'] as String? ?? '',
    );
    _sourceUrlCtrl = TextEditingController(
      text: b['source_url'] as String? ?? '',
    );
    _lat = (b['latitude'] as num?)?.toDouble();
    _lng = (b['longitude'] as num?)?.toDouble();
    _isActive = (b['is_active'] as bool?) ?? false;
    _isVerified = b['verified_by_admin'] != null;
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _sourceMapCtrl.dispose();
    _sourceUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Validation
    if (_isActive && (!_isVerified || _lat == null || _lng == null)) {
      setState(() {
        _message = 'لتفعيل العمارة يجب أن تكون محققة وتحتوي على إحداثيات';
        _messageSuccess = false;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _message = null;
    });
    try {
      final adminId = SupabaseService.instance.currentUser?.id;
      final data = <String, dynamic>{
        'display_address': _addressCtrl.text.trim(),
        'source_map': _sourceMapCtrl.text.trim().isEmpty
            ? null
            : _sourceMapCtrl.text.trim(),
        'source_url': _sourceUrlCtrl.text.trim().isEmpty
            ? null
            : _sourceUrlCtrl.text.trim(),
        'is_active': _isActive,
        'verified_by_admin': _isVerified ? adminId : null,
        'verification_status': _isVerified ? 'verified' : 'needs_verification',
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (_lat != null) data['latitude'] = _lat;
      if (_lng != null) data['longitude'] = _lng;

      await SupabaseService.instance.updateBuilding(
        widget.building['id'] as String,
        data,
      );
      if (mounted) {
        setState(() {
          _isSaving = false;
          _message = 'تم حفظ بيانات العمارة بنجاح ✓';
          _messageSuccess = true;
        });
        Future.delayed(Duration(milliseconds: 800), () {
          if (mounted) Navigator.pop(context, true);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _message = 'تعذر الحفظ: $e';
          _messageSuccess = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.building;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: AdminTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 560,
          constraints: BoxConstraints(maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AdminTheme.borderSoft),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AdminTheme.goldDark.withAlpha(31),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.location_city_rounded,
                        color: AdminTheme.goldDark,
                        size: 18,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'منطقة ${b['area_letter']} - عمارة ${b['building_number']}',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AdminTheme.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context, false),
                      icon: Icon(
                        Icons.close_rounded,
                        color: AdminTheme.muted,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Address
                      if (b['gps_submitted_at'] != null &&
                          b['verification_status'] != 'verified') ...[
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AdminTheme.goldDark.withAlpha(20),
                            border: Border.all(color: AdminTheme.goldDark),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'العميل اقترح موقعًا من GPS بدقة تقريبية '
                            '${b['gps_accuracy_m'] ?? 'غير معروفة'} متر. '
                            'راجع النقطة على الخريطة وتأكد من حرف المنطقة '
                            'ورقم العمارة بنفسك، وبعدها فعل «محقق» و«نشط». '
                            'إحداثيات الاقتراح: '
                            '${b['gps_suggested_latitude']}, '
                            '${b['gps_suggested_longitude']}.',
                            style: TextStyle(fontFamily: 'Cairo',
                                color: AdminTheme.ink, fontSize: 12),
                          ),
                        ),
                        if (b['gps_suggested_latitude'] != null &&
                            b['gps_suggested_longitude'] != null)
                          TextButton.icon(
                            onPressed: () => setState(() {
                              _lat = (b['gps_suggested_latitude'] as num).toDouble();
                              _lng = (b['gps_suggested_longitude'] as num).toDouble();
                            }),
                            icon: Icon(Icons.location_on_outlined),
                            label: Text('استخدام إحداثيات اقتراح العميل',
                                style: TextStyle(fontFamily: 'Cairo')),
                          ),
                        SizedBox(height: 12),
                      ],
                      // Address
                      _buildLabel('العنوان'),
                      SizedBox(height: 6),
                      TextField(
                        controller: _addressCtrl,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: AdminTheme.ink,
                        ),
                        decoration: _inputDecoration(
                          'مثال: منطقة أ - عمارة 70، حدائق الأهرام',
                        ),
                      ),
                      SizedBox(height: 14),
                      // Source info
                      _buildLabel('مصدر الخريطة (اختياري)'),
                      SizedBox(height: 6),
                      TextField(
                        controller: _sourceMapCtrl,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: AdminTheme.ink,
                          fontSize: 13,
                        ),
                        decoration: _inputDecoration('مثال: Google Maps'),
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: _sourceUrlCtrl,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: AdminTheme.ink,
                          fontSize: 13,
                        ),
                        decoration: _inputDecoration('رابط المصدر (اختياري)'),
                      ),
                      SizedBox(height: 16),
                      // Coordinates section
                      Row(
                        children: [
                          _buildLabel('الإحداثيات'),
                          Spacer(),
                          if (_lat != null && _lng != null)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AdminTheme.goldDark.withAlpha(26),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11,
                                  color: AdminTheme.goldDark,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 8),
                      // Map picker toggle
                      GestureDetector(
                        onTap: () =>
                            setState(() => _showMapPicker = !_showMapPicker),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _showMapPicker
                                ? AdminTheme.goldDark.withAlpha(20)
                                : AdminTheme.surfaceSoft,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _showMapPicker
                                  ? AdminTheme.goldDark
                                  : AdminTheme.borderSoft,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.map_rounded,
                                color: _showMapPicker
                                    ? AdminTheme.goldDark
                                    : AdminTheme.muted,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                _showMapPicker
                                    ? 'إخفاء الخريطة'
                                    : 'فتح الخريطة لتحديد الموقع',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 13,
                                  color: _showMapPicker
                                      ? AdminTheme.goldDark
                                      : AdminTheme.ink,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Spacer(),
                              Icon(
                                _showMapPicker
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: AdminTheme.muted,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_showMapPicker) ...[
                        SizedBox(height: 10),
                        _RealMapPicker(
                          initialLat: _lat ?? 29.9792,
                          initialLng: _lng ?? 31.1342,
                          onLocationSelected: (lat, lng) {
                            setState(() {
                              _lat = lat;
                              _lng = lng;
                            });
                          },
                        ),
                        SizedBox(height: 6),
                        Text(
                          'اضغط على الخريطة لتحديد موقع العمارة. يمكنك التكبير والتصغير والتحريك.',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            color: AdminTheme.mutedLight,
                          ),
                        ),
                      ],
                      SizedBox(height: 16),
                      // Toggles
                      Row(
                        children: [
                          Expanded(
                            child: _buildToggle(
                              'تم التحقق',
                              _isVerified,
                              (v) => setState(() => _isVerified = v),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildToggle(
                              'تفعيل العمارة',
                              _isActive,
                              (v) => setState(() => _isActive = v),
                            ),
                          ),
                        ],
                      ),
                      if (_isActive &&
                          (!_isVerified || _lat == null || _lng == null))
                        Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AdminTheme.error.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AdminTheme.error.withAlpha(77),
                              ),
                            ),
                            child: Text(
                              '⚠️ لتفعيل العمارة يجب: تحديد الموقع على الخريطة + تفعيل التحقق',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11,
                                color: AdminTheme.error,
                              ),
                            ),
                          ),
                        ),
                      if (_message != null) ...[
                        SizedBox(height: 12),
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _messageSuccess
                                ? AppTheme.successLight.withAlpha(26)
                                : AdminTheme.error.withAlpha(26),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _message!,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: _messageSuccess
                                  ? AppTheme.successLight
                                  : AdminTheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Save button
              Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
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
                            'حفظ التغييرات',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AdminTheme.ink,
      ),
    );
  }

  Widget _buildToggle(String label, bool value, void Function(bool) onChanged) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AdminTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminTheme.borderSoft),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              color: AdminTheme.ink,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AdminTheme.goldDark,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontFamily: 'Cairo',
        color: AdminTheme.mutedLight,
        fontSize: 12,
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
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

// ─── REAL MAP PICKER ─────────────────────────────────────────────────────────

class _RealMapPicker extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final void Function(double lat, double lng) onLocationSelected;

  const _RealMapPicker({
    required this.initialLat,
    required this.initialLng,
    required this.onLocationSelected,
  });

  @override
  State<_RealMapPicker> createState() => _RealMapPickerState();
}

class _RealMapPickerState extends State<_RealMapPicker> {
  late LatLng _selectedPoint;
  late MapController _mapController;

  @override
  void initState() {
    super.initState();
    _selectedPoint = LatLng(widget.initialLat, widget.initialLng);
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _onTap(TapPosition tapPosition, LatLng point) {
    setState(() => _selectedPoint = point);
    widget.onLocationSelected(point.latitude, point.longitude);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 280,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _selectedPoint,
                initialZoom: 16.0,
                onTap: _onTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.vetosanya.app',
                  maxZoom: 19,
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedPoint,
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AdminTheme.goldDark.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AdminTheme.goldDark.withAlpha(77)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                color: AdminTheme.goldDark,
                size: 16,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'الموقع المحدد: ${_selectedPoint.latitude.toStringAsFixed(6)}, ${_selectedPoint.longitude.toStringAsFixed(6)}',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: AdminTheme.goldDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
