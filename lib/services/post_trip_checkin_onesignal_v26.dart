import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../routes/app_routes.dart';
import 'push_notification_service.dart';

/// Connects OneSignal subscriptions to the *verified* Supabase user ID.
/// Only handles the new post-trip feedback notification; existing ride push
/// and accounting flows are intentionally unchanged.
class PostTripCheckinOneSignalV26 {
  PostTripCheckinOneSignalV26._();

  static final PostTripCheckinOneSignalV26 instance =
      PostTripCheckinOneSignalV26._();

  String? _lastUserId;
  bool _started = false;
  bool _pendingComplaint = false;

  void start() {
    if (_started || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _started = true;

    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      if (data == null) return;
      final payload = Map<String, dynamic>.from(data);
      if (payload['notification_type'] == 'post_trip_checkin') {
        _pendingComplaint = true;
        _openPendingComplaint();
        return;
      }
      // Existing trip routing checks participation before opening details.
      unawaited(PushNotificationService.instance.openPushPayload(payload));
    });

    Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      final userId = Supabase.instance.client.auth.currentUser?.id ??
          state.session?.user.id;
      unawaited(_syncUser(userId));
      if (userId != null) _openPendingComplaint();
    });

    unawaited(_syncUser(Supabase.instance.client.auth.currentUser?.id));
  }

  Future<void> _syncUser(String? userId) async {
    if (_lastUserId == userId) return;
    _lastUserId = userId;
    try {
      if (userId == null) {
        await OneSignal.logout();
      } else {
        // Use Auth UUID, never a typed phone number or unverified role.
        await OneSignal.login(userId);
      }
    } catch (error) {
      debugPrint('OneSignal user binding deferred: $error');
      // Allow retry on the next Auth transition if network was unavailable.
      _lastUserId = null;
    }
  }

  void _openPendingComplaint() {
    if (!_pendingComplaint) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_pendingComplaint) return;
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        appRouter.go(AppRoutes.signUpLoginScreen);
        return; // Keep pending until a verified login completes.
      }
      _pendingComplaint = false;
      appRouter.go('${AppRoutes.customerFeedback}?type=complaint');
    });
  }
}
