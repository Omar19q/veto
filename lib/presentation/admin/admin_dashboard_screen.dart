import '../../services/veto_mode_v21.dart';
import 'package:vetosanya/widgets/captain_photo_v16.dart';
import '../../services/staff_access_v16.dart';
import '../growth/admin_growth_screen.dart';
import '../growth/admin_badge_activation_screen.dart';
import 'staff_management_v16.dart';
import 'admin_debt_invoices_v17.dart';
import 'team_chat_screen_v16.dart';
import '../../services/admin_directory_pager_v15.dart';
import 'admin_overview_v9.dart';
import 'admin_live_operations_v10.dart';
import 'admin_incidents_v10.dart';
import 'admin_health_v10.dart';
import 'admin_pricing_engine_v10.dart';
import 'admin_hot_zones_v35.dart';
import 'admin_customer_loyalty_hub_v38.dart';
import 'admin_location_hub_v38.dart';
import 'admin_trip_rules_v9.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_captain_recovery_v58.dart';
import 'dart:ui' as ui;
import 'admin_captain_actions_v10.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/admin_copy_button.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';
import '../../services/app_sound_service.dart';
import 'verification_desk_v22.dart';
import '../../services/zone_pricing_service.dart';
import '../../theme/admin_theme.dart';
import './admin_captain_form.dart';
import './admin_customers_panel.dart';
import './admin_pricing_panel.dart';
import './admin_wallet_panel.dart';
import './admin_promo_panel.dart';
import './admin_notifications_panel.dart';
import './admin_audit_log_panel.dart';
import './admin_reports_panel.dart';
import './admin_banners_panel.dart';
import './admin_feedback_panel.dart';
import './admin_karizma_panel.dart';
import './admin_captain_rewards_panel.dart';
import './admin_topup_panel.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  StaffAccessV16 _access = const StaffAccessV16();
  RealtimeChannel? _staffAccessChannel;
  static const _sectionPermissions = [
    'reports.view',
    'verification.view',
    'customers.view',
    'captains.view',
    'trips.view',
    'pricing.view',
    'pricing.view',
    'pricing.view',
    'settings.view',
    'finance.view',
    'pricing.view',
    'notifications.view',
    'staff.view',
    'settings.view',
    'reports.view',
    'captains.view',
    'settings.view',
    'complaints.view',
    'settings.view',
    'finance.view',
    'finance.view',
    'trips.view',
    'trips.view',
    'settings.view',
    'staff.manage',
    'chat.view',
    'notifications.view',
    'finance.view',
    'settings.view', // V29 customer frames: owner-only via _canSection
    'captains.view', // V59 direct owner badge control
    'growth.view', // V66: owner marketing, first-trip campaigns and friend referrals
  ];
  bool get _verificationOnlyV21 => !_access.owner && _access.active &&
      _access.can('verification.view') && _access.can('verification.manage') &&
      _access.permissions.difference(const {'verification.view', 'verification.manage', 'notifications.view'}).isEmpty;
  bool _canSection(int index) =>
      (index == 24 || index == 28 || index == 29 || index == 30) ? _access.owner : _access.can(_sectionPermissions[index]);
  Future<void> _refreshStaffAccess() async {
    try {
      final next = await StaffAccessV16.load();
      if (!mounted) return;
      setState(() {
        _access = next;
        if (_verificationOnlyV21) _selectedIndex = 1;
        if (!next.can('verification.view') || !next.can('verification.manage'))
          _pendingVerification = null;
      });
      if (!next.active) {
        _verificationPopupSubscription?.unsubscribe();
        _verificationFallbackV17?.cancel();
        _verificationFallbackV17 = null;
        _syncVerificationNagTimer(null);
        context.go('/staff-login');
      } else if (next.can('verification.view') &&
          next.can('verification.manage')) {
        _subscribeToVerificationOverlay();
      } else {
        _verificationPopupSubscription?.unsubscribe();
        _verificationFallbackV17?.cancel();
        _verificationFallbackV17 = null;
        _syncVerificationNagTimer(null);
      }
    } catch (_) {
      if (mounted)
        setState(() {
          _access = const StaffAccessV16();
          _pendingVerification = null;
        });
    }
  }

  bool _statsInFlight = false;
  bool _statsDirty = false;
  bool _railExpanded = false;
  final GlobalKey<ScaffoldState> _adminScaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  String? _errorMessage;
  String? _focusTopupRequest;

  // Realtime subscriptions for live admin stats
  TripRealtimeLease? _tripsSubscription;
  Timer? _statsRefreshDebounce;
  RealtimeChannel? _verificationPopupSubscription;
  Timer? _verificationPopupDebounce;
  Timer? _verificationNagTimer;
  Timer? _verificationFallbackV17;
  Map<String, dynamic>? _pendingVerification;
  final Set<String> _alertedVerificationIds = {};
  final Set<String> _skippedVerificationIds = {};
  bool _verificationMuted = false;
  Future<void> _loadVerificationMute() async {
    final preferences = await SharedPreferences.getInstance();
    final userId = SupabaseService.instance.currentUser?.id ?? 'anonymous';
    if (mounted) setState(() => _verificationMuted =
      preferences.getBool('veto_admin_verification_mute_$userId') ?? false);
  }
  Future<void> _toggleVerificationMute() async {
    final next = !_verificationMuted;
    setState(() => _verificationMuted=next);
    final prefs=await SharedPreferences.getInstance();
    final userId=SupabaseService.instance.currentUser?.id ?? 'anonymous';
    await prefs.setBool('veto_admin_verification_mute_$userId',next);
    if (!next) _refreshPendingVerification(playSound:false);
  }
  void _skipVerificationPopup() {
    final id=_pendingVerification?['id']?.toString();
    if (id==null)return;
    setState(() {
      _skippedVerificationIds.add(id);
      _pendingVerification=null;
      _verificationCodeController.clear();
    });
    _refreshPendingVerification(playSound:false);
  }
  final TextEditingController _verificationCodeController =
      TextEditingController();
  bool _verificationSaving = false;
  bool _verificationWhatsappOpening = false;

  final List<_AdminSection> _sections = [
    _AdminSection(icon: Icons.dashboard_rounded, label: 'الرئيسية'),
    _AdminSection(icon: Icons.verified_user_rounded, label: 'التحقق'),
    _AdminSection(icon: Icons.people_rounded, label: 'العملاء'),
    _AdminSection(icon: Icons.drive_eta_rounded, label: 'الكباتن'),
    _AdminSection(icon: Icons.route_rounded, label: 'الرحلات'),
    _AdminSection(icon: Icons.place_rounded, label: 'الأماكن'),
    _AdminSection(icon: Icons.location_city_rounded, label: 'العمارات'),
    _AdminSection(icon: Icons.attach_money_rounded, label: 'التسعير'),
    _AdminSection(icon: Icons.store_rounded, label: 'السوبر ماركت'),
    _AdminSection(icon: Icons.account_balance_wallet_rounded, label: 'المحافظ'),
    _AdminSection(icon: Icons.local_offer_rounded, label: 'البروموكود'),
    _AdminSection(icon: Icons.notifications_rounded, label: 'الإشعارات'),
    _AdminSection(icon: Icons.history_rounded, label: 'سجل التغييرات'),
    _AdminSection(icon: Icons.settings_rounded, label: 'الإعدادات'),
    _AdminSection(icon: Icons.analytics_rounded, label: 'التقارير'),
    _AdminSection(icon: Icons.person_add_alt_1_rounded, label: 'طلبات الكباتن'),
    _AdminSection(icon: Icons.view_carousel_rounded, label: 'البنرات'),
    _AdminSection(icon: Icons.feedback_outlined, label: 'اقتراحات وشكاوى'),
    _AdminSection(icon: Icons.auto_awesome_rounded, label: 'كاريزما'),
    _AdminSection(icon: Icons.card_giftcard_rounded, label: 'مكافآت الكباتن'),
    _AdminSection(
      icon: Icons.account_balance_wallet_rounded,
      label: 'شحن المحفظة والعروض',
    ),
    _AdminSection(icon: Icons.map_rounded, label: 'العمليات الحية'),
    _AdminSection(icon: Icons.warning_amber_rounded, label: 'الحالات والمخاطر'),
    _AdminSection(icon: Icons.monitor_heart_outlined, label: 'صحة النظام'),
    _AdminSection(icon: Icons.badge_outlined, label: 'إدارة الفريق'),
    _AdminSection(icon: Icons.forum_outlined, label: 'محادثات الفريق'),
    _AdminSection(
      icon: Icons.notifications_active_outlined,
      label: 'مركز إشعارات الفريق',
    ),
    _AdminSection(icon: Icons.receipt_long_rounded, label: 'فواتير مديونية الكباتن'),
    _AdminSection(icon: Icons.workspace_premium_rounded, label: 'إطارات ورتب العملاء'),
    _AdminSection(icon: Icons.qr_code_2_rounded, label: 'أكواد وبادجات الكباتن'),
    _AdminSection(icon: Icons.card_giftcard_rounded, label: 'إدارة الدعوات والعروض'),
  ];

  @override
  void initState() {
    super.initState();
    AdminTheme.loadPreference();
    _loadVerificationMute();
    _checkAdminAccess();
  }

  @override
  void dispose() {
    _staffAccessChannel?.unsubscribe();
    _tripsSubscription?.unsubscribe();
    _verificationPopupSubscription?.unsubscribe();
    _statsRefreshDebounce?.cancel();
    _verificationPopupDebounce?.cancel();
    _verificationNagTimer?.cancel();
    _verificationFallbackV17?.cancel();
    _verificationCodeController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminAccess() async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) {
      if (mounted) context.go('/admin');
      return;
    }
    try {
      final access = await StaffAccessV16.load();
      if (!mounted) return;
      if (!access.active) {
        context.go('/staff-login');
        return;
      }
      setState(() {
        _access = access;
        if (_verificationOnlyV21) _selectedIndex = 1;
        _isLoading = false;
        if (!_canSection(_selectedIndex)) {
          final first = List.generate(
            _sections.length,
            (i) => i,
          ).where(_canSection);
          if (first.isNotEmpty) _selectedIndex = first.first;
        }
      });
      if (access.owner || access.can('reports.view')) {
        _loadStats();
        _subscribeToAdminRealtime();
      }
      if (access.can('verification.view') && access.can('verification.manage'))
        _subscribeToVerificationOverlay();
      _staffAccessChannel ??= SupabaseService.instance.client
          .channel('v16-staff-access-${user.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'staff_v16',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: user.id,
            ),
            callback: (_) => _refreshStaffAccess(),
          )
          .subscribe((status, error) {
            if (status == RealtimeSubscribeStatus.subscribed)
              _refreshStaffAccess();
          });
    } catch (_) {
      if (mounted)
        setState(
          () => _errorMessage = 'تعذر التحقق من صلاحيات الفريق. أعد المحاولة.',
        );
    }
  }

  void _subscribeToAdminRealtime() {
    _tripsSubscription ??= SupabaseService.instance.subscribeToScaleAdminPulse(
      _scheduleStatsRefresh,
    );
  }

  void _scheduleStatsRefresh() {
    if (_statsRefreshDebounce?.isActive == true) return;
    _statsRefreshDebounce = Timer(const Duration(seconds: 2), () {
      _statsRefreshDebounce = null;
      _loadStats();
    });
  }

  void _subscribeToVerificationOverlay() {
    // Verification-only staff use their dedicated desk; do not play the old
    // admin overlay sound on top of its new-request notification.
    if (_verificationOnlyV21) return;
    if (!_access.can('verification.view') ||
        !_access.can('verification.manage'))
      return;
    _verificationPopupSubscription?.unsubscribe();
    _verificationPopupSubscription = SupabaseService.instance
        .subscribeToVerificationRequests((_) => _scheduleVerificationRefresh());
    // Recover missed Realtime events (including after reconnect) while the
    // authorized dashboard is visible. Sound is deduplicated by request ID.
    _verificationFallbackV17 ??= Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refreshPendingVerification(),
    );
    // If the dashboard opens while a request is already waiting, treat it as
    // actionable work and surface it immediately.
    _refreshPendingVerification(playSound: true);
  }

  void _scheduleVerificationRefresh() {
    _verificationPopupDebounce?.cancel();
    _verificationPopupDebounce = Timer(
      const Duration(milliseconds: 160),
      () => _refreshPendingVerification(),
    );
  }

  void _syncVerificationNagTimer(String? requestId) {
    _verificationNagTimer?.cancel();
    _verificationNagTimer = null;
  }

  Future<void> _refreshPendingVerification({bool playSound = true}) async {
    if (!_access.can('verification.view') ||
        !_access.can('verification.manage'))
      return;
    try {
      final rows = await SupabaseService.instance.client
          .from('verification_requests')
          .select('id,phone,status,created_at')
          .eq('status', 'pending')
          .order('created_at', ascending: true)
          .limit(100);
      if (!mounted ||
          !_access.can('verification.view') ||
          !_access.can('verification.manage'))
        return;

      final visible=rows.where((r)=>!_skippedVerificationIds.contains(r['id']?.toString())).toList();
       final next = visible.isEmpty ? null : Map<String, dynamic>.from(visible.first);
      final nextId = next?['id']?.toString();
      final changedRequest =
          nextId != null &&
          nextId.isNotEmpty &&
          !_alertedVerificationIds.contains(nextId);

      setState(() {
        _pendingVerification = next;
        if (next == null) {
          _verificationCodeController.clear();
        } else if (changedRequest) {
          _verificationCodeController.clear();
        }
      });
      _syncVerificationNagTimer(nextId);

      if (playSound && !_verificationMuted && changedRequest) {
        _alertedVerificationIds.add(nextId);
        if (_alertedVerificationIds.length > 500)
          _alertedVerificationIds.remove(_alertedVerificationIds.first);
        try { await HapticFeedback.mediumImpact(); } catch (_) {}
        await AppSoundService.instance.playVerificationAlert();
      }
    } catch (_) {
      // Keep the last visible request. Realtime/resubscribe will retry without
      // polling the dashboard continuously.
    }
  }

  bool _validVerificationCode(String code) => RegExp(r'^\d{4}$').hasMatch(code);

  String _whatsAppNumber(String rawPhone) {
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if (digits.startsWith('20')) return digits;
    if (digits.startsWith('0') && digits.length >= 10) {
      return '20${digits.substring(1)}';
    }
    return digits;
  }

  Future<bool> _persistVerificationCode() async {
    final request = _pendingVerification;
    if (request == null || _verificationSaving) return false;
    final code = _verificationCodeController.text.trim();
    if (!_validVerificationCode(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'اكتب كود مكوّن من 4 أرقام.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      return false;
    }

    setState(() => _verificationSaving = true);
    try {
      await SupabaseService.instance.assignVerificationCode(
        request['id'].toString(),
        code,
      );
      _verificationNagTimer?.cancel();
      _verificationNagTimer = null;
      await _refreshPendingVerification(playSound: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم حفظ كود التحقق.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر حفظ الكود. حاول مرة أخرى.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _verificationSaving = false);
    }
  }

  Future<void> _saveVerificationCodeFromOverlay() async {
    await _persistVerificationCode();
  }

  Future<void> _saveVerificationAndOpenWhatsApp() async {
    final request = _pendingVerification;
    if (request == null ||
        _verificationSaving ||
        _verificationWhatsappOpening) {
      return;
    }
    final code = _verificationCodeController.text.trim();
    if (!_validVerificationCode(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'اكتب كود من 4 أرقام الأول.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      return;
    }

    final number = _whatsAppNumber(request['phone']?.toString() ?? '');
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'رقم الهاتف غير صالح لفتح WhatsApp.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      return;
    }

    setState(() => _verificationWhatsappOpening = true);
    try {
      final saved = await _persistVerificationCode();
      if (!saved || !mounted) return;

      final message =
          'أهلاً بك في VETO SANYA 👋\n'
          'كود التحقق الخاص بك هو: $code\n'
          'الكود صالح لمدة 10 دقائق. لا تشاركه مع أي شخص.';
      final uri = Uri.parse(
        'https://wa.me/$number?text=${Uri.encodeComponent(message)}',
      );
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم حفظ الكود، لكن تعذر فتح WhatsApp.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _verificationWhatsappOpening = false);
    }
  }

  Future<void> _rejectVerificationFromOverlay() async {
    final request = _pendingVerification;
    if (request == null || _verificationSaving) return;
    setState(() => _verificationSaving = true);
    try {
      await SupabaseService.instance.cancelVerificationRequest(
        request['id'].toString(),
      );
      _verificationNagTimer?.cancel();
      _verificationNagTimer = null;
      await _refreshPendingVerification(playSound: false);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر رفض الطلب الآن.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _verificationSaving = false);
    }
  }

  Widget _buildVerificationOverlay() {
    final request = _pendingVerification!;
    final phone = request['phone']?.toString() ?? 'رقم غير متاح';
    final createdRaw = request['created_at']?.toString();
    final createdAt = DateTime.tryParse(createdRaw ?? '')?.toLocal();
    final timeText = createdAt == null
        ? 'وصل الآن'
        : '${createdAt.hour.toString().padLeft(2, '0')}:'
              '${createdAt.minute.toString().padLeft(2, '0')}';

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: AbsorbPointer(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  color: const Color(0xFF07101F).withValues(alpha: .48),
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                  decoration: BoxDecoration(
                    color: AdminTheme.surface.withValues(alpha: .96),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: AdminTheme.gold.withValues(alpha: .88),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AdminTheme.goldDark.withValues(alpha: .22),
                        blurRadius: 42,
                        spreadRadius: 2,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: .88, end: 1),
                            duration: const Duration(milliseconds: 650),
                            curve: Curves.easeOutBack,
                            builder: (context, value, child) =>
                                Transform.scale(scale: value, child: child),
                            child: Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AdminTheme.gold,
                                    AdminTheme.goldDark,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(19),
                                boxShadow: [
                                  BoxShadow(
                                    color: AdminTheme.gold.withValues(
                                      alpha: .28,
                                    ),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.flash_on_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 7,
                                  runSpacing: 7,
                                  children: [
                                    Text(
                                      'طلب تحقق سريع',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: AdminTheme.ink,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: const Text(
                                        'مباشر',
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF15803D),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'اكتب الكود وابعته للعميل على WhatsApp من نفس النافذة.',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 11.5,
                                    height: 1.5,
                                    color: AdminTheme.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AdminTheme.surfaceSoft,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AdminTheme.borderSoft),
                            ),
                            child: Text(
                              timeText,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.w800,
                                color: AdminTheme.muted,
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'تخطي الطلب دون حذفه',
                            icon: const Icon(Icons.close),
                            onPressed: _skipVerificationPopup,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AdminTheme.surfaceSoft,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AdminTheme.borderSoft),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AdminTheme.gold.withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(
                                Icons.phone_rounded,
                                color: AdminTheme.goldDark,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'رقم صاحب طلب التحقق',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 10.5,
                                      color: AdminTheme.muted,
                                    ),
                                  ),
                                  SelectableText(
                                    phone,
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 19,
                                      fontWeight: FontWeight.w900,
                                      color: AdminTheme.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('رقم الطلب: ${request['id']?.toString().substring(0, 8) ?? ''}',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700, color: AdminTheme.muted)),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _verificationCodeController,
                        enabled: !_verificationSaving,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        maxLength: 4,
                        textAlign: TextAlign.center,
                        autofocus: true,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 29,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 10,
                          color: AdminTheme.ink,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          labelText: 'كود التحقق',
                          hintText: '••••',
                          prefixIcon: const Icon(Icons.password_rounded),
                          filled: true,
                          fillColor: AdminTheme.surfaceSoft,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onSubmitted: (_) => _saveVerificationAndOpenWhatsApp(),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          onPressed:
                              (_verificationSaving ||
                                  _verificationWhatsappOpening)
                              ? null
                              : _saveVerificationAndOpenWhatsApp,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon:
                              (_verificationSaving ||
                                  _verificationWhatsappOpening)
                              ? const SizedBox(
                                  width: 19,
                                  height: 19,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.chat_rounded),
                          label: const Text(
                            'حفظ الكود وفتح WhatsApp',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _verificationSaving
                                  ? null
                                  : _saveVerificationCodeFromOverlay,
                              icon: const Icon(Icons.save_rounded),
                              label: const Text(
                                'حفظ فقط',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: _verificationSaving
                                  ? null
                                  : _rejectVerificationFromOverlay,
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Color(0xFFDC2626),
                              ),
                              label: const Text(
                                'رفض الطلب',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'التنبيه يفضل شغال لحد ما تتعامل مع الطلب. بعد حفظ الكود ينتقل الطلب تلقائيًا للحالة التالية.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10.5,
                          height: 1.45,
                          color: AdminTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadStats() async {
    if (!_access.can('reports.view')) return;
    if (_statsInFlight) {
      _statsDirty = true;
      return;
    }
    _statsInFlight = true;
    try {
      final stats = await SupabaseService.instance.getAdminDashboardStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'تعذر تحميل البيانات';
        });
      }
    } finally {
      _statsInFlight = false;
      if (_statsDirty && mounted) {
        _statsDirty = false;
        _scheduleStatsRefresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: AdminTheme.dark,
    builder: (context, dark, _) => Theme(
      data: AdminTheme.theme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: LayoutBuilder(
          builder: (context, layout) {
            final compact = layout.maxWidth < 900;
            final sidebar = _AdminSidebar(
              sections: _sections,
              selectedIndex: _selectedIndex,
              onSelect: (i) {
                setState(() => _selectedIndex = i);
                // Close only the drawer: popping the route can blank the admin UI.
                if (compact) _adminScaffoldKey.currentState?.closeDrawer();
              },
              onLogout: () async {
                await SupabaseService.instance.signOut();
                VetoModeV21.reset();
                if (mounted) context.go('/admin');
              },
            );
            final scaffold = Scaffold(
              key: _adminScaffoldKey,
              backgroundColor: AdminTheme.background,
              drawer: compact && !_verificationOnlyV21 ? Drawer(child: SafeArea(child: sidebar)) : null,
              appBar: AppBar(
                leading: compact || _verificationOnlyV21
                    ? null
                    : IconButton(
                        tooltip: 'توسيع القائمة',
                        onPressed: () =>
                            setState(() => _railExpanded = !_railExpanded),
                        icon: Icon(
                          _railExpanded ? Icons.menu_open : Icons.menu,
                        ),
                      ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _sections[_selectedIndex].label,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'VETO SANYA / مركز الإدارة',
                      style: TextStyle(fontSize: 11, color: AdminTheme.muted),
                    ),
                  ],
                ),
                actions: [
                  if (_access.owner || _access.can('growth.view'))
                    IconButton(tooltip: 'دعوات الأصدقاء والعروض', icon: const Icon(Icons.campaign_outlined),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminGrowthScreen()))),
                  if (_verificationOnlyV21)
                    IconButton(
                      tooltip: 'الرجوع إلى حساب العميل أو الكابتن',
                      icon: const Icon(Icons.swap_horiz_rounded),
                      onPressed: () async {
                        final id = SupabaseService.instance.currentUser?.id;
                        if (id == null) return;
                        try {
                          if (await VetoModeV21.canUseCaptain(id)) {
                            if (mounted) await VetoModeV21.openCaptain(GoRouter.of(context), id);
                          } else if (await VetoModeV21.canUseCustomer(id)) {
                            if (mounted) await VetoModeV21.openCustomer(GoRouter.of(context), id);
                          } else if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('هذا الحساب مخصص للتحقق فقط.')),
                            );
                          }
                        } catch (_) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تعذر فتح الحساب، حاول مرة أخرى.')),
                          );
                        }
                      },
                    ),
                  if (_verificationOnlyV21)
                    IconButton(
                      tooltip: 'تسجيل الخروج',
                      icon: const Icon(Icons.logout_rounded),
                      onPressed: () async {
                        await SupabaseService.instance.signOut();
                        VetoModeV21.reset();
                        if (mounted) context.go('/admin');
                      },
                    ),
                  if (_access.can('verification.manage') && !_verificationOnlyV21)
                    IconButton(
                      tooltip: _verificationMuted
                        ? 'تشغيل نافذة التحقق والتنبيه'
                        : 'كتم نافذة التحقق والتنبيه — الطلبات محفوظة',
                      icon: Icon(_verificationMuted
                        ? Icons.notifications_off_outlined
                        : Icons.notifications_active_outlined),
                      onPressed: _toggleVerificationMute,
                    ),
                  IconButton(
                    tooltip: dark ? 'الوضع الفاتح' : 'الوضع الداكن',
                    onPressed: AdminTheme.toggle,
                    icon: Icon(
                      dark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                    ),
                  ),
                  IconButton(
                    tooltip: 'تحديث البيانات',
                    onPressed: _loadStats,
                    icon: Icon(Icons.refresh),
                  ),
                ],
              ),
              bottomNavigationBar: compact && !_verificationOnlyV21
                  ? NavigationBar(
                      selectedIndex:
                          const [0, 4, 3, 14].contains(_selectedIndex)
                          ? const [0, 4, 3, 14].indexOf(_selectedIndex)
                          : 0,
                      onDestinationSelected: (i) =>
                          setState(() => _selectedIndex = [0, 4, 3, 14][i]),
                      destinations: [
                        NavigationDestination(
                          icon: Icon(Icons.dashboard_outlined),
                          label: 'الرئيسية',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.route_outlined),
                          label: 'الرحلات',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.local_taxi_outlined),
                          label: 'الكباتن',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.analytics_outlined),
                          label: 'التقارير',
                        ),
                      ],
                    )
                  : null,
              body: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      AdminTheme.background,
                      AdminTheme.surfaceSoft.withValues(alpha: .65),
                      AdminTheme.background,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    if (!compact && !_verificationOnlyV21)
                      if (_railExpanded)
                        sidebar
                      else
                        SizedBox(
                          width: 78,
                          child: ListView(
                            children: [
                              for (var i = 0; i < _sections.length; i++)
                                  if (i != 8 && _canSection(i))
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: 3),
                                  child: IconButton(
                                    tooltip: _sections[i].label,
                                    isSelected: _selectedIndex == i,
                                    onPressed: () =>
                                        setState(() => _selectedIndex = i),
                                    icon: Icon(
                                      _sections[i].icon,
                                      color: _selectedIndex == i
                                          ? AdminTheme.goldDark
                                          : AdminTheme.muted,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    Expanded(child: _buildContent()),
                  ],
                ),
              ),
            );
            return Stack(
              children: [
                scaffold,
                if (_pendingVerification != null && !_verificationMuted && !_verificationOnlyV21)
                  Positioned.fill(child: _buildVerificationOverlay()),
              ],
            );
          },
        ),
      ),
    ),
  );

  Widget _buildContent() {
    if (!_canSection(_selectedIndex))
      return const Center(
        child: Text('هذه الوظيفة غير متاحة ضمن صلاحياتك. تواصل مع الأونر.'),
      );
    switch (_selectedIndex) {
      case 0:
        return AdminOverviewV9(
          isLoading: _isLoading,
          stats: _stats,
          errorMessage: _errorMessage,
          onRefresh: _loadStats,
          onNavigate: (section, requestId) => setState(() {
            _selectedIndex = section;
            _focusTopupRequest = requestId;
          }),
        );
      case 1:
        return _verificationOnlyV21 ? const VerificationDeskV22() : _VerificationPanel();
      case 2:
        return AdminCustomersPanel();
      case 3:
        return _CaptainsPanel();
      case 4:
        return _TripsPanel();
      case 5:
        return AdminLocationHubV38(kind: AdminLocationKind.places, showCityDrafts: _access.owner);
      case 6:
        return AdminLocationHubV38(kind: AdminLocationKind.buildings, showCityDrafts: _access.owner);
      case 7:
        return AdminPricingPanel(showCityDrafts: _access.owner);
      case 8:
        return const Center(child: Text('فيتو ماركت متوقف مؤقتًا.'));
      case 9:
        return AdminWalletPanel();
      case 10:
        return AdminPromoPanel();
      case 11:
        return AdminNotificationsPanel();
      case 12:
        return AdminAuditLogPanel();
      case 13:
        return ListView(
          padding: EdgeInsets.all(18),
          children: [
            AdminTripRulesV9(),
            const AdminPricingEngineV10(),
            const AdminHotZonesV35(),
            SizedBox(height: 20),
            SizedBox(height: 900, child: _SettingsPanel()),
          ],
        );
      case 14:
        return AdminReportsPanel();
      case 15:
        return const AdminCaptainRecoveryV58();
      case 16:
        return AdminBannersPanel();
      case 17:
        return AdminFeedbackPanel();
      case 18:
        return AdminKarizmaPanel();
      case 19:
        return AdminCaptainRewardsPanel();
      case 20:
        return AdminTopupPanel(
          key: ValueKey(_focusTopupRequest),
          initialRequestId: _focusTopupRequest,
        );
      case 21:
        return const AdminLiveOperationsV10();
      case 22:
        return const AdminIncidentsV10();
      case 23:
        return const AdminHealthV10();
      case 24:
        return const StaffManagementV16();
      case 25:
        return const TeamChatScreenV16();
      case 26:
        return const TeamNotificationCenterV16();
      case 27:
        return const AdminDebtInvoicesV17();
      case 29:
        return const AdminBadgeActivationScreen();
      case 30:
        return const AdminGrowthScreen();
      case 28:
        return const AdminCustomerLoyaltyHubV38();
      default:
        return SizedBox.shrink();
    }
  }
}

