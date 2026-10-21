import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import 'supabase_service.dart';
import 'location_upload_gate_v15.dart';

/// Foreground-only driver location. Does not request background location or
/// launch a foreground/background Android service. Stops when the app is hidden.
/// Dispatch requires a recent GPS fix; a hidden app may become ineligible.
class CaptainTrackingService with WidgetsBindingObserver {
  CaptainTrackingService._();
  static final CaptainTrackingService instance = CaptainTrackingService._();

  final StreamController<Position> _positions = StreamController<Position>.broadcast();
  Stream<Position> get positions => _positions.stream;
  // Emitted only after the backend confirms an actual GPS update.
  final StreamController<DateTime> _serverFixes = StreamController<DateTime>.broadcast();
  Stream<DateTime> get serverFixes => _serverFixes.stream;
  DateTime? _lastServerFix;
  DateTime? get lastServerFix => _lastServerFix;

  bool get isRunning => _captainId != null && !_paused;

  StreamSubscription<Position>? _gps;
  Timer? _heartbeat;
  String? _captainId;
  String? _userId;
  bool _paused = false;
  bool _uploading = false;
  int _generation = 0;
  final LocationUploadGateV15 _uploadGate = LocationUploadGateV15();

  LocationSettings get settings {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 5),
      );
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: true,
        allowBackgroundLocationUpdates: false,
        showBackgroundLocationIndicator: false,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 0);
  }

  Future<void> start(String captainId) async {
    if (_captainId == captainId && isRunning) return;
    await stop();
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationServiceDisabledException();
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      throw StateError('location_permission_required');
    }
    final client = SupabaseService.instance.client;
    final user = client.auth.currentUser;
    if (user == null) throw StateError('authentication_required');
    final registered = await client.from('captains').select('id')
        .eq('id', captainId).eq('user_id', user.id).maybeSingle();
    if (registered == null) throw StateError('not_current_captain');
    _captainId = captainId;
    _userId = user.id;
    _paused = WidgetsBinding.instance.lifecycleState != null &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    if (!_paused) _listen();
  }

  void _listen() {
    if (_captainId == null || _paused || _gps != null) return;
    final generation = ++_generation;
    _gps = Geolocator.getPositionStream(locationSettings: settings).listen(
      (position) {
        if (generation != _generation || _paused) return;
        _positions.add(position);
        unawaited(_upload(position, generation));
      },
      onError: (Object error) {
        debugPrint('Captain foreground GPS: $error');
        _positions.addError(error);
      },
      onDone: () { _gps = null; },
      cancelOnError: false,
    );
    // Stationary GPS streams may not emit every five seconds. This modest
    // heartbeat keeps the server-side two-minute location freshness valid.
    _heartbeat = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_paused || _uploading || generation != _generation) return;
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        await _upload(position, generation);
      } catch (error) {
        debugPrint('Captain location heartbeat: $error');
      }
    });
  }

  Future<bool> _upload(Position position, int generation, {bool force = false}) async {
    final captainId = _captainId;
    final age = DateTime.now().difference(position.timestamp);
    if (_uploading || _paused || captainId == null ||
        generation != _generation ||
        SupabaseService.instance.currentUser?.id != _userId ||
        age > const Duration(seconds: 60) ||
        age < const Duration(seconds: -5) ||
        !position.latitude.isFinite || !position.longitude.isFinite ||
        position.latitude.abs() > 90 || position.longitude.abs() > 180 ||
        (!force && !_uploadGate.shouldUpload(
          position.latitude, position.longitude, DateTime.now()))) {
      return false;
    }
    _uploading = true;
    _uploadGate.attempted(DateTime.now());
    try {
      await SupabaseService.instance.updateCaptainLocation(
        captainId, position.latitude, position.longitude,
      ).timeout(const Duration(seconds: 12));
      if (generation == _generation && !_paused) {
        final confirmedAt = DateTime.now();
        _uploadGate.committed(position.latitude, position.longitude, confirmedAt);
        _lastServerFix = confirmedAt;
        _serverFixes.add(confirmedAt);
        return true;
      }
      return false;
    } catch (error) {
      debugPrint('Captain GPS upload: $error');
      return false;
    } finally {
      _uploading = false;
    }
  }

  // Retry a stalled foreground GPS stream without starting background tracking.
  // Useful on devices that temporarily suspend location callbacks.
  Future<bool> refreshNow() async {
    if (_captainId == null || _paused) return false;
    // Another foreground location upload may already be in flight. Wait for
    // its server acknowledgement rather than issuing a competing RPC.
    if (_uploading) {
      try {
        await serverFixes.first.timeout(const Duration(seconds: 13));
        return !_paused && _captainId != null;
      } catch (_) {
        return false;
      }
    }
    final generation = _generation;
    try {
      final fix = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      // Do not report a previously successful fix as proof of this upload.
      // The dispatch engine requires a current server-side timestamp.
      return await _upload(fix, generation, force: true);
    } catch (error) {
      debugPrint('Captain foreground GPS retry: $error');
      return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_captainId != null) {
        _paused = false;
        _listen();
        // Immediately refresh the server fix after a period in the background.
        // Remains foreground-only: no permission or location access while hidden.
        final generation = _generation;
        unawaited(_freshFixOnResume(generation));
      }
    } else {
      _paused = true;
      _generation++;
      _heartbeat?.cancel();
      _heartbeat = null;
      final old = _gps;
      _gps = null;
      if (old != null) unawaited(old.cancel());
    }
  }

  Future<void> _freshFixOnResume(int generation) async {
    if (_captainId == null || _paused) return;
    try {
      final fix = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (_captainId != null && !_paused && generation == _generation) {
        _positions.add(fix);
        await _upload(fix, generation, force: true);
      }
    } catch (error) {
      debugPrint('Captain foreground resume location: $error');
    }
  }

  Future<void> stop() async {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _captainId = null;
    _userId = null;
    _paused = false;
    _heartbeat?.cancel();
    _heartbeat = null;
    final old = _gps;
    _gps = null;
    await old?.cancel();
    _lastServerFix = null;
    _uploadGate.reset();
  }
}
