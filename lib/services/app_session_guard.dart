import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../routes/app_routes.dart';
import 'supabase_service.dart';

/// V25: checks the server-owned session slot every 8 seconds and on resume.
/// This widget does not change either login screen or any trip/account UI.
class AppSessionGuard extends StatefulWidget {
  final Widget child;
  const AppSessionGuard({super.key, required this.child});

  @override
  State<AppSessionGuard> createState() => _AppSessionGuardState();
}

class _AppSessionGuardState extends State<AppSessionGuard>
    with WidgetsBindingObserver {
  Timer? _timer;
  StreamSubscription<AuthState>? _authSubscription;
  DateTime _newLoginGrace = DateTime.fromMillisecondsSinceEpoch(0);
  bool _checking = false;
  bool _ejected = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = SupabaseService.instance.authStateChanges.listen((state) {
      if (state.event == AuthChangeEvent.signedIn) {
        // The OTP screen registers the brand-new session immediately after
        // sign-in. Do not mistake this temporary gap for a displaced session.
        _newLoginGrace = DateTime.now().add(const Duration(seconds: 30));
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _check());
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) _check();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  String? _sessionId(Session? session) {
    if (session == null) return null;
    try {
      final segments = session.accessToken.split('.');
      if (segments.length != 3) return null;
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
      );
      return claims is Map ? claims['session_id']?.toString() : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _check() async {
    if (!mounted || _checking || _ejected || DateTime.now().isBefore(_newLoginGrace)) {
      return;
    }
    final client = SupabaseService.instance.client;
    final session = client.auth.currentSession;
    final sid = _sessionId(session);
    if (session == null || sid == null) return;
    _checking = true;
    try {
      final state = await SupabaseService.instance.sessionStatusV25();
      // Never log out a new session because an older in-flight request failed.
      if (!mounted || sid != _sessionId(client.auth.currentSession)) return;
      if (state['active'] != true) {
        await _eject(state['reason']?.toString() ?? 'other_device');
      } else if (state['registered'] == false) {
        // One-time registration for sessions restored from older app versions.
        try {
          await SupabaseService.instance.activateSessionV25();
        } catch (_) {
          final latest = await SupabaseService.instance.sessionStatusV25();
          if (mounted && sid == _sessionId(client.auth.currentSession) &&
              latest['active'] != true) {
            await _eject(latest['reason']?.toString() ?? 'other_device');
          }
        }
      }
    } catch (_) {
      // Network offline / temporary RPC error: do not wipe a legitimate session.
      // Server-side table policies still deny a displaced session on reconnect.
    } finally {
      _checking = false;
    }
  }

  Future<void> _eject(String reason) async {
    if (_ejected || !mounted) return;
    _ejected = true;
    final path = appRouter.routeInformationProvider.value.uri.path;
    final wasAdmin = path.startsWith('/admin');
    final message = reason == 'admin_ended'
        ? 'تم إنهاء جلستك بواسطة الإدارة. يمكنك تسجيل الدخول مرة أخرى.'
        : 'تم تسجيل الدخول إلى حسابك من جهاز آخر، لذلك انتهت جلستك هنا.';
    try {
      await SupabaseService.instance.client.auth.signOut(
        scope: SignOutScope.local,
      );
    } catch (_) {
      // Keep blocking the previous screen if local sign-out fails.
    }
    if (!mounted) return;
    appRouter.go(wasAdmin ? AppRoutes.adminLogin : AppRoutes.signUpLoginScreen);
    setState(() => _notice = message);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _authSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_notice != null)
          Positioned.fill(
            child: Material(
              color: Colors.black87,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.phonelink_erase_rounded,
                                  size: 48, color: Colors.orange),
                              const SizedBox(height: 14),
                              const Text('انتهت الجلسة',
                                  style: TextStyle(
                                      fontSize: 20, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              Text(_notice!, textAlign: TextAlign.center,
                                  style: const TextStyle()),
                              const SizedBox(height: 18),
                              FilledButton(
                                onPressed: () => setState(() {
                                  _ejected = false;
                                  _notice = null;
                                }),
                                child: const Text('العودة لتسجيل الدخول',
                                    style: TextStyle()),
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
    );
  }
}
