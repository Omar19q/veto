import 'dart:convert';
import 'package:dio/dio.dart';
import 'map_provider_policy.dart';

/// Only display styling: geometry, source URLs, attribution and road widths are
/// unchanged. Data labels prefer available language fields, never translations.
class OpenFreeMapStyleService {
  static final instance = OpenFreeMapStyleService();
  final _client = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );
  Map<String, dynamic>? _base;
  Future<String> style({required bool dark, required String language}) async {
    _base ??= Map<String, dynamic>.from(
      (await _client.get(MapProviderPolicy.openFreeMapStyle)).data as Map,
    );
    return jsonEncode(transform(_base!, dark: dark, language: language));
  }

  static Map<String, dynamic> transform(
    Map<String, dynamic> input, {
    required bool dark,
    required String language,
  }) {
    final result = jsonDecode(jsonEncode(input)) as Map<String, dynamic>;
    for (final layer in (result['layers'] as List? ?? []).whereType<Map>()) {
      final layout = layer['layout'];
      if (layout is Map && layout['text-field'] != null && jsonEncode(layout['text-field']).contains('name')) {
        layout['text-field'] = [
          'coalesce',
          ['get', language == 'ar' ? 'name:ar' : 'name:en'],
          ['get', language == 'ar' ? 'name:nonlatin' : 'name:latin'],
          ['get', 'name'],
        ];
      }
      if (!dark) continue;
      final paint = layer['paint'];
      if (paint is! Map) continue;
      final source = '${layer['source-layer'] ?? ''}';
      String colour(String property) {
        if (property == 'text-halo-color') return '#111827';
        if (property == 'text-color') return '#E2E8F0';
        if (property == 'background-color') return '#111827';
        if (source.contains('water')) return '#16364A';
        if (source.contains('landcover') || source.contains('park'))
          return '#193C32';
        if (property == 'line-color') return '#65768B';
        return '#253142';
      }

      Object? replace(Object? value, String property) {
        if (value is String &&
            (RegExp(r'^#[0-9a-fA-F]{3,8}$').hasMatch(value) ||
                value.startsWith('rgba(') ||
                value.startsWith('hsl(')))
          return colour(property);
        if (value is List)
          return value.map((v) => replace(v, property)).toList();
        return value;
      }

      for (final key in paint.keys.toList()) {
        if (key is String && key.endsWith('-color'))
          paint[key] = replace(paint[key], key);
      }
    }
    return result;
  }
}
