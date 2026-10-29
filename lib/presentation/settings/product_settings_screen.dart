import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../services/product_preferences.dart';
import '../../services/supabase_service.dart';
import './widgets/change_name_dialog.dart';
import './widgets/change_phone_sheet.dart';

class ProductSettingsScreen extends StatefulWidget {
  const ProductSettingsScreen({super.key});
  @override
  State<ProductSettingsScreen> createState() => _ProductSettingsScreenState();
}

class _ProductSettingsScreenState extends State<ProductSettingsScreen> {
  bool _saving = false;
  bool _isLoadingAccount = true;
  bool _isLinkingGoogle = false;

  String _customerName = '';
  String _customerPhone = '';
  String? _customerId;
  String? _userId;
  bool _isGoogleLinked = false;
  String? _googleEmail;

  @override
  void initState() {
    super.initState();
    _loadAccountData();
  }

  Future<void> _loadAccountData() async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingAccount = false);
      return;
    }

    _userId = user.id;
    _isGoogleLinked = SupabaseService.instance.isGoogleLinked();
    _googleEmail = SupabaseService.instance.getLinkedGoogleEmail();

    try {
      final customer = await SupabaseService.instance.getCustomerByUserId(user.id);
      if (customer != null && mounted) {
        _customerId = customer['id']?.toString();
        _customerName = customer['full_name']?.toString() ?? '';
        final phone = customer['phone']?.toString() ?? '';
        if (phone.isNotEmpty) {
          _customerPhone = phone;
        } else if (user.phone != null && user.phone!.isNotEmpty) {
          _customerPhone = user.phone!;
        }
      } else if (mounted) {
        _customerName = user.userMetadata?['full_name']?.toString() ??
            user.userMetadata?['name']?.toString() ??
            '';
        _customerPhone = user.phone ?? '';
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoadingAccount = false);
    }
  }

  Future<void> _changeName() async {
    if (_userId == null || _customerId == null) return;
    final updated = await ChangeNameDialog.show(
      context,
      userId: _userId!,
      customerId: _customerId!,
      currentName: _customerName,
    );

    if (updated != null && mounted) {
      setState(() => _customerName = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث الاسم بنجاح'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _changePhone() async {
    if (_userId == null || _customerId == null) return;
    final updated = await ChangePhoneSheet.show(
      context,
      userId: _userId!,
      customerId: _customerId!,
      currentPhone: _customerPhone,
    );

    if (updated != null && mounted) {
      setState(() => _customerPhone = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تأكيد وتحديث رقم الهاتف بنجاح!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      _loadAccountData();
    }
  }

  Future<void> _linkGoogle() async {
    if (_isLinkingGoogle) return;
    setState(() => _isLinkingGoogle = true);

    try {
      const serverClientId = String.fromEnvironment(
        'GOOGLE_WEB_CLIENT_ID',
        defaultValue:
            '292708296634-hmo84p3o2db399id24367p00asio9gef.apps.googleusercontent.com',
      );
      final googleSignIn = GoogleSignIn(
        serverClientId: serverClientId.isNotEmpty ? serverClientId : null,
        scopes: const ['email', 'profile', 'openid'],
      );

      try {
        await googleSignIn.signOut();
      } catch (_) {}

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled account picker
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null || idToken.isEmpty) {
        throw Exception('لم يُرجع حساب Google رمز تأكيد (ID Token فارغ)');
      }

      await SupabaseService.instance.linkGoogleAccount(
        idToken: idToken,
        accessToken: accessToken,
      );

      // Save email in user metadata for display
      final user = SupabaseService.instance.currentUser;
      if (user != null) {
        try {
          await SupabaseService.instance.client.auth.updateUser(
            UserAttributes(
              data: {
                'google_linked': true,
                'google_email': googleUser.email,
              },
            ),
          );
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم ربط حساب Google (${googleUser.email}) بنجاح!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        _loadAccountData();
      }
    } on AuthException catch (e) {
      if (mounted) {
        final isConflict = e.message.toLowerCase().contains('already') ||
            e.statusCode == '422' ||
            e.statusCode == '400';
        final msg = isConflict
            ? 'حساب Google هذا مرتبط بالفعل بحساب آخر على فيتو ثانية.'
            : 'تعذر ربط حساب Google: ${e.message}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء ربط الحساب: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLinkingGoogle = false);
    }
  }

  Future<void> _save(Future<void> Function() action) async {
    setState(() => _saving = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).preferenceSaveFailed),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final prefs = ProductPreferences.instance;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF13182A) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2A3355) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0B0F1A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final goldColor = isDark ? const Color(0xFFFFC107) : const Color(0xFFD97706);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F1A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          l.settings,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          if (prefs.loadFailed)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                l.preferencesLoadFailed,
                style: const TextStyle(color: Colors.red),
              ),
            ),

          // ─── 1. SECTION: ACCOUNT SETTINGS ─────────────────────────────────
          _buildSectionHeader('الحساب والبيانات الشخصية', subtitleColor),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                // 1.1 Full Name
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: goldColor.withAlpha(isDark ? 35 : 20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.person_outline_rounded, color: goldColor, size: 22),
                  ),
                  title: Text(
                    'الاسم الكامل',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    _isLoadingAccount
                        ? 'جاري التحميل...'
                        : (_customerName.isNotEmpty ? _customerName : 'لم يتم تحديد الاسم'),
                    style: TextStyle(color: subtitleColor, fontSize: 13),
                  ),
                  trailing: TextButton.icon(
                    onPressed: _isLoadingAccount ? null : _changeName,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('تعديل'),
                    style: TextButton.styleFrom(
                      foregroundColor: goldColor,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                ),

                Divider(height: 1, indent: 64, endIndent: 16, color: borderColor),

                // 1.2 Phone Number
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: goldColor.withAlpha(isDark ? 35 : 20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.phone_iphone_rounded, color: goldColor, size: 22),
                  ),
                  title: Text(
                    'رقم الهاتف',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    _isLoadingAccount
                        ? 'جاري التحميل...'
                        : (_customerPhone.isNotEmpty ? _customerPhone : 'غير مسجل'),
                    style: TextStyle(color: subtitleColor, fontSize: 13),
                  ),
                  trailing: TextButton.icon(
                    onPressed: _isLoadingAccount ? null : _changePhone,
                    icon: const Icon(Icons.sync_rounded, size: 16),
                    label: const Text('تغيير'),
                    style: TextButton.styleFrom(
                      foregroundColor: goldColor,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                ),

                Divider(height: 1, indent: 64, endIndent: 16, color: borderColor),

                // 1.3 Google Account Link
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4285F4).withAlpha(isDark ? 35 : 18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'G',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF4285F4),
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    'حساب Google',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    _isGoogleLinked
                        ? (_googleEmail ?? 'مرتبط بالحساب')
                        : 'غير مرتبط - اربطه لتسجيل الدخول بسهولة',
                    style: TextStyle(
                      color: _isGoogleLinked ? const Color(0xFF10B981) : subtitleColor,
                      fontSize: 13,
                      fontWeight: _isGoogleLinked ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  trailing: _isGoogleLinked
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withAlpha(25),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF10B981).withAlpha(60)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 15),
                              SizedBox(width: 4),
                              Text(
                                'مرتبط',
                                style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        )
                      : FilledButton.tonal(
                          onPressed: (_isLoadingAccount || _isLinkingGoogle) ? null : _linkGoogle,
                          style: FilledButton.styleFrom(
                            backgroundColor: goldColor.withAlpha(isDark ? 50 : 30),
                            foregroundColor: goldColor,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isLinkingGoogle
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text(
                                  'ربط الآن',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                ),
                        ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ─── 2. SECTION: APP PREFERENCES ──────────────────────────────────
          _buildSectionHeader('تفضيلات التطبيق', subtitleColor),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Language
                Text(
                  l.language,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'ar', label: Text(l.arabic)),
                    ButtonSegment(value: 'en', label: Text(l.english)),
                  ],
                  selected: {prefs.locale.languageCode},
                  onSelectionChanged: _saving
                      ? null
                      : (v) => _save(() => prefs.setLanguage(v.single)),
                ),

                const SizedBox(height: 20),
                Divider(height: 1, color: borderColor),
                const SizedBox(height: 16),

                // Appearance
                Text(
                  l.appearance,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 10),
                for (final entry in [
                  MapEntry(ThemeMode.system, l.system),
                  MapEntry(ThemeMode.light, l.light),
                  MapEntry(ThemeMode.dark, l.dark),
                ])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.value, style: TextStyle(color: titleColor)),
                    leading: Icon(
                      entry.key == ThemeMode.dark
                          ? Icons.dark_mode_outlined
                          : entry.key == ThemeMode.light
                              ? Icons.light_mode_outlined
                              : Icons.settings_brightness,
                      color: goldColor,
                    ),
                    trailing: prefs.themeMode == entry.key
                        ? Icon(Icons.check_circle_rounded, color: goldColor)
                        : null,
                    onTap: _saving ? null : () => _save(() => prefs.setTheme(entry.key)),
                  ),
              ],
            ),
          ),

          if (_saving)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(),
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
