import 'package:flutter/material.dart';

import '../../../services/supabase_service.dart';
import '../../../widgets/customer_identity_v29.dart';
import '../../../l10n/strings.dart';

/// V37 read-only loyalty teaser. The server is the single source of truth;
/// never awards credit, changes customer counters, or trusts device totals.
class HomeProgressV37 extends StatefulWidget {
  const HomeProgressV37({super.key, required this.customerId,
    this.loadProfile, this.loadReward, this.loadRank});
  final String? customerId;
  final Future<dynamic> Function()? loadProfile, loadReward, loadRank;

  @override
  State<HomeProgressV37> createState() => _HomeProgressV37State();
}

class _HomeProgressV37State extends State<HomeProgressV37> {
  Map<String, dynamic>? _profile;
  int? _rank;
  Map<String, dynamic>? _campaignV39;
  bool _loading = true;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final revision = ++_revision;
    if (widget.customerId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final response = await (widget.loadProfile?.call() ?? SupabaseService.instance.client.rpc('customer_loyalty_profile_v29'))
          .timeout(const Duration(seconds: 8));
      if (!mounted || revision != _revision) return;
      if (response is Map && response['completed_trips'] is num &&
          (response['completed_trips'] as num) >= 0) {
        setState(() => _profile = Map<String, dynamic>.from(response));
      } else { throw StateError('invalid_loyalty_profile'); }
      try {
        final result = await (widget.loadReward?.call() ?? SupabaseService.instance.client.rpc('v39_customer_reward_status'))
          .timeout(const Duration(seconds: 6));
        if (mounted && revision == _revision && result is Map) {
          setState(() => _campaignV39 = Map<String, dynamic>.from(result));
        }
      } catch (_) { /* Optional until V39 staged migration is installed. */ }
      try {
        if (!mounted || revision != _revision) return;
        final ranking = await (widget.loadRank?.call() ?? SupabaseService.instance.client.rpc('v37_customer_trip_rank'))
            .timeout(const Duration(seconds: 6));
        if (!mounted || revision != _revision) return;
        if (ranking is Map) {
          setState(() => _rank = (ranking['rank'] as num?)?.toInt());
        }
      } catch (_) {
        // Rank is optional until V37 SQL is installed.
      }
    } catch (_) {
      // A loyalty service outage must never block booking.
    } finally {
      if (mounted && revision == _revision) setState(() => _loading = false);
    }
  }

  @override
  void didUpdateWidget(covariant HomeProgressV37 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customerId != widget.customerId) {
      _profile = null;
      _rank = null;
      _campaignV39 = null;
      _loading = true;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _profile == null) return const SizedBox.shrink();
    final data = _profile!;
    final colors = Theme.of(context).colorScheme;
    final l = context.strings;
    final completed = (data['completed_trips'] as num?)?.toInt() ?? 0;
    final frames = (data['frames'] as List?) ?? const [];
    Map<String, dynamic>? current;
    int nextThreshold = 0;
    for (final raw in frames) {
      if (raw is! Map) continue;
      final frame = Map<String, dynamic>.from(raw);
      final minTrips = (frame['min_trips'] as num?)?.toInt() ?? 0;
      if (frame['key'] == data['selected_frame']) current = frame;
      if (minTrips > completed && (nextThreshold == 0 || minTrips < nextThreshold)) {
        nextThreshold = minTrips;
      }
    }
    final remaining = nextThreshold > completed ? nextThreshold - completed : 0;
    final previous = frames.whereType<Map>()
        .map((f) => (f['min_trips'] as num?)?.toInt() ?? 0)
        .where((n) => n <= completed)
        .fold<int>(0, (v, n) => n > v ? n : v);
    final progress = nextThreshold > previous
        ? ((completed - previous) / (nextThreshold - previous)).clamp(0.0, 1.0)
        : 1.0;
    final gold = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFFFC928) : colors.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 5, 16, 6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surface, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(children: [
          CustomerFrameAvatarV29(size: 47,
            photo: data['photo']?.toString(),
            accentHex: current?['accent_hex']?.toString(),
            glyph: current?['glyph']?.toString()),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(switch (data['tier']?.toString()) {
                null || 'عضو' || 'عضو فيتو' => l.newsMember,
                'فضي' => l.homeLoyaltySilver,
                'ذهبي' => l.homeLoyaltyGold,
                final title => title,
              },
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle( color: gold,
                  fontWeight: FontWeight.w900, fontSize: 12))),
              if (_rank != null) Text(l.homeLoyaltyRank(_rank!), style: TextStyle(
                 fontSize: 10, color: colors.onSurfaceVariant)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(borderRadius: BorderRadius.circular(15), child: LinearProgressIndicator(
              minHeight: 6, value: progress,
              backgroundColor: colors.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(gold),
            )),
            const SizedBox(height: 4),
            Text(remaining > 0 ? l.homeLoyaltyProgress(remaining, completed)
                : l.homeLoyaltyCompleted(completed), maxLines: 1,
              style: TextStyle( fontSize: 10,
                color: colors.onSurfaceVariant)),
            if (_campaignV39?['available'] == true) ...[
              const SizedBox(height: 4),
              Text(_campaignV39?['credited'] == true
                  ? l.homeLoyaltyRewardCredited
                  : l.homeLoyaltyRewardRemaining((_campaignV39?['remaining'] as num?)?.toInt() ?? 0, '${_campaignV39?['amount'] ?? ''}'),
                maxLines: 1,
                style: TextStyle( fontSize: 10,
                  fontWeight: FontWeight.w800, color: gold)),
            ],
          ])),
        ]),
      ),
    );
  }
}
