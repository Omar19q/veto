import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'push_notification_service.dart';
import 'supabase_service.dart';

/// Blocks every interaction while the device cannot reach the real backend.
/// Connectivity type alone is not enough: Wi-Fi can exist without internet,
/// so every check also probes Supabase Auth with a short timeout.
class NetworkGuard extends StatefulWidget {
  final Widget child;

  const NetworkGuard({super.key, required this.child});

  @override
  State<NetworkGuard> createState() => _NetworkGuardState();
}

class _NetworkGuardState extends State<NetworkGuard>
    with WidgetsBindingObserver {
  final Connectivity _connectivity = Connectivity();
  late final Dio _dio;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _timer;
  bool? _isOnline;
  bool _checking = false;
  bool _foreground = true;
  final _jitter = Random();

  bool get _isBlocked => _isOnline != true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        sendTimeout: const Duration(seconds: 5),
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (_) => _checkNow(),
    );
    _scheduleCheck();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkNow());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _timer?.cancel();
    if (_foreground) {
      _checkNow();
      _scheduleCheck();
    }
  }

  void _scheduleCheck() {
    _timer?.cancel();
    if (!_foreground || !mounted) return;
    final seconds = (_isOnline == false ? 10 : 60) + _jitter.nextInt(10);
    _timer = Timer(Duration(seconds: seconds), () async {
      await _checkNow();
      _scheduleCheck();
    });
  }

  Future<void> _checkNow() async {
    if (!mounted || !_foreground || _checking) return;
    if (_isBlocked) {
      setState(() => _checking = true);
    } else {
      _checking = true;
    }
    var online = false;

    try {
      final connections = await _connectivity.checkConnectivity();
      final hasNetworkInterface =
          connections.isNotEmpty &&
          connections.any((result) => result != ConnectivityResult.none);
      if (hasNetworkInterface &&
          SupabaseService.supabaseUrl.isNotEmpty &&
          SupabaseService.supabaseAnonKey.isNotEmpty) {
        final response = await _dio.get<void>(
          '${SupabaseService.supabaseUrl}/auth/v1/health',
          options: Options(
            headers: {'apikey': SupabaseService.supabaseAnonKey},
          ),
        );
        online = response.statusCode != null && response.statusCode! < 400;
      }
    } catch (_) {
      online = false;
    }

    if (!mounted) return;
    final wasOffline = _isOnline == false;
    final changed = _isOnline != online;
    _checking = false;
    if (changed || !online) {
      setState(() => _isOnline = online);
    }
    _scheduleCheck();

    if (online && wasOffline) {
      // Token registration may have failed while the app started offline.
      unawaited(PushNotificationService.instance.initialize());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _connectivitySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _dio.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backdropColor = isDark ? const Color(0xF20B0F1A) : const Color(0x8A0B0F1A);
    final cardColor = isDark ? AppTheme.surface : Colors.white;
    final borderColor = isDark ? AppTheme.cardBorder : const Color(0xFFE2E8F0);
    final titleColor = isDark ? AppTheme.textPrimary : const Color(0xFF0B0F1A);
    final subtitleColor = isDark ? AppTheme.textSecondary : const Color(0xFF64748B);
    final shadowColor = isDark ? Colors.black45 : const Color(0x1F0B0F1A);
    final iconBgColor = isDark ? AppTheme.gold.withAlpha(24) : const Color(0xFFFEF3C7);
    final iconColor = isDark ? AppTheme.gold : const Color(0xFFD97706);

    return PopScope(
      canPop: !_isBlocked,
      child: Stack(
        children: [
          AbsorbPointer(absorbing: _isBlocked, child: widget.child),
          if (_isBlocked)
            Positioned.fill(
              child: Material(
                color: backdropColor,
                child: SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: borderColor),
                              boxShadow: [
                                BoxShadow(
                                  color: shadowColor,
                                  blurRadius: 32,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: iconBgColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _isOnline == null
                                        ? Icons.sync_rounded
                                        : Icons.wifi_off_rounded,
                                    color: iconColor,
                                    size: 38,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  _isOnline == null
                                      ? 'جاري فحص الاتصال'
                                      : 'الاتصال بالإنترنت منقطع',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: AppTheme.productFontFamily(context),
                                    color: titleColor,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _isOnline == null
                                      ? 'لحظات ونتأكد إن الخدمة متاحة.'
                                      : 'التطبيق محتاج اتصال مستمر علشان يحمي حالة الرحلات والحساب. مش هيتنفذ أي إجراء لحد ما النت يرجع.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: AppTheme.productFontFamily(context),
                                    color: subtitleColor,
                                    fontSize: 14,
                                    height: 1.7,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: _checking ? null : _checkNow,
                                    icon: _checking
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.refresh_rounded),
                                    label: Text(
                                      'إعادة المحاولة',
                                      style: TextStyle(
                                        fontFamily: AppTheme.productFontFamily(context),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
