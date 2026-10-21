import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_service.dart';
import '../../services/app_sound_service.dart';
import '../../theme/admin_theme.dart';

/// Standalone/additive admin home widget. No changes to legacy request workflows.
class AdminOperationsCenter extends StatefulWidget {
  final void Function(int section, String? requestId) onNavigate;
  const AdminOperationsCenter({super.key, required this.onNavigate});
  @override
  State<AdminOperationsCenter> createState() => _AdminOperationsCenterState();
}

class _AdminOperationsCenterState extends State<AdminOperationsCenter>
    with WidgetsBindingObserver {
  final _db = SupabaseService.instance.client;
  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  final List<TripRealtimeLease> _channels = [];
  int? _topups,
      _verification,
      _marketOrders,
      _complaints,
      _suggestions,
      _applications,
      _available;
  int? _captainAlerts;
  String? _latestTopup;
  bool _sound = false, _working = false;
  int? _previousTopups;
  DateTime? _updated;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreSound();
    _refresh();
    _timer = Timer.periodic(Duration(seconds: 60), (_) => _refresh());
    _connectivity = Connectivity().onConnectivityChanged.listen((result) {
      if (!result.contains(ConnectivityResult.none)) _refresh();
    });
    _channels.add(
      SupabaseService.instance.subscribeToScaleAdminPulse(_refresh),
    );
  }

  Future<void> _restoreSound() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted)
      setState(
        () => _sound = prefs.getBool('admin_topup_alert_audio') ?? false,
      );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _connectivity?.cancel();
    for (final channel in _channels) {
      channel.unsubscribe();
    }
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_working) return;
    _working = true;
    try {
      try {
        await SupabaseService.instance.expireStaleVerificationRequests();
      } catch (_) {}
      final raw = await _db
          .rpc('admin_operations_counts_scale_v15')
          .timeout(const Duration(seconds: 15));
      final data = Map<String, dynamic>.from(raw as Map);
      int? number(String key) => (data[key] as num?)?.toInt();
      final count = number('wallet_topup_requests') ?? 0;
      final newest = data['latest_topup']?.toString();
      final verification = number('verification'),
          marketOrders = number('market_orders'),
          complaints = number('complaints'),
          suggestions = number('suggestions'),
          applications = number('captain_applications'),
          available = number('available'),
          captainAlerts = number('admin_alerts');
      if (!mounted) return;
      final prefs=await SharedPreferences.getInstance();
      final userId=SupabaseService.instance.currentUser?.id ?? 'anonymous';
      final verificationMuted=prefs.getBool('veto_admin_verification_mute_$userId')??false;
      final newAlert =
          (_previousTopups != null && count > _previousTopups!) ||
          (!verificationMuted && _verification != null &&
              verification != null &&
              verification > _verification!) ||
          (_marketOrders != null &&
              marketOrders != null &&
              marketOrders > _marketOrders!) ||
          (_complaints != null &&
              complaints != null &&
              complaints > _complaints!) ||
          (_applications != null &&
              applications != null &&
              applications > _applications!);
      final play = _sound && newAlert;
      setState(() {
        _previousTopups = count;
        _topups = count;
        _latestTopup = newest;
        _verification = verification;
        _marketOrders = marketOrders;
        _complaints = complaints;
        _suggestions = suggestions;
        _applications = applications;
        _available = available;
        _updated = DateTime.now();
        _captainAlerts = captainAlerts;
      });
      if (play) AppSoundService.instance.playNotification();
    } catch (_) {
      /* Preserve last-known counters on offline / unapplied migrations. */
    } finally {
      _working = false;
    }
  }

  Widget _text(
    String value, {
    double size = 13,
    Color? color,
    bool bold = false,
  }) => Text(
    value,
    style: TextStyle(
      fontFamily: 'Cairo',
      fontSize: size,
      color: color ?? AdminTheme.ink,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
    ),
  );
  Widget _card({
    required String title,
    required String description,
    required IconData icon,
    required int? count,
    required VoidCallback onTap,
    bool featured = false,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      width: featured ? 275 : 175,
      padding: EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: featured
            ? LinearGradient(
                colors: [AdminTheme.surfaceStrong, AdminTheme.surface],
              )
            : null,
        color: featured ? null : AdminTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: featured ? AdminTheme.gold : AdminTheme.borderSoft,
        ),
        boxShadow: featured
            ? [
                BoxShadow(
                  blurRadius: 20,
                  color: AdminTheme.goldDark.withAlpha(30),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AdminTheme.goldDark, size: 29),
          SizedBox(height: 9),
          _text(
            count?.toString() ?? '—',
            size: 28,
            color: AdminTheme.goldDark,
            bold: true,
          ),
          _text(title, bold: true, size: 14),
          SizedBox(height: 5),
          _text(description, size: 11, color: AdminTheme.muted),
          SizedBox(height: 10),
          _text(
            'فتح ومراجعة ←',
            size: 11,
            color: AdminTheme.goldDark,
            bold: true,
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final values = [
      _topups,
      _verification,
      _marketOrders,
      _complaints,
      _suggestions,
      _applications,
    ];
    final total = values.every((n) => n != null)
        ? values.fold<int>(0, (sum, n) => sum + n!)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 132,
          width: double.infinity,
          padding: EdgeInsets.all(19),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [AdminTheme.surfaceStrong, AdminTheme.surface],
            ),
            border: Border.all(color: AdminTheme.borderSoft),
          ),
          child: Container(
            alignment: Alignment.centerRight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _text('مركز الطلبات', size: 25, bold: true),
                _text(
                  total == null
                      ? 'جارٍ تحميل التنبيهات'
                      : '$total جديدة تحتاج المتابعة',
                  size: 16,
                  color: AdminTheme.goldDark,
                  bold: true,
                ),
                _text(
                  'متابعة الشحن والتحقق وطلبات فيتو ماركت والشكاوى والكباتن من مكان واحد',
                  size: 11,
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 13),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _card(
              title: 'المناطق والأسعار',
              description: 'ارسم المدن واضبط الأسعار وأيقونة كل مدينة',
              icon: Icons.map_outlined,
              count: null,
              onTap: () => context.push('/admin/pricing-zones'),
            ),
            _card(
              title: 'الرقابة على الكباتن',
              description: 'تأخير الوصول والتقييمات والالتماسات',
              icon: Icons.admin_panel_settings_rounded,
              count: _captainAlerts,
              onTap: () => context.push('/admin/alerts'),
            ),
            _card(
              title: 'طلب شحن جديد',
              description: 'عميل أرسل طلب شحن — افتح الطلب لمراجعة التحويل.',
              icon: Icons.account_balance_wallet_rounded,
              count: _topups,
              featured: true,
              onTap: () => widget.onNavigate(20, _latestTopup),
            ),
            _card(
              title: 'أكواد التحقق',
              description: 'طلبات تحتاج إجراءً من الإدارة',
              icon: Icons.verified_user_rounded,
              count: _verification,
              onTap: () => widget.onNavigate(1, null),
            ),
            _card(
              title: 'طلبات فيتو ماركت',
              description: 'طلبات جديدة بانتظار المراجعة أو التأكيد',
              icon: Icons.shopping_bag_rounded,
              count: _marketOrders,
              onTap: () => widget.onNavigate(8, null),
            ),
            _card(
              title: 'الشكاوى',
              description: 'رسائل العملاء المطلوب متابعتها',
              icon: Icons.report_problem_outlined,
              count: _complaints,
              onTap: () => widget.onNavigate(17, null),
            ),
            _card(
              title: 'الاقتراحات',
              description: 'رسائل تطوير تجربة المستخدم',
              icon: Icons.lightbulb_outline,
              count: _suggestions,
              onTap: () => widget.onNavigate(17, null),
            ),
            _card(
              title: 'تسجيل الكباتن',
              description: 'طلبات الانضمام الجديدة',
              icon: Icons.person_add_alt_1_rounded,
              count: _applications,
              onTap: () => widget.onNavigate(15, null),
            ),
          ],
        ),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AdminTheme.surfaceSoft,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: AdminTheme.goldDark.withAlpha(75)),
          ),
          child: Wrap(
            spacing: 22,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sensors, color: AdminTheme.goldDark),
                  SizedBox(width: 8),
                  _text(
                    'الكباتن المتاحون الآن: ${_available ?? '—'}',
                    color: AdminTheme.goldDark,
                    bold: true,
                    size: 16,
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: _sound,
                    activeThumbColor: AdminTheme.goldDark,
                    onChanged: (v) async {
                      setState(() => _sound = v);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('admin_topup_alert_audio', v);
                    },
                  ),
                  _text('تنبيه صوتي اختياري للطلبات الجديدة', size: 11),
                ],
              ),
              IconButton(
                tooltip: 'تحديث الآن',
                onPressed: _refresh,
                icon: Icon(Icons.refresh_rounded, color: AdminTheme.goldDark),
              ),
              if (_updated != null)
                _text(
                  'آخر تحديث: ${_updated!.hour.toString().padLeft(2, '0')}:${_updated!.minute.toString().padLeft(2, '0')}',
                  size: 11,
                  color: AdminTheme.muted,
                ),
            ],
          ),
        ),
        SizedBox(height: 14),
      ],
    );
  }
}
