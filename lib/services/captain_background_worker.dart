import 'dart:async';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'location_upload_gate_v15.dart';

@pragma('vm:entry-point')
void captainBackgroundEntry(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  String? token;
  String? captainId;
  int expiresAt = 0;
  bool uploading = false;
  bool stopped = false;
  final uploadGate = LocationUploadGateV15();
  final startedAt = DateTime.now();
  StreamSubscription<Position>? gps;
  Timer? credentialsTimer;
  Timer? positionTimer;
  final subscriptions = <StreamSubscription<dynamic>>[];
  final client = SupabaseClient(
    SupabaseService.supabaseUrl,
    SupabaseService.supabaseAnonKey,
    accessToken: () async => token,
  );

  Future<void> stop() async {
    if (stopped) return;
    stopped = true;
    credentialsTimer?.cancel();
    positionTimer?.cancel();
    token = null;
    await gps?.cancel();
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    await client.dispose();
    service.invoke('trackingStopped');
    await service.stopSelf();
  }

  Future<void> upload(Position position) async {
    final now = DateTime.now();
    final age = now.difference(position.timestamp);
    if (stopped ||
        uploading ||
        captainId == null ||
        token == null ||
        expiresAt <= now.millisecondsSinceEpoch ~/ 1000 ||
        age > const Duration(seconds: 60) ||
        age < const Duration(seconds: -5) ||
        !position.latitude.isFinite ||
        !position.longitude.isFinite ||
        position.latitude.abs() > 90 ||
        position.longitude.abs() > 180 ||
        !uploadGate.shouldUpload(position.latitude, position.longitude, now))
      return;
    uploading = true;
    uploadGate.attempted(now);
    try {
      final raw = await client
          .rpc(
            'update_captain_location',
            params: {
              'p_captain_id': captainId,
              'p_lat': position.latitude,
              'p_lng': position.longitude,
            },
          )
          .timeout(const Duration(seconds: 15));
      if (raw is Map && raw['success'] == true) {
        uploadGate.committed(position.latitude, position.longitude, now);
        service.invoke('position', position.toJson());
      } else {
        service.invoke('trackingError', {'error': 'location_update_rejected'});
      }
    } catch (_) {
      service.invoke('trackingError', {'error': 'location_network_error'});
    } finally {
      uploading = false;
    }
  }

  subscriptions.add(
    service.on('stopTracking').listen((_) => unawaited(stop())),
  );
  subscriptions.add(
    service.on('credentials').listen((data) {
      if (data == null || stopped) return;
      final nextCaptain = data['captainId']?.toString();
      if (captainId != null && nextCaptain != captainId) {
        unawaited(stop());
        return;
      }
      token = data['accessToken']?.toString();
      captainId = nextCaptain;
      expiresAt = (data['expiresAt'] as num?)?.toInt() ?? 0;
      if (token == null || captainId == null) return;
      gps ??=
          Geolocator.getPositionStream(
            locationSettings: AndroidSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 15,
              intervalDuration: const Duration(seconds: 10),
            ),
          ).listen(
            (position) => unawaited(upload(position)),
            onError: (_) {
              service.invoke('trackingError', {
                'error': 'location_permission_or_gps_error',
              });
            },
          );
      service.invoke('trackingReady');
    }),
  );
  if (service is AndroidServiceInstance) {
    await service.setForegroundNotificationInfo(
      title: 'فيتو ثانية — الكابتن متصل',
      content: 'موقعك يتحدث أثناء الرحلة وقفل الشاشة',
    );
  }
  credentialsTimer = Timer.periodic(const Duration(seconds: 15), (_) {
    if (stopped) return;
    final now = DateTime.now();
    if ((token == null &&
            now.difference(startedAt) > const Duration(seconds: 45)) ||
        (expiresAt > 0 &&
            now.millisecondsSinceEpoch ~/ 1000 > expiresAt + 60)) {
      unawaited(stop());
      return;
    }
    service.invoke('credentialsRequested');
  });
  positionTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
    if (stopped || uploading) return;
    try {
      await upload(
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 12),
          ),
        ),
      );
    } catch (_) {}
  });
  service.invoke('credentialsRequested');
}
