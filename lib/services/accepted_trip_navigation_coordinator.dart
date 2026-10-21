/// A confirmed server snapshot may navigate only while the same request/account
/// is still current. Cancellation and route changes win over a late read reply.
class AcceptedTripNavigationCoordinator {
  bool _reading = false;
  Future<bool> confirm({
    required Future<Map<String, dynamic>?> Function() readTrip,
    required bool Function() isCurrent,
    required void Function() onConfirmed,
  }) async {
    if (_reading || !isCurrent()) return false;
    _reading = true;
    try {
      final snapshot = await readTrip();
      if (!isCurrent()) return false;
      final captain = snapshot?['captain_id']?.toString();
      if (!const {
            'accepted',
            'arriving',
            'arrived',
            'started',
          }.contains(snapshot?['trip_status']) ||
          captain == null ||
          captain.isEmpty)
        return false;
      onConfirmed();
      return true;
    } catch (_) {
      // The searching screen keeps its refresh/cancel actions usable. A read
      // failure is never treated as a successful acceptance.
      return false;
    } finally {
      _reading = false;
    }
  }
}
