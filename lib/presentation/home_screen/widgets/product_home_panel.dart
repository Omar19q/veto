import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../../../l10n/strings.dart';
import '../../../services/booking_address_seed.dart';
import '../../../services/booking_performance.dart';
import '../../../services/supabase_service.dart';

class ProductHomePanel extends StatefulWidget {
  const ProductHomePanel({
    super.key,
    required this.customerId,
    required this.pickupCaption,
    required this.onStart,
    required this.onMarket,
    this.loadAddresses,
    this.loadRecentTrips,
    this.suggestedPickup,
  });
  final String? customerId;
  final String pickupCaption;
  final void Function(BookingAddressSelection selection, String? service)
  onStart;
  final VoidCallback onMarket;
  final BookingAddressSeed? suggestedPickup;
  final Future<List<Map<String, dynamic>>> Function(
    String customerId,
  )? loadAddresses,
      loadRecentTrips;
  @override
  State<ProductHomePanel> createState() => _ProductHomePanelState();
}

class _ProductHomePanelState extends State<ProductHomePanel> {
  BookingAddressSeed? _pickup;
  String? _service;
  bool _loading = true;
  bool _failed = false;
  bool _pickupChosen = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ProductHomePanel old) {
    super.didUpdateWidget(old);
    if (old.customerId != widget.customerId) {
      _pickup = null;
      _pickupChosen = false;
      _loading = widget.customerId != null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    final id = widget.customerId;
    if (id == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        widget.loadAddresses?.call(id) ??
            SupabaseService.instance.getCustomerAddresses(id),
        widget.loadRecentTrips?.call(id) ??
            SupabaseService.instance.getCustomerTrips(id, limit: 12),
      ]).timeout(const Duration(seconds: 8));
      if (!mounted || id != widget.customerId) return;
      final saved = results[0]
          .map(BookingAddressSeed.saved)
          .whereType<BookingAddressSeed>()
          .toList();
      if (!mounted || id != widget.customerId) return;
      setState(() {
        _pickup = saved.where((a) => a.defaultPickup).firstOrNull;
        _loading = false;
        _failed = false;
      });
      // A local platform read must never hold the booking UI in loading state.
      unawaited(_restorePickup(id, saved));
    } catch (_) {
      if (mounted && id == widget.customerId)
        setState(() {
          _loading = false;
          _failed = true;
        });
    }
  }

  Future<void> _restorePickup(
    String account,
    List<BookingAddressSeed> saved,
  ) async {
    try {
      final choice = (await SharedPreferences.getInstance()).getString(
        'veto_pickup_$account',
      );
      if (!mounted || account != widget.customerId || _pickupChosen) return;
      final stored = saved
          .where((a) => '${a.latitude},${a.longitude}' == choice)
          .firstOrNull;
      if (stored != null) setState(() => _pickup = stored);
    } catch (_) {
      /* Optional convenience only. */
    }
  }

  void _start([BookingAddressSeed? destination]) => widget.onStart(
    BookingAddressSelection(
      pickup: _pickup ?? (_pickupChosen ? null : widget.suggestedPickup),
      destination: destination,
      attempt: BookingPerformanceAttempt(),
    ),
    _service,
  );
  @override
  Widget build(BuildContext context) {
    final l = context.strings;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final scale = MediaQuery.textScalerOf(context).scale(14);
    final compactLabels = scale <= 19;
    final pickupName = _pickup?.label ?? widget.pickupCaption;
    final services = <({String id, String label})>[
      (id: 'car', label: l.car),
      (id: 'motorcycle', label: l.motorcycle),
      (id: 'package', label: l.delivery),
      (id: 'market', label: l.market),
    ];

    // Only the two actions needed to start booking are permanently visible.
    // Destinations and saved places are accessible inside the booking flow.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _start(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.person_pin_circle_outlined, size: 24),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.pickup, style: theme.textTheme.labelSmall),
                        Text(
                          pickupName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_location_alt_outlined, size: 22),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: () => _start(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_rounded, size: 21),
                const SizedBox(width: 8),
                Text(
                  l.whereTo,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF111827),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 58 + MediaQuery.textScalerOf(context).scale(14) * 2.5,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < services.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: services[i].label,
                    child: Material(
                      color: _service == services[i].id
                          ? colors.primaryContainer
                          : colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(13),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(13),
                        onTap: () {
                          if (services[i].id == 'market') {
                            widget.onMarket();
                          } else {
                            setState(() => _service = services[i].id);
                            _start();
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 7,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/vehicles/${const {'car': 'veto_economy', 'motorcycle': 'veto_moto', 'package': 'veto_parcel', 'market': 'veto_market'}[services[i].id]}.webp',
                                width: 54,
                                height: 36,
                                fit: BoxFit.contain,
                                cacheWidth: 128,
                                semanticLabel: services[i].label,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                services[i].label,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: compactLabels ? 12 : null,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_failed)
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(l.retry),
          ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
      ],
    );
  }
}
