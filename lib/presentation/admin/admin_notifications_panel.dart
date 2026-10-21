import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../theme/admin_theme.dart';

class AdminNotificationsPanel extends StatefulWidget {
  const AdminNotificationsPanel({super.key});

  @override
  State<AdminNotificationsPanel> createState() =>
      _AdminNotificationsPanelState();
}

class _AdminNotificationsPanelState extends State<AdminNotificationsPanel> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  bool _showForm = false;
  RealtimeChannel? _notificationsChannel;

  @override
  void initState() {
    super.initState();
    _load();
    final uid = SupabaseService.instance.currentUser?.id;
    if (uid != null) {
      _notificationsChannel = SupabaseService.instance
          .subscribeToNotificationChanges(uid, (_) {
            if (mounted) _load();
          });
    }
  }

  @override
  void dispose() {
    _notificationsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final notifs = await SupabaseService.instance.getNotifications(
        SupabaseService.instance.currentUser?.id ?? '',
      );
      if (mounted) {
        setState(() {
          _notifications = notifs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _typeLabel(String type) {
    final labels = {
      'trip': 'رحلة',
      'offer': 'عرض',
      'chat': 'رسالة',
      'wallet': 'محفظة',
      'promo': 'بروموكود',
      'system': 'نظام',
      'verification': 'تحقق',
    };
    return labels[type] ?? type;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                'الإشعارات',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AdminTheme.ink,
                ),
              ),
              Spacer(),
              ElevatedButton.icon(
                onPressed: () => setState(() => _showForm = !_showForm),
                icon: Icon(
                  _showForm ? Icons.close : Icons.send_rounded,
                  size: 18,
                ),
                label: Text(
                  _showForm ? 'إلغاء' : 'إرسال إشعار',
                  style: TextStyle(fontFamily: 'Cairo'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.goldDark,
                  foregroundColor: Color(0xFF0B0F1A),
                ),
              ),
              SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.refresh_rounded, color: AdminTheme.goldDark),
                onPressed: _load,
              ),
            ],
          ),
        ),
        if (_showForm)
          _SendNotificationForm(
            onSent: () {
              setState(() => _showForm = false);
              _load();
            },
          ),
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: AdminTheme.goldDark),
                )
              : _notifications.isEmpty
              ? Center(
                  child: Text(
                    'لا توجد إشعارات',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: AdminTheme.muted,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _notifications.length,
                  separatorBuilder: (_, __) => SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final n = _notifications[i];
                    final isRead = n['is_read'] as bool? ?? false;
                    return Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isRead ? AdminTheme.surface : AdminTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isRead
                              ? AdminTheme.surfaceSoft
                              : AdminTheme.borderSoft,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AdminTheme.goldDark.withAlpha(31),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _typeLabel(
                                n['notification_type'] as String? ?? 'system',
                              ),
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 10,
                                color: AdminTheme.goldDark,
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  n['title'] as String? ?? '',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AdminTheme.ink,
                                  ),
                                ),
                                Text(
                                  n['body'] as String? ?? '',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 12,
                                    color: AdminTheme.muted,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AdminTheme.goldDark,
                                shape: BoxShape.circle,
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

class _SendNotificationForm extends StatefulWidget {
  final VoidCallback onSent;
  const _SendNotificationForm({required this.onSent});

  @override
  State<_SendNotificationForm> createState() => _SendNotificationFormState();
}

class _SendNotificationFormState extends State<_SendNotificationForm> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _targetRole = 'all_customers';
  bool _isSending = false;
  String? _message;
  bool _success = false;
  String? _batchRequest;
  String? _batchFingerprint;
  Uint8List? _imageBytes;
  String? _imageExtension;
  String? _uploadedImageUrl;

  Future<void> _selectImage() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 88, maxWidth: 1600);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final ext = image.name.split('.').last.toLowerCase();
      if (!const {'png','jpg','jpeg','webp'}.contains(ext) || bytes.lengthInBytes > 3145728) {
        if (mounted) setState(() => _message = 'اختار صورة JPG أو PNG أو WebP بحجم أقل من 3 ميجابايت.');
        return;
      }
      if (mounted) setState(() {
        _imageBytes = bytes; _imageExtension = ext; _uploadedImageUrl = null;
        _batchRequest = null; _message = null;
      });
    } catch (_) {
      if (mounted) setState(() => _message = 'تعذر اختيار الصورة من المعرض.');
    }
  }

  Future<String?> _uploadImageIfNeeded() async {
    if (_imageBytes == null) return null;
    if (_uploadedImageUrl != null) return _uploadedImageUrl;
    final ext = _imageExtension ?? 'jpg';
    final type = ext == 'png' ? 'image/png' : ext == 'webp' ? 'image/webp' : 'image/jpeg';
    final uid = SupabaseService.instance.currentUser?.id;
    if (uid == null) throw StateError('سجّل دخول الأدمن أولًا.');
    final filename = 'broadcast/$uid/${DateTime.now().microsecondsSinceEpoch}.$ext';
    final storage = SupabaseService.instance.client.storage.from('veto-notification-images');
    await storage.uploadBinary(filename, _imageBytes!,
      fileOptions: FileOptions(contentType:type,upsert:false));
    _uploadedImageUrl = storage.getPublicUrl(filename);
    return _uploadedImageUrl;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_isSending) return;
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      setState(() {
        _message = 'العنوان والمحتوى مطلوبان';
        _success = false;
      });
      return;
    }
    setState(() => _isSending = true);
    try {
      final title = _titleCtrl.text.trim(),
          body = _bodyCtrl.text.trim(),
          role = _targetRole;
      final imageUrl = await _uploadImageIfNeeded();
      final fingerprint = '$role:$title:$body:${imageUrl ?? ''}';
      if (_batchFingerprint != fingerprint || _batchRequest == null) {
        _batchRequest = SupabaseService.newFinancialRequestId();
        _batchFingerprint = fingerprint;
      }
      while (mounted) {
        final raw = await SupabaseService.instance.client
            .rpc(
              'admin_notification_batch_v27',
              params: {
                'p_request_id': _batchRequest,
                'p_role': role,
                'p_title': title,
                'p_body': body,
                'p_image_url': imageUrl,
              },
            )
            .timeout(const Duration(seconds: 20));
        if (raw['success'] != true) throw StateError('notification_failed');
        if (raw['done'] == true) break;
      }
      if (!mounted) return;
      _batchRequest = null;
      if (mounted) {
        setState(() {
          _isSending = false;
          _message = 'تم إرسال الإشعار بنجاح ✓';
          _success = true;
        });
        Future.delayed(Duration(seconds: 1), () {
          if (mounted) widget.onSent();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _message = 'خطأ: $e';
          _success = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTheme.goldDark.withAlpha(60)),
      ),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: _targetRole,
            dropdownColor: AdminTheme.surfaceSoft,
            style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
            decoration: _inputDec('المستهدف'),
            items: [
              DropdownMenuItem(
                value: 'all_customers',
                child: Text(
                  'جميع العملاء',
                  style: TextStyle(fontFamily: 'Cairo'),
                ),
              ),
              DropdownMenuItem(
                value: 'all_captains',
                child: Text(
                  'جميع الكباتن',
                  style: TextStyle(fontFamily: 'Cairo'),
                ),
              ),
              const DropdownMenuItem(value:'all_staff',child:Text('موظفو الفريق')),
              const DropdownMenuItem(value:'all',child:Text('الجميع — بدون تكرار الحساب')),
            ],
            onChanged: (v) => setState(() => _targetRole = v!),
          ),
          SizedBox(height: 12),
          TextField(
            controller: _titleCtrl,
            style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
            decoration: _inputDec('عنوان الإشعار'),
          ),
          SizedBox(height: 12),
          TextField(
            controller: _bodyCtrl,
            maxLines: 3,
            style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
            decoration: _inputDec('محتوى الإشعار'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isSending ? null : _selectImage,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('إرفاق صورة من المعرض (اختياري)'),
          ),
          if (_imageBytes != null) ...[
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(10),
              child: Image.memory(_imageBytes!, height: 170, fit: BoxFit.contain)),
            TextButton.icon(onPressed: _isSending ? null : () => setState(() {
              _imageBytes = null; _imageExtension = null; _uploadedImageUrl = null;
              _batchRequest = null;
            }), icon:const Icon(Icons.delete_outline), label:const Text('إزالة الصورة')),
          ],
          if (_message != null) ...[
            SizedBox(height: 8),
            Text(
              _message!,
              style: TextStyle(
                fontFamily: 'Cairo',
                color: _success ? Color(0xFF4CAF50) : Color(0xFFEF5350),
                fontSize: 13,
              ),
            ),
          ],
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSending ? null : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.goldDark,
                foregroundColor: Color(0xFF0B0F1A),
              ),
              child: _isSending
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF0B0F1A),
                      ),
                    )
                  : Text(
                      'إرسال الإشعار',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDec(String label) => InputDecoration(
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
  );
}
