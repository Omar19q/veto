import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_service.dart';
import '../../services/booking_address_seed.dart';
import '../../services/customer_location_state.dart';
import '../../theme/app_theme.dart';
import '../../l10n/strings.dart';
import '../../routes/app_routes.dart';
import 'address_suggestion_history.dart';

class CustomerSavedAddresses extends StatefulWidget {
  const CustomerSavedAddresses({
    super.key,
    this.initialRows,
    this.autoLoad = true,
    this.customerId,
    this.onSaveAddress,
  });

  final List<Map<String, dynamic>>? initialRows;
  final bool autoLoad;
  final String? customerId;
  final Future<void> Function(Map<String, dynamic> data)? onSaveAddress;

  @override
  State<CustomerSavedAddresses> createState() => _CustomerSavedAddressesState();
}

class _CustomerSavedAddressesState extends State<CustomerSavedAddresses> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true, _failed = false;
  bool _saving = false;
  String? _owner;
  String? _customerId;

  @override
  void initState() {
    super.initState();
    if (widget.initialRows != null) {
      _rows = List<Map<String, dynamic>>.from(widget.initialRows!);
      _loading = false;
      _customerId = widget.customerId;
    }
    if (widget.autoLoad) {
      _load();
    }
  }

  Future<void> _load() async {
    final api = SupabaseService.instance,
        owner = SupabaseService.instance.currentUser?.id;
    try {
      if (owner == null) throw StateError('authentication_required');
      final customer = await api.getCustomerByUserId(owner);
      if (customer == null) throw StateError('customer_required');
      final customerId = customer['id'].toString();
      final rows = await api.getCustomerAddresses(customerId);
      if (mounted && owner == api.currentUser?.id) {
        setState(() {
          _owner = owner;
          _customerId = customerId;
          _rows = rows;
          _loading = false;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
          _rows = [];
        });
      }
    }
  }

  Future<void> _addAddress() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String? customerId = _customerId ?? widget.customerId;
    if (customerId == null) {
      final owner = SupabaseService.instance.currentUser?.id;
      if (owner != null) {
        final customer =
            await SupabaseService.instance.getCustomerByUserId(owner);
        customerId = customer?['id']?.toString();
        if (mounted && customerId != null) {
          _customerId = customerId;
        }
      }
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor:
          isDark ? const Color(0xFF13182A) : Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AddAddressBottomSheet(
        customerId: customerId,
        onSaveOverride: widget.onSaveAddress,
        onAddressAdded: () async {
          await _load();
        },
      ),
    );
  }

  Future<void> _edit(Map<String, dynamic> row) async {
    if (_saving || _owner != SupabaseService.instance.currentUser?.id) return;
    final l = context.strings;
    var label = row['label']?.toString() ?? '';
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.savedPlaces),
        content: TextFormField(
          initialValue: label,
          maxLength: 60,
          decoration: InputDecoration(labelText: l.savedNameHint),
          onChanged: (value) => label = value.trim(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'delete'),
            child: Text(l.savedDelete),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.savedCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: Text(l.savedSave),
          ),
        ],
      ),
    );
    if (!mounted ||
        action == null ||
        _owner != SupabaseService.instance.currentUser?.id) {
      return;
    }
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.savedDeleteTitle),
          content: Text(
            l.savedDeleteDescription(row['label']?.toString() ?? ''),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.savedCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.savedDelete),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
    } else if (label.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.savedEnterLabel)));
      return;
    }
    if (_owner != SupabaseService.instance.currentUser?.id) return;
    setState(() => _saving = true);
    try {
      final api = SupabaseService.instance;
      if (action == 'delete') {
        await api.deleteCustomerAddress(row['id'].toString());
      } else {
        await api.updateCustomerAddress(row['id'].toString(), {'label': label});
      }
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.retry)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go(AppRoutes.homeScreen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.strings;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.savedPlaces),
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _handleBack,
          ),
          actions: [
          IconButton(
            key: const Key('add_address_appbar_button'),
            icon: const Icon(Icons.add_rounded),
            tooltip: 'إضافة عنوان جديد',
            onPressed: _saving ? null : _addAddress,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_address_fab'),
        onPressed: _saving ? null : _addAddress,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text(
          'إضافة عنوان جديد',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: isDark ? AppTheme.gold : const Color(0xFF0B0F1A),
        foregroundColor: isDark ? const Color(0xFF0B0F1A) : Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_failed)
                  TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: Text(l.retry),
                  ),
                for (final row in _rows)
                  Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    color: Theme.of(context).colorScheme.surface,
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: (isDark ? AppTheme.gold : const Color(0xFF0B0F1A))
                              .withAlpha(24),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          row['is_default'] == true
                              ? Icons.star_rounded
                              : Icons.bookmark_rounded,
                          color: isDark ? AppTheme.gold : const Color(0xFF0B0F1A),
                          size: 22,
                        ),
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${row['label'] ?? ''}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (row['is_default'] == true) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: (isDark ? AppTheme.gold : const Color(0xFF0B0F1A))
                                    .withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'افتراضي',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppTheme.gold
                                      : const Color(0xFF0B0F1A),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text('${row['display_address'] ?? ''}'),
                      trailing: IconButton(
                        tooltip: l.savedNameHint,
                        onPressed: _saving ? null : () => _edit(row),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      onTap: () {
                        final seed = BookingAddressSeed.saved(row);
                        if (seed != null) {
                          context.push(
                            '/trip-booking-screen',
                            extra: BookingAddressSelection(destination: seed),
                          );
                        }
                      },
                    ),
                  ),
                if (!_failed && _rows.isEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withAlpha(80),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: (isDark
                                    ? AppTheme.gold
                                    : const Color(0xFF0B0F1A))
                                .withAlpha(24),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.bookmark_add_outlined,
                            size: 30,
                            color: isDark
                                ? AppTheme.gold
                                : const Color(0xFF0B0F1A),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l.menuNoAddresses,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          key: const Key('add_address_empty_state_button'),
                          onPressed: _saving ? null : _addAddress,
                          icon: const Icon(Icons.add_location_alt_rounded),
                          label: const Text('إضافة عنوان جديد'),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const AddressSuggestionHistory(),
                    ),
                  ),
                  icon: const Icon(Icons.edit_location_alt_outlined),
                  label: Text(l.menuAddressSuggestions),
                ),
                const SizedBox(height: 80),
              ],
            ),
      ),
    );
  }
}

