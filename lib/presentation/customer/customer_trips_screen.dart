import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/strings.dart';
import '../../routes/app_routes.dart';
import '../../services/ride_categories.dart';
import '../../services/supabase_service.dart';
import 'customer_trip_details_v46.dart';

class CustomerTripsScreen extends StatefulWidget {
  const CustomerTripsScreen({super.key});

  @override
  State<CustomerTripsScreen> createState() => _CustomerTripsScreenState();
}

class _CustomerTripsScreenState extends State<CustomerTripsScreen> {
  List<Map<String, dynamic>> _trips = [];
  List<Map<String, dynamic>> _marketOrders = [];
  bool _isLoading = true;
  bool _loadFailed = false;
  int _loadRevision = 0;
  String? _accountId;
  StreamSubscription? _authSubscription;

  @override
  void initState() {
    super.initState();
    _accountId = SupabaseService.instance.currentUser?.id;
    _authSubscription = SupabaseService.instance.client.auth.onAuthStateChange
        .listen((_) {
          final next = SupabaseService.instance.currentUser?.id;
          if (!mounted || next == _accountId) return;
          _loadRevision++;
          setState(() {
            _accountId = next;
            _trips = [];
            _marketOrders = [];
            _isLoading = true;
            _loadFailed = false;
          });
          unawaited(_load());
        });
    unawaited(_load());
  }

  @override
  void dispose() {
    _loadRevision++;
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final revision = ++_loadRevision;
    final userId = SupabaseService.instance.currentUser?.id;
    bool ownsRead() =>
        mounted &&
        revision == _loadRevision &&
        SupabaseService.instance.currentUser?.id == userId;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadFailed = false;
      });
    }
    try {
      final svc = SupabaseService.instance;
      if (userId == null) throw StateError('authentication_required');
      final customer = await svc.getCustomerByUserId(userId);
      if (!ownsRead()) return;
      if (customer == null) throw StateError('customer_profile_missing');
      final cid = customer['id'] as String;
      final trips = await svc.getCustomerTrips(cid);
      final orders = await svc.getMarketOrders(customerId: cid);
      if (ownsRead()) {
        setState(() {
          _trips = trips;
          _marketOrders = orders;
          _isLoading = false;
        });
      }
    } catch (error) {
      debugPrint('Customer order history read failed: ${error.runtimeType}');
      if (ownsRead()) {
        setState(() {
          _isLoading = false;
          _loadFailed = true;
        });
      }
    }
  }

  String _statusLabel(String status) {
    final labels = {
      'requested': context.strings.history6d43782b,
      'offer_received': context.strings.history0791d4ac,
      'accepted': context.strings.historyf5fde9cb,
      'arriving': context.strings.history2de6d001,
      'arrived': context.strings.history39ac9d30,
      'started': context.strings.history888bd5a4,
      'completed': context.strings.historyf1d6d15f,
      'cancelled': context.strings.historyd87ae61b,
      'pending': context.strings.history62853165,
      'confirmed': context.strings.history1318e3f2,
      'preparing': context.strings.history06f3d61f,
      'delivered': context.strings.history5f7b65d5,
    };
    return labels[status] ?? status;
  }

  String _serviceLabel(String service) {
    final labels = {
      'car_ride': context.strings.history285fe647,
      'motorcycle_ride': context.strings.history13b46160,
      'package': context.strings.history040fc12a,
      'vito_market': context.strings.history91392c59,
    };
    return labels[service] ?? service;
  }

  Future<void> _showCustomerTripInvoice(Map<String, dynamic> trip) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: .87,
        child: CustomerTripDetailsV46(trip: trip),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: Directionality.of(context),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  context.strings.historyc951ef09,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : _loadFailed
                    ? Center(
                        child: TextButton.icon(
                          onPressed: _load,
                          icon: Icon(Icons.refresh),
                          label: Text(context.strings.historyLoadFailed),
                        ),
                      )
                    : (_trips.isEmpty && _marketOrders.isEmpty)
                    ? Center(
                        child: Text(
                          context.strings.historyb5fae2e2,
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (_trips.isNotEmpty) ...[
                            Text(
                              context.strings.history22a82a2c,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._trips.map(
                              (t) => Column(
                                children: [
                                  GestureDetector(
                                    onTap: () => _showCustomerTripInvoice(t),
                                    child: _TripCard(
                                      trip: t,
                                      statusLabel: _statusLabel,
                                      serviceLabel: _serviceLabel,
                                    ),
                                  ),
                                  if (const {
                                    'cancelled',
                                    'completed',
                                  }.contains(t['trip_status']?.toString()))
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 14,
                                      ),
                                      child: OutlinedButton.icon(
                                        onPressed: () => context.push(
                                          '${AppRoutes.tripBookingScreen}?retryTripId=${t['id']}',
                                        ),
                                        icon: const Icon(Icons.repeat_rounded),
                                        label: Text(
                                          context.strings.history452d2aff,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                          if (_marketOrders.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              context.strings.historyaf4b3178,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._marketOrders.map(
                              (o) => _OrderCard(
                                order: o,
                                statusLabel: _statusLabel,
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final String Function(String) statusLabel;
  final String Function(String) serviceLabel;

  const _TripCard({
    required this.trip,
    required this.statusLabel,
    required this.serviceLabel,
  });

  @override
  Widget build(BuildContext context) {
    final status = trip['trip_status'] as String? ?? '';
    final service = trip['service_type'] as String? ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                tripCategoryLabel(context,trip,serviceLabel(service)),
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withAlpha(31),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel(status),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${trip['pickup_address'] ?? ''} → ${trip['destination_address'] ?? ''}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (trip['total_fare'] != null) ...[
            const SizedBox(height: 4),
            Text(
              context.strings.moneyValue('${trip['total_fare']}'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final String Function(String) statusLabel;

  const _OrderCard({required this.order, required this.statusLabel});

  @override
  Widget build(BuildContext context) {
    final status = order['order_status'] as String? ?? '';
    return GestureDetector(
      onTap: () => context.push(
        AppRoutes.vitoMarketOrderTracking,
        extra: {'orderId': order['id'] as String},
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            Icon(
              Icons.shopping_bag_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.strings.history578c9670,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    statusLabel(status),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              order['total_amount'] is num
                  ? context.strings.moneyValue(
                      (order['total_amount'] as num).toStringAsFixed(2),
                    )
                  : context.strings.historyAmountUnavailable,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
