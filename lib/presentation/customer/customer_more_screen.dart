import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/strings.dart';
import '../../routes/app_routes.dart';
import '../../services/staff_access_v16.dart';
import '../../services/supabase_service.dart';
import '../../services/veto_mode_v21.dart';
import '../addresses/customer_saved_addresses.dart';
import '../growth/growth_screens.dart';
import '../settings/product_settings_screen.dart';
import 'customer_loyalty_panel_v29.dart';

/// Full-screen Modern & Premium "More" navigation hub.
/// Replaces the legacy side drawer with a clean, thumb-accessible, grouped interface.
class CustomerMoreScreen extends StatefulWidget {
  const CustomerMoreScreen({super.key});

  @override
  State<CustomerMoreScreen> createState() => _CustomerMoreScreenState();
}

class _CustomerMoreScreenState extends State<CustomerMoreScreen> {
  bool _approvedCaptainV21 = false;
  bool _staffVerifierV21 = false;
  String _customerName = '';
  String _customerPhone = '';
  String _supportPhone = '';
  String _supportWhatsapp = '';
  String? _profilePhotoUrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkCaptainV21();
    _checkVerifierV21();
  }

  Future<void> _checkVerifierV21() async {
    try {
      final access = await StaffAccessV16.load();
      final allowed =
          access.active &&
          access.can('verification.view') &&
          access.can('verification.manage');
      if (mounted && allowed != _staffVerifierV21) {
        setState(() => _staffVerifierV21 = allowed);
      }
    } catch (_) {}
  }

  Future<void> _checkCaptainV21() async {
    final id = SupabaseService.instance.currentUser?.id;
    if (id == null) return;
    try {
      final approved = await VetoModeV21.canUseCaptain(id);
      if (mounted && approved != _approvedCaptainV21) {
        setState(() => _approvedCaptainV21 = approved);
      }
    } catch (_) {}
  }

  Future<void> _loadProfile() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final user = SupabaseService.instance.currentUser;
      if (user != null) {
        _customerPhone = user.phone ?? '';
        final customer = await SupabaseService.instance.getCustomerByUserId(
          user.id,
        );
        if (customer != null && mounted) {
          _customerName = (customer['full_name'] as String?) ?? '';
          final phone = (customer['phone'] as String?) ?? '';
          if (phone.isNotEmpty) _customerPhone = phone;
          _profilePhotoUrl = customer['profile_photo_url'] as String?;
        }
      }
      final phone = await SupabaseService.instance.getSetting(
        'customer_service_phone',
      );
      final wa = await SupabaseService.instance.getSetting(
        'customer_service_whatsapp',
      );
      if (mounted) {
        if (phone != null && phone.isNotEmpty) _supportPhone = phone;
        if (wa != null && wa.isNotEmpty) _supportWhatsapp = wa;
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _launchWhatsAppSupport() async {
    final raw = _supportWhatsapp.isNotEmpty ? _supportWhatsapp : '01031517830';
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final intl = digits.startsWith('20')
        ? digits
        : '20${digits.replaceFirst(RegExp(r'^0+'), '')}';
    final uri = Uri.parse(
      'https://wa.me/$intl?text=${Uri.encodeComponent('مرحباً خدمة عملاء فيتو ثانية، أحتاج مساعدة')}',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح تطبيق واتساب حالياً')),
      );
    }
  }

  Future<void> _showLogoutDialog(BuildContext context, bool isDark) async {
    final cardColor = isDark ? const Color(0xFF13182A) : Colors.white;
    final titleColor = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0B0F1A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: cardColor,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withAlpha(24),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFEF4444),
                  size: 32,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'تسجيل الخروج',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك؟',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: subtitleColor,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await SupabaseService.instance.signOut();
                        if (mounted) {
                          context.go('/sign-up-login-screen');
                        }
                      },
                      child: const Text('تأكيد الخروج'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0B0F1A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF13182A) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2A3355) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0B0F1A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final goldColor = isDark ? const Color(0xFFFFC107) : const Color(0xFFD97706);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProfile,
          color: goldColor,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Screen Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'المزيد',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: titleColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'تحديث البيانات',
                        onPressed: _loadProfile,
                        icon: Icon(
                          Icons.refresh_rounded,
                          color: goldColor,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // 2. User Profile Card
                _buildProfileHeaderCard(
                  cardColor: cardColor,
                  borderColor: borderColor,
                  titleColor: titleColor,
                  subtitleColor: subtitleColor,
                  goldColor: goldColor,
                ),

                const SizedBox(height: 20),

                // 3. Section: Account & Trips
                _buildSectionHeader('الحساب والمشاوير', subtitleColor),
                const SizedBox(height: 8),
                _buildMenuCard(
                  cardColor: cardColor,
                  borderColor: borderColor,
                  children: [
                    _buildMenuItem(
                      icon: Icons.person_outline_rounded,
                      title: 'الملف الشخصي والولاء',
                      subtitle: 'نقاطك ومستواك في برنامج ولاء فيتو',
                      titleColor: titleColor,
                      subtitleColor: subtitleColor,
                      iconColor: goldColor,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CustomerLoyaltyPanelV29(),
                        ),
                      ),
                    ),
                    _buildDivider(borderColor),
                    _buildMenuItem(
                      icon: Icons.bookmark_outline_rounded,
                      title: 'العناوين المحفوظة',
                      subtitle: 'المنزل، العمل، والأماكن المفضلة',
                      titleColor: titleColor,
                      subtitleColor: subtitleColor,
                      iconColor: goldColor,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CustomerSavedAddresses(),
                        ),
                      ),
                    ),
                    _buildDivider(borderColor),
                    _buildMenuItem(
                      icon: Icons.receipt_long_rounded,
                      title: 'سجل الرحلات',
                      subtitle: 'سجل رحلاتك السابقة وتفاصيل الفواتير',
                      titleColor: titleColor,
                      subtitleColor: subtitleColor,
                      iconColor: goldColor,
                      onTap: () => context.go('/my-trips'),
                    ),
                    _buildDivider(borderColor),
                    _buildMenuItem(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'المحفظة والرصيد',
                      subtitle: 'الرصيد المتاح، الشحن، وسجل المعاملات',
                      titleColor: titleColor,
                      subtitleColor: subtitleColor,
                      iconColor: goldColor,
                      onTap: () => context.go('/wallet'),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 4. Section: Services & Growth
                _buildSectionHeader('الخدمات والعروض', subtitleColor),
                const SizedBox(height: 8),
                _buildMenuCard(
                  cardColor: cardColor,
                  borderColor: borderColor,
                  children: [
                    _buildMenuItem(
                      icon: Icons.directions_car_filled_rounded,
                      title: _approvedCaptainV21
                          ? 'التبديل إلى وضع الكابتن'
                          : 'اشتغل كابتن مع فيتو ثانية',
                      subtitle: _approvedCaptainV21
                          ? 'الانتقال لواجهة القيادة واستقبال الطلبات'
                          : 'انضم لأسطول الكباتن وابدأ بزيادة دخلك اليومي',
                      titleColor: titleColor,
                      subtitleColor: subtitleColor,
                      iconColor: goldColor,
                      isProminent: true,
                      onTap: () async {
                        if (_approvedCaptainV21) {
                          final id = SupabaseService.instance.currentUser?.id;
                          if (id != null) {
                            await VetoModeV21.openCaptain(
                              GoRouter.of(context),
                              id,
                            );
                          }
                        } else {
                          context.push(AppRoutes.captainRegistration);
                        }
                      },
                    ),
                    _buildDivider(borderColor),
                    _buildMenuItem(
                      icon: Icons.card_giftcard_rounded,
                      title: 'العروض والمكافآت',
                      subtitle: 'ادعُ أصدقاءك واكسب رصيداً إضافياً مجاناً',
                      titleColor: titleColor,
                      subtitleColor: subtitleColor,
                      iconColor: goldColor,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GrowthReferralScreen(),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 5. Section: Support & Safety
                _buildSectionHeader('الدعم والأمان', subtitleColor),
                const SizedBox(height: 8),
                _buildMenuCard(
                  cardColor: cardColor,
                  borderColor: borderColor,
                  children: [
                    _buildMenuItem(
                      icon: Icons.headset_mic_outlined,
                      title: 'مركز المساعدة والشكاوى',
                      subtitle: 'تقديم شكوى، اقتراح، أو متابعة طلب سابق',
                      titleColor: titleColor,
                      subtitleColor: subtitleColor,
                      iconColor: goldColor,
                      onTap: () => context.push(AppRoutes.customerFeedback),
                    ),
                    _buildDivider(borderColor),
                    _buildMenuItem(
                      icon: Icons.chat_rounded,
                      title: 'تواصل معنا عبر واتساب',
                      subtitle: 'خدمة العملاء متواجدة للرد على مدار الساعة',
                      titleColor: titleColor,
                      subtitleColor: subtitleColor,
                      iconColor: const Color(0xFF25D366),
                      onTap: _launchWhatsAppSupport,
                    ),
                    _buildDivider(borderColor),
                    _buildMenuItem(
                      icon: Icons.shield_outlined,
                      title: 'الأمان والسلامة',
                      subtitle: 'مشاركة مسار المشوار مع الأهل وإرشادات الأمان',
                      titleColor: titleColor,
                      subtitleColor: subtitleColor,
                      iconColor: goldColor,
                      onTap: () => context.push(AppRoutes.safetySupport),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 6. Section: Settings & Info
                _buildSectionHeader('الإعدادات والمعلومات', subtitleColor),
                const SizedBox(height: 8),
                _buildMenuCard(
                  cardColor: cardColor,
                  borderColor: borderColor,
                  children: [
                    _buildMenuItem(
                      icon: Icons.notifications_none_rounded,
                      title: 'الإشعارات',
                      subtitle: 'سجل التنبيهات والرسائل الواردة',
                      titleColor: titleColor,
                      subtitleColor: subtitleColor,
                      iconColor: goldColor,
                      onTap: () => context.push(AppRoutes.notifications),
                    ),
                    _buildDivider(borderColor),
                    _buildMenuItem(
                      icon: Icons.settings_outlined,
                      title: 'إعدادات التطبيق',
                      subtitle: 'اللغة، المظهر، والوضع التلقائي للجهاز',
                      titleColor: titleColor,
                      subtitleColor: subtitleColor,
                      iconColor: goldColor,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProductSettingsScreen(),
                        ),
                      ),
                    ),
                    _buildDivider(borderColor),
                    _buildMenuItem(
                      icon: Icons.policy_outlined,
                      title: 'الشروط والأحكام والخصوصية',
                      subtitle: 'سياسة الاستخدام وحماية البيانات القانونية',
                      titleColor: titleColor,
                      subtitleColor: subtitleColor,
                      iconColor: goldColor,
                      onTap: () => context.push(AppRoutes.legalCenter),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 7. Logout Button
                InkWell(
                  onTap: () => _showLogoutDialog(context, isDark),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withAlpha(isDark ? 30 : 16),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withAlpha(isDark ? 80 : 40),
                      ),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            color: Color(0xFFEF4444),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'تسجيل الخروج',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // 8. Version tag
                Center(
                  child: Text(
                    'VETO SANYA • الإصدار 2.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: subtitleColor.withAlpha(160),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _buildProfileHeaderCard({
    required Color cardColor,
    required Color borderColor,
    required Color titleColor,
    required Color subtitleColor,
    required Color goldColor,
  }) {
    final displayName = _customerName.trim().isNotEmpty
        ? _customerName.trim()
        : 'عميل فيتو ثانية';
    final displayPhone = _customerPhone.trim().isNotEmpty
        ? _customerPhone.trim()
        : 'رقم الهاتف غير متاح';

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: goldColor, width: 2),
            ),
            child: ClipOval(
              child: _profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty
                  ? Image.network(
                      _profilePhotoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildFallbackAvatar(goldColor),
                    )
                  : _buildFallbackAvatar(goldColor),
            ),
          ),

          const SizedBox(width: 14),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayPhone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: subtitleColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withAlpha(22),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          color: Color(0xFF10B981),
                          size: 13,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'حساب نشط وموثق',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Edit Profile Icon Button
          IconButton(
            tooltip: 'تعديل الملف الشخصي',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CustomerLoyaltyPanelV29(),
              ),
            ),
            icon: Icon(
              Icons.chevron_left_rounded,
              color: goldColor,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackAvatar(Color goldColor) {
    return Container(
      color: goldColor.withAlpha(25),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          color: goldColor,
          size: 34,
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required Color cardColor,
    required Color borderColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color titleColor,
    required Color subtitleColor,
    required Color iconColor,
    required VoidCallback onTap,
    bool isProminent = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(isProminent ? 32 : 18),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: iconColor, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: isProminent ? FontWeight.w800 : FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: subtitleColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_left_rounded,
              color: subtitleColor.withAlpha(140),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(Color color) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 68,
      endIndent: 16,
      color: color.withAlpha(140),
    );
  }
}
