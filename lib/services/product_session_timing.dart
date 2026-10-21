import 'package:flutter/widgets.dart';

/// Starts at Dart entry or app resume, not at the OS launcher. Data stays in
/// memory; optional consent and server flags are checked only during delivery.
class ProductSessionTiming with WidgetsBindingObserver {
  ProductSessionTiming({int Function()? elapsedMilliseconds})
      : _elapsedOverride = elapsedMilliseconds;
  static final instance = ProductSessionTiming();
  final int Function()? _elapsedOverride;
  final _clock = Stopwatch();
  bool _started = false, _observing = false;
  int? _homeVisible;
  int get _elapsed => _elapsedOverride?.call() ?? _clock.elapsedMilliseconds;
  void start({bool observeLifecycle = true}) {
    _clock..reset()..start();
    _started = true;
    _homeVisible = null;
    if (observeLifecycle && !_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
  }
  void markHomeVisible() {
    if (_started) _homeVisible ??= _elapsed;
  }
  void clearHomeForAccountChange() => _homeVisible = null;
  Map<String, int?> snapshot() => !_started ? const {} : {
    'app_to_booking_ms': _elapsed,
    'home_visible_ms': _homeVisible,
  };
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) start(observeLifecycle:false);
  }
}
