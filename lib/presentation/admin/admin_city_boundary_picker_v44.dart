import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Draft polygon editor. Never activates a city or changes live pricing.
/// Coordinates are collected by tapping a real map, not fabricated from a name.
class AdminCityBoundaryPickerV44 extends StatefulWidget {
  final String cityName;
  final Map<String, dynamic>? existing;
  const AdminCityBoundaryPickerV44({super.key, required this.cityName, this.existing});

  @override
  State<AdminCityBoundaryPickerV44> createState() => _AdminCityBoundaryPickerV44State();
}

class _AdminCityBoundaryPickerV44State extends State<AdminCityBoundaryPickerV44> {
  final List<LatLng> _vertices = [];
  bool _redrawing = false;
  bool _originalIsMulti = false;

  @override
  void initState() {
    super.initState();
    final raw = widget.existing;
    _originalIsMulti = raw?['type'] == 'MultiPolygon';
    final coordinates = raw?['coordinates'];
    try {
      if (coordinates is List && coordinates.isNotEmpty) {
        final rings = _originalIsMulti ? (coordinates.first as List) : coordinates;
        final ring = (rings).first as List;
        for (final pair in ring) {
          if (pair is List && pair.length >= 2 && pair[0] is num && pair[1] is num) {
            _vertices.add(LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble()));
          }
        }
        if (_vertices.length > 1 && _vertices.first == _vertices.last) _vertices.removeLast();
      }
    } catch (_) { _vertices.clear(); }
  }

  void _tap(LatLng point) {
    if (_originalIsMulti && !_redrawing) return;
    if (_vertices.length >= 100) return;
    setState(() => _vertices.add(point));
  }

  void _confirm() {
    if (_originalIsMulti && !_redrawing) {
      Navigator.pop(context, widget.existing);
      return;
    }
    if (_vertices.length < 3) return;
    final ring = <List<double>>[
      for (final p in _vertices) [p.longitude, p.latitude],
      [_vertices.first.longitude, _vertices.first.latitude],
    ];
    Navigator.pop(context, {'type': 'Polygon', 'coordinates': [ring]});
  }

  @override
  Widget build(BuildContext context) {
    final center = _vertices.isNotEmpty ? _vertices.first : const LatLng(30.0444, 31.2357);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text('حدود ${widget.cityName}', style: const TextStyle(fontFamily: 'Cairo'))),
        body: Column(children: [
          Container(padding: const EdgeInsets.all(10), width: double.infinity,
            color: const Color(0xFF182438), child: Text(
              _originalIsMulti && !_redrawing
                ? 'المدينة متعددة الحدود. راجعها، أو اختر رسم جديد لاستبدالها بالكامل.'
                : 'اضغط على الخريطة حول حدود المدينة. 3 نقاط على الأقل، ثم اعتماد الرسم للمراجعة.',
              style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'))),
          Expanded(child: FlutterMap(
            options: MapOptions(initialCenter: center, initialZoom: _vertices.isEmpty ? 10 : 12,
              onTap: (_, point) => _tap(point)),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.vetosanya.app'),
              if (_vertices.length >= 3) PolygonLayer(polygons: [
                Polygon(points: _vertices, color: const Color(0x4499B300),
                  borderColor: const Color(0xFFB88D00), borderStrokeWidth: 3),
              ]),
              MarkerLayer(markers: [for (var i = 0; i < _vertices.length; i++)
                Marker(point: _vertices[i], width: 28, height: 28,
                  child: CircleAvatar(backgroundColor: Colors.amber,
                    child: Text('${i+1}', style: const TextStyle(fontSize: 11, color: Colors.black))))]),
            ],
          )),
          SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(12), child: Wrap(
            spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
            if (_originalIsMulti && !_redrawing) OutlinedButton(
              onPressed: () => setState(() { _vertices.clear(); _redrawing = true; }),
              child: const Text('رسم حدود جديدة بالكامل')),
            OutlinedButton.icon(onPressed: _vertices.isEmpty ? null : () => setState(() => _vertices.removeLast()),
              icon: const Icon(Icons.undo), label: const Text('تراجع')),
            OutlinedButton.icon(onPressed: _vertices.isEmpty ? null : () => setState(() { _vertices.clear(); _redrawing = true; }),
              icon: const Icon(Icons.delete_outline), label: const Text('مسح')),
            FilledButton.icon(onPressed: _vertices.length >= 3 || (_originalIsMulti && !_redrawing) ? _confirm : null,
              icon: const Icon(Icons.check), label: Text('اعتماد الحدود (${_vertices.length})')),
          ]))),
        ]),
      ),
    );
  }
}