class _AddAddressBottomSheet extends StatefulWidget {
  const _AddAddressBottomSheet({
    this.customerId,
    required this.onAddressAdded,
    this.onSaveOverride,
  });

  final String? customerId;
  final VoidCallback onAddressAdded;
  final Future<void> Function(Map<String, dynamic> data)? onSaveOverride;

  @override
  State<_AddAddressBottomSheet> createState() => _AddAddressBottomSheetState();
}

class _AddAddressBottomSheetState extends State<_AddAddressBottomSheet> {
  final _labelController = TextEditingController(text: 'المنزل');
  final _buildingController = TextEditingController();
  final _floorController = TextEditingController();
  final _apartmentController = TextEditingController();
  final _customAddressController = TextEditingController();

  static const List<String> _hadayekAreas = <String>[
    'أ', 'ب', 'ج', 'د', 'هـ', 'و', 'ز', 'ح', 'ط', 'ك', 'ل', 'م', 'ن', 'ع', 'س', 'ص',
  ];

  String? _selectedArea = 'أ';
  bool _isHadayek = true;
  bool _isDefault = false;
  bool _isLocating = false;
  bool _isSaving = false;
  String? _errorMessage;
  double? _latitude;
  double? _longitude;

  @override
  void dispose() {
    _labelController.dispose();
    _buildingController.dispose();
    _floorController.dispose();
    _apartmentController.dispose();
    _customAddressController.dispose();
    super.dispose();
  }

