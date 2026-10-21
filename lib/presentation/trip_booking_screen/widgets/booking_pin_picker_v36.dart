import 'dart:async';
import '../../../widgets/openfreemap_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../l10n/strings.dart';
import '../../../services/product_geocoding_service.dart';

/// Existing LatLng result contract retained; adds a customer-confirmed address.
class BookingPinPickerV36 extends StatefulWidget {
  const BookingPinPickerV36({
    super.key,
    this.initialLat,
    this.initialLng,
    this.isDestination = false,
  });
  final double? initialLat, initialLng;
  final bool isDestination;
  @override
  State<BookingPinPickerV36> createState() => _BookingPinPickerV36State();
}

class _BookingPinPickerV36State extends State<BookingPinPickerV36> {
  LatLng? _point;
  final _description = TextEditingController();
  final _geo = ProductGeocodingService();
  Timer? _debounce;
  int _revision = 0;
  bool _loading = false;
  bool get _canConfirm => _point != null && !_loading &&
      (_suggested != null || _description.text.trim().isNotEmpty);
  String? _suggested;
  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null &&
        widget.initialLng != null &&
        widget.initialLat!.isFinite &&
        widget.initialLng!.isFinite &&
        widget.initialLat!.abs() <= 90 &&
        widget.initialLng!.abs() <= 180) {
      _point = LatLng(widget.initialLat!, widget.initialLng!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _select(_point!);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _description.dispose();
    super.dispose();
  }

  void _select(LatLng point) {
    final revision = ++_revision;
    _debounce?.cancel();
    setState(() {
      _point = point;
      _suggested = null;
      _loading = true;
    });
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      String? suggested;
      try {
        suggested = (await _geo.reverse(
          point.latitude,
          point.longitude,
          language: Localizations.localeOf(context).languageCode,
        ))?.address;
      } catch (_) {
        /* Keep the confirmed pin and editable description, never invent a street. */
      }
      if (!mounted || revision != _revision) return;
      setState(() {
        _loading = false;
        _suggested = suggested;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.strings, colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isDestination ? l.chooseDestination : l.choosePickup,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: OpenFreeMapSurface.enabled
                ? OpenFreeMapSurface(
                    center: _point ?? const LatLng(29.9792, 31.1342),
                    points: [if (_point != null) _point!],
                    onTap: _select,
                  )
                : FlutterMap(
                    options: MapOptions(
                      initialCenter: _point ?? const LatLng(29.986, 31.137),
                      initialZoom: 15,
                      onTap: (_, p) => _select(p),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.vetosanya.app',
                      ),
                      if (_point != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _point!,
                              width: 48,
                              height: 54,
                              child: Icon(
                                widget.isDestination
                                    ? Icons.flag_rounded
                                    : Icons.person_pin_circle_rounded,
                                size: 38,
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                      const RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution('© OpenStreetMap contributors'),
                        ],
                      ),
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                12 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_loading) const LinearProgressIndicator(),
                  Text(
                    _suggested ?? 'مش لقينا اسم واضح. وصف المكان هيساعد الكابتن يوصلك.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _description,
                    maxLength: 200,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'وصف المكان',
                      hintText: 'مثال: عمارة 12 بجوار المسجد',
                    ),
                  ),
                  FilledButton(
                    onPressed: !_canConfirm
                        ? null
                        : () {
                            final label = _description.text.trim().isNotEmpty
                                ? _description.text.trim()
                                : _suggested ?? l.locationUnconfirmed;
                            Navigator.pop(
                              context,
                              ConfirmedMapPoint(
                                _point!.latitude,
                                _point!.longitude,
                                label,
                              ),
                            );
                          },
                    child: Text(widget.isDestination
                        ? 'تأكيد الوجهة' : 'تأكيد مكان الركوب'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
