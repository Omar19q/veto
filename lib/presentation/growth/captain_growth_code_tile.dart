import 'dart:async';
import 'package:flutter/material.dart';
import '../../l10n/strings.dart';
import '../../services/growth_service.dart';
import 'growth_screens.dart';

/// Shows only the code returned for the authenticated captain. No sample or
/// locally generated badge number is shown while the server is unavailable.
class CaptainGrowthCodeTile extends StatefulWidget {
  const CaptainGrowthCodeTile({super.key, required this.accountId, this.service});
  final String accountId;
  final GrowthService? service;
  @override
  State<CaptainGrowthCodeTile> createState() => _CaptainGrowthCodeTileState();
}

class _CaptainGrowthCodeTileState extends State<CaptainGrowthCodeTile> {
  int revision = 0;
  String? code;
  bool failed = false, loading = false;
  bool capacityPending = false;
  bool unavailable = false;
  Map<String, dynamic>? metrics;
  bool metricsFailed = false;
  @override
  void initState() { super.initState(); load(); }
  @override
  void didUpdateWidget(covariant CaptainGrowthCodeTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId) {
      revision++; code = null; metrics = null; metricsFailed = false; failed = false; capacityPending = false; unavailable = false; load();
    }
  }
  Future<void> load() async {
    final current = ++revision;
    if (widget.accountId.isEmpty) return;
    setState(() { loading = true; failed = false; metricsFailed = false; capacityPending = false; });
    try {
      final data = await (widget.service ?? GrowthService()).profile(captain: true);
      if (!mounted || current != revision) return;
      final value = data['code']?.toString();
      if (data['enabled'] == true &&
          (value == null || !RegExp(r'^\d{4,19}$').hasMatch(value) ||
           BigInt.parse(value) < BigInt.from(1001))) {
        throw StateError('invalid_captain_referral_code');
      }
      setState(() {
        final fromServer = value;
        code = fromServer != null && RegExp(r'^\d{4,19}$').hasMatch(fromServer)
          ? fromServer : null;
        capacityPending = data['reason'] == 'captain_code_capacity_exhausted';
        unavailable = data['enabled'] != true && !capacityPending;
        loading = false;
      });
      if (data['enabled'] == true) unawaited(_loadMetrics(current));
    } catch (error) {
      debugPrint('Captain referral profile unavailable: ${error.runtimeType}');
      if (mounted && current == revision) {
        setState(() { code = null; loading = false; failed = true; });
      }
    }
  }
  Future<void> _loadMetrics(int current) async {
    try {
      final data = await (widget.service ?? GrowthService()).referralBreakdown(captain: true);
      if (mounted && current == revision) setState(() => metrics = data);
    } catch (_) {
      if (mounted && current == revision) setState(() => metricsFailed = true);
    }
  }
  String _num(String key) => '${metrics?[key] ?? '—'}';
  void _openDetails() => Navigator.push(context,
    MaterialPageRoute(builder: (_) => const GrowthReferralScreen(captain: true)));

  @override
  Widget build(BuildContext context) {
    if (widget.accountId.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.qr_code_2_rounded, color: scheme.primary, size: 30),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.strings.captainBadgeTitle, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              Text(code == null ? (loading ? context.strings.captainCodeLoading : failed ? context.strings.captainCodeFailed :
                capacityPending ? context.strings.captainCodePending : context.strings.captainCodeUnavailable) : code!,
                style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
            ])),
            IconButton(tooltip:context.strings.captainCodeRefresh, onPressed: loading ? null : load,
              icon: const Icon(Icons.refresh)),
          ]),
          const SizedBox(height: 12),
          if (loading) const LinearProgressIndicator(),
          if (metrics != null) ...[
            Wrap(spacing: 9, runSpacing: 9, children: [
              _metric(context.strings.referralRegistrations, _num('registrations')),
              _metric(context.strings.referralQualified, _num('qualified')),
              _metric(context.strings.referralPending, _num('pending')),
              _metric(context.strings.referralDue, _num('due')),
              _metric(context.strings.referralPaid, _num('paid')),
            ]),
            const SizedBox(height: 8),
            Text(metrics?['badge_activated'] == true ? context.strings.badgeActive : context.strings.badgePending,
              style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)),
            Text(context.strings.badgeTeam(metrics?['team_code']?.toString() ?? context.strings.noLinkedTeam),
              style: TextStyle(color: scheme.onSurfaceVariant)),
          ] else if (metricsFailed && !loading) ...[
            Text(context.strings.badgeMetricsUnavailable),
          ],
          const SizedBox(height: 10),
          FilledButton.icon(onPressed: code == null ? null : () => GrowthBadgeScreen.open(
              context, code!, widget.service ?? GrowthService()),
            icon: const Icon(Icons.print_outlined),
            label: Text(context.strings.badgePrintAction)),
          TextButton.icon(onPressed: code == null ? null : _openDetails,
            icon: const Icon(Icons.bar_chart_rounded), label: Text(context.strings.badgeDetailsAction)),
          const SizedBox(height: 6),
          Text(context.strings.badgeMetricsSource,
            style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    );
  }

  Widget _metric(String title, String value) => Container(
    constraints: const BoxConstraints(minWidth: 126),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
      Text(title, style: const TextStyle(fontSize: 12)),
    ]),
  );
}
