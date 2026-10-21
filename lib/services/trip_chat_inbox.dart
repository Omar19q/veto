import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_sound_service.dart';
import 'supabase_service.dart';

class TripChatInbox extends ChangeNotifier with WidgetsBindingObserver {
  TripChatInbox._();
  static final instance = TripChatInbox._();
  final Map<String, Map<String, dynamic>> _unread = {};
  final Set<String> _seen = {};
  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _auth;
  RouteInformationProvider? _routes;
  String? _userId;
  bool _foreground = true;
  bool _syncing = false;
  bool _syncAgain = false;
  bool _marking = false;
  int _generation = 0;
  String? get visibleTrip {
    final uri = _routes?.value.uri;
    return _foreground && uri?.path == '/trip-chat'
        ? uri?.queryParameters['tripId']
        : null;
  }

  bool hasUnread(String tripId) =>
      visibleTrip != tripId &&
      _unread.values.any((m) => m['trip_id']?.toString() == tripId);

  Future<void> initialize(RouteInformationProvider routes) async {
    if (_routes != null) return;
    _routes = routes;
    routes.addListener(_routeChanged);
    WidgetsBinding.instance.addObserver(this);
    _auth = SupabaseService.instance.authStateChanges.listen((state) {
      unawaited(_bind(state.session?.user.id));
    });
    await _bind(SupabaseService.instance.currentUser?.id);
  }

  Future<void> _bind(String? userId) async {
    if (_userId == userId && (_channel != null || userId == null)) return;
    final generation = ++_generation;
    final old = _channel;
    _channel = null;
    _userId = userId;
    _unread.clear();
    _seen.clear();
    notifyListeners();
    if (old != null) await SupabaseService.instance.client.removeChannel(old);
    if (userId == null || generation != _generation) return;
    _channel = SupabaseService.instance.client
        .channel('trip_inbox_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: userId,
          ),
          callback: (payload) {
            if (generation != _generation) return;
            final message = payload.newRecord;
            if (message.isEmpty) {
              unawaited(_sync());
              return;
            }
            _receive(message);
          },
        )
        .subscribe((status, _) {
          if (status == RealtimeSubscribeStatus.subscribed) unawaited(_sync());
        });
    await _sync();
  }

  void _receive(
    Map<String, dynamic> message, {
    bool playSound = true,
    bool fromEvent = true,
    bool notify = true,
  }) {
    final id = message['id']?.toString();
    final tripId = message['trip_id']?.toString();
    if (id == null ||
        tripId == null ||
        message['receiver_id']?.toString() != _userId)
      return;
    final fresh = _seen.add(id);
    if (_seen.length > 4000) _seen.remove(_seen.first);
    if (message['read_at'] != null) {
      _unread.remove(id);
    } else {
      _unread[id] = Map<String, dynamic>.from(message);
      if (fresh && playSound && _foreground && visibleTrip != tripId) {
        unawaited(AppSoundService.instance.playChat());
      }
    }
    if (_syncing && fromEvent) _syncAgain = true;
    if (notify) notifyListeners();
    if (visibleTrip == tripId) unawaited(markVisibleRead());
  }

  Future<void> _sync() async {
    final userId = _userId;
    if (userId == null) return;
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    final generation = _generation;
    try {
      final rows = <Map<String, dynamic>>[];
      for (var offset = 0; ; offset += 500) {
        final page = await SupabaseService.instance.client
            .from('chat_messages')
            .select('id,trip_id,receiver_id,read_at,created_at')
            .eq('receiver_id', userId)
            .isFilter('read_at', null)
            .order('created_at')
            .order('id')
            .range(offset, offset + 499);
        rows.addAll(List<Map<String, dynamic>>.from(page));
        if (page.length < 500) break;
      }
      if (generation != _generation) return;
      final initial = _seen.isEmpty;
      for (final row in rows) {
        _receive(row, playSound: !initial, fromEvent: false, notify: false);
      }
      final ids = rows.map((m) => m['id']?.toString()).toSet();
      if (!_syncAgain) _unread.removeWhere((id, _) => !ids.contains(id));
      notifyListeners();
      unawaited(markVisibleRead());
    } catch (_) {
      // Keep unread badges while temporarily offline.
    } finally {
      _syncing = false;
      if (_syncAgain) {
        _syncAgain = false;
        // Defer another snapshot: events may have arrived during the query.
        Future<void>.delayed(const Duration(seconds: 1), () => _sync());
      }
    }
  }

  Future<void> markVisibleRead() async {
    final tripId = visibleTrip;
    if (_marking || tripId == null || _userId == null) return;
    final ids = _unread.entries
        .where((e) => e.value['trip_id']?.toString() == tripId)
        .map((e) => e.key)
        .take(1000)
        .toList();
    if (ids.isEmpty) return;
    _marking = true;
    var succeeded = false;
    final generation = _generation;
    try {
      await SupabaseService.instance.client.rpc(
        'mark_trip_chat_read_v13',
        params: {'p_trip_id': tripId, 'p_message_ids': ids},
      );
      if (generation != _generation) return;
      for (final id in ids) {
        _unread.remove(id);
      }
      succeeded = true;
      notifyListeners();
    } catch (_) {
      // Retry on the next Realtime event, resume or fallback snapshot.
    } finally {
      _marking = false;
      if (succeeded &&
          visibleTrip == tripId &&
          _unread.values.any((m) => m['trip_id']?.toString() == tripId)) {
        unawaited(markVisibleRead());
      }
    }
  }

  void _routeChanged() {
    notifyListeners();
    unawaited(markVisibleRead());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _routeChanged();
    if (_foreground) unawaited(_sync());
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _routes?.removeListener(_routeChanged);
    _auth?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }
}