class _AdminSection {
  final IconData icon;
  final String label;
  const _AdminSection({required this.icon, required this.label});
}

class _AdminSidebar extends StatelessWidget {
  final List<_AdminSection> sections;
  final int selectedIndex;
  final void Function(int) onSelect;
  final VoidCallback onLogout;

  const _AdminSidebar({
    required this.sections,
    required this.selectedIndex,
    required this.onSelect,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 252,
      decoration: BoxDecoration(
        color: AdminTheme.surface,
        border: Border(left: BorderSide(color: AdminTheme.borderSoft)),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(18, 24, 18, 16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AdminTheme.gold,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AdminTheme.gold.withValues(alpha: .20),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.bolt_rounded,
                    color: AdminTheme.ink,
                    size: 28,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VETO SANYA',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: AdminTheme.ink,
                        ),
                      ),
                      Text(
                        'لوحة الإدارة والتقارير',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10.5,
                          color: AdminTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              itemCount: sections.length,
              itemBuilder: (context, i) {
                final section = sections[i];
                final selected = i == selectedIndex;
                return Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: selected
                        ? AdminTheme.surfaceStrong
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => onSelect(i),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? AdminTheme.gold
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: selected
                                    ? AdminTheme.gold
                                    : AdminTheme.surfaceSoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                section.icon,
                                size: 18,
                                color: AdminTheme.ink,
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                section.label,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  fontWeight: selected
                                      ? FontWeight.w900
                                      : FontWeight.w600,
                                  color: AdminTheme.ink,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (selected)
                              Icon(
                                Icons.chevron_left_rounded,
                                size: 18,
                                color: AdminTheme.goldDark,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(12),
            child: OutlinedButton.icon(
              onPressed: onLogout,
              icon: Icon(Icons.logout_rounded, size: 18),
              label: Text(
                'تسجيل الخروج',
                style: TextStyle(fontFamily: 'Cairo'),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 46),
                foregroundColor: AdminTheme.ink,
                side: BorderSide(color: AdminTheme.border),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── DASHBOARD OVERVIEW ──────────────────────────────────────────────────────

class _VerificationPanel extends StatefulWidget {
  _VerificationPanel();

  @override
  State<_VerificationPanel> createState() => _VerificationPanelState();
}

class _VerificationPanelState extends State<_VerificationPanel> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  RealtimeChannel? _verificationChannel;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // Includes UPDATE events: 'verified' is an UPDATE, not a new request.
    _verificationChannel = SupabaseService.instance
        .subscribeToVerificationRequests((_) => _load());
    // Fallback for briefly disconnected Realtime clients.
    _refreshTimer = Timer.periodic(Duration(seconds: 60), (_) => _load());
  }

  @override
  void dispose() {
    _verificationChannel?.unsubscribe();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _openVerificationWhatsApp(String phone, String code) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final international = digits.startsWith('20')
        ? digits
        : digits.startsWith('0')
        ? '20${digits.substring(1)}'
        : digits;
    if (!RegExp(r'^20[0-9]{10}$').hasMatch(international) ||
        !RegExp(r'^[0-9]{4}$').hasMatch(code))
      return;
    final message =
        'مرحبًا بك في VETO SANYA 👋\n'
        'رمز التحقق الخاص بطلب تسجيل الدخول هو: $code\n'
        'يرجى إدخاله في التطبيق قبل انتهاء صلاحيته. '
        'لا تشارك الرمز مع أي شخص.';
    final url = Uri.https('wa.me', '/$international', {'text': message});
    // Opens a draft; the administrator must review and tap Send themselves.
    if (!await launchUrl(url, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر فتح واتساب',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
    }
  }

  Future<void> _load() async {
    try {
      await SupabaseService.instance.expireStaleVerificationRequests();
      final reqs = await SupabaseService.instance.getAllVerificationRequests();
      if (mounted) {
        setState(() {
          _requests = reqs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _statusLabel(String s) {
    final labels = {
      'pending': 'في الانتظار',
      'code_sent': 'تم إرسال الكود',
      'verified': 'تم التحقق',
      'expired': 'منتهي',
      'cancelled': 'ملغي',
    };
    return labels[s] ?? s;
  }

  Color _statusColor(String s) {
    final colors = {
      'pending': Color(0xFFFFC107),
      'code_sent': Color(0xFF2196F3),
      'verified': Color(0xFF4CAF50),
      'expired': Color(0xFF9E9E9E),
      'cancelled': Color(0xFFEF5350),
    };
    return colors[s] ?? AdminTheme.muted;
  }

  String _requestAgeText(Map<String, dynamic> row) {
    DateTime? parse(String key) {
      final raw = row[key]?.toString();
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw)?.toLocal();
    }

    final reference = parse('code_sent_at') ?? parse('created_at');
    if (reference == null) return 'الوقت غير متاح';
    final diff = DateTime.now().difference(reference);
    if (diff.inMinutes < 1) return 'تم التحديث منذ لحظات';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    return 'منذ ${diff.inHours} ساعة';
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
                'طلبات التحقق',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AdminTheme.ink,
                ),
              ),
              Spacer(),
              IconButton(
                icon: Icon(Icons.refresh_rounded, color: AdminTheme.goldDark),
                onPressed: _load,
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: AdminTheme.goldDark),
                )
              : _requests.isEmpty
              ? Center(
                  child: Text(
                    'لا توجد طلبات',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: AdminTheme.muted,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _requests.length,
                  separatorBuilder: (_, __) => SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final r = _requests[i];
                    final status = r['status'] as String? ?? 'pending';
                    return Container(
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AdminTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AdminTheme.borderSoft),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r['phone'] as String? ?? '',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AdminTheme.ink,
                                  ),
                                ),
                              ),
                              AdminCopyButton(
                                text: r['phone']?.toString() ?? '',
                                description: 'رقم الهاتف',
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _statusColor(status).withAlpha(31),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _statusLabel(status),
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 11,
                                    color: _statusColor(status),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6),
                          Text(
                            _requestAgeText(r),
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              color: AdminTheme.muted,
                            ),
                          ),
                          if (r['code'] != null) ...[
                            SizedBox(height: 6),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              children: [
                                Text(
                                  'الكود: ${r['code']}',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 14,
                                    color: AdminTheme.goldDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                AdminCopyButton(
                                  text: r['code'].toString(),
                                  description: 'كود التحقق',
                                ),
                                if (status == 'code_sent')
                                  TextButton.icon(
                                    onPressed: () => _openVerificationWhatsApp(
                                      r['phone']?.toString() ?? '',
                                      r['code'].toString(),
                                    ),
                                    icon: Icon(Icons.send_rounded, size: 17),
                                    label: Text(
                                      'توجيه لواتساب',
                                      style: TextStyle(fontFamily: 'Cairo'),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          if (status == 'pending' || status == 'code_sent') ...[
                            SizedBox(height: 10),
                            _CodeAssignRow(
                              requestId: r['id'] as String,
                              onAssigned: _load,
                            ),
                          ],
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

class _CodeAssignRow extends StatefulWidget {
  final String requestId;
  final VoidCallback onAssigned;
  const _CodeAssignRow({required this.requestId, required this.onAssigned});

  @override
  State<_CodeAssignRow> createState() => _CodeAssignRowState();
}

class _CodeAssignRowState extends State<_CodeAssignRow> {
  final _ctrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _assign() async {
    final code = _ctrl.text.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'الكود يجب أن يكون 4 أرقام',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await SupabaseService.instance.assignVerificationCode(
        widget.requestId,
        code,
      );
      widget.onAssigned();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حفظ الكود وأصبح جاهزًا للعميل.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر حفظ الكود: $error'),
            backgroundColor: AdminTheme.error,
          ),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            style: TextStyle(
              fontFamily: 'Cairo',
              color: AdminTheme.ink,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'أدخل كود من 4 أرقام',
              counterText: '',
              hintStyle: TextStyle(
                fontFamily: 'Cairo',
                color: AdminTheme.muted,
                fontSize: 12,
              ),
              filled: true,
              fillColor: AdminTheme.surfaceSoft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AdminTheme.borderSoft),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AdminTheme.borderSoft),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AdminTheme.goldDark),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: _isSaving ? null : _assign,
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminTheme.goldDark,
            foregroundColor: Color(0xFF0B0F1A),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: _isSaving
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF0B0F1A),
                  ),
                )
              : Text(
                  'حفظ الكود',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── CAPTAINS PANEL ──────────────────────────────────────────────────────────

class _CaptainsPanel extends StatefulWidget {
  _CaptainsPanel();

  @override
  State<_CaptainsPanel> createState() => _CaptainsPanelState();
}

class _CaptainsPanelState extends State<_CaptainsPanel> {
  List<Map<String, dynamic>> _captains = [];
  final _pager = AdminDirectoryPagerV15('captains');
  void _syncPage() {
    if (mounted)
      setState(() {
        _captains = List.of(_pager.rows);
        _isLoading = _pager.loading;
      });
  }

  String _query = '';
  List<Map<String, dynamic>> get _filteredCaptains => _captains
      .where(
        (c) => '${c['full_name'] ?? ''} ${c['phone'] ?? ''}'
            .toLowerCase()
            .contains(_query.trim().toLowerCase()),
      )
      .toList();
  bool _isLoading = true;
  bool _isHardeningCredentials = false;
  bool _showForm = false;
  Map<String, dynamic>? _editingCaptain;
  TripRealtimeLease? _captainChannel;

  @override
  void initState() {
    super.initState();
    _pager.addListener(_syncPage);
    _load();
    _subscribeToCaptains();
  }

  @override
  void dispose() {
    _captainChannel?.unsubscribe();
    _pager.dispose();
    super.dispose();
  }

  void _subscribeToCaptains() {
    _captainChannel = SupabaseService.instance.subscribeToCaptainStatus((_) {
      if (mounted) _pager.resync();
    });
  }

  Future<void> _endCaptainSession(Map<String, dynamic> captain) async {
    final userId = captain['user_id']?.toString() ?? '';
    if (userId.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('لا يوجد حساب مرتبط بهذا الكابتن')),
        );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            'إنهاء جلسة الكابتن',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          content: Text(
            'سيُطلب من الكابتن تسجيل الدخول مجددًا. لا تُلغى الرحلة الجارية '
            'ولا تتغير مستحقاته أو عمولاته.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: Text('رجوع'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: Text('إنهاء الجلسة'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await SupabaseService.instance.adminEndUserSessionV25(userId);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تم إنهاء جلسة الكابتن بنجاح')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر إنهاء الجلسة: $e')));
    }
  }

  Future<void> _load() => _pager.refresh();

  Future<void> _editCaptainCommission(Map<String, dynamic> captain) async {
    final controller = TextEditingController(
      text: captain['custom_commission']?.toString() ?? '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AdminTheme.surface,
          title: Row(
            children: [
              Icon(Icons.percent_rounded, color: AdminTheme.goldDark),
              SizedBox(width: 8),
              Text(
                'عمولة الكابتن',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w900,
                  color: AdminTheme.ink,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  captain['full_name']?.toString() ?? 'الكابتن',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w800,
                    color: AdminTheme.ink,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'اكتب نسبة خاصة لهذا الكابتن، أو امسح الرقم للرجوع إلى عمولة الخدمة الافتراضية. التغيير يطبق على الرحلات الجديدة فقط.',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: AdminTheme.muted,
                  ),
                ),
                SizedBox(height: 14),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'نسبة العمولة %',
                    hintText: 'مثال: 7 أو اتركها فارغة',
                    suffixIcon: Icon(Icons.percent_rounded),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('رجوع'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: Icon(Icons.save_rounded),
              label: Text('حفظ العمولة'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) {
      controller.dispose();
      return;
    }
    final raw = controller.text.trim();
    controller.dispose();
    final percent = raw.isEmpty ? null : double.tryParse(raw);
    if (raw.isNotEmpty &&
        (percent == null ||
            !percent.isFinite ||
            percent < 0 ||
            percent > 100)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('اكتب نسبة صحيحة من 0 إلى 100.')));
      return;
    }
    try {
      await ZonePricingService.instance.commission(
        captain['id'].toString(),
        percent,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            percent == null
                ? 'تم الرجوع إلى العمولة الافتراضية.'
                : 'تم حفظ عمولة ${percent.toStringAsFixed(percent % 1 == 0 ? 0 : 2)}% للكابتن.',
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر حفظ العمولة: $e')));
    }
  }

  Future<void> _hardenCaptainCredentials() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            'تأمين حسابات الكباتن',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          content: Text(
            'سيتم إلغاء كلمات المرور الداخلية القديمة واستبدالها بقيم '
            'عشوائية لا يعرفها أحد. دخول الكابتن سيظل بالكود الذي ترسله '
            'الإدارة فقط. نفّذ الخطوة مرة واحدة بعد نشر دالة الأمان.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('رجوع'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: Icon(Icons.security_rounded),
              label: Text('تأمين الآن'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isHardeningCredentials = true);
    try {
      final result = await SupabaseService.instance
          .hardenAllCaptainCredentials();
      if (!mounted) return;
      final updated = result['updated'] ?? 0;
      final skipped = result['skipped'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تأمين $updated حساب كابتن بنجاح'
            '${skipped == 0 ? '' : ' — $skipped حساب بدون مستخدم مرتبط'}',
          ),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تأمين كل الحسابات: $error'),
          backgroundColor: Color(0xFFC62828),
        ),
      );
    } finally {
      if (mounted) setState(() => _isHardeningCredentials = false);
    }
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
                'الكباتن (${_captains.length})',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AdminTheme.ink,
                ),
              ),
              Spacer(),
              IconButton(
                tooltip: 'تأمين حسابات الكباتن القديمة',
                onPressed: _isHardeningCredentials
                    ? null
                    : _hardenCaptainCredentials,
                icon: _isHardeningCredentials
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.security_rounded),
                color: AdminTheme.goldDark,
              ),
              SizedBox(width: 4),
              ElevatedButton.icon(
                onPressed: () => setState(() {
                  _showForm = !_showForm;
                  _editingCaptain = null;
                }),
                icon: Icon(
                  _showForm ? Icons.close : Icons.add_rounded,
                  size: 18,
                ),
                label: Text(
                  _showForm ? 'إلغاء' : 'إضافة كابتن',
                  style: TextStyle(fontFamily: 'Cairo'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.goldDark,
                  foregroundColor: Color(0xFF0B0F1A),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: TextField(
            onChanged: (v) {
              setState(() => _query = v);
              _pager.search(v);
            },
            style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'ابحث باسم الكابتن أو رقم الهاتف',
              hintStyle: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        ),
        if (_showForm)
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: AdminCaptainFormPanel(
                existingCaptain: _editingCaptain,
                onSaved: () {
                  setState(() {
                    _showForm = false;
                    _editingCaptain = null;
                  });
                  _load();
                },
              ),
            ),
          ),
        if (!_showForm)
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: AdminTheme.goldDark,
                    ),
                  )
                : _filteredCaptains.isEmpty
                ? Center(
                    child: Text(
                      'لا يوجد كباتن',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: AdminTheme.muted,
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: _pager.scroll,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredCaptains.length,
                    separatorBuilder: (_, __) => SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final c = _filteredCaptains[i];
                      final isOnline = c['is_online'] as bool? ?? false;
                      return Container(
                        padding: EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AdminTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AdminTheme.borderSoft),
                        ),
                        child: Row(
                          children: [
                            Builder(
                              builder: (context) {
                                final photo =
                                    (c['profile_photo_url'] ??
                                            c['profile_photo'] ??
                                            '')
                                        .toString();
                                final name = c['full_name']?.toString() ?? '';
                                final fallback = Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AdminTheme.goldDark.withAlpha(35),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Text(
                                    name.isEmpty ? '؟' : name.substring(0, 1),
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      color: AdminTheme.goldDark,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                    ),
                                  ),
                                );
                                if (!photo.startsWith('https://'))
                                  return fallback;
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(13),
                                  child: Image(image: captainPhotoV16(photo),
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => fallback,
                                  ),
                                );
                              },
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c['full_name'] as String? ?? '',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AdminTheme.ink,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          c['phone'] as String? ?? '',
                                          style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 12,
                                            color: AdminTheme.muted,
                                          ),
                                        ),
                                      ),
                                      AdminCopyButton(
                                        text: c['phone']?.toString() ?? '',
                                        description: 'رقم الكابتن',
                                      ),
                                    ],
                                  ),
                                  Text(
                                    _servicesLabel(c),
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 11,
                                      color: AdminTheme.goldDark,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    c['custom_commission'] == null
                                        ? 'العمولة: الافتراضية حسب الخدمة'
                                        : 'العمولة الخاصة: ${c['custom_commission']}%',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: AdminTheme.ink,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'رحلات: ${c['trip_count'] ?? c['total_trip_count'] ?? 0}  •  مكتملة: ${c['completed_trip_count'] ?? c['total_completed_trips'] ?? 0}  •  ملغاة: ${c['cancelled_trip_count'] ?? 0}',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 10,
                                      color: AdminTheme.muted,
                                    ),
                                  ),
                                  Text(
                                    'تقييمات: ${c['rating_count'] ?? 0}  •  متوسط: ${((c['average_rating'] as num?)?.toDouble() ?? (c['rating'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)} ★',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 10,
                                      color: AdminTheme.muted,
                                    ),
                                  ),
                                  Text(
                                    'تاريخ التسجيل: ${c['created_at'] ?? '—'}',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 10,
                                      color: AdminTheme.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        (isOnline
                                                ? Color(0xFF4CAF50)
                                                : AdminTheme.muted)
                                            .withAlpha(31),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isOnline ? 'متصل' : 'غير متصل',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 10,
                                      color: isOnline
                                          ? Color(0xFF4CAF50)
                                          : AdminTheme.muted,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'تنبيه وإنذار وإيقاف',
                                  icon: Icon(
                                    Icons.admin_panel_settings_outlined,
                                    color: AdminTheme.goldDark,
                                  ),
                                  onPressed: () async {
                                    await showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      showDragHandle: true,
                                      builder: (_) => AdminCaptainActionsV10(
                                        captainId: c['id'].toString(),
                                        name: c['full_name']?.toString() ?? '',
                                      ),
                                    );
                                    _load();
                                  },
                                ),
                                IconButton(
                                  tooltip: 'إنهاء جلسة الكابتن',
                                  icon: Icon(
                                    Icons.phonelink_erase_rounded,
                                    color: Colors.orangeAccent,
                                    size: 19,
                                  ),
                                  onPressed: () => _endCaptainSession(c),
                                ),
                                IconButton(
                                  tooltip: 'تعديل عمولة الكابتن',
                                  icon: Icon(
                                    Icons.percent_rounded,
                                    color: AdminTheme.goldDark,
                                    size: 19,
                                  ),
                                  onPressed: () => _editCaptainCommission(c),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.edit_rounded,
                                    color: AdminTheme.goldDark,
                                    size: 18,
                                  ),
                                  onPressed: () => setState(() {
                                    _editingCaptain = c;
                                    _showForm = true;
                                  }),
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
    );
  }

  String _servicesLabel(Map<String, dynamic> c) {
    final services = <String>[];
    if (c['can_do_car_ride'] == true) services.add('سيارة');
    if (c['can_do_motorcycle_ride'] == true) services.add('موتوسيكل');
    if (c['can_do_package'] == true) services.add('طرد');
    if (c['can_do_vito_market'] == true) services.add('ماركت');
    return services.isEmpty ? 'لا خدمات' : services.join(' • ');
  }
}

