import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'trip_realtime_v10.dart';
import 'scale_metrics_v15.dart';

/// One filtered socket per signed-in admin, shared by all mounted panels.
class AdminPulseHubV15 {
  final SupabaseClient client;
  final _listeners = <void Function(), int>{};
  int _generation = 0;
  RealtimeChannel? _channel;
  Timer? _resync;
  String? _owner;
  AdminPulseHubV15(this.client) {
    client.auth.onAuthStateChange.listen((event) {
      if (event.session?.user.id != _owner) {
        _listeners.clear();
        _close();
      }
    });
  }
  void _emit() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    for (final listener in List.of(_listeners.keys)) {
      try {
        listener();
      } catch (_) {
        /* A closing panel cannot block others. */
      }
    }
  }

  void _close() {
    _generation++;
    final old = _channel;
    _channel = null;
    _resync?.cancel();
    _resync = null;
    if (old != null) unawaited(client.removeChannel(old));
  }

  TripRealtimeLease watch(void Function() refresh) {
    _owner = client.auth.currentUser?.id;
    _listeners.update(refresh, (count) => count + 1, ifAbsent: () => 1);
    if (_channel == null) {
      final generation = ++_generation;
      _channel = client
          .channel('scale_admin_${_owner}_$generation')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'scale_admin_pulse_v15',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: 'operations',
            ),
            callback: (_) => _emit(),
          )
          .subscribe((status, _) {
            if (generation != _generation) return;
            if (status == RealtimeSubscribeStatus.subscribed) {
              ScaleMetricsV15.record('admin_realtime_subscribed', 0, true);
              _emit();
            }
          });
      // Bounded recovery for a final event suppressed by server throttling.
      _resync = Timer.periodic(const Duration(seconds: 30), (_) => _emit());
    }
    final ownedChannel = _channel;
    return TripRealtimeLease(() async {
      if (!identical(ownedChannel, _channel)) return;
      final count = _listeners[refresh] ?? 0;
      if (count > 1) {
        _listeners[refresh] = count - 1;
      } else {
        _listeners.remove(refresh);
      }
      if (_listeners.isEmpty) _close();
    });
  }
}
