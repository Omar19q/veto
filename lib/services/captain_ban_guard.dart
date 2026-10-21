import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../presentation/captain_dashboard_screen/captain_ban_screen.dart';
import '../routes/app_routes.dart';
import 'supabase_service.dart';

class CaptainBanGuard extends StatefulWidget {
  final Widget child;
  const CaptainBanGuard({super.key, required this.child});
  @override
  State<CaptainBanGuard> createState() => _CaptainBanGuardState();
}

class _CaptainBanGuardState extends State<CaptainBanGuard>
    with WidgetsBindingObserver {
  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _auth;
  Timer? _poll;
  Map<String, dynamic>? _state;
  String? _user;
  bool _busy = false, _again = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _auth = SupabaseService.instance.authStateChanges.listen(
      (event) => _bind(event.session?.user.id),
    );
    _bind(SupabaseService.instance.currentUser?.id);
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_state?['is_captain'] != false) _refresh();
    });
  }

  Future<void> _bind(String? user) async {
    if (_user == user && (user == null || _channel != null)) return;
    final generation = ++_generation;
    _user = user;
    final old = _channel;
    _channel = null;
    if (mounted) setState(() => _state = null);
    if (old != null) await SupabaseService.instance.client.removeChannel(old);
    if (user == null || generation != _generation || !mounted) return;
    _channel = SupabaseService.instance.client
        .channel('captain-ban-$user')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'captains',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user,
          ),
          callback: (_) => _refresh(),
        )
        .subscribe();
    await _refresh();
  }

  Future<void> _refresh() async {
    if (_user == null || !mounted) return;
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    final generation = _generation;
    try {
      final data = await SupabaseService.instance.client.rpc(
        'captain_moderation_status',
      );
      if (!mounted || generation != _generation) return;
      final wasBanned = _state?['banned'] == true;
      setState(() => _state = Map<String, dynamic>.from(data as Map));
      if (wasBanned && _state?['banned'] != true)
        appRouter.go(AppRoutes.captainDashboardScreen);
    } catch (_) {
      // Keep an existing ban visible while offline; the server owns expiry.
    } finally {
      _busy = false;
      if (_again) {
        _again = false;
        unawaited(_refresh());
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _auth?.cancel();
    _poll?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final until = DateTime.tryParse(_state?['banned_until']?.toString() ?? '');
    final now = DateTime.tryParse(_state?['server_now']?.toString() ?? '');
    final banned = _state?['banned'] == true && until != null && now != null;
    return Stack(
      children: [
        ExcludeSemantics(
          excluding: banned,
          child: IgnorePointer(ignoring: banned, child: widget.child),
        ),
        if (banned)
          Positioned.fill(
            child: PopScope(
              canPop: false,
              child: CaptainBanScreen(
                key: ValueKey(_state?['ban_reference']),
                bannedUntil: until,
                serverNow: now,
                reason:
                    _state?['reason']?.toString() ??
                    'مراجعة الحساب بواسطة الإدارة',
                onRefresh: _refresh,
              ),
            ),
          ),
      ],
    );
  }
}
