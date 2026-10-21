import 'dart:async';
import 'package:flutter/material.dart';

import '../../services/captain_market_assignment_backend.dart';
import '../../l10n/strings.dart';
import '../../theme/app_theme.dart';
import 'captain_market_order_screen.dart';

/// Compatibility screen for older routes. Market tasks are assigned directly;
/// captains no longer accept or reject an offer.
class CaptainMarketJobsScreen extends StatefulWidget {
  final CaptainMarketAssignmentBackend? backend;
  const CaptainMarketJobsScreen({super.key, this.backend});

  @override
  State<CaptainMarketJobsScreen> createState() =>
      _CaptainMarketJobsScreenState();
}

class _CaptainMarketJobsScreenState extends State<CaptainMarketJobsScreen> {
  bool _loading = true;
  bool _failed = false;
  int _revision = 0;
  late final CaptainMarketAssignmentBackend _backend;
  StreamSubscription<String?>? _auth;
  Map<String, dynamic>? _assignment;

  @override
  void initState() {
    super.initState();
    _backend = widget.backend ?? CaptainMarketAssignmentBackend();
    _auth = _backend.accountChanges.listen((_) {
      if (!mounted) return;
      setState(() => _assignment = null);
      unawaited(_load());
    });
    _load();
  }

  Future<void> _load() async {
    final revision = ++_revision;
    final owner = _backend.accountId;
    setState(() {
      _loading = true;
      _failed = false;
      _assignment = null;
    });
    bool current() =>
        mounted && revision == _revision && owner == _backend.accountId;
    try {
      if (owner == null) {
        if (current()) setState(() => _failed = true);
        return;
      }
      final value = await _backend.getAssignment();
      if (current()) setState(() => _assignment = value);
    } catch (_) {
      if (current()) setState(() => _failed = true);
    } finally {
      if (current()) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _revision++;
    _auth?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = _assignment?['order'];
    final orderId = order is Map ? order['id']?.toString() : null;
    return Directionality(
      textDirection: Directionality.of(context),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(context.strings.captainAssignmentTitle),
          actions: [
            IconButton(
              onPressed: _loading ? null : _load,
              tooltip: context.strings.captainAssignmentRefresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.gold),
              )
            : _failed
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.strings.captainMarketLoadFailed,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _load,
                        child: Text(context.strings.captainAssignmentRefresh),
                      ),
                    ],
                  ),
                ),
              )
            : orderId == null || orderId.isEmpty
            ? Center(
                child: Text(
                  context.strings.captainAssignmentEmpty,
                  style: TextStyle(
                    
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : Center(
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          CaptainMarketOrderScreen(orderId: orderId),
                    ),
                  ),
                  icon: const Icon(Icons.delivery_dining_rounded),
                  label: Text(context.strings.captainAssignmentOpen),
                ),
              ),
      ),
    );
  }
}
