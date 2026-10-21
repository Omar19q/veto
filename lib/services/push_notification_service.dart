import 'dart:async';
import 'dart:convert';
import '../routes/app_routes.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';
import 'staff_access_v16.dart';

class PushNotificationService with WidgetsBindingObserver {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _defaultChannel =
      AndroidNotificationChannel(
        'veto_general_v2',
        'تنبيهات فيتو ثانية',
        description: 'تنبيهات الرحلات والمحفظة والعروض العامة',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('veto_chat'),
      );

  static const AndroidNotificationChannel _offerChannel =
      AndroidNotificationChannel(
        'veto_offer_v2',
        'عروض الرحلات',
        description: 'تنبيهات عروض الرحلات',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('veto_offer'),
      );

  static const AndroidNotificationChannel _chatChannel =
      AndroidNotificationChannel(
        'veto_chat_v2',
        'المحادثات',
        description: 'تنبيهات المحادثات',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('veto_chat'),
      );

  static const AndroidNotificationChannel _marketOrderChannel =
      AndroidNotificationChannel(
        'veto_market_order_v3',
        'طلبات فيتو ماركت الجديدة',
        description: 'تنبيه طلب متجر جديد بنغمة واضحة لمدة 15 ثانية',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('veto_market_order'),
      );

  static const AndroidNotificationChannel _verificationChannel =
      AndroidNotificationChannel(
        'veto_verification_v22',
        'طلبات التحقق السريع',
        description: 'تنبيه موظفي التحقق لطلبات الدخول الجديدة',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('veto_verification'),
      );

  bool _ready = false;
  bool _observerRegistered = false;
  bool _appInForeground = true;
  RealtimeChannel? _notificationsChannel;
  String? _boundUserId;
  StreamSubscription<AuthState>? _authSubscription;
  final Map<String, DateTime> _recentlyDisplayed = {};

