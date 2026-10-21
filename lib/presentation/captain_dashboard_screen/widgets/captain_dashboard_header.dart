import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class CaptainDashboardHeader extends StatelessWidget {
  final String captainName;
  final String vehicleType;
  final String vehiclePlate;
  final double rating;
  final int totalTrips;
  final VoidCallback onProfileTap;
  final VoidCallback onNotificationTap;

  const CaptainDashboardHeader({
    required this.captainName,
    required this.vehicleType,
    required this.vehiclePlate,
    required this.rating,
    required this.totalTrips,
    required this.onProfileTap,
    required this.onNotificationTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          // Profile avatar
          GestureDetector(
            onTap: onProfileTap,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.surfaceVariant,
                border: Border.all(
                  color: AppTheme.gold.withAlpha(80),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: AppTheme.gold,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'مرحباً،',
                      style: TextStyle(
                        
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        captainName,
                        style: TextStyle(
                          
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(
                      vehicleType == 'motorcycle'
                          ? Icons.two_wheeler_rounded
                          : Icons.directions_car_rounded,
                      color: AppTheme.textSecondary,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      vehiclePlate,
                      style: TextStyle(
                        
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.star_rounded, color: AppTheme.gold, size: 12),
                    const SizedBox(width: 2),
                    Text(
                      rating.toStringAsFixed(1),
                      style: TextStyle(
                        
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.gold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Notification bell
          GestureDetector(
            onTap: onNotificationTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.notifications_outlined,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.errorLight,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
