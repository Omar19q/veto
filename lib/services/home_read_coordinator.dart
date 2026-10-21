import 'dart:async';

/// Preserve the essential active-trip read while nonessential market status
/// loads independently. Errors remain visible through the owning UI callback.
class HomeReadCoordinator {
  static Future<T> load<T, M>({required Future<T> essential,
    required Future<M> ancillary,required void Function(M) onAncillary,
    required void Function(Object) onAncillaryError}) {
    unawaited(() async {
      try { onAncillary(await ancillary); }
      catch (error) { onAncillaryError(error); }
    }());
    return essential;
  }
}
