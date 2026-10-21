import 'dart:async';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One shared channel for all mounted team surfaces; refreshes on reconnect and resume.
class TeamChatServiceV16 with WidgetsBindingObserver {
  TeamChatServiceV16(this.client);
  final SupabaseClient client;
  static TeamChatServiceV16? _shared;
  static TeamChatServiceV16 get shared =>
      _shared ??= TeamChatServiceV16(Supabase.instance.client);
  final Set<VoidCallback> _listeners = {};
  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _auth;
  Timer? _debounce;
  String? _user;
  static String newClientKey() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 15) | 64;
    b[8] = (b[8] & 63) | 128;
    final s = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }

  VoidCallback watch(VoidCallback listener) {
    _listeners.add(listener);
    if (_listeners.length == 1) {
      WidgetsBinding.instance.addObserver(this);
      _auth = client.auth.onAuthStateChange.listen((state) {
        if (_user != state.session?.user.id) {
          _connect();
          _emit();
        }
      });
      _connect();
    }
    return () {
      _listeners.remove(listener);
      if (_listeners.isEmpty) {
        WidgetsBinding.instance.removeObserver(this);
        _auth?.cancel();
        _auth = null;
        _debounce?.cancel();
        final old = _channel;
        _channel = null;
        if (old != null) unawaited(client.removeChannel(old));
      }
    };
  }

  void _connect() {
    final old = _channel;
    _channel = null;
    if (old != null) unawaited(client.removeChannel(old));
    _user = client.auth.currentUser?.id;
    if (_user == null || _listeners.isEmpty) return;
    var channel = client.channel('v16_team_$_user');
    for (final table in [
      'team_messages_v16',
      'team_members_v16',
      'team_notifications_v16',
      'team_threads_v16',
      'staff_v16',
    ]) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => _emit(),
      );
    }
    _channel = channel;
    channel.subscribe((status, _) {
      if (identical(_channel, channel) &&
          status == RealtimeSubscribeStatus.subscribed) {
        _emit();
      }
    });
  }

  void _emit() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      for (final listener in List<VoidCallback>.of(_listeners)) {
        listener();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _emit();
  }

  Future<List<Map<String, dynamic>>> inbox({String? before}) async =>
      List<Map<String, dynamic>>.from(
        await client.rpc(
          'v16_chat_inbox',
          params: {'p_before': before, 'p_limit': 30},
        ),
      );
  Future<List<Map<String, dynamic>>> directory() async =>
      List<Map<String, dynamic>>.from(await client.rpc('v16_chat_directory'));
  Future<List<Map<String, dynamic>>> history(
    String thread, {
    int? before,
  }) async {
    var q = client.from('team_messages_v16').select().eq('thread_id', thread);
    if (before != null) q = q.lt('id', before);
    return List<Map<String, dynamic>>.from(
      await q.order('id', ascending: false).limit(40),
    );
  }

  Future<int> send(String thread, String key, String body) async =>
      (await client.rpc(
                'v16_chat_send',
                params: {'p_thread': thread, 'p_key': key, 'p_body': body},
              )
              as num)
          .toInt();
  Future<void> read(String thread, int through) async {
    await client.rpc(
      'v16_chat_read',
      params: {'p_thread': thread, 'p_through': through},
    );
  }

  Future<String> create(String title, List<String> members, bool group) async =>
      await client.rpc(
            'v16_chat_create',
            params: {'p_title': title, 'p_members': members, 'p_group': group},
          )
          as String;
  Future<List<Map<String, dynamic>>> members(String thread) async =>
      List<Map<String, dynamic>>.from(
        await client
            .from('team_members_v16')
            .select('user_id')
            .eq('thread_id', thread),
      );
  Future<void> memberSet(String thread, String user, bool add) async {
    await client.rpc(
      'v16_chat_member_set',
      params: {'p_thread': thread, 'p_user': user, 'p_add': add},
    );
  }

  Future<List<Map<String, dynamic>>> notifications({int? before}) async {
    var q = client.from('team_notifications_v16').select();
    if (before != null) q = q.lt('id', before);
    return List<Map<String, dynamic>>.from(
      await q.order('id', ascending: false).limit(40),
    );
  }

  Future<void> notificationRead(int id) async {
    await client.rpc('v16_notification_read', params: {'p_id': id});
  }
}

/// Preserve this key and immutable payload across network retries.
class TeamPendingMessageV16 {
  TeamPendingMessageV16(this.body) : key = TeamChatServiceV16.newClientKey();
  final String key;
  final String body;
  bool sending = false;
  bool failed = false;
}
