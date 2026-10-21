import 'package:flutter/material.dart';
import 'admin_captain_actions_v10.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/supabase_service.dart';
import '../../theme/admin_theme.dart';

class AdminCaptainFormPanel extends StatefulWidget {
  final Map<String, dynamic>? existingCaptain;

  /// V16: reuse this exact admin form to promote an existing customer.
  final Map<String, dynamic>? customerToPromote;
  final VoidCallback onSaved;

  const AdminCaptainFormPanel({
    super.key,
    this.existingCaptain,
    this.customerToPromote,
    required this.onSaved,
  });

  @override
  State<AdminCaptainFormPanel> createState() => _AdminCaptainFormPanelState();
}

class _AdminCaptainFormPanelState extends State<AdminCaptainFormPanel> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _brandCtrl;
  late TextEditingController _modelCtrl;
  late TextEditingController _yearCtrl;
  late TextEditingController _colorCtrl;
  late TextEditingController _plateCtrl;
  late TextEditingController _marketShareCtrl;
  late TextEditingController _commissionCtrl;

  String _vehicleType = 'car';
  String _captainStatus = 'active';
  bool _isOnline = false;
  bool _isAvailable = false;

  bool _canDoCarRide = false;
  bool _canDoMotorcycleRide = false;
  bool _canDoPackage = false;
  bool _canDoVitoMarket = false;

  bool _isSaving = false;
  String? _saveMessage;
  bool _saveSuccess = false;
  XFile? _profilePhoto;
  XFile? _vehiclePhoto;

  bool get _isEditing => widget.existingCaptain != null;
  bool get _isPromoting => widget.customerToPromote != null;

  @override
  void initState() {
    super.initState();
    final c = widget.existingCaptain ?? widget.customerToPromote;
    _commissionCtrl = TextEditingController(
      text: c?['custom_commission']?.toString() ?? '',
    );
    _nameCtrl = TextEditingController(text: c?['full_name'] as String? ?? '');
    _phoneCtrl = TextEditingController(text: c?['phone'] as String? ?? '');
    _brandCtrl = TextEditingController(
      text: c?['vehicle_brand'] as String? ?? '',
    );
    _modelCtrl = TextEditingController(
      text: c?['vehicle_model'] as String? ?? '',
    );
    _yearCtrl = TextEditingController(
      text: c?['vehicle_year']?.toString() ?? '',
    );
    _colorCtrl = TextEditingController(
      text: c?['vehicle_color'] as String? ?? '',
    );
    _plateCtrl = TextEditingController(
      text: c?['vehicle_plate'] as String? ?? '',
    );
    _marketShareCtrl = TextEditingController(
      text:
          (100 -
                  ((c?['market_delivery_share_percent'] as num?)?.toDouble() ??
                      100))
              .clamp(0, 100)
              .toString(),
    );

    if (c != null) {
      _vehicleType = c['vehicle_type'] as String? ?? 'car';
      _captainStatus = c['captain_status'] as String? ?? 'active';
      _isOnline = c['is_online'] as bool? ?? false;
      _isAvailable = c['is_available'] as bool? ?? false;
      _canDoCarRide = c['can_do_car_ride'] as bool? ?? false;
      _canDoMotorcycleRide = c['can_do_motorcycle_ride'] as bool? ?? false;
      _canDoPackage = c['can_do_package'] as bool? ?? false;
      _canDoVitoMarket = c['can_do_vito_market'] as bool? ?? false;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _colorCtrl.dispose();
    _plateCtrl.dispose();
    _marketShareCtrl.dispose();
    _commissionCtrl.dispose();
    super.dispose();
  }

  /// When vehicle type changes, auto-clear incompatible service flags
  void _onVehicleTypeChanged(String newType) {
    setState(() {
      _vehicleType = newType;
      // car_ride is only valid for car
      if (newType != 'car' && _canDoCarRide) {
        _canDoCarRide = false;
      }
      // motorcycle_ride is only valid for motorcycle
      if (newType != 'motorcycle' && _canDoMotorcycleRide) {
        _canDoMotorcycleRide = false;
      }
    });
  }

  Future<void> _pickPhoto({required bool vehicle}) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1400,
    );
    if (file != null && mounted)
      setState(() => vehicle ? _vehiclePhoto = file : _profilePhoto = file);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final commission = double.tryParse(_commissionCtrl.text.trim());
    if (_commissionCtrl.text.trim().isNotEmpty &&
        (commission == null ||
            !commission.isFinite ||
            commission < 0 ||
            commission > 100)) {
      setState(
        () => _saveMessage =
            'اكتب عمولة بين 0 و100، أو اترك الحقل فارغًا للعمولة العامة.',
      );
      return;
    }
    final marketShare = double.tryParse(_marketShareCtrl.text.trim());
    if (marketShare == null || marketShare < 0 || marketShare > 100) {
      setState(() {
        _saveMessage =
            'عمولة الشركة من توصيل فيتو ماركت يجب أن تكون بين 0 و100%.';
        _saveSuccess = false;
      });
      return;
    }

    // Client-side vehicle-type compatibility check (mirrors backend validation)
    if (_canDoCarRide && _vehicleType != 'car') {
      setState(() {
        _saveMessage = 'خدمة مشوار سيارة تتطلب نوع مركبة: سيارة.';
        _saveSuccess = false;
      });
      return;
    }
    if (_canDoMotorcycleRide && _vehicleType != 'motorcycle') {
      setState(() {
        _saveMessage = 'خدمة مشوار موتوسيكل تتطلب نوع مركبة: موتوسيكل.';
        _saveSuccess = false;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _saveMessage = null;
    });

    try {
      final phone = _phoneCtrl.text.trim();

      if (_isEditing) {
        // Update existing captain
        await SupabaseService.instance
            .updateCaptain(widget.existingCaptain!['id'] as String, {
              'custom_commission': _commissionCtrl.text.trim().isEmpty
                  ? null
                  : double.parse(_commissionCtrl.text.trim()),
              'full_name': _nameCtrl.text.trim(),
              'phone': phone,
              'vehicle_type': _vehicleType,
              'vehicle_brand': _brandCtrl.text.trim().isNotEmpty
                  ? _brandCtrl.text.trim()
                  : null,
              'vehicle_model': _modelCtrl.text.trim().isNotEmpty
                  ? _modelCtrl.text.trim()
                  : null,
              'vehicle_year': _yearCtrl.text.trim().isNotEmpty
                  ? int.tryParse(_yearCtrl.text.trim())
                  : null,
              'vehicle_color': _colorCtrl.text.trim().isNotEmpty
                  ? _colorCtrl.text.trim()
                  : null,
              'vehicle_plate': _plateCtrl.text.trim().isNotEmpty
                  ? _plateCtrl.text.trim()
                  : null,
              'captain_status': _captainStatus,
              'is_online': _isOnline,
              'is_available': _isAvailable,
              'can_do_car_ride': _canDoCarRide,
              'can_do_motorcycle_ride': _canDoMotorcycleRide,
              'can_do_package': _canDoPackage,
              'can_do_vito_market': _canDoVitoMarket,
            });
        if (_profilePhoto != null) {
          final url = await SupabaseService.instance.uploadPublicImage(
            path: 'captains/${widget.existingCaptain!['id']}/profile.jpg',
            bytes: await _profilePhoto!.readAsBytes(),
            contentType: 'image/jpeg',
          );
          await SupabaseService.instance.updateCaptain(
            widget.existingCaptain!['id'] as String,
            {'profile_photo': url},
          );
        }
        if (_vehiclePhoto != null) {
          final url = await SupabaseService.instance.uploadPublicImage(
            path: 'captains/${widget.existingCaptain!['id']}/vehicle.jpg',
            bytes: await _vehiclePhoto!.readAsBytes(),
            contentType: 'image/jpeg',
          );
          await SupabaseService.instance.updateCaptain(
            widget.existingCaptain!['id'] as String,
            {'vehicle_photo': url},
          );
        }
        await _saveMarketShare(
          widget.existingCaptain!['id'].toString(),
          marketShare,
        );
        if (mounted) {
          setState(() {
            _isSaving = false;
            _saveMessage = 'تم تحديث بيانات الكابتن بنجاح ✓';
            _saveSuccess = true;
          });
          widget.onSaved();
        }
      } else if (_isPromoting) {
        // Retain the customer's auth UUID, customer ID, wallet and trip history.
        // The SQL RPC inserts a captain for the SAME user_id atomically.
        final result = await SupabaseService.instance.adminPromoteCustomerV16(
          customerId: widget.customerToPromote!['id'].toString(),
          fullName: _nameCtrl.text.trim(),
          vehicleType: _vehicleType,
          vehicleBrand: _brandCtrl.text.trim(),
          vehicleModel: _modelCtrl.text.trim(),
          vehicleYear: int.tryParse(_yearCtrl.text.trim()),
          vehicleColor: _colorCtrl.text.trim(),
          vehiclePlate: _plateCtrl.text.trim(),
          captainStatus: _captainStatus,
          canDoCarRide: _canDoCarRide,
          canDoMotorcycleRide: _canDoMotorcycleRide,
          canDoPackage: _canDoPackage,
          canDoVitoMarket: _canDoVitoMarket,
        );
        if (result['success'] != true) {
          throw Exception(result['error'] ?? 'customer_promotion_failed');
        }
        final captainId = result['captain_id']?.toString();
        if (captainId != null) await _saveMarketShare(captainId, marketShare);
        // Promotion is already committed. An optional photo upload failure
        // must not present the entire conversion as failed and invite a retry.
        try {
          // Inherit the existing customer's profile photo by URL only when
          // the owner did not select a new one; no account/image deletion.
          final currentCustomerPhoto = widget.customerToPromote?['profile_photo_url']?.toString();
          if (captainId != null && _profilePhoto == null &&
              currentCustomerPhoto != null && currentCustomerPhoto.startsWith('https://')) {
            await SupabaseService.instance.updateCaptain(captainId, {
              'profile_photo': currentCustomerPhoto,
              'profile_photo_url': currentCustomerPhoto,
            });
          }
          if (captainId != null && _profilePhoto != null) {
            final url = await SupabaseService.instance.uploadPublicImage(
              path:
                  'captains/$captainId/profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
              bytes: await _profilePhoto!.readAsBytes(),
              contentType: 'image/jpeg',
            );
            await SupabaseService.instance.updateCaptain(captainId, {
              'profile_photo': url,
              'profile_photo_url': url,
            });
          }
          if (captainId != null && _vehiclePhoto != null) {
            final url = await SupabaseService.instance.uploadPublicImage(
              path:
                  'captains/$captainId/vehicle_${DateTime.now().millisecondsSinceEpoch}.jpg',
              bytes: await _vehiclePhoto!.readAsBytes(),
              contentType: 'image/jpeg',
            );
            await SupabaseService.instance.updateCaptain(captainId, {
              'vehicle_photo': url,
              'vehicle_photo_url': url,
            });
          }
        } catch (photoError) {
          // Images can be added later through the existing captain edit form.
          debugPrint(
            'V16: optional promotion photo upload failed: $photoError',
          );
        }
        if (mounted) {
          setState(() {
            _isSaving = false;
            _saveSuccess = true;
            _saveMessage = 'تم تحويل العميل لكابتن بنفس الحساب ✓';
          });
          widget.onSaved();
        }
      } else {
        // Create new captain via Edge Function (handles auth user creation server-side)
        // The Edge Function also validates vehicle-type compatibility
        final result = await SupabaseService.instance
            .createCaptainViaEdgeFunction(
              fullName: _nameCtrl.text.trim(),
              phone: phone,
              vehicleType: _vehicleType,
              vehicleBrand: _brandCtrl.text.trim().isNotEmpty
                  ? _brandCtrl.text.trim()
                  : null,
              vehicleModel: _modelCtrl.text.trim().isNotEmpty
                  ? _modelCtrl.text.trim()
                  : null,
              vehicleYear: _yearCtrl.text.trim().isNotEmpty
                  ? _yearCtrl.text.trim()
                  : null,
              vehicleColor: _colorCtrl.text.trim().isNotEmpty
                  ? _colorCtrl.text.trim()
                  : null,
              vehiclePlate: _plateCtrl.text.trim().isNotEmpty
                  ? _plateCtrl.text.trim()
                  : null,
              captainStatus: _captainStatus,
              canDoCarRide: _canDoCarRide,
              canDoMotorcycleRide: _canDoMotorcycleRide,
              canDoPackage: _canDoPackage,
              canDoVitoMarket: _canDoVitoMarket,
            );

        if (result['success'] == true) {
          final created = result['captain'] as Map<String, dynamic>?;
          final createdId = created?['id']?.toString();
          if (createdId != null) await _saveMarketShare(createdId, marketShare);
          if (createdId != null && _profilePhoto != null) {
            final url = await SupabaseService.instance.uploadPublicImage(
              path: 'captains/$createdId/profile.jpg',
              bytes: await _profilePhoto!.readAsBytes(),
              contentType: 'image/jpeg',
            );
            await SupabaseService.instance.updateCaptain(createdId, {
              'profile_photo': url,
            });
          }
          if (createdId != null && _vehiclePhoto != null) {
            final url = await SupabaseService.instance.uploadPublicImage(
              path: 'captains/$createdId/vehicle.jpg',
              bytes: await _vehiclePhoto!.readAsBytes(),
              contentType: 'image/jpeg',
            );
            await SupabaseService.instance.updateCaptain(createdId, {
              'vehicle_photo': url,
            });
          }
        }
        if (mounted) {
          if (result['success'] == true) {
            setState(() {
              _isSaving = false;
              _saveMessage = 'تم إنشاء الكابتن بنجاح ✓';
              _saveSuccess = true;
            });
            // Clear form
            _nameCtrl.clear();
            _phoneCtrl.clear();
            _brandCtrl.clear();
            _modelCtrl.clear();
            _yearCtrl.clear();
            _colorCtrl.clear();
            _plateCtrl.clear();
            setState(() {
              _vehicleType = 'car';
              _captainStatus = 'active';
              _canDoCarRide = false;
              _canDoMotorcycleRide = false;
              _canDoPackage = false;
              _canDoVitoMarket = false;
              _profilePhoto = null;
              _vehiclePhoto = null;
              _marketShareCtrl.text = '0';
            });
            widget.onSaved();
          } else {
            setState(() {
              _isSaving = false;
              _saveMessage = result['error'] as String? ?? 'تعذر إنشاء الكابتن';
              _saveSuccess = false;
            });
          }
        }
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

  Future<void> _saveMarketShare(String captainId, double percent) async {
    final raw = await SupabaseService.instance.client.rpc(
      'admin_set_captain_market_share_v7',
      // Keep the server's existing captain-share storage contract unchanged.
      params: {'p_captain_id': captainId, 'p_percent': 100 - percent},
    );
    final result = Map<String, dynamic>.from((raw as Map?) ?? {});
    if (result['success'] != true) {
      throw Exception(result['error'] ?? 'market_share_update_failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            MediaQuery.sizeOf(context).width < 520 ? 12 : 24,
            16,
            MediaQuery.sizeOf(context).width < 520 ? 12 : 24,
            MediaQuery.viewInsetsOf(context).bottom + 100,
          ),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing
                      ? 'تعديل بيانات الكابتن'
                      : (_isPromoting
                            ? 'تحويل عميل لكابتن بنفس الحساب'
                            : 'إضافة كابتن جديد'),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AdminTheme.ink,
                  ),
                ),
                if (!_isEditing) ...[
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AdminTheme.goldDark.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AdminTheme.goldDark.withAlpha(60),
                      ),
                    ),
                    child: Text(
                      _isPromoting
                          ? 'سيتم استخدام نفس حساب العميل ورقم هاتفه دون إنشاء مستخدم جديد. سيتم الحفاظ على رحلاته ومحفظته.'
                          : 'سيتم إنشاء حساب تسجيل دخول للكابتن تلقائياً بواسطة النظام.',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: AdminTheme.goldDark,
                      ),
                    ),
                  ),
                ],
                SizedBox(height: 20),
                _sectionTitle('البيانات الأساسية'),
                SizedBox(height: 12),
                _buildField(
                  _nameCtrl,
                  'الاسم بالكامل',
                  validator: (v) => v?.isEmpty == true ? 'مطلوب' : null,
                ),
                SizedBox(height: 12),
                _buildField(
                  _phoneCtrl,
                  'رقم الهاتف المصري',
                  keyboardType: TextInputType.phone,
                  enabled: !_isPromoting,
                  validator: (v) {
                    if (v?.isEmpty == true) return 'مطلوب';
                    final digits = v!.replaceAll(RegExp(r'\D'), '');
                    if (digits.length < 10) return 'رقم هاتف غير صحيح';
                    return null;
                  },
                ),
                SizedBox(height: 20),
                _sectionTitle('بيانات المركبة'),
                SizedBox(height: 12),
                _buildDropdown(
                  label: 'نوع المركبة',
                  value: _vehicleType,
                  items: [
                    DropdownMenuItem(
                      value: 'car',
                      child: Text(
                        'سيارة',
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'motorcycle',
                      child: Text(
                        'موتوسيكل',
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                  ],
                  onChanged: (v) => _onVehicleTypeChanged(v!),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildField(_brandCtrl, 'الماركة')),
                    SizedBox(width: 12),
                    Expanded(child: _buildField(_modelCtrl, 'الموديل')),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        _yearCtrl,
                        'سنة الصنع',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(child: _buildField(_colorCtrl, 'اللون')),
                  ],
                ),
                SizedBox(height: 12),
                _buildField(_plateCtrl, 'رقم اللوحة'),
                SizedBox(height: 12),
                if (_isPromoting) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AdminTheme.surfaceSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AdminTheme.borderSoft)),
                    child: Row(children: [
                      if ((widget.customerToPromote?['profile_photo_url']?.toString() ?? '')
                          .startsWith('https://'))
                        ClipRRect(borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            widget.customerToPromote!['profile_photo_url'].toString(),
                            width: 56, height: 56, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded)))
                      else const Icon(Icons.person_rounded, size: 42),
                      const SizedBox(width: 12),
                      const Expanded(child: Text(
                        'بيانات الاسم والهاتف والصورة مأخوذة من ملف العميل الحالي. '
                        'راجع بيانات المركبة والرخصة قبل الاعتماد، ولن يُنشأ حساب دخول جديد.',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 12))),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],
                LayoutBuilder(
                  builder: (context, limits) {
                    final profile = OutlinedButton.icon(
                      onPressed: () => _pickPhoto(vehicle: false),
                      icon: Icon(
                        Icons.person_rounded,
                        color: AdminTheme.goldDark,
                      ),
                      label: Text(
                        _profilePhoto == null
                            ? 'صورة الكابتن'
                            : 'تم اختيار صورة الكابتن',
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                    );
                    final vehicle = OutlinedButton.icon(
                      onPressed: () => _pickPhoto(vehicle: true),
                      icon: Icon(
                        Icons.directions_car_rounded,
                        color: AdminTheme.goldDark,
                      ),
                      label: Text(
                        _vehiclePhoto == null
                            ? 'صورة المركبة'
                            : 'تم اختيار صورة المركبة',
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                    );
                    if (limits.maxWidth < 520)
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [profile, SizedBox(height: 8), vehicle],
                      );
                    return Row(
                      children: [
                        Expanded(child: profile),
                        SizedBox(width: 10),
                        Expanded(child: vehicle),
                      ],
                    );
                  },
                ),
                SizedBox(height: 20),

                // ── SERVICES SECTION ──────────────────────────────────────────────
                _sectionTitle('الخدمات المتاحة'),
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AdminTheme.surfaceSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AdminTheme.borderSoft),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // car_ride — only enabled when vehicle type is car
                      _buildServiceTile(
                        label: 'مشوار سيارة',
                        subtitle: 'يتطلب نوع مركبة: سيارة',
                        icon: Icons.directions_car_rounded,
                        value: _canDoCarRide,
                        enabled: _vehicleType == 'car',
                        disabledReason: _vehicleType != 'car'
                            ? 'غير متاح للموتوسيكل'
                            : null,
                        onChanged: (v) => setState(() => _canDoCarRide = v!),
                      ),
                      Divider(color: AdminTheme.borderSoft, height: 1),
                      // motorcycle_ride — only enabled when vehicle type is motorcycle
                      _buildServiceTile(
                        label: 'مشوار موتوسيكل',
                        subtitle: 'يتطلب نوع مركبة: موتوسيكل',
                        icon: Icons.two_wheeler_rounded,
                        value: _canDoMotorcycleRide,
                        enabled: _vehicleType == 'motorcycle',
                        disabledReason: _vehicleType != 'motorcycle'
                            ? 'غير متاح للسيارة'
                            : null,
                        onChanged: (v) =>
                            setState(() => _canDoMotorcycleRide = v!),
                      ),
                      Divider(color: AdminTheme.borderSoft, height: 1),
                      // package — available for any vehicle type
                      _buildServiceTile(
                        label: 'طرد',
                        subtitle: 'متاح لجميع أنواع المركبات',
                        icon: Icons.inventory_2_rounded,
                        value: _canDoPackage,
                        enabled: true,
                        onChanged: (v) => setState(() => _canDoPackage = v!),
                      ),
                      Divider(color: AdminTheme.borderSoft, height: 1),
                      // vito_market — available for any vehicle type
                      _buildServiceTile(
                        label: 'فيتو ماركت',
                        subtitle:
                            'متاح لجميع أنواع المركبات — التعيين تلقائي ونهائي',
                        icon: Icons.shopping_bag_rounded,
                        value: _canDoVitoMarket,
                        enabled: true,
                        onChanged: (v) => setState(() => _canDoVitoMarket = v!),
                      ),
                      if (_canDoVitoMarket) ...[
                        Divider(color: AdminTheme.borderSoft, height: 20),
                        _buildField(
                          _marketShareCtrl,
                          'عمولة الشركة من توصيل فيتو ماركت %',
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'اكتب 10 لعمولة 10%: توصيل 25 ج → عمولة الشركة 2.50 ج وصافي الكابتن 22.50 ج. النسبة تُثبت عند تعيين كل طلب.',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: AdminTheme.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 20),

                if (_isEditing) ...[
                  _sectionTitle('عمولة الرحلات'),
                  if (widget.existingCaptain != null)
                    OutlinedButton.icon(
                      onPressed: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        showDragHandle: true,
                        builder: (_) => AdminCaptainActionsV10(
                          captainId: widget.existingCaptain!['id'].toString(),
                          name: _nameCtrl.text,
                        ),
                      ),
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      label: const Text(
                        'تنبيه / إنذار / إيقاف / توثيق الكابتن',
                      ),
                    ),
                  _buildField(
                    _commissionCtrl,
                    'عمولة خاصة % — فارغ لاستخدام العمولة العامة',
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  Text(
                    'تُثبّت العمولة عند قبول الرحلة، ولا تغيّر الرحلات السابقة.',
                  ),
                  SizedBox(height: 20),
                ],
                _sectionTitle('الحالة'),
                SizedBox(height: 12),
                _buildDropdown(
                  label: 'حالة الكابتن',
                  value: _captainStatus,
                  items: [
                    DropdownMenuItem(
                      value: 'active',
                      child: Text('نشط', style: TextStyle(fontFamily: 'Cairo')),
                    ),
                    DropdownMenuItem(
                      value: 'suspended',
                      child: Text(
                        'موقوف',
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'blocked',
                      child: Text(
                        'محظور',
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _captainStatus = v!),
                ),
                if (_isEditing) ...[
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSwitch(
                          'متصل',
                          _isOnline,
                          (v) => setState(() => _isOnline = v),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildSwitch(
                          'متاح',
                          _isAvailable,
                          (v) => setState(() => _isAvailable = v),
                        ),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: 24),
                if (_saveMessage != null) ...[
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          (_saveSuccess ? Color(0xFF4CAF50) : Color(0xFFEF5350))
                              .withAlpha(31),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _saveSuccess
                            ? Color(0xFF4CAF50)
                            : Color(0xFFEF5350),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _saveSuccess
                              ? Icons.check_circle_outline_rounded
                              : Icons.error_outline_rounded,
                          color: _saveSuccess
                              ? Color(0xFF4CAF50)
                              : Color(0xFFEF5350),
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _saveMessage!,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              color: _saveSuccess
                                  ? Color(0xFF4CAF50)
                                  : Color(0xFFEF5350),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                ],
                if (MediaQuery.sizeOf(context).width >= 520)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminTheme.goldDark,
                        foregroundColor: Color(0xFF0B0F1A),
                        padding: EdgeInsets.symmetric(vertical: 14),
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
                                color: Color(0xFF0B0F1A),
                              ),
                            )
                          : Text(
                              _isEditing
                                  ? 'حفظ التعديلات'
                                  : (_isPromoting
                                        ? 'تحويل إلى كابتن'
                                        : 'إنشاء الكابتن'),
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
          ),
        ),
        if (MediaQuery.sizeOf(context).width < 520)
          Positioned(
            left: 12,
            right: 12,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.goldDark,
                  foregroundColor: Color(0xFF0B0F1A),
                  padding: EdgeInsets.symmetric(vertical: 15),
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
                          color: Color(0xFF0B0F1A),
                        ),
                      )
                    : Text(
                        _isEditing
                            ? 'حفظ التعديلات'
                            : (_isPromoting
                                  ? 'تحويل إلى كابتن'
                                  : 'إنشاء الكابتن'),
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AdminTheme.goldDark,
      ),
    );
  }

  Widget _buildServiceTile({
    required String label,
    required String subtitle,
    required IconData icon,
    required bool value,
    required bool enabled,
    String? disabledReason,
    required void Function(bool?) onChanged,
  }) {
    final effectiveValue = enabled ? value : false;
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: CheckboxListTile(
        value: effectiveValue,
        onChanged: enabled ? onChanged : null,
        title: Row(
          children: [
            Icon(icon, color: AdminTheme.goldDark, size: 16),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: AdminTheme.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        subtitle: Text(
          disabledReason ?? subtitle,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 11,
            color: disabledReason != null
                ? Color(0xFFEF5350)
                : AdminTheme.muted,
          ),
        ),
        activeColor: AdminTheme.goldDark,
        checkColor: Color(0xFF0B0F1A),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        dense: true,
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: ctrl,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        fontFamily: 'Cairo',
        color: AdminTheme.ink,
        fontSize: 14,
      ),
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
          borderSide: BorderSide(color: AdminTheme.goldDark),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
      items: items,
      onChanged: onChanged,
      dropdownColor: AdminTheme.surfaceSoft,
      style: TextStyle(
        fontFamily: 'Cairo',
        color: AdminTheme.ink,
        fontSize: 14,
      ),
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
          borderSide: BorderSide(color: AdminTheme.goldDark),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildSwitch(String label, bool value, void Function(bool) onChanged) {
    return Row(
      children: [
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AdminTheme.goldDark,
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14,
            color: AdminTheme.ink,
          ),
        ),
      ],
    );
  }
}
