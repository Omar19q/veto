/// Shares only simultaneous non-financial reads. Completed values are never
/// cached, and a response cannot cross an authenticated account boundary.
class AccountScopedReadPool<T> {
  final Map<String, Future<T>> _pending = {};

  Future<T> read({required String key, required String owner,
    required String? Function() currentOwner, required Future<T> Function() load}) async {
    if (currentOwner() != owner) throw StateError('account_changed');
    final scope = '$owner:$key';
    final work = _pending.putIfAbsent(scope, () async {
      try { return await Future<T>.sync(load); }
      finally { _pending.remove(scope); }
    });
    final result = await work;
    if (currentOwner() != owner) throw StateError('account_changed');
    return result;
  }
}
