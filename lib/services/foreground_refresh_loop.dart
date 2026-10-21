import 'dart:async';

/// Polls read-only UI data while its screen is foregrounded. Realtime bursts
/// coalesce, and a slow request never starts a second overlapping request.
class ForegroundRefreshLoop {
  ForegroundRefreshLoop({required this.refresh, required this.interval});

  final Future<void> Function() refresh;
  final Duration interval;
  Timer? _poll;
  Timer? _debounce;
  bool _foreground = false;
  bool _disposed = false;
  bool _running = false;
  bool get isForeground => _foreground && !_disposed;

  void setForeground(bool foreground) {
    if (_disposed || foreground == _foreground) return;
    _foreground = foreground;
    _poll?.cancel();
    _debounce?.cancel();
    if (foreground) {
      _poll = Timer.periodic(interval, (_) => request());
      unawaited(request());
    }
  }

  void notifyChanged() {
    if (_disposed || !_foreground) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () => request());
  }

  Future<void> request() async {
    if (_disposed || !_foreground || _running) return;
    _running = true;
    try {
      await refresh();
    } finally {
      _running = false;
    }
  }

  void dispose() {
    _disposed = true;
    _poll?.cancel();
    _debounce?.cancel();
  }
}
