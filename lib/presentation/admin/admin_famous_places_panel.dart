import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/supabase_service.dart';
import '../../widgets/place_category_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/admin_theme.dart';

class AdminFamousPlacesPanel extends StatefulWidget {
  const AdminFamousPlacesPanel({super.key});

  @override
  State<AdminFamousPlacesPanel> createState() => _AdminFamousPlacesPanelState();
}

class _AdminFamousPlacesPanelState extends State<AdminFamousPlacesPanel> {
  List<Map<String, dynamic>> _places = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await SupabaseService.instance.getAllFamousPlaces();
      if (mounted) {
        setState(() {
          _places = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'تعذر تحميل الأماكن: $e';
        });
      }
    }
  }

  Future<void> _addOrEditPlace([Map<String, dynamic>? existing]) async {
    await showDialog(
      context: context,
      builder: (ctx) => _PlaceFormDialog(
        existing: existing,
        onSaved: () {
          Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }

  Future<void> _toggleActive(String placeId, bool current) async {
    try {
      await SupabaseService.instance.updateFamousPlace(placeId, {
        'is_active': !current,
      });
      _load();
    } catch (_) {}
  }

  Future<void> _delete(String placeId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AdminTheme.surface,
          title: Text(
            'حذف المكان',
            style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
          ),
          content: Text(
            'هل أنت متأكد من حذف هذا المكان؟',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: AdminTheme.muted,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'إلغاء',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: AdminTheme.muted,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.error,
                foregroundColor: Colors.white,
              ),
              child: Text('حذف', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
    if (confirm == true) {
      try {
        await SupabaseService.instance.deleteFamousPlace(placeId);
        _load();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(
            children: [
              Text(
                'الأماكن المشهورة',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AdminTheme.ink,
                ),
              ),
              Spacer(),
              OutlinedButton.icon(
                onPressed: () async {
                  await showDialog(context: context,
                    builder: (_) => _CategoryManagerDialog());
                  if (mounted) _load();
                },
                icon: Icon(Icons.category_rounded),
                label: Text('إدارة الفئات', style: TextStyle(fontFamily:'Cairo')),
              ),
              SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _addOrEditPlace(),
                icon: Icon(Icons.add_rounded, size: 18),
                label: Text(
                  'إضافة مكان',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.goldDark,
                  foregroundColor: AppTheme.primary,
                ),
              ),
              SizedBox(width: 8),
              IconButton(
                onPressed: _load,
                icon: Icon(Icons.refresh_rounded, color: AdminTheme.goldDark),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: AdminTheme.goldDark),
                )
              : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: AdminTheme.error,
                    ),
                  ),
                )
              : _places.isEmpty
              ? Center(
                  child: Text(
                    'لا توجد أماكن مشهورة مضافة حاليًا',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: AdminTheme.mutedLight,
                      fontSize: 15,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _places.length,
                  separatorBuilder: (_, __) => SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final p = _places[index];
                    final isActive = (p['is_active'] as bool?) ?? false;
                    final hasCoords =
                        p['latitude'] != null && p['longitude'] != null;
                    return Container(
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AdminTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AdminTheme.borderSoft),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AdminTheme.goldDark.withAlpha(31),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.place_rounded,
                              color: AdminTheme.goldDark,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (p['name'] as String?) ?? '',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AdminTheme.ink,
                                  ),
                                ),
                                if (p['address'] != null)
                                  Text(
                                    p['address'] as String,
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 12,
                                      color: AdminTheme.muted,
                                    ),
                                  ),
                                if (hasCoords)
                                  Text(
                                    '${(p['latitude'] as num).toStringAsFixed(4)}, ${(p['longitude'] as num).toStringAsFixed(4)}',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 10,
                                      color: AdminTheme.goldDark,
                                    ),
                                  )
                                else
                                  Text(
                                    'لا توجد إحداثيات',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 10,
                                      color: AdminTheme.error,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Switch(
                            value: isActive,
                            onChanged: (_) =>
                                _toggleActive(p['id'] as String, isActive),
                            activeThumbColor: AdminTheme.goldDark,
                          ),
                          IconButton(
                            onPressed: () => _addOrEditPlace(p),
                            icon: Icon(
                              Icons.edit_rounded,
                              color: AdminTheme.muted,
                              size: 18,
                            ),
                          ),
                          IconButton(
                            onPressed: () => _delete(p['id'] as String),
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: AdminTheme.error,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─── PLACE FORM DIALOG ───────────────────────────────────────────────────────

class _PlaceFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;

  const _PlaceFormDialog({this.existing, required this.onSaved});

  @override
  State<_PlaceFormDialog> createState() => _PlaceFormDialogState();
}

class _PlaceFormDialogState extends State<_PlaceFormDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _addressCtrl;
  double? _lat;
  double? _lng;
  bool _isActive = true;
  String _category = 'other';
  List<Map<String,dynamic>> _categoryOptions = [];
  bool _isSaving = false;
  String? _message;
  bool _messageSuccess = false;
  bool _showMapPicker = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?['name'] as String? ?? '');
    _descCtrl = TextEditingController(text: e?['description'] as String? ?? '');
    _addressCtrl = TextEditingController(text: e?['address'] as String? ?? '');
    _lat = (e?['latitude'] as num?)?.toDouble();
    _lng = (e?['longitude'] as num?)?.toDouble();
    _isActive = (e?['is_active'] as bool?) ?? true;
    _category = e?['category']?.toString() ?? 'other';
    _loadCategoryOptions();
  }

  Future<void> _loadCategoryOptions() async {
    try {
      final values = await SupabaseService.instance.getPlaceCategoriesV21(admin:true);
      if (!mounted) return;
      setState(() => _categoryOptions = values);
    } catch (_) {
      if (mounted) setState(() => _message = 'فشل تحميل الفئات، تحقق من تطبيق SQL V21.');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() {
        _message = 'من فضلك أدخل اسم المكان';
        _messageSuccess = false;
      });
      return;
    }
    setState(() {
      _isSaving = true;
      _message = null;
    });
    try {
      final user = SupabaseService.instance.currentUser;
      if (_isEditing) {
        await SupabaseService.instance
            .updateFamousPlace(widget.existing!['id'] as String, {
              'name': _nameCtrl.text.trim(),
              'description': _descCtrl.text.trim().isNotEmpty
                  ? _descCtrl.text.trim()
                  : null,
              'address': _addressCtrl.text.trim().isNotEmpty
                  ? _addressCtrl.text.trim()
                  : null,
              if (_lat != null) 'latitude': _lat,
              if (_lng != null) 'longitude': _lng,
              'is_active': _isActive,
              'category': _category,
            });
      } else {
        await SupabaseService.instance.addFamousPlace(
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isNotEmpty
              ? _descCtrl.text.trim()
              : null,
          address: _addressCtrl.text.trim().isNotEmpty
              ? _addressCtrl.text.trim()
              : null,
          latitude: _lat,
          longitude: _lng,
          createdBy: user?.id ?? '',
          category: _category,
        );
      }
      if (mounted) {
        setState(() {
          _isSaving = false;
          _message = _isEditing
              ? 'تم تحديث المكان بنجاح ✓'
              : 'تم إضافة المكان بنجاح ✓';
          _messageSuccess = true;
        });
        Future.delayed(Duration(milliseconds: 800), () {
          if (mounted) widget.onSaved();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _message = 'تعذر حفظ البيانات: $e';
          _messageSuccess = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showMapPicker) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: AdminTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            width: 520,
            height: 520,
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AdminTheme.borderSoft),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.map_rounded,
                        color: AdminTheme.goldDark,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'اختر موقع المكان على الخريطة',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AdminTheme.ink,
                        ),
                      ),
                      Spacer(),
                      IconButton(
                        onPressed: () => setState(() => _showMapPicker = false),
                        icon: Icon(
                          Icons.close_rounded,
                          color: AdminTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _RealMapPicker(
                    initialLat: _lat ?? 29.9792,
                    initialLng: _lng ?? 31.1342,
                    onLocationSelected: (lat, lng) {
                      setState(() {
                        _lat = lat;
                        _lng = lng;
                        _showMapPicker = false;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: AdminTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 480,
          constraints: BoxConstraints(maxHeight: 580),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AdminTheme.borderSoft),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.place_rounded,
                      color: AdminTheme.goldDark,
                      size: 22,
                    ),
                    SizedBox(width: 10),
                    Text(
                      _isEditing ? 'تعديل المكان' : 'إضافة مكان مشهور',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AdminTheme.ink,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
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
                    children: [
                      _buildField(_nameCtrl, 'اسم المكان *'),
                      SizedBox(height: 12),
                      _buildField(_descCtrl, 'الوصف (اختياري)'),
                      SizedBox(height: 12),
                      _buildField(_addressCtrl, 'العنوان (اختياري)'),
                      SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _category,
                        decoration: InputDecoration(labelText: 'فئة المكان',
                          labelStyle: TextStyle(fontFamily:'Cairo')),
                        items: [
                          if (!_categoryOptions.any((c) => c['slug'] == _category))
                            DropdownMenuItem(value: _category,
                              child: Text(_category, style: TextStyle(fontFamily:'Cairo'))),
                          ..._categoryOptions.map((cat) => DropdownMenuItem<String>(
                            value: cat['slug']?.toString() ?? '',
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(PlaceCategoryIcons.get(cat['icon_key']?.toString()),
                                color: AdminTheme.goldDark, size: 16),
                              SizedBox(width: 8),
                              Text(cat['title']?.toString() ?? '', style: TextStyle(fontFamily:'Cairo')),
                            ]),
                          )),
                        ],
                        onChanged: (v) { if(v!=null) setState(()=>_category=v); },
                      ),
                      SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'تحديد الموقع على الخريطة',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AdminTheme.ink,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      // Show selected coordinates
                      if (_lat != null && _lng != null)
                        Container(
                          padding: EdgeInsets.all(8),
                          margin: EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: AdminTheme.goldDark.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AdminTheme.goldDark.withAlpha(77),
                            ),
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
                                  'الموقع: ${_lat!.toStringAsFixed(6)}, ${_lng!.toStringAsFixed(6)}',
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
                      // Map picker button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              setState(() => _showMapPicker = true),
                          icon: Icon(
                            Icons.map_rounded,
                            color: AdminTheme.goldDark,
                            size: 18,
                          ),
                          label: Text(
                            _lat != null
                                ? 'تغيير الموقع على الخريطة'
                                : 'اختر الموقع من الخريطة',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: AdminTheme.goldDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AdminTheme.goldDark),
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'تفعيل المكان',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              color: AdminTheme.ink,
                            ),
                          ),
                          Spacer(),
                          Switch(
                            value: _isActive,
                            onChanged: (v) => setState(() => _isActive = v),
                            activeThumbColor: AdminTheme.goldDark,
                          ),
                        ],
                      ),
                      if (_message != null)
                        Container(
                          padding: EdgeInsets.all(10),
                          margin: EdgeInsets.only(top: 8),
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
                  ),
                ),
              ),
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
                            _isEditing ? 'حفظ التعديلات' : 'إضافة المكان',
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

  Widget _buildField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
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
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }
}

