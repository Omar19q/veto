import 'package:flutter/foundation.dart';
import 'dart:async';
import 'growth_service.dart';
import 'package:geolocator/geolocator.dart';

enum CustomerLocationPhase {
  newUser,
  saved,
  loading,
  gpsOff,
  denied,
  outsideCoverage,
  lowAccuracy,
  ready,
  failed,
}

class CustomerLocationSnapshot {
  const CustomerLocationSnapshot(this.phase, {this.city});
  final CustomerLocationPhase phase;
  final String? city;
  String get message => switch (phase) {
    CustomerLocationPhase.newUser => 'اختار نقطة الركوب أو استخدم الموقع',
    CustomerLocationPhase.saved => 'آخر موقع محفوظ؛ راجع نقطة الركوب',
    CustomerLocationPhase.loading => 'جارٍ تحديد الموقع…',
    CustomerLocationPhase.gpsOff =>
      'خدمة الموقع مغلقة؛ يمكنك اختيار المنطقة يدويًا',
    CustomerLocationPhase.denied =>
      'إذن الموقع غير متاح؛ يمكنك اختيار المنطقة يدويًا',
    CustomerLocationPhase.outsideCoverage =>
      'لم نعثر على مدينة مغطاة عند نقطة الموقع',
    CustomerLocationPhase.lowAccuracy =>
      'دقة الموقع غير كافية؛ حدد نقطة الركوب يدويًا',
    CustomerLocationPhase.ready => 'موقعك: ${city ?? 'راجع نقطة الركوب'}',
    CustomerLocationPhase.failed => 'تعذر تحديد الموقع؛ يمكنك الاختيار يدويًا',
  };
}

/// Coordinates remain owned by existing map/quote code. This state only keeps
/// permission and status messages consistent; it never invents a pickup point.
class CustomerLocationState {
  static final state = ValueNotifier(
    const CustomerLocationSnapshot(CustomerLocationPhase.newUser),
  );
  static bool _requestedPermission = false;
  static Future<Position?> locate() async {
    state.value = const CustomerLocationSnapshot(CustomerLocationPhase.loading);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        state.value = const CustomerLocationSnapshot(
          CustomerLocationPhase.gpsOff,
        );
        return null;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && !_requestedPermission) {
        _requestedPermission = true;
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        unawaited(GrowthService().observe('location_permission_denied'));
        state.value = const CustomerLocationSnapshot(
          CustomerLocationPhase.denied,
        );
        return null;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 7),
        ),
      );
      if (!usable(p, DateTime.now())) {
        state.value = const CustomerLocationSnapshot(
          CustomerLocationPhase.lowAccuracy,
        );
        return null;
      }
      return p;
    } catch (_) {
      unawaited(GrowthService().observe('location_detection_failed'));
      state.value = const CustomerLocationSnapshot(
        CustomerLocationPhase.failed,
      );
      return null;
    }
  }

  static bool usable(Position p, DateTime now) =>
      p.latitude.isFinite &&
      p.longitude.isFinite &&
      p.accuracy.isFinite &&
      p.latitude.abs() <= 90 &&
      p.longitude.abs() <= 180 &&
      p.accuracy >= 0 &&
      p.accuracy <= 100 &&
      now.difference(p.timestamp) >= const Duration(seconds: -5) &&
      now.difference(p.timestamp) <= const Duration(seconds: 60);
  static void resolved(String? city) {
    state.value = CustomerLocationSnapshot(
      city == null
          ? CustomerLocationPhase.outsideCoverage
          : CustomerLocationPhase.ready,
      city: city,
    );
  }
}
