import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/admin_theme.dart';

String _copy(BuildContext context, String ar, String en) =>
    Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

class AdminBannersPanel extends StatefulWidget {
  const AdminBannersPanel({super.key, this.loadBanners, this.setActive});
  final Future<List<Map<String, dynamic>>> Function()? loadBanners;
  final Future<void> Function(String id, bool active)? setActive;

  @override
  State<AdminBannersPanel> createState() => _AdminBannersPanelState();
}

class _AdminBannersPanelState extends State<AdminBannersPanel> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  bool _failed = false;
  final _updating = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows =
          await (widget.loadBanners?.call() ??
              SupabaseService.instance.getEditableHomeBanners());
      if (mounted)
        setState(() {
          _rows = rows;
          _failed = false;
        });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(Map<String, dynamic> banner, bool active) async {
    final id = banner['id'].toString();
    if (_updating.contains(id)) return;
    setState(() => _updating.add(id));
    try {
      if (widget.setActive != null) {
        await widget.setActive!(id, active);
      } else {
        await SupabaseService.instance.client
            .from('home_banners')
            .update({'is_active': active})
            .eq('id', id);
      }
      await _load();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _copy(
                context,
                'تعذر تحديث البنر. حاول مرة أخرى.',
                'Could not update the banner. Please retry.',
              ),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _updating.remove(id));
    }
  }

  Future<void> _openDialog([Map<String, dynamic>? banner]) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _BannerDialog(existing: banner),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: Directionality.of(context),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(20),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _copy(context, 'البنرات والعروض', 'Banners and offers'),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AdminTheme.ink,
                  ),
                ),
                IconButton(
                  onPressed: _load,
                  tooltip: _copy(context, 'تحديث', 'Refresh'),
                  icon: Icon(Icons.refresh_rounded, color: AdminTheme.goldDark),
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _openDialog(),
                  icon: Icon(Icons.add),
                  label: Text(_copy(context, 'إضافة بنر', 'Add banner')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.goldDark,
                    foregroundColor: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                      color: AdminTheme.goldDark,
                    ),
                  )
                : _failed
                ? Center(
                    child: TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: Text(
                        _copy(
                          context,
                          'تعذر تحميل البنرات. إعادة المحاولة',
                          'Could not load banners. Retry',
                        ),
                      ),
                    ),
                  )
                : _rows.isEmpty
                ? Center(
                    child: Text(
                      _copy(context, 'لا توجد بنرات بعد', 'No banners yet'),
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: AdminTheme.muted,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _rows.length,
                    separatorBuilder: (_, __) => SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final b = _rows[i];
                      return Container(
                        padding: EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AdminTheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AdminTheme.borderSoft),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child:
                                  (b['image_url']?.toString().isNotEmpty ??
                                      false)
                                  ? Image.network(
                                      b['image_url'].toString(),
                                      width: 86,
                                      height: 58,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _fallbackPreview(),
                                    )
                                  : _fallbackPreview(),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    b['title']?.toString() ?? '',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      color: AdminTheme.ink,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    (b['subtitle']?.toString().isNotEmpty ??
                                            false)
                                        ? b['subtitle'].toString()
                                        : _copy(
                                            context,
                                            'بدون نص إضافي',
                                            'No additional text',
                                          ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      color: AdminTheme.muted,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                Switch(
                                  value: b['is_active'] == true,
                                  onChanged:
                                      _updating.contains(b['id'].toString())
                                      ? null
                                      : (v) => _toggle(b, v),
                                  activeThumbColor: AdminTheme.goldDark,
                                ),
                                IconButton(
                                  tooltip: _copy(context, 'تعديل', 'Edit'),
                                  onPressed: () => _openDialog(b),
                                  icon: Icon(
                                    Icons.edit_rounded,
                                    color: AdminTheme.goldDark,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackPreview() => Container(
    width: 86,
    height: 58,
    color: AdminTheme.surfaceSoft,
    alignment: Alignment.center,
    child: Icon(Icons.image_rounded, color: AdminTheme.goldDark),
  );
}

class _BannerDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _BannerDialog({this.existing});

  @override
  State<_BannerDialog> createState() => _BannerDialogState();
}

class _BannerDialogState extends State<_BannerDialog> {
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _url;
  late bool _isActive;
  late String _action;
  XFile? _image;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(
      text: widget.existing?['title']?.toString() ?? '',
    );
    _subtitle = TextEditingController(
      text: widget.existing?['subtitle']?.toString() ?? '',
    );
    _url = TextEditingController(
      text: widget.existing?['image_url']?.toString() ?? '',
    );
    final action = widget.existing?['action_type']?.toString() ?? 'book';
    _action = const ['none', 'book', 'market'].contains(action)
        ? action
        : 'none';
    _isActive = widget.existing?['is_active'] == true;
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final uri = Uri.tryParse(_url.text.trim());
    if (_title.text.trim().isEmpty ||
        (_url.text.trim().isNotEmpty &&
            (uri == null ||
                uri.scheme != 'https' ||
                uri.host.isEmpty ||
                uri.userInfo.isNotEmpty))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _copy(
              context,
              'اكتب عنوان البنر ورابط صورة HTTPS صحيح، أو اترك الصورة فارغة.',
              'Enter a banner title and a valid HTTPS image URL, or leave the image empty.',
            ),
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      String? imageUrl = _url.text.trim().isEmpty ? null : _url.text.trim();
      if (_image != null) {
        final bytes = await _image!.readAsBytes();
        if (bytes.length > 10 * 1024 * 1024)
          throw const FormatException('image_too_large');
        final png =
            bytes.length >= 8 &&
            bytes[0] == 137 &&
            bytes[1] == 80 &&
            bytes[2] == 78 &&
            bytes[3] == 71;
        final jpeg =
            bytes.length >= 3 &&
            bytes[0] == 255 &&
            bytes[1] == 216 &&
            bytes[2] == 255;
        final webp =
            bytes.length >= 12 &&
            String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
            String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP';
        if (!png && !jpeg && !webp)
          throw const FormatException('unsupported_image');
        final extension = png
            ? 'png'
            : webp
            ? 'webp'
            : 'jpg';
        imageUrl = await SupabaseService.instance.uploadPublicImage(
          path: 'banners/${DateTime.now().millisecondsSinceEpoch}.$extension',
          bytes: bytes,
          contentType: png
              ? 'image/png'
              : webp
              ? 'image/webp'
              : 'image/jpeg',
        );
      }
      await SupabaseService.instance.saveHomeBanner(
        bannerId: widget.existing?['id']?.toString(),
        title: _title.text,
        subtitle: _subtitle.text,
        imageUrl: imageUrl,
        actionType: _action,
        isActive: _isActive,
        sortOrder: (widget.existing?['sort_order'] as num?)?.toInt() ?? 0,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _copy(context, 'تعذر حفظ البنر', 'Could not save the banner'),
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Directionality(
      textDirection: Directionality.of(context),
      child: AlertDialog(
        backgroundColor: AdminTheme.surface,
        title: Text(
          editing
              ? _copy(context, 'تعديل البنر', 'Edit banner')
              : _copy(context, 'إضافة بنر', 'Add banner'),
          style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_title, _copy(context, 'العنوان الرئيسي', 'Title')),
              _field(
                _subtitle,
                _copy(context, 'النص الإضافي', 'Additional text'),
              ),
              _field(
                _url,
                _copy(context, 'رابط الصورة (اختياري)', 'Image URL (optional)'),
              ),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _action,
                dropdownColor: AdminTheme.surface,
                decoration: InputDecoration(
                  labelText: _copy(context, 'نوع الإجراء', 'Action'),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'none',
                    child: Text(_copy(context, 'بدون زر', 'No action')),
                  ),
                  DropdownMenuItem(
                    value: 'book',
                    child: Text(_copy(context, 'حجز رحلة', 'Book a ride')),
                  ),
                  DropdownMenuItem(
                    value: 'market',
                    child: Text(_copy(context, 'فيتو ماركت', 'VETO Market')),
                  ),
                ],
                onChanged: (v) => setState(() => _action = v ?? 'book'),
              ),
              SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isActive,
                activeThumbColor: AdminTheme.goldDark,
                onChanged: (v) => setState(() => _isActive = v),
                title: Text(
                  _copy(
                    context,
                    'إظهار البنر للعملاء',
                    'Show banner to customers',
                  ),
                  style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
                ),
              ),
              SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () async {
                  final f = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 80,
                    maxWidth: 1600,
                  );
                  if (f != null && mounted) setState(() => _image = f);
                },
                icon: Icon(Icons.image_rounded, color: AdminTheme.goldDark),
                label: Text(
                  _image == null
                      ? _copy(context, 'اختيار صورة من المعرض', 'Choose image')
                      : _copy(context, 'تم اختيار الصورة', 'Image selected'),
                  style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_copy(context, 'إلغاء', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.goldDark,
              foregroundColor: AppTheme.primary,
            ),
            child: _saving
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _copy(context, 'حفظ', 'Save'),
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label) => Padding(
    padding: EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: c,
      style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AdminTheme.surfaceSoft,
        border: OutlineInputBorder(),
      ),
    ),
  );
}
