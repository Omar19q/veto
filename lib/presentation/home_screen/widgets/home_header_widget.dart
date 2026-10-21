import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../../l10n/strings.dart';

class HomeHeaderWidget extends StatelessWidget {
  const HomeHeaderWidget({
    super.key,
    required this.customerName,
    required this.locationCaption,
    required this.walletBalance,
    required this.completedTrips,
    required this.unreadCount,
    required this.onNotificationTap,
    required this.onProfileTap,
  });
  final String customerName, locationCaption;
  final double walletBalance;
  final int completedTrips, unreadCount;
  final VoidCallback onNotificationTap, onProfileTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context),
        colors = theme.colorScheme,
        l = context.strings;
    final name = customerName.trim().split(' ').first;
    final hour = DateTime.now().hour;
    final greeting = hour >= 5 && hour < 12
        ? l.morning
        : hour < 17
        ? l.afternoon
        : hour < 22
        ? l.evening
        : l.welcome;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SvgPicture.asset(
                  'assets/images/veto_sanya_logo_mark.svg',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'VETO SANYA',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: l.profile,
                onPressed: onProfileTap,
                icon: const Icon(Icons.person_outline),
              ),
              Badge(
                isLabelVisible: unreadCount > 0,
                label: Text(unreadCount >= 100 ? '99+' : '$unreadCount'),
                child: IconButton(
                  tooltip: l.notifications,
                  onPressed: onNotificationTap,
                  icon: const Icon(Icons.notifications_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? greeting : '$greeting، $name',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      locationCaption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: l.moneyValue(
                  NumberFormat(
                    '0.00',
                    Localizations.localeOf(context).languageCode,
                  ).format(walletBalance),
                ),
                excludeSemantics: true,
                child: Chip(
                  avatar: Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 18,
                    color: colors.primary,
                  ),
                  label: Text(
                    l.moneyValue(
                      NumberFormat(
                        '0.00',
                        Localizations.localeOf(context).languageCode,
                      ).format(walletBalance),
                    ),
                    textDirection: Directionality.of(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
