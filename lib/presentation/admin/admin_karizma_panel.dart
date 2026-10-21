import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/admin_theme.dart';

class AdminKarizmaPanel extends StatefulWidget {
  const AdminKarizmaPanel({super.key});

  @override
  State<AdminKarizmaPanel> createState() => _AdminKarizmaPanelState();
}

class _AdminKarizmaPanelState extends State<AdminKarizmaPanel> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result =
          await SupabaseService.instance.getAllKarizmaPosts();

      if (!mounted) return;

      setState(() {
        _posts = result;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openForm([Map<String, dynamic>? existing]) async {
    final titleController = TextEditingController(
      text: existing?['title']?.toString() ?? '',
    );
    final bodyController = TextEditingController(
      text: existing?['body']?.toString() ?? '',
    );

    String audience = existing?['audience']?.toString() ?? 'customer';
    XFile? imageFile;
    bool saving = false;
    bool closed = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: AdminTheme.surface,
              title: Text(
                existing == null
                    ? 'إضافة منشور كاريزما'
                    : 'تعديل منشور كاريزما',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: AdminTheme.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: AdminTheme.ink,
                      ),
                      decoration: InputDecoration(
                        labelText: 'العنوان',
                        labelStyle: TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: bodyController,
                      maxLines: 7,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: AdminTheme.ink,
                      ),
                      decoration: InputDecoration(
                        labelText: 'المحتوى',
                        labelStyle: TextStyle(fontFamily: 'Cairo'),
                        alignLabelWithHint: true,
                      ),
                    ),
                    SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: audience,
                      dropdownColor: AdminTheme.surface,
                      decoration: InputDecoration(
                        labelText: 'يظهر لمن',
                        labelStyle: TextStyle(fontFamily: 'Cairo'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'customer',
                          child: Text(
                            'العملاء',
                            style: TextStyle(fontFamily: 'Cairo'),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'captain',
                          child: Text(
                            'الكباتن',
                            style: TextStyle(fontFamily: 'Cairo'),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'all',
                          child: Text(
                            'الكل',
                            style: TextStyle(fontFamily: 'Cairo'),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          audience = value;
                        });
                      },
                    ),
                    SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final file = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 85,
                            maxWidth: 1400,
                          );

                          if (file == null) return;

                          setDialogState(() {
                            imageFile = file;
                          });
                        },
                        icon: Icon(
                          Icons.image_rounded,
                          color: AdminTheme.goldDark,
                        ),
                        label: Text(
                          imageFile == null
                              ? 'إضافة صورة'
                              : 'تم اختيار الصورة',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                    ),
                    if (imageFile != null) ...[
                      SizedBox(height: 10),
                      Text(
                        imageFile!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'إلغاء',
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                ),
                StatefulBuilder(
                  builder: (_, __) {
                    return ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final title = titleController.text.trim();
                              final body = bodyController.text.trim();

                              if (title.isEmpty || body.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'اكتب العنوان والمحتوى أولًا',
                                      style: TextStyle(fontFamily: 'Cairo'),
                                    ),
                                  ),
                                );
                                return;
                              }

                              setDialogState(() {
                                saving = true;
                              });

                              try {
                                String? imageUrl =
                                    existing?['image_url']?.toString();

                                if (imageFile != null) {
                                  final fileName = imageFile!.name.toLowerCase();
                                  final imageExtension = fileName.endsWith('.png')
                                      ? 'png' : fileName.endsWith('.webp')
                                      ? 'webp' : 'jpg';
                                  final contentType = imageExtension == 'png'
                                      ? 'image/png' : imageExtension == 'webp'
                                      ? 'image/webp' : 'image/jpeg';
                                  final path = 'karizma/${DateTime.now().microsecondsSinceEpoch}.$imageExtension';
                                  await SupabaseService.instance.client.storage
                                      .from('veto-karizma-images').uploadBinary(
                                        path, await imageFile!.readAsBytes(),
                                        fileOptions: FileOptions(contentType: contentType,
                                            upsert: false),
                                      );
                                  imageUrl = SupabaseService.instance.client.storage
                                      .from('veto-karizma-images').getPublicUrl(path);
                                }

                                await SupabaseService.instance.saveKarizmaPost(
                                  id: existing?['id']?.toString(),
                                  title: title,
                                  body: body,
                                  audience: audience,
                                  imageUrl: imageUrl,
                                );

                                if (!dialogContext.mounted) return;
                                closed = true;
                                Navigator.of(dialogContext).pop();
                              } catch (_) {
                                if (!dialogContext.mounted) return;

                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'تعذر حفظ منشور كاريزما',
                                      style: TextStyle(fontFamily: 'Cairo'),
                                    ),
                                  ),
                                );
                              } finally {
                                if (!closed && dialogContext.mounted) {
                                  setDialogState(() { saving = false; });
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminTheme.goldDark,
                        foregroundColor: AppTheme.primary,
                      ),
                      child: Text(
                        'حفظ',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    bodyController.dispose();

    await _load();
  }

  Future<void> _showComments(String postId) async {
    try {
      final rows = await SupabaseService.instance.ownerKarizmaCommentsV33(postId);
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('التعليقات وهوية صاحب الحساب',
          style: TextStyle(fontFamily: 'Cairo')),
        content: SizedBox(width: 600, height: 440, child: rows.isEmpty
          ? const Center(child: Text('لا توجد تعليقات بعد'))
          : ListView.separated(itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (_, i) {
                final row = rows[i];
                return ListTile(
                  title: Text("${row['nickname'] ?? row['real_name'] ?? 'عضو فيتو'}",
                    style: const TextStyle(fontFamily: 'Cairo')),
                  subtitle: SelectableText(
                    'التعليق: ${row['body'] ?? ''}\n'
                    'الاسم الحقيقي: ${row['real_name'] ?? 'غير مسجل'}\n'
                    'الهاتف: ${row['phone'] ?? '—'}\n'
                    'معرف الحساب: ${row['user_id'] ?? '—'}',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                );
              })),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('إغلاق'))],
      ));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تعذر تحميل سجل التعليقات؛ تحقق من SQL V33 وصلاحيات الإدارة.')));
    }
  }

  Future<void> _editVisibleLikes() async {
    if (_posts.isEmpty) return;
    String postId = _posts.first['id'].toString();
    final controller = TextEditingController(text: '10');
    try {
      final saved = await showDialog<bool>(context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
          title: const Text('إضافة إعجابات للمنشور',
            style: TextStyle(fontFamily: 'Cairo')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: postId,
              items: _posts.map((p) => DropdownMenuItem<String>(
                value: p['id'].toString(),
                child: Text(p['title']?.toString() ?? 'منشور',
                  overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (v) { if (v != null) setDialog(() => postId = v); },
              isExpanded: true,
            ),
            TextField(controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'إضافة عدد إعجابات (+)', helperText: 'العدد ده هيتضاف فوق الإعجابات الحقيقية')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء')),
            FilledButton(onPressed: () async {
              final likes = int.tryParse(controller.text.trim());
              if (likes == null || likes < 0 || likes > 1000000) return;
              try {
                await SupabaseService.instance.client.rpc(
                  'v44_owner_add_karizma_likes', params: {
                    'p_post_id': postId, 'p_increment': likes,
                  });
                if (ctx.mounted) Navigator.of(ctx).pop(true);
              } catch (_) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('تعذر إضافة الإعجابات. راجع SQL V44.')));
              }
            }, child: const Text('حفظ')),
          ],
        )));
      if (saved == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تمت إضافة الإعجابات')));
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _deletePost(String id) async {
    try {
      await SupabaseService.instance.deleteKarizmaPost(id);
      await _load();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر حذف المنشور',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: Row(
              children: [
                Text(
                  'كاريزما',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AdminTheme.ink,
                  ),
                ),
                Spacer(),
                IconButton(
                  tooltip: 'تعديل الإعجابات',
                  onPressed: _posts.isEmpty ? null : _editVisibleLikes,
                  icon: Icon(Icons.thumb_up_alt_outlined,
                    color: AdminTheme.goldDark),
                ),
                ElevatedButton.icon(
                  onPressed: () => _openForm(),
                  icon: Icon(Icons.add_rounded),
                  label: Text(
                    'منشور جديد',
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
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
                : _posts.isEmpty
                    ? Center(
                        child: Text(
                          'لا توجد منشورات كاريزما',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: AdminTheme.muted,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.all(18),
                        itemCount: _posts.length,
                        separatorBuilder: (_, __) =>
                            SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final post = _posts[index];
                          final rawImage =
                              post['image_url']?.toString() ?? '';
                          final imageUrl = rawImage.isNotEmpty &&
                              !rawImage.startsWith('https://') &&
                              !rawImage.startsWith('http://')
                              ? SupabaseService.instance.client.storage
                                  .from('veto-public').getPublicUrl(rawImage)
                              : rawImage;
                          final audience =
                              post['audience']?.toString() ?? 'customer';

                          return Container(
                            padding: EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AdminTheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AdminTheme.borderSoft,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: imageUrl.isNotEmpty
                                      ? Image.network(
                                          imageUrl,
                                          width: 62,
                                          height: 62,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _iconPlaceholder(),
                                        )
                                      : _iconPlaceholder(),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        post['title']?.toString() ?? '',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          color: AdminTheme.ink,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        post['body']?.toString() ?? '',
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          color: AdminTheme.muted,
                                          fontSize: 11,
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        _audienceLabel(audience),
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          color: AdminTheme.goldDark,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    IconButton(
                                      tooltip: 'التعليقات وهويات أصحابها',
                                      onPressed: () => _showComments(post['id'].toString()),
                                      icon: Icon(Icons.comment_rounded,
                                        color: AdminTheme.goldDark),
                                    ),
                                    IconButton(
                                      tooltip: 'تعديل',
                                      onPressed: () => _openForm(post),
                                      icon: Icon(
                                        Icons.edit_rounded,
                                        color: AdminTheme.goldDark,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'حذف',
                                      onPressed: () => _deletePost(
                                        post['id'].toString(),
                                      ),
                                      icon: Icon(
                                        Icons.delete_rounded,
                                        color: AdminTheme.error,
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

  String _audienceLabel(String value) {
    switch (value) {
      case 'captain':
        return 'يظهر للكباتن';
      case 'all':
        return 'يظهر للكل';
      case 'customer':
      default:
        return 'يظهر للعملاء';
    }
  }

  Widget _iconPlaceholder() {
    return Container(
      width: 62,
      height: 62,
      color: AdminTheme.goldDark.withAlpha(22),
      alignment: Alignment.center,
      child: Icon(
        Icons.auto_awesome_rounded,
        color: AdminTheme.goldDark,
        size: 25,
      ),
    );
  }
}
