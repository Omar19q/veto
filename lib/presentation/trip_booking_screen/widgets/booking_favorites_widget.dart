import '../../../l10n/strings.dart';
import 'package:flutter/material.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/app_theme.dart';

/// This reuses the existing customer_addresses table and its customer-owned RLS.
/// It does not store favorites on a device (so changing phones retains them).
class BookingFavoritesWidget extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic> place) onSelected;
  final bool allowOutsideCity;
  const BookingFavoritesWidget({super.key, required this.onSelected,
    this.allowOutsideCity = true});

  @override
  State<BookingFavoritesWidget> createState() => _BookingFavoritesWidgetState();
}

class _BookingFavoritesWidgetState extends State<BookingFavoritesWidget> {
  bool _loading = true;
  bool _choosing = false;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = SupabaseService.instance;
      final uid = api.currentUser?.id;
      if (uid == null) throw StateError('login_required');
      final customer = await api.getCustomerByUserId(uid);
      if (customer == null) throw StateError('customer_missing');
      final addresses = await api.getCustomerAddresses(customer['id'].toString());
      if (!mounted) return;
      setState(() {
        _items = addresses.where((item) =>
          _coordinate(item['latitude']) != null &&
          _coordinate(item['longitude']) != null &&
          (widget.allowOutsideCity || item['is_outside_city'] != true)).toList();
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _error = context.strings.savedLoadFailed; });
    }
  }

  Future<void> _remove(Map<String, dynamic> item) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.strings.savedDeleteTitle, style: TextStyle()),
        content: Text(context.strings.savedDeleteDescription(item['label']?.toString() ?? ''),
          style: const TextStyle()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.strings.savedBack)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.strings.savedDelete)),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    try {
      await SupabaseService.instance.deleteCustomerAddress(item['id'].toString());
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error = context.strings.savedDeleteFailed);
    }
  }

  static double? _coordinate(dynamic raw) =>
    raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');

  @override
  Widget build(BuildContext context) {
    if (_loading) return Center(child: Padding(
      padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppTheme.gold)));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text(context.strings.savedPlacesTitle, style: TextStyle(
           color: AppTheme.textPrimary, fontSize: 16,
          fontWeight: FontWeight.w800))),
        IconButton(tooltip: context.strings.savedRefresh, onPressed: _load,
          icon: const Icon(Icons.refresh_rounded, color: AppTheme.gold)),
      ]),
      Text(context.strings.savedHelp,
        style: TextStyle( color: AppTheme.textSecondary, fontSize: 12)),
      if (_error != null) Padding(padding: const EdgeInsets.all(8),
        child: Text(_error!, style: const TextStyle( color: Colors.redAccent))),
      if (_items.isEmpty) Padding(padding: EdgeInsets.all(22),
        child: Text(context.strings.savedEmptyHelp,
          textAlign: TextAlign.center, style: TextStyle(
          color: AppTheme.textSecondary))),
      if (_items.isNotEmpty) ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.43),
        child: ListView(shrinkWrap: true, children: _items.map((item) => Card(
        color: AppTheme.surfaceVariant,
        child: ListTile(
          enabled: !_choosing,
          leading: const Icon(Icons.star_rounded, color: AppTheme.gold),
          title: Text(item['label']?.toString() ?? context.strings.savedFallbackLabel,
            style: const TextStyle( color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700)),
          subtitle: Text(item['display_address']?.toString() ?? '',
            style: const TextStyle( color: AppTheme.textSecondary)),
          trailing: IconButton(tooltip: context.strings.savedRemoveTooltip,
            onPressed: _choosing ? null : () => _remove(item),
            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.textSecondary)),
          onTap: () async {
            if (_choosing) return;
            setState(() { _choosing = true; _error = null; });
            try { await widget.onSelected(item); }
            catch (_) { if (mounted) setState(() => _error = context.strings.savedChooseFailed); }
            finally { if (mounted) setState(() => _choosing = false); }
          },
        ),
      )).toList()),
      ),
    ]);
  }
}

/// Use on a result row. The supplied coordinates must be real: no fake fallback.
Future<void> saveBookingFavorite(
  BuildContext context, {
  required String name,
  required String displayAddress,
  required double? lat,
  required double? lng,
  String? areaLetter,
  String? buildingNumber,
  bool outsideCity = false,
}) async {
  if (lat == null || lng == null || !lat.isFinite || !lng.isFinite) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(context.strings.savedCoordinatesRequired)));
    return;
  }
  var pendingLabel = name;
  final label = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(context.strings.savedAddTitle, style: TextStyle()),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(displayAddress, style: const TextStyle( fontSize: 12)),
        const SizedBox(height: 12),
        TextFormField(initialValue: name, onChanged: (value) => pendingLabel = value,
          autofocus: true, maxLength: 60,
          style: const TextStyle(),
          decoration: InputDecoration(labelText: context.strings.savedNameHint)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.strings.savedCancel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, pendingLabel.trim()), child: Text(context.strings.savedSave)),
      ],
    ),
  );
  if (label == null || !context.mounted) return;
  if (label.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.strings.savedEnterLabel)));
    return;
  }
  try {
    final api = SupabaseService.instance;
    final uid = api.currentUser?.id;
    if (uid == null) throw StateError('login_required');
    final customer = await api.getCustomerByUserId(uid);
    if (customer == null) throw StateError('customer_missing');
    final id = customer['id'].toString();
    final saved = await api.getCustomerAddresses(id);
    final duplicate = saved.any((x) => x['label']?.toString().toLowerCase() == label.toLowerCase()
      && _coordEqual(x['latitude'], lat) && _coordEqual(x['longitude'], lng));
    if (duplicate) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.savedAlreadyExists)));
      return;
    }
    await api.addCustomerAddress(
      customerId: id, label: label, displayAddress: displayAddress,
      areaLetter: areaLetter, buildingNumber: buildingNumber,
      latitude: lat, longitude: lng, isOutsideCity: outsideCity,
    );
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.strings.savedAdded)));
  } catch (_) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.strings.savedAddFailed)));
  }
}

bool _coordEqual(dynamic a, double b) {
  final n = a is num ? a.toDouble() : double.tryParse(a?.toString() ?? '');
  return n != null && (n - b).abs() < .0000001;
}
