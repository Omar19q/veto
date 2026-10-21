import 'scale_metrics_v15.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A screen owns a lease; disposing it never tears down another screen's socket.
class TripRealtimeLease {
  final Future<void> Function() _release;
  bool _closed = false;
  TripRealtimeLease(this._release);
  Future<void> unsubscribe() async {
    if (_closed) return;
    _closed = true;
    await _release();
  }
}

class TripRealtimeHub {
  final SupabaseClient client;
  final Future<Map<String, dynamic>?> Function(String) fetch;
  final Map<String, _Watch> _watches = {};
  String? _owner;
  TripRealtimeHub(this.client, this.fetch) {
    _owner = client.auth.currentUser?.id;
    client.auth.onAuthStateChange.listen((state) {
      final next = state.session?.user.id;
      if (next == _owner) return;
      _owner = next;
      for (final value in _watches.values.toList()) {
        value.close();
        value.listeners.clear();
        unawaited(client.removeChannel(value.channel!));
      }
      _watches.clear();
    });
  }
  TripRealtimeLease watch(
    String id,
    void Function(Map<String, dynamic>) callback,
  ) {
    final key = '${client.auth.currentUser?.id}_$id';
    final watch = _watches.putIfAbsent(key, () {
      final value = _Watch(fetch, id);
      value.channel = client
          .channel('v10_trip_${client.auth.currentUser?.id}_$id')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'trips',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: id,
            ),
            callback: (payload) {
              value.emit(payload.newRecord);
              value.scheduleRefresh();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'trip_dispatches',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'trip_id',
              value: id,
            ),
            callback: (p) => value.emit({'dispatch': p.newRecord}),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'trip_offers',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'trip_id',
              value: id,
            ),
            callback: (p) => value.emit({'offer': p.newRecord}),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'trip_live_locations_v10',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'trip_id',
              value: id,
            ),
            callback: (payload) {
              final p = payload.newRecord;
              value.emit({'live_location': p});
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'trip_events_v10',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'trip_id',
              value: id,
            ),
            callback: (payload) {
              value.emit({'trip_event_v11': payload.newRecord});
              unawaited(value.refresh());
            },
          )
          .subscribe((status, error) {
            if (status == RealtimeSubscribeStatus.subscribed)
              unawaited(value.refresh());
          });
      return value;
    });
    watch.listeners.update(callback, (count) => count + 1, ifAbsent: () => 1);
    if (watch._snapshot.isNotEmpty)
      scheduleMicrotask(() {
        if (watch.listeners.containsKey(callback))
          callback(Map.of(watch._snapshot));
      });
    watch.scheduleRefresh();
    return TripRealtimeLease(() async {
      final count = watch.listeners[callback] ?? 0;
      if (count > 1) {
        watch.listeners[callback] = count - 1;
      } else {
        watch.listeners.remove(callback);
      }
      if (watch.listeners.isEmpty) {
        watch.close();
        if (identical(_watches[key], watch)) _watches.remove(key);
        await client.removeChannel(watch.channel!);
      }
    });
  }
}

class _Watch {
  final Future<Map<String, dynamic>?> Function(String) fetch;
  final String id;
  final Map<void Function(Map<String, dynamic>), int> listeners = {};
  RealtimeChannel? channel;
  Timer? _refreshTimer;
  bool _closed = false;
  void close() {
    _closed = true;
    _refreshTimer?.cancel();
  }

  void scheduleRefresh() {
    if (_closed) return;
    _refreshTimer ??= Timer(const Duration(milliseconds: 250), () {
      _refreshTimer = null;
      unawaited(refresh());
    });
  }

  bool _fetching = false;
  bool _again = false;
  _Watch(this.fetch, this.id);
  int _revision = 0;
  Map<String, dynamic> _snapshot = {};
  void emit(Map<String, dynamic> value) {
    if (_closed) return;
    _revision++;
    _snapshot = {..._snapshot, ...value};
    for (final listener in List.of(listeners.keys)) {
      try {
        listener(Map.of(_snapshot));
      } catch (_) {
        /* A disposed view must not block other leases. */
      }
    }
  }

  Future<void> refresh() async {
    if (_closed || listeners.isEmpty) return;
    if (_fetching) {
      _again = true;
      return;
    }
    _fetching = true;
    final revision = _revision;
    try {
      final data = await fetch(id).observeScaleV15('trip_realtime_resync');
      if (data != null && revision == _revision)
        emit(data);
      else if (data != null)
        _again = true;
    } catch (_) {
      // Keep the last visible snapshot; reconnect and explicit retry resync it.
    } finally {
      _fetching = false;
      if (_again && listeners.isNotEmpty) {
        _again = false;
        scheduleRefresh();
      }
    }
  }
}
