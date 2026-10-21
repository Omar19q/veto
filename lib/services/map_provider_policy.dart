/// Provider selection contains capabilities only. It never contains credentials
/// or changes the Supabase pricing/coverage authority.
enum MapDisplayProvider { legacyRaster, openFreeMap, googleSdk }
enum MapDataProvider { geoapify, google }

class MapProviderPolicy {
  const MapProviderPolicy({
    this.display = MapDisplayProvider.legacyRaster,
    this.addresses = MapDataProvider.geoapify,
    this.routes = MapDataProvider.geoapify,
    this.googleApproved = false,
    this.googleAdapterVerified = false,
    this.openFreeMapAdapterVerified = false,
  });
  final MapDisplayProvider display;
  final MapDataProvider addresses, routes;
  final bool googleApproved, googleAdapterVerified, openFreeMapAdapterVerified;
  static const legacyRasterTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const openFreeMapStyle = 'https://tiles.openfreemap.org/styles/liberty';

  void requireDisplayAvailable() {
    switch (display) {
      case MapDisplayProvider.legacyRaster: return;
      case MapDisplayProvider.openFreeMap:
        if (!openFreeMapAdapterVerified) throw StateError('vector_map_adapter_unavailable');
        return;
      case MapDisplayProvider.googleSdk:
        requireDataAvailable(MapDataProvider.google);
    }
  }
  void requireDataAvailable(MapDataProvider provider) {
    if (provider == MapDataProvider.google &&
        (!googleApproved || !googleAdapterVerified)) {
      throw StateError('google_maps_not_approved_or_verified');
    }
  }
  // Never choose Google in response to quota exhaustion or a network failure.
  MapDataProvider providerForFailure(MapDataProvider requested) => requested;
}