// ─── REAL MAP PICKER ─────────────────────────────────────────────────────────
// Admin taps any point on the real OSM map to select coordinates.
// Replaces the old manual text-field coordinate picker.

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
  late double _selectedLat;
  late double _selectedLng;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _selectedLat = widget.initialLat;
    _selectedLng = widget.initialLng;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(_selectedLat, _selectedLng),
              initialZoom: 15.0,
              minZoom: 5.0,
              maxZoom: 19.0,
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedLat = point.latitude;
                  _selectedLng = point.longitude;
                });
              },
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
                    point: LatLng(_selectedLat, _selectedLng),
                    width: 44,
                    height: 54,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AdminTheme.goldDark,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AdminTheme.goldDark.withAlpha(128),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.place_rounded,
                            color: AppTheme.primary,
                            size: 20,
                          ),
                        ),
                        Container(width: 2, height: 10, color: AdminTheme.goldDark),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AdminTheme.surface,
            border: Border(top: BorderSide(color: AdminTheme.borderSoft)),
          ),
          child: Column(
            children: [
              Text(
                'اضغط على الخريطة لتحديد الموقع',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: AdminTheme.muted,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '${_selectedLat.toStringAsFixed(6)}, ${_selectedLng.toStringAsFixed(6)}',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  color: AdminTheme.goldDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      widget.onLocationSelected(_selectedLat, _selectedLng),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.goldDark,
                    foregroundColor: AppTheme.primary,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'حفظ الموقع',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w700,
                    ),
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


/// Category slugs are immutable; titles, icons, order and visibility can change.
class _CategoryManagerDialog extends StatefulWidget {
  _CategoryManagerDialog();
  @override
  State<_CategoryManagerDialog> createState() => _CategoryManagerDialogState();
}

class _CategoryManagerDialogState extends State<_CategoryManagerDialog> {
  List<Map<String,dynamic>> _rows = [];
  String? _error;
  bool _busy = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final data = await SupabaseService.instance.getPlaceCategoriesV21(admin:true);
      if (mounted) setState(() { _rows = data; _error = null; _busy = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'تعذر تحميل الفئات: $e'; _busy = false; });
    }
  }

  Future<void> _edit([Map<String,dynamic>? original]) async {
    final slug = TextEditingController(text: original?['slug']?.toString() ?? '');
    final title = TextEditingController(text: original?['title']?.toString() ?? '');
    final order = TextEditingController(text: original?['sort_order']?.toString() ?? '100');
    var iconKey = original?['icon_key']?.toString() ?? 'place';
    if (!PlaceCategoryIcons.icons.containsKey(iconKey)) iconKey = 'place';
    var active = original?['is_active'] != false;
    String? formError;
    var saving = false;
    await showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => AlertDialog(
        title: Text(original == null ? 'إضافة فئة' : 'تعديل فئة',
          style: TextStyle(fontFamily:'Cairo')),
        content: ConstrainedBox(constraints: BoxConstraints(maxWidth: 390),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller:slug, enabled: original == null && !saving,
              decoration: InputDecoration(labelText:'رمز الفئة بالإنجليزية (مثال: hotel)'),
              style: TextStyle(fontFamily:'Cairo')),
            TextField(controller:title, enabled: !saving,
              decoration: InputDecoration(labelText:'الاسم الذي يراه العميل'),
              style: TextStyle(fontFamily:'Cairo')),
            TextField(controller:order, enabled: !saving, keyboardType:TextInputType.number,
              decoration: InputDecoration(labelText:'الترتيب (من 0 إلى 10000)'),
              style: TextStyle(fontFamily:'Cairo')),
            SizedBox(height: 10),
            DropdownButtonFormField<String>(value: iconKey,
              decoration:InputDecoration(labelText:'الأيقونة'),
              items:PlaceCategoryIcons.icons.entries.map((entry) => DropdownMenuItem(
                value:entry.key, child: Row(mainAxisSize:MainAxisSize.min,children:[
                  Icon(entry.value,color:AdminTheme.goldDark),SizedBox(width:8),
                  Text(entry.key,style:TextStyle(fontFamily:'Cairo'))]))).toList(),
              onChanged:saving ? null : (v) { if(v!=null) update(()=>iconKey=v); }),
            SwitchListTile(title:Text('الفئة ظاهرة للعميل',style:TextStyle(fontFamily:'Cairo')),
              value:active, onChanged:saving?null:(v)=>update(()=>active=v)),
            if(formError!=null) Text(formError!,style:TextStyle(color:Colors.redAccent)),
          ]))),
        actions:[
          TextButton(onPressed:saving?null:()=>Navigator.pop(ctx),child:Text('إلغاء')),
          FilledButton(onPressed:saving?null:() async {
            final key=slug.text.trim(); final name=title.text.trim();
            final position=int.tryParse(order.text.trim());
            if(key=='all' || !RegExp(r'^[a-z][a-z0-9_]{1,31}$').hasMatch(key) || name.length<2 ||
               name.length>55 || position==null || position<0 || position>10000) {
              update(()=>formError='راجع رمز الفئة والاسم والترتيب.'); return;
            }
            update(() {saving=true;formError=null;});
            try {
              await SupabaseService.instance.savePlaceCategoryV21(
                slug:key,title:name,iconKey:iconKey,sortOrder:position,
                active:active,existing:original!=null);
              if(ctx.mounted) Navigator.pop(ctx);
            } catch(e) { if(ctx.mounted) update(() {formError='لم تُحفظ الفئة: $e';saving=false;}); }
          }, child:Text('حفظ')),
        ],
      ),
    ));
    slug.dispose(); title.dispose(); order.dispose();
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title:Text('إدارة فئات الأماكن',style:TextStyle(fontFamily:'Cairo')),
    content: SizedBox(width:420,height:450,child:Column(children:[
      if(_error!=null) Text(_error!,style:TextStyle(color:Colors.redAccent)),
      if(_busy) LinearProgressIndicator(),
      Expanded(child:ListView.builder(itemCount:_rows.length,itemBuilder:(ctx,i){
        final cat=_rows[i];
        return ListTile(
          leading:Icon(PlaceCategoryIcons.get(cat['icon_key']?.toString()),color:AdminTheme.goldDark),
          title:Text(cat['title']?.toString() ?? '',style:TextStyle(fontFamily:'Cairo')),
          subtitle:Text('${cat['slug']} • ${cat['is_active']==true?'ظاهر':'مخفي'}',
            style:TextStyle(fontFamily:'Cairo',fontSize:11)),
          trailing:Icon(Icons.edit_outlined),onTap:()=>_edit(cat));
      })),
    ])),
    actions:[
      TextButton(onPressed:()=>Navigator.pop(context),child:Text('إغلاق')),
      FilledButton.icon(onPressed:()=>_edit(),icon:Icon(Icons.add),
        label:Text('إضافة فئة')),
    ],
  );
}
