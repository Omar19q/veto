import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../../services/market_history_backend.dart';
import '../../l10n/strings.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';

/// Only previous orders of the currently authenticated customer are queried.
/// Reorder NEVER silently substitutes unavailable products or trusts old prices.
class VitoMarketHistoryScreen extends StatefulWidget {
  final MarketHistoryBackend? backend;
  const VitoMarketHistoryScreen({super.key, this.backend});
  @override
  State<VitoMarketHistoryScreen> createState() =>
      _VitoMarketHistoryScreenState();
}

class _VitoMarketHistoryScreenState extends State<VitoMarketHistoryScreen> {
  List<Map<String, dynamic>> orders = [];
  bool loading = true, busy = false;
  bool failed = false;
  late final MarketHistoryBackend db = widget.backend ?? MarketHistoryBackend();
  String? _uid;
  int _epoch = 0, _readRevision = 0;
  StreamSubscription<String?>? _auth;
  BuildContext? _confirmationContext;
  bool _owns(String? uid, int epoch) =>
      mounted &&
      uid != null &&
      uid == _uid &&
      db.accountId == uid &&
      epoch == _epoch;
  @override
  void dispose() {
    _auth?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _uid = db.accountId;
    _auth = db.accountChanges.listen((uid) {
      if (!mounted || uid == _uid) return;
      final modal = _confirmationContext;
      if (modal != null &&
          modal.mounted &&
          ModalRoute.of(modal)?.isCurrent == true)
        Navigator.of(modal).pop(false);
      setState(() {
        _uid = uid;
        _epoch++;
        orders = [];
        busy = false;
      });
      load();
    });
    load();
  }

  Future<void> load() async {
    final uid = db.accountId, epoch = _epoch, revision = ++_readRevision;
    bool current() =>
        mounted &&
        epoch == _epoch &&
        revision == _readRevision &&
        db.accountId == uid;
    setState(() {
      loading = true;
      failed = false;
      orders = [];
    });
    try {
      if (uid == null) throw StateError('login_required');
      final customer = await db.getCustomer(uid);
      if (!current()) return;
      if (customer == null) throw StateError('customer_not_found');
      final data = await db.getOrders(customer['id'].toString());
      if (current()) setState(() => orders = data);
    } catch (_) {
      if (current()) setState(() => failed = true);
    } finally {
      if (current()) setState(() => loading = false);
    }
  }

  Future<void> reorder(Map<String, dynamic> order) async {
    final uid = db.accountId, epoch = _epoch;
    bool ownsRequest() => _owns(uid, epoch);
    if (busy || !ownsRequest()) return;
    setState(() => busy = true);
    try {
      final stores = await db.getStores();
      final selected = stores.where((s) => s['id'] == order['supermarket_id']);
      if (!ownsRequest()) return;
      if (selected.isEmpty || selected.first['is_open'] != true)
        throw StateError('store_unavailable');
      final shop = selected.first;
      final products = await db.getProducts(shop['id'].toString());
      if (!ownsRequest()) return;
      final byId = {for (final p in products) p['id'].toString(): p};
      final items = List<Map<String, dynamic>>.from(
        order['market_order_items'] as List? ?? [],
      );
      final cart = <String, Map<String, dynamic>>{};
      final missing = <String>[];
      for (final i in items) {
        final id = i['product_id'].toString(),
            requested = (i['quantity'] as num?)?.toInt() ?? 0;
        final current = byId[id];
        final stock = (current?['vm_stock_qty'] as num?)?.toInt();
        if (current == null || requested <= 0 || stock == 0) {
          missing.add(i['product_name']?.toString() ?? id);
          continue;
        }
        final qty = stock == null
            ? requested
            : (requested < stock ? requested : stock);
        if (qty < requested)
          missing.add(
            context.strings.marketHistoryStock('${i['product_name']}', '$qty'),
          );
        if (qty > 0) cart[id] = {'product': current, 'quantity': qty};
      }
      if (cart.isEmpty) throw StateError('products_unavailable');
      if (!ownsRequest()) return;
      if (missing.isNotEmpty) {
        final accept = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            _confirmationContext = ctx;
            return AlertDialog(
              title: Text(context.strings.marketHistoryPartial),
              content: SingleChildScrollView(
                child: Text(
                  context.strings.marketHistoryMissing(missing.join('\n')),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(context.strings.marketHistoryCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(context.strings.marketHistoryAccept),
                ),
              ],
            );
          },
        );
        if (accept != true) return;
      }
      if (!ownsRequest()) return;
      context.push(
        AppRoutes.vitoMarketCheckout,
        extra: {'supermarket': shop, 'cart': cart},
      );
    } catch (e) {
      if (ownsRequest())
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError && e.message == 'store_unavailable'
                  ? context.strings.marketHistoryStoreUnavailable
                  : e is StateError && e.message == 'products_unavailable'
                  ? context.strings.marketHistoryProductsUnavailable
                  : context.strings.marketHistoryReorderFailed,
            ),
          ),
        );
    } finally {
      if (ownsRequest()) setState(() => busy = false);
    }
  }

  String _statusLabel(String value) => switch (value) {
    'pending' => context.strings.history62853165,
    'confirmed' => context.strings.history1318e3f2,
    'preparing' => context.strings.history06f3d61f,
    'accepted' => context.strings.historyf5fde9cb,
    'on_the_way' => context.strings.history2de6d001,
    'delivered' => context.strings.history5f7b65d5,
    'completed' => context.strings.historyf1d6d15f,
    'cancelled' => context.strings.historyd87ae61b,
    _ => value,
  };

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: Directionality.of(context),
    child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.strings.marketHistoryTitle),
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          IconButton(
            onPressed: loading ? null : load,
            icon: Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(14),
              children: [
                if (failed)
                  Text(
                    context.strings.marketHistoryFailed,
                    style: TextStyle(color: AppTheme.gold),
                  ),
                if (!failed && orders.isEmpty)
                  Center(
                    child: Text(
                      context.strings.marketHistoryEmpty,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ...orders.map(
                  (o) => Card(
                    color: Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            context.strings.marketHistoryOrder(
                              o['id'].toString().length > 8
                                  ? o['id'].toString().substring(0, 8)
                                  : o['id'].toString(),
                              _statusLabel(o['order_status']?.toString() ?? ''),
                            ),
                            style: TextStyle(
                              color: AppTheme.gold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            context.strings.marketHistoryAmount(
                              o['total_amount']?.toString() ?? '—',
                            ),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            context.strings.marketHistoryDate(
                              o['created_at']?.toString() ?? '—',
                            ),
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: busy ? null : () => reorder(o),
                            icon: Icon(Icons.replay),
                            label: Text(context.strings.marketHistoryReorder),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    ),
  );
}
