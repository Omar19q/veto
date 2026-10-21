import '../../../l10n/strings.dart';
import 'package:flutter/material.dart';
import '../../../services/growth_service.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/app_theme.dart';

/// Only displays a promotional entitlement that the signed-in database user
/// actually owns. Never derives eligibility from device preferences or name.
class HomeEarnedSavingsBannerV67 extends StatefulWidget {
  const HomeEarnedSavingsBannerV67({
    super.key,
    required this.customerId,
    required this.onBook,
  });
  final String? customerId;
  final VoidCallback onBook;

  @override
  State<HomeEarnedSavingsBannerV67> createState() =>
      _HomeEarnedSavingsBannerV67State();
}

class _HomeEarnedSavingsBannerV67State
    extends State<HomeEarnedSavingsBannerV67> {
  Map<String, dynamic>? _offer;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(HomeEarnedSavingsBannerV67 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customerId != widget.customerId) {
      _offer = null;
      _reload();
    }
  }

  Future<void> _reload() async {
    final revision = ++_revision;
    final accountId = SupabaseService.instance.currentUser?.id;
    if (!GrowthService.buildEnabled || widget.customerId == null ||
        accountId == null) return;
    try {
      final raw = await SupabaseService.instance.client
          .rpc('v67_my_ride_savings')
          .timeout(const Duration(seconds: 12));
      if (!mounted || revision != _revision ||
          accountId != SupabaseService.instance.currentUser?.id) return;
      if (raw is Map) {
        final value = Map<String, dynamic>.from(raw);
        setState(() => _offer = value['eligible'] == true ? value : null);
      }
    } catch (e) {
      // Older deployments lacking the optional read-only function simply hide
      // this banner rather than advertising an unverified financial promise.
      debugPrint('Home savings eligibility unavailable: ${e.runtimeType}');
      if (mounted && revision == _revision) setState(() => _offer = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = _offer;
    if (offer == null) return const SizedBox.shrink();
    final benefit = offer['benefit']?.toString();
    final percent = double.tryParse(offer['percent']?.toString() ?? '');
    final amount = double.tryParse(offer['amount']?.toString() ?? '');
    if (benefit != 'referral' && benefit != 'friend_credit') {
      return const SizedBox.shrink();
    }
    if (benefit == 'referral' &&
        (percent == null || percent <= 0 || percent > 100)) {
      return const SizedBox.shrink();
    }
    if (benefit == 'friend_credit' &&
        (amount == null || amount <= 0)) return const SizedBox.shrink();

    final isReferral = benefit == 'referral';
    final safePercent = percent ?? 0;
    final title = isReferral
        ? context.strings.homeReferralSaving(safePercent.toStringAsFixed(safePercent % 1 == 0 ? 0 : 1))
        : context.strings.homeCreditSaving(amount!.toStringAsFixed(2));
    final subtitle = isReferral
        ? context.strings.homeReferralSavingHelp
        : context.strings.homeCreditSavingHelp;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Material(
        color: AppTheme.gold.withAlpha(25),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: widget.onBook,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.gold.withAlpha(170)),
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const Icon(Icons.local_offer_rounded,
                color: AppTheme.gold, size: 31),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              )),
              const Icon(Icons.chevron_right_rounded,
                color: AppTheme.gold, size: 16),
            ]),
          ),
        ),
      ),
    );
  }
}
