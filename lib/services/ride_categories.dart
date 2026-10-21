import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

bool categoryArabic(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ar';

const rideCategoryIds = {
  'veto_economy',
  'veto_comfort',
  'veto_premium',
  'veto_ladies',
  'veto_moto',
  'veto_parcel',
};

String? restoredRideCategory(dynamic value) =>
    value is String && rideCategoryIds.contains(value) ? value : null;

Set<String> restoredTripPromises(dynamic value) => value is List
    ? value
          .whereType<String>()
          .where(
            (id) => const {
              'quiet',
              'no_music',
              'ac',
              'child',
              'baggage',
              'child_seat',
            }.contains(id),
          )
          .toSet()
    : <String>{};
String categoryCopy(BuildContext context, String ar, String en) =>
    categoryArabic(context) ? ar : en;

String tripCategoryLabel(
  BuildContext context,
  Map<String, dynamic> trip,
  String fallback,
) {
  final snapshot = trip['pricing_snapshot'];
  if (snapshot is Map) {
    final config = snapshot['category_config_v3'];
    if (config is Map) {
      final text = config[categoryArabic(context) ? 'name_ar' : 'name_en'];
      if (text is String && text.trim().isNotEmpty) return text;
    }
  }
  return fallback;
}

class RideCategory {
  const RideCategory(this.row);
  final Map<String, dynamic> row;
  String get id => row['id'] as String;
  String get service => row['base_service'] as String;
  bool get enabled => row['enabled'] == true;
  bool get authorized => row['authorized'] == true;
  Color get accent => Color(
    int.tryParse(
          'FF${(row['accent'] ?? '#FFC247').toString().replaceFirst('#', '')}',
          radix: 16,
        ) ??
        0xFFFFC247,
  );
  String name(BuildContext context) =>
      '${row[categoryArabic(context) ? 'name_ar' : 'name_en']}';
  String description(BuildContext context) =>
      '${row[categoryArabic(context) ? 'description_ar' : 'description_en'] ?? ''}';
  String get asset => 'assets/vehicles/$id.webp';
  String get legacyService => switch (service) {
    'motorcycle_ride' => 'motorcycle',
    'package' => 'package',
    'vito_market' => 'market',
    _ => 'car',
  };
}

class RideCategories {
  RideCategories._();
  static final instance = RideCategories._();
  SupabaseClient get db => SupabaseService.instance.client;
  Future<Map<String, dynamic>> catalog() async {
    try {
      final data = await db.rpc('v3_category_catalog');
      return Map<String, dynamic>.from(data as Map? ?? {});
    } on PostgrestException catch (e) {
      // Existing Production stays usable until the additive backend is deployed.
      if (e.code == 'PGRST202' || e.code == '42883') return {};
      rethrow;
    }
  }

  Future<List<RideCategory>> mine() async =>
      ((await db.rpc('v3_my_categories')) as List)
          .map((e) => RideCategory(Map<String, dynamic>.from(e)))
          .toList();
  Future<Map<String, dynamic>> admin() async =>
      Map<String, dynamic>.from(await db.rpc('v3_admin_category_data') as Map);
  Future<void> save(String entity, Map<String, dynamic> value) async {
    await db.rpc(
      'v3_admin_save',
      params: {'p_entity': entity, 'p_value': value},
    );
  }
}

/// Accept local digit keyboards; never calculate or authorize a fare here.
num? parseCategoryNumber(String raw) {
  final digits = String.fromCharCodes(
    raw.trim().runes.map(
      (c) => c >= 0x0660 && c <= 0x0669
          ? c - 0x0660 + 0x30
          : c >= 0x06f0 && c <= 0x06f9
          ? c - 0x06f0 + 0x30
          : c,
    ),
  );
  final normalized = digits.replaceAll('٫', '.').replaceAll(',', '.');
  return num.tryParse(normalized);
}
