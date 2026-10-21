import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../l10n/strings.dart';

enum TripStatus {
  requested,
  offerReceived,
  accepted,
  arriving,
  arrived,
  started,
  completed,
  cancelled,
}

class StatusBadgeWidget extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;

  const StatusBadgeWidget({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
  });

  factory StatusBadgeWidget.fromTripStatus(TripStatus status) {
    switch (status) {
      case TripStatus.requested:
        return StatusBadgeWidget(
          label: 'مطلوب',
          backgroundColor: AppTheme.surfaceVariant,
          textColor: AppTheme.textSecondary,
        );
      case TripStatus.offerReceived:
        return StatusBadgeWidget(
          label: 'عروض متاحة',
          backgroundColor: AppTheme.gold.withAlpha(38),
          textColor: AppTheme.gold,
          icon: Icons.local_offer_rounded,
        );
      case TripStatus.accepted:
        return StatusBadgeWidget(
          label: 'مقبول',
          backgroundColor: const Color(0xFF1A3A2A),
          textColor: AppTheme.successLight,
          icon: Icons.check_circle_outline_rounded,
        );
      case TripStatus.arriving:
        return StatusBadgeWidget(
          label: 'الكابتن في الطريق',
          backgroundColor: const Color(0xFF1A2A3A),
          textColor: const Color(0xFF64B5F6),
          icon: Icons.directions_car_rounded,
        );
      case TripStatus.arrived:
        return StatusBadgeWidget(
          label: 'الكابتن وصل',
          backgroundColor: const Color(0xFF1A3A2A),
          textColor: AppTheme.successLight,
          icon: Icons.location_on_rounded,
        );
      case TripStatus.started:
        return StatusBadgeWidget(
          label: 'الرحلة بدأت',
          backgroundColor: AppTheme.gold.withAlpha(38),
          textColor: AppTheme.gold,
          icon: Icons.play_circle_rounded,
        );
      case TripStatus.completed:
        return StatusBadgeWidget(
          label: 'مكتملة',
          backgroundColor: const Color(0xFF1A3A2A),
          textColor: AppTheme.successLight,
          icon: Icons.check_circle_rounded,
        );
      case TripStatus.cancelled:
        return StatusBadgeWidget(
          label: 'ملغية',
          backgroundColor: const Color(0xFF3A1A1A),
          textColor: AppTheme.errorLight,
          icon: Icons.cancel_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.strings;
    final translated = switch (label) {
      'مطلوب' => l.tripBadgeRequested,
      'عروض متاحة' => l.tripBadgeOffers,
      'مقبول' => l.tripBadgeAccepted,
      'الكابتن في الطريق' => l.tripBadgeArriving,
      'الكابتن وصل' => l.tripBadgeArrived,
      'الرحلة بدأت' => l.tripBadgeStarted,
      'مكتملة' => l.tripBadgeCompleted,
      'ملغية' => l.tripBadgeCancelled,
      _ => label,
    };
    final light = Theme.of(context).brightness == Brightness.light;
    final colors = Theme.of(context).colorScheme;
    final foreground = light ? colors.onSurface : textColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: light ? colors.surfaceContainerHighest : backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            translated,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