  Future<void> _captureLocation() async {
    setState(() {
      _isLocating = true;
      _errorMessage = null;
    });
    try {
      final pos = await CustomerLocationState.locate();
      if (mounted) {
        if (pos != null) {
          setState(() {
            _latitude = pos.latitude;
            _longitude = pos.longitude;
            _isLocating = false;
          });
        } else {
          setState(() {
            _isLocating = false;
            _errorMessage =
                'تعذر تحديد الموقع تلقائيًا. تأكد من تفعيل خدمة الموقع GPS.';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLocating = false;
          _errorMessage = 'حدث خطأ أثناء تحديد الموقع.';
        });
      }
    }
  }

  Future<void> _submit() async {
    final label = _labelController.text.trim();
    if (label.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال اسم للعنوان (مثال: المنزل)');
      return;
    }

    String displayAddress;
    String? areaLetter;
    String? buildingNumber;
    String? floor;
    String? apartment;

    if (_isHadayek) {
      if (_selectedArea == null || !_hadayekAreas.contains(_selectedArea)) {
        setState(() => _errorMessage = 'يرجى اختيار حرف المنطقة داخل حدائق الأهرام');
        return;
      }
      final building = _buildingController.text.trim();
      if (building.isEmpty) {
        setState(() => _errorMessage = 'يرجى إدخال رقم العمارة');
        return;
      }
      areaLetter = _selectedArea;
      buildingNumber = building;
      floor = _floorController.text.trim().isNotEmpty
          ? _floorController.text.trim()
          : null;
      apartment = _apartmentController.text.trim().isNotEmpty
          ? _apartmentController.text.trim()
          : null;

      displayAddress =
          'حدائق الأهرام - منطقة $areaLetter - عمارة $buildingNumber';
      if (floor != null) displayAddress += ' - دور $floor';
      if (apartment != null) displayAddress += ' - شقة $apartment';
    } else {
      final custom = _customAddressController.text.trim();
      if (custom.isEmpty) {
        setState(() => _errorMessage = 'يرجى إدخال تفاصيل العنوان');
        return;
      }
      displayAddress = custom;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      if (widget.onSaveOverride != null) {
        await widget.onSaveOverride!({
          'label': label,
          'area_letter': areaLetter,
          'building_number': buildingNumber,
          'floor': floor,
          'apartment': apartment,
          'display_address': displayAddress,
          'latitude': _latitude,
          'longitude': _longitude,
          'is_default': _isDefault,
        });
      } else {
        String? cid = widget.customerId;
        if (cid == null) {
          final uid = SupabaseService.instance.currentUser?.id;
          if (uid == null) throw StateError('auth_required');
          final cust = await SupabaseService.instance.getCustomerByUserId(uid);
          if (cust == null) throw StateError('customer_required');
          cid = cust['id'].toString();
        }

        await SupabaseService.instance.addCustomerAddress(
          customerId: cid,
          label: label,
          areaLetter: areaLetter,
          buildingNumber: buildingNumber,
          floor: floor,
          apartment: apartment,
          displayAddress: displayAddress,
          latitude: _latitude,
          longitude: _longitude,
          isDefault: _isDefault,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onAddressAdded();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تمت إضافة العنوان بنجاح ✓'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage =
              'تعذر حفظ العنوان. تأكد من اتصال الإنترنت ثم حاول مرة أخرى.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppTheme.gold : const Color(0xFF0B0F1A);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withAlpha(24),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.add_location_alt_rounded,
                    color: primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'إضافة عنوان جديد',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Quick label presets
            Row(
              children: [
                _LabelChip(
                  label: 'المنزل',
                  icon: Icons.home_rounded,
                  selected: _labelController.text == 'المنزل',
                  onTap: () => setState(() => _labelController.text = 'المنزل'),
                ),
                const SizedBox(width: 8),
                _LabelChip(
                  label: 'العمل',
                  icon: Icons.work_rounded,
                  selected: _labelController.text == 'العمل',
                  onTap: () => setState(() => _labelController.text = 'العمل'),
                ),
                const SizedBox(width: 8),
                _LabelChip(
                  label: 'أخرى',
                  icon: Icons.place_rounded,
                  selected: _labelController.text != 'المنزل' &&
                      _labelController.text != 'العمل',
                  onTap: () {
                    if (_labelController.text == 'المنزل' ||
                        _labelController.text == 'العمل') {
                      setState(() => _labelController.text = '');
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Label text field
            TextFormField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'اسم العنوان',
                hintText: 'مثال: البيت، الشغل، النادي...',
                prefixIcon: Icon(Icons.label_outline_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Scope toggle: Hadayek vs Other
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('حدائق الأهرام'),
                  icon: Icon(Icons.location_city_rounded),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('عنوان آخر'),
                  icon: Icon(Icons.map_rounded),
                ),
              ],
              selected: {_isHadayek},
              onSelectionChanged: (selected) {
                setState(() {
                  _isHadayek = selected.first;
                  _errorMessage = null;
                });
              },
            ),
            const SizedBox(height: 16),

            if (_isHadayek) ...[
              const Text(
                'اختر حرف المنطقة داخل حدائق الأهرام',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _hadayekAreas.map((letter) {
                  final isSelected = _selectedArea == letter;
                  return ChoiceChip(
                    label: SizedBox(
                      width: 28,
                      child: Center(
                        child: Text(
                          letter,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? (isDark
                                    ? const Color(0xFF0B0F1A)
                                    : Colors.white)
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) => setState(() {
                      _selectedArea = letter;
                      _errorMessage = null;
                    }),
                    selectedColor: primaryColor,
                    showCheckmark: false,
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _buildingController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'رقم العمارة *',
                        hintText: 'مثال: 125',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _floorController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'الدور',
                        hintText: '3',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _apartmentController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'الشقة',
                        hintText: '5',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              TextFormField(
                controller: _customAddressController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'تفاصيل العنوان *',
                  hintText: 'المنطقة، الشارع، رقم العقار أو أقرب علامة مميزة...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],

            const SizedBox(height: 14),

            // GPS location capture
            OutlinedButton.icon(
              onPressed: _isLocating ? null : _captureLocation,
              icon: _isLocating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _latitude != null
                          ? Icons.check_circle_rounded
                          : Icons.my_location_rounded,
                      color: _latitude != null ? const Color(0xFF10B981) : null,
                    ),
              label: Text(
                _latitude != null
                    ? 'تم التقاط موقعك عبر GPS ✓'
                    : 'تحديد موقعي الحالي تلقائياً عبر GPS',
                style: TextStyle(
                  color: _latitude != null ? const Color(0xFF10B981) : null,
                  fontWeight:
                      _latitude != null ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 6),

            // Default switch
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تعيين كعنوان افتراضي'),
              subtitle: const Text('يظهر كخيار رئيسي عند طلب المشاوير'),
              value: _isDefault,
              onChanged: (val) => setState(() => _isDefault = val),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Save button
            FilledButton(
              key: const Key('save_address_submit_button'),
              onPressed: _isSaving ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'حفظ العنوان',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabelChip extends StatelessWidget {
  const _LabelChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppTheme.gold : const Color(0xFF0B0F1A);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? primaryColor.withAlpha(24)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? primaryColor
                  : Theme.of(context).colorScheme.outlineVariant,
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? primaryColor
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected
                      ? primaryColor
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