// ─── TRIPS PANEL ─────────────────────────────────────────────────────────────

class _TripsPanel extends StatefulWidget {
  _TripsPanel();

  @override
  State<_TripsPanel> createState() => _TripsPanelState();
}

class _TripsPanelState extends State<_TripsPanel> {
  List<Map<String, dynamic>> _trips = [];
  String _query = '';
  bool _hasMore = true;
  bool _loadingMore = false;
  Map<String, dynamic>? _pageCursor;
  final TextEditingController _tripSearchCtrl = TextEditingController();
  List<Map<String, dynamic>> get _filteredTrips => _trips.where((t) {
    final c = t['customers'] is Map ? t['customers'] as Map : {};
    final cap = t['captains'] is Map ? t['captains'] as Map : {};
    return '${t['id'] ?? ''} ${c['full_name'] ?? ''} ${c['phone'] ?? ''} ${cap['full_name'] ?? ''} ${cap['phone'] ?? ''}'
        .toLowerCase()
        .contains(_query.trim().toLowerCase());
  }).toList();
  bool _isLoading = true;
  String? _loadError;
  TripRealtimeLease? _tripsChannel;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeToTrips();
  }

  @override
  void dispose() {
    _tripsChannel?.unsubscribe();
    _tripSearchCtrl.dispose();
    super.dispose();
  }

  void _subscribeToTrips() {
    _tripsChannel = SupabaseService.instance.subscribeToAllTrips((_, __) {
      if (mounted && !_isLoading && !_loadingMore) _load();
    });
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final trips = await SupabaseService.instance.getAllTrips(limit: 100);
      if (mounted) {
        setState(() {
          _trips = trips;
          _hasMore = trips.length == 100;
          _pageCursor = trips.isEmpty ? null : trips.last;
          _isLoading = false;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError =
              'تعذر تحميل الرحلات: ${e.toString().replaceFirst('Exception: ', '')}';
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _pageCursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final rows = await SupabaseService.instance.getAdminTripsPageV9(
        before: _pageCursor!['created_at'].toString(),
        beforeId: _pageCursor!['id'].toString(),
      );
      if (!mounted) return;
      setState(() {
        final known = _trips.map((t) => t['id']).toSet();
        _trips.addAll(rows.where((t) => !known.contains(t['id'])));
        _hasMore = rows.length == 100;
        if (rows.isNotEmpty) _pageCursor = rows.last;
      });
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل الرحلات الأقدم. حاول مرة أخرى.')),
        );
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _searchExactTrip() async {
    final q = _tripSearchCtrl.text.trim();
    if (q.isEmpty) return;
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(q)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('انسخ رقم الرحلة الكامل للبحث في السجل.')),
      );
      return;
    }
    try {
      final trip = await SupabaseService.instance.findAdminTripV21(q);
      if (!mounted) return;
      if (trip == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('لم يتم العثور على الرحلة.')));
        return;
      }
      setState(() {
        _trips.removeWhere((t) => t['id'] == trip['id']);
        _trips.insert(0, trip);
        _query = q;
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر البحث عن الرحلة: $e')));
    }
  }

  Future<void> _advanceTrip(Map<String, dynamic> trip) async {
    final forward = <String, String>{
      'accepted': 'arriving',
      'arriving': 'arrived',
      'arrived': 'started',
    };
    final current = trip['trip_status']?.toString() ?? '';
    final next = forward[current];
    if (next == null) return;
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تعديل حالة الرحلة', style: TextStyle(fontFamily: 'Cairo')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'رقم الرحلة: ${trip['id']}',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
            ),
            SizedBox(height: 9),
            Text(
              '${_statusLabel(current)} ← ${_statusLabel(next)}',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'لحماية الأموال: التعديل فقط للانتقال للأمام. لا يمكن إكمال أو إلغاء الرحلة يدويًا.',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
            ),
            SizedBox(height: 9),
            TextField(
              controller: reason,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: 'سبب التعديل (5 حروف على الأقل)',
              ),
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('تأكيد التعديل'),
          ),
        ],
      ),
    );
    final why = reason.text.trim();
    reason.dispose();
    if (!mounted || confirmed != true) return;
    if (why.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('اكتب سببًا من 5 حروف على الأقل.')),
      );
      return;
    }
    try {
      await SupabaseService.instance.adminAdvanceTripV21(
        tripId: trip['id'].toString(),
        currentStatus: current,
        nextStatus: next,
        reason: why,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تم تعديل الحالة وتسجيل السبب.')));
      _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر تعديل الحالة: $e')));
    }
  }

  String _statusLabel(String s) {
    final labels = {
      'requested': 'طلب',
      'offer_received': 'عروض',
      'accepted': 'مقبول',
      'arriving': 'في الطريق',
      'arrived': 'وصل',
      'started': 'بدأت',
      'completed': 'مكتملة',
      'cancelled': 'ملغاة',
    };
    return labels[s] ?? s;
  }

  String _money(dynamic value) {
    final n = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return '${n.toStringAsFixed(2)} ج';
  }

  String _date(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return '—';
    final d = DateTime.tryParse(raw)?.toLocal();
    if (d == null) return raw;
    String two(int x) => x.toString().padLeft(2, '0');
    return '${d.year}/${two(d.month)}/${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final visibleTrips = _filteredTrips;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                'الرحلات المعروضة (${_trips.length})',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AdminTheme.ink,
                ),
              ),
              Spacer(),
              if (_hasMore && !_isLoading)
                TextButton(
                  onPressed: _loadingMore ? null : _loadMore,
                  child: Text(_loadingMore ? 'تحميل…' : 'رحلات أقدم'),
                ),
              IconButton(
                icon: Icon(Icons.refresh_rounded, color: AdminTheme.goldDark),
                onPressed: _load,
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: TextField(
            controller: _tripSearchCtrl,
            onChanged: (v) => setState(() => _query = v),
            onSubmitted: (_) => _searchExactTrip(),
            style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'ابحث برقم الرحلة أو اسم العميل أو الهاتف',
              hintStyle: TextStyle(fontFamily: 'Cairo'),
              suffixIcon: IconButton(
                tooltip: 'ابحث برقم الرحلة في جميع السجلات',
                icon: Icon(
                  Icons.manage_search_rounded,
                  color: AdminTheme.goldDark,
                ),
                onPressed: _searchExactTrip,
              ),
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: AdminTheme.goldDark),
                )
              : _loadError != null
              ? Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: 560),
                    margin: EdgeInsets.all(20),
                    padding: EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AdminTheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AdminTheme.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AdminTheme.goldDark,
                          size: 34,
                        ),
                        SizedBox(height: 8),
                        Text(
                          _loadError!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: AdminTheme.ink,
                          ),
                        ),
                        SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: Icon(Icons.refresh_rounded),
                          label: Text('إعادة تحميل الرحلات'),
                        ),
                      ],
                    ),
                  ),
                )
              : visibleTrips.isEmpty
              ? Center(
                  child: Text(
                    'لا توجد رحلات مطابقة. اضغط تحديث لإعادة جلب جميع السجلات.',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: AdminTheme.muted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: visibleTrips.length,
                  separatorBuilder: (_, __) => SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final t = visibleTrips[i];
                    final status = t['trip_status']?.toString() ?? '';
                    final customer = t['customers'] is Map
                        ? Map<String, dynamic>.from(t['customers'])
                        : <String, dynamic>{};
                    final captain = t['captains'] is Map
                        ? Map<String, dynamic>.from(t['captains'])
                        : <String, dynamic>{};
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () =>
                          context.push('/admin/trip-details?tripId=${t['id']}'),
                      child: Container(
                        padding: EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AdminTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AdminTheme.borderSoft),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${customer['full_name'] ?? 'عميل'}  •  ${captain['full_name'] ?? 'لم يُعيّن بعد'}',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.w800,
                                      color: AdminTheme.ink,
                                    ),
                                  ),
                                ),
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
                                    _statusLabel(status),
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 11,
                                      color: AdminTheme.goldDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 6),
                            SelectableText(
                              'رقم الرحلة: ${t['id'] ?? '—'}',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 10,
                                color: AdminTheme.muted,
                              ),
                            ),
                            if ({
                              'accepted',
                              'arriving',
                              'arrived',
                            }.contains(status))
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => _advanceTrip(t),
                                  icon: Icon(
                                    Icons.edit_note_rounded,
                                    color: AdminTheme.goldDark,
                                  ),
                                  label: Text(
                                    'تعديل الحالة بأمان',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      color: AdminTheme.goldDark,
                                    ),
                                  ),
                                ),
                              ),
                            SizedBox(height: 6),
                            Text(
                              '${t['pickup_address'] ?? ''} → ${t['destination_address'] ?? ''}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                color: AdminTheme.ink,
                              ),
                            ),
                            SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  _date(t['created_at']),
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 11,
                                    color: AdminTheme.muted,
                                  ),
                                ),
                                Spacer(),
                                Text(
                                  _money(t['total_fare']),
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AdminTheme.goldDark,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.receipt_long_rounded,
                                  size: 18,
                                  color: AdminTheme.goldDark,
                                ),
                              ],
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

