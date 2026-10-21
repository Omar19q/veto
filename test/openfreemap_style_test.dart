import 'package:flutter_test/flutter_test.dart';
import 'package:vetosanya/services/openfreemap_style_service.dart';

void main() {
  final original = <String, dynamic>{
    'version': 8,
    'sources': {
      'base': {
        'type': 'vector',
        'url': 'https://tiles.openfreemap.org/planet',
        'attribution': 'OpenStreetMap',
      },
    },
    'layers': [
      {
        'id': 'roads',
        'type': 'line',
        'source': 'base',
        'paint': {'line-color': '#fff', 'line-width': 3},
      },
      {
        'id': 'labels',
        'type': 'symbol',
        'source': 'base',
        'layout': {'text-field': '{name}'},
        'paint': {'text-color': '#111', 'text-halo-color': '#fff'},
      },
    ],
  };
  test(
    'Dark map changes rendering only, preserving sources widths and original input',
    () {
      final result = OpenFreeMapStyleService.transform(
        original,
        dark: true,
        language: 'en',
      );
      expect(result['sources'], original['sources']);
      expect(result['layers'][0]['paint']['line-width'], 3);
      expect(result['layers'][0]['paint']['line-color'], '#65768B');
      expect(original['layers'][0]['paint']['line-color'], '#fff');
      expect(result['layers'][1]['layout']['text-field'][1], [
        'get',
        'name:en',
      ]);
    },
  );
  test(
    'Light Arabic labels prefer available Arabic fields without translating names',
    () {
      final result = OpenFreeMapStyleService.transform(
        original,
        dark: false,
        language: 'ar',
      );
      expect(result['layers'][0]['paint'], original['layers'][0]['paint']);
      expect(result['layers'][1]['layout']['text-field'], [
        'coalesce',
        ['get', 'name:ar'],
        ['get', 'name:nonlatin'],
        ['get', 'name'],
      ]);
    },
  );
}