  Future<void> showBackgroundData(RemoteMessage message) async {
    final title = message.data['title']?.toString();
    final body = message.data['body']?.toString();
    if (title == null && body == null) return;
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_veto'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    final android = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    for (final channel in [
      _defaultChannel,
      _offerChannel,
      _chatChannel,
      _marketOrderChannel,
      _verificationChannel,
    ]) {
      await android?.createNotificationChannel(channel);
    }
    final type = message.data['notification_type']?.toString();
    await showLocal(
      id:
          (message.data['notification_id']?.toString() ??
                  message.messageId ??
                  DateTime.now().millisecondsSinceEpoch.toString())
              .hashCode &
          0x7fffffff,
      title: title ?? 'فيتو ثانية',
      body: body ?? '',
      sound: type == 'verification' ? 'verification' :
          type == 'offer' && message.data['market_order_id'] != null
          ? 'market_order'
          : type,
    );
  }

  Future<void> initialize() async {
    if (kIsWeb || _ready) return;
    if (!_observerRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _observerRegistered = true;
    }

    try {
      await Firebase.initializeApp();

      const androidSettings = AndroidInitializationSettings(
        '@drawable/ic_stat_veto',
      );
      const iosSettings = DarwinInitializationSettings();

      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _local.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) {
          try {
            final data = jsonDecode(response.payload ?? '{}');
            if (data is Map)
              unawaited(_openTripV10(Map<String, dynamic>.from(data)));
          } catch (_) {}
        },
      );

      final androidPlugin = _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      await androidPlugin?.createNotificationChannel(_defaultChannel);
      await androidPlugin?.createNotificationChannel(_offerChannel);
      await androidPlugin?.createNotificationChannel(_chatChannel);
      await androidPlugin?.createNotificationChannel(_marketOrderChannel);
      await androidPlugin?.createNotificationChannel(_verificationChannel);
      await androidPlugin?.requestNotificationsPermission();

      final messaging = FirebaseMessaging.instance;

      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );

      await messaging.requestPermission(alert: true, badge: true, sound: true);

      // Failure to obtain a token must not prevent installing auth/foreground
      // listeners. Retry registering the token when the app resumes.
      String? token;
      try {
        token = await messaging.getToken();
        if (token != null) await _saveToken(token);
      } catch (e) {
        debugPrint('FCM token deferred until resume: $e');
      }

      messaging.onTokenRefresh.listen((token) async {
        await _saveToken(token);
      });

      _authSubscription?.cancel();
      _authSubscription = SupabaseService.instance.client.auth.onAuthStateChange
          .listen((state) async {
            final user = state.session?.user;
            if (user != null) {
              await _saveToken(null);
              await _bindNotificationStream(user.id);
              final pending = _pendingTripOpenV10;
              if (pending != null)
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => unawaited(_openTripV10(pending)),
                );
            } else {
              _notificationsChannel?.unsubscribe();
              _notificationsChannel = null;
              _boundUserId = null;
              try {
                await FirebaseMessaging.instance.deleteToken();
              } catch (e) {
                debugPrint('Push token cleanup failed: $e');
              }
            }
          });

      final currentUser = SupabaseService.instance.currentUser;
      if (currentUser != null) {
        await _bindNotificationStream(currentUser.id);
        await _saveToken(token);
      }

      // Android push is now presented by OneSignal; do not also surface the
      // underlying FCM message via FlutterLocalNotifications (double alert).
      if (defaultTargetPlatform != TargetPlatform.android) {
      FirebaseMessaging.onMessage.listen((message) async {
        if (message.data['notification_type'] == 'chat') return;
        await _showOnce(
          key: message.data['notification_id']?.toString() ?? message.messageId,
          payload: jsonEncode(message.data),
          id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
          title: message.notification?.title ?? 'فيتو ثانية',
          body: message.notification?.body ?? '',
          sound:
              message.data['market_order_id'] != null &&
                  message.data['notification_type'] == 'offer'
              ? 'market_order'
              : message.data['notification_type']?.toString(),
        );
      });

      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => unawaited(_openTripV10(message.data)),
      );
      final opened = await FirebaseMessaging.instance.getInitialMessage();
      if (opened != null)
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => unawaited(_openTripV10(opened.data)),
        );
      }
      _ready = true;
    } catch (e) {
      debugPrint('PushNotificationService.initialize: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
    if (state != AppLifecycleState.resumed) return;
    if (!_ready) {
      // Initialization may have failed while offline; recover on return.
      initialize();
      return;
    }
    // FCM tokens may rotate while Android suspends the process.
    _syncOnResume();
  }

  Future<void> _syncOnResume() async {
    try {
      final userId = SupabaseService.instance.currentUser?.id;
      if (userId == null) return;
      await _saveToken(null);
      await _bindNotificationStream(userId);
    } catch (e) {
      debugPrint('Push resume sync: $e');
    }
  }

  Future<void> openPushPayload(Map<String, dynamic> data) => _openTripV10(data);

  Future<void> _bindNotificationStream(String userId) async {
    if (_boundUserId == userId && _notificationsChannel != null) return;

    _notificationsChannel?.unsubscribe();

    _notificationsChannel = SupabaseService.instance.client
        .channel('user_notifications_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) async {
            if (!_appInForeground) return;
            // The OneSignal SDK presents native push on Android. Avoid two
            // banners (Realtime local + OneSignal) for the same DB event.
            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return;
            final row = payload.newRecord;
            if (row['notification_type'] == 'chat') return;
            await _showOnce(
              key: row['id']?.toString(),
              payload: jsonEncode({ ...?((row['data'] is Map) ? Map<String, dynamic>.from(row['data'] as Map) : null), 'notification_type': row['notification_type']?.toString() }),
              id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
              title: row['title']?.toString() ?? 'فيتو ثانية',
              body: row['body']?.toString() ?? '',
              sound:
                  row['data'] is Map &&
                      (row['data'] as Map)['market_order_id'] != null &&
                      row['notification_type'] == 'offer'
                  ? 'market_order'
                  : row['notification_type']?.toString(),
            );
          },
        )
        .subscribe();

    _boundUserId = userId;
  }

  Future<void> _saveToken(String? token) async {
    try {
      token ??= await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;

      final user = SupabaseService.instance.currentUser;
      if (user == null) return;

      await SupabaseService.instance.client.rpc(
        'register_push_token',
        params: {
          'p_token': token,
          'p_platform': defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android',
        },
      );
    } catch (e) {
      debugPrint('Push token save failed: $e');
    }
  }

  Map<String, dynamic>? _pendingTripOpenV10;
  Future<void> _openTripV10(Map<String, dynamic> data) async {
    final id = data['trip_id']?.toString();
    final user = SupabaseService.instance.currentUser;
    if (user == null) {
      _pendingTripOpenV10 = data;
      return;
    }
    _pendingTripOpenV10 = null;
    if (data['notification_type'] == 'post_trip_checkin') {
      appRouter.go('${AppRoutes.customerFeedback}?type=complaint');
      return;
    }
    if (data['notification_type'] == 'verification') {
      try {
        final access = await StaffAccessV16.load();
        if (access.can('verification.view')) {
          appRouter.go(AppRoutes.adminDashboard);
        }
      } catch (_) {}
      return;
    }
    if (id == null || !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id)) {
      // Staff and owner use the administrative inbox, customers use theirs.
      try {
        final access = await StaffAccessV16.load();
        if (access.active && access.can('notifications.view')) {
          appRouter.go(AppRoutes.adminDashboard);
        } else {
          appRouter.go(AppRoutes.notifications);
        }
      } catch (_) {
        appRouter.go(AppRoutes.notifications);
      }
      return;
    }
    try {
      final trip = await SupabaseService.instance.getTripById(id);
      if (trip == null) return;
      final captain = await SupabaseService.instance.getCaptainByUserId(
        user.id,
      );
      if (captain != null) {
        appRouter.go(
          trip['captain_id'] == captain['id']
              ? '${AppRoutes.captainLiveTrip}?tripId=$id'
              : AppRoutes.captainDashboardScreen,
        );
      } else {
        appRouter.go(
          trip['captain_id'] == null
              ? '${AppRoutes.tripBookingScreen}?resumeTripId=$id'
              : '${AppRoutes.liveTrip}?tripId=$id',
        );
      }
    } catch (_) {
      appRouter.go(AppRoutes.notifications);
    }
  }

  Future<void> _showOnce({
    required String? key,
    required int id,
    required String title,
    required String body,
    String? sound,
    String? payload,
  }) async {
    final now = DateTime.now();
    _recentlyDisplayed.removeWhere(
      (_, shownAt) => now.difference(shownAt) > const Duration(minutes: 2),
    );

    final normalizedKey = key?.trim();
    if (normalizedKey != null && normalizedKey.isNotEmpty) {
      final shownAt = _recentlyDisplayed[normalizedKey];
      if (shownAt != null &&
          now.difference(shownAt) < const Duration(seconds: 30)) {
        return;
      }
      _recentlyDisplayed[normalizedKey] = now;
    }

    await showLocal(
      id: id,
      title: title,
      body: body,
      sound: sound,
      payload: payload,
    );
  }

  Future<void> showLocal({
    required int id,
    required String title,
    required String body,
    String? sound,
    String? payload,
  }) async {
    final channelId = sound == 'verification' ? 'veto_verification_v22'
        : sound == 'market_order'
        ? 'veto_market_order_v3'
        : sound == 'offer'
        ? 'veto_offer_v2'
        : sound == 'chat'
        ? 'veto_chat_v2'
        : 'veto_general_v2';

    final androidDetails = AndroidNotificationDetails(
      channelId,
      sound == 'verification' ? 'طلبات التحقق السريع'
          : sound == 'market_order'
          ? 'طلبات فيتو ماركت الجديدة'
          : sound == 'offer'
          ? 'عروض الرحلات'
          : sound == 'chat'
          ? 'المحادثات'
          : 'Veto Sanya',
      channelDescription: 'تنبيهات فيتو ثانية',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@drawable/ic_stat_veto',
      sound: sound == 'verification'
          ? const RawResourceAndroidNotificationSound('veto_verification')
          : sound == 'market_order'
          ? const RawResourceAndroidNotificationSound('veto_market_order')
          : sound == 'offer'
          ? const RawResourceAndroidNotificationSound('veto_offer')
          : const RawResourceAndroidNotificationSound('veto_chat'),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _local.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }
}