// ─── SETTINGS PANEL ──────────────────────────────────────────────────────────

class _SettingsPanel extends StatefulWidget {
  _SettingsPanel();

  @override
  State<_SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<_SettingsPanel> {
  List<Map<String, dynamic>> _settings = [];
  bool _isLoading = true;
  final Map<String, TextEditingController> _controllers = {};
  String? _saveMessage;
  bool _saveSuccess = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final settings = await SupabaseService.instance.getAllSettings();
      if (mounted) {
        setState(() {
          _settings = settings;
          for (final s in settings) {
            final key = s['key'] as String;
            _controllers[key] = TextEditingController(
              text: s['value'] as String? ?? '',
            );
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save(String key) async {
    try {
      await SupabaseService.instance.updateSetting(
        key,
        _controllers[key]?.text.trim() ?? '',
      );
      if (mounted) {
        setState(() {
          _saveMessage = 'تم الحفظ ✓';
          _saveSuccess = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saveMessage = 'خطأ: $e';
          _saveSuccess = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              'الإعدادات',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AdminTheme.ink,
              ),
            ),
          ),
        ),
        if (_saveMessage != null)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _saveMessage!,
              style: TextStyle(
                fontFamily: 'Cairo',
                color: _saveSuccess ? Color(0xFF4CAF50) : Color(0xFFEF5350),
                fontSize: 13,
              ),
            ),
          ),
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: AdminTheme.goldDark),
                )
              : ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _settings.length,
                  separatorBuilder: (_, __) => SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final s = _settings[i];
                    final key = s['key'] as String;
                    return Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controllers[key],
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: AdminTheme.ink,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              labelText: s['description'] as String? ?? key,
                              labelStyle: TextStyle(
                                fontFamily: 'Cairo',
                                color: AdminTheme.muted,
                                fontSize: 12,
                              ),
                              filled: true,
                              fillColor: AdminTheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: AdminTheme.borderSoft,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: AdminTheme.borderSoft,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: AdminTheme.goldDark,
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _save(key),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminTheme.goldDark,
                            foregroundColor: Color(0xFF0B0F1A),
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          child: Text(
                            'حفظ',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}


