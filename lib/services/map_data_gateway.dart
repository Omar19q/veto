import 'map_provider_policy.dart';

typedef MapBackendCall = Future<dynamic> Function(Map<String, dynamic> request);

/// One server request shape for address/route services. Future Google adapter
/// must be registered after approval; unavailable adapters fail explicitly.
/// Renderer adapters are separate: OpenFreeMap's vector style is not a raster URL.
class MapDataGateway {
  MapDataGateway({required MapBackendCall geoapify,
    MapBackendCall? google, this.policy = const MapProviderPolicy()})
      : _adapters = {MapDataProvider.geoapify: geoapify,
          if (google != null) MapDataProvider.google: google};
  final MapProviderPolicy policy;
  final Map<MapDataProvider, MapBackendCall> _adapters;
  Future<dynamic> call(Map<String, dynamic> request) {
    final operation = request['operation'];
    if (!const ['search', 'reverse', 'route'].contains(operation)) {
      throw ArgumentError('unsupported_map_operation');
    }
    final provider = operation == 'route' ? policy.routes : policy.addresses;
    policy.requireDataAvailable(provider);
    final adapter = _adapters[provider];
    if (adapter == null) throw StateError('map_adapter_unavailable');
    // No catch-and-switch: auth errors, quota failures and provider errors remain
    // failures. Existing manual-address fallback remains available in the UI.
    return adapter(Map<String, dynamic>.unmodifiable(request));
  }
}
