import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Owner's verified-point picker. Does not add an address or modify boundaries.
/// Coordinates are chosen by tapping the map (not guessed from a city name).
class AdminPlacePinPickerV39 extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final bool requireFreshTap;
  const AdminPlacePinPickerV39({super.key, this.initialLat, this.initialLng, this.requireFreshTap=false});
  @override
  State<AdminPlacePinPickerV39> createState() => _AdminPlacePinPickerV39State();
}

class _AdminPlacePinPickerV39State extends State<AdminPlacePinPickerV39> {
  LatLng? selected;
  bool tapped=false;
  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      selected = LatLng(widget.initialLat!, widget.initialLng!);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('حدد المكان على الخريطة',
        style: TextStyle(fontFamily: 'Cairo'))),
      body: Stack(children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: selected ?? const LatLng(30.0444, 31.2357),
            initialZoom: selected == null ? 10 : 16,
            onTap: (_, point) => setState(() {selected = point; tapped=true;}),
          ),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.vetosanya.app'),
            if (selected != null) MarkerLayer(markers: [
              Marker(point: selected!, width: 56, height: 60,
                child: const Icon(Icons.location_pin, color: Color(0xFFEFAC00), size: 48)),
            ]),
          ],
        ),
        Positioned(top: 12, left: 12, right: 12,
          child: Card(child: Padding(padding: const EdgeInsets.all(12),
            child: Text(selected == null || (widget.requireFreshTap && !tapped)
                ? 'اضغط على نقطة المكان الدقيقة قبل الاعتماد'
                : 'راجع النقطة على الخريطة قبل الحفظ',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Cairo'))))),
        Positioned(bottom: 18, left: 18, right: 18,
          child: SafeArea(top: false, child: FilledButton.icon(
            onPressed: selected == null || (widget.requireFreshTap && !tapped)
              ? null : () => Navigator.pop(context, selected),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('اعتماد النقطة', style: TextStyle(fontFamily: 'Cairo')),
          ))),
      ]),
    ),
  );
}
