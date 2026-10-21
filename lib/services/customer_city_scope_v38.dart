/// Presentation-only choice. Never changes pricing, the device GPS, or the
/// pickup/destination coordinates sent to Supabase.
class CustomerCityScopeV38 {
  static String? _name;
  static bool _manual = false;

  static String? get name => _name;
  static bool get hasChoice => _name != null && _name!.isNotEmpty;
  static bool isHadayekName(String? name) {
    final normalized = (name ?? '').toLowerCase()
        .replaceAll('أ','ا').replaceAll('إ','ا').replaceAll('آ','ا');
    return (normalized.contains('حدائق') || normalized.contains('حدايق'))
        && normalized.contains('الاهرام');
  }
  static bool get isHadayek => isHadayekName(_name);

  static void choose(String name) {
    _name = name;
    _manual = true;
  }

  static void resolved(String? name) {
    if (!_manual) _name = name;
  }

  static void resetToGps() {
    _manual = false;
    _name = null;
  }
}
