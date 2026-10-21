import 'package:flutter/material.dart';

import 'admin_buildings_panel.dart';
import 'admin_famous_places_panel.dart';
import 'admin_city_catalog_v37.dart';

/// One entry point for the existing building/place modules.
/// Hadayek remains completely untouched; other-city records are reviewed
/// offline until their verified geometry and actual pricing are approved.
enum AdminLocationKind { buildings, places }

class AdminLocationHubV38 extends StatefulWidget {
  final AdminLocationKind kind;
  final bool showCityDrafts;
  const AdminLocationHubV38({super.key, required this.kind, this.showCityDrafts = false});

  @override
  State<AdminLocationHubV38> createState() => _AdminLocationHubV38State();
}

class _AdminLocationHubV38State extends State<AdminLocationHubV38> {
  bool _otherCities = false;

  @override
  Widget build(BuildContext context) => Column(children: [
    if (widget.showCityDrafts)
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: SegmentedButton<bool>(
          segments: [
            const ButtonSegment(value: false, label: Text('حدائق الأهرام'), icon: Icon(Icons.home_work_outlined)),
            ButtonSegment(value: true,
              label: Text(widget.kind == AdminLocationKind.buildings ? 'عمارات المدن' : 'أماكن المدن'),
              icon: const Icon(Icons.location_city_outlined)),
          ],
          selected: {_otherCities},
          onSelectionChanged: (choice) => setState(() => _otherCities = choice.first),
        ),
      ),
    Expanded(
      child: _otherCities && widget.showCityDrafts
        ? AdminCityCatalogV37(kind: widget.kind == AdminLocationKind.buildings ? 'building' : 'landmark')
        : widget.kind == AdminLocationKind.buildings
          ? const AdminBuildingsPanel()
          : const AdminFamousPlacesPanel(),
    ),
  ]);
}
