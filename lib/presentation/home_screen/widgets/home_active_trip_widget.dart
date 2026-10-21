import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class HomeActiveTripWidget extends StatelessWidget {
  final Map<String, dynamic> activeTrip;
  final VoidCallback onTap;

  const HomeActiveTripWidget({
    super.key,
    required this.activeTrip,
    required this.onTap,
  });

  String _statusLabel(String status) {
    const labels = {
      'requested': 'جاري البحث عن كابتن',
      'offer_received': 'عروض واردة',
      'accepted': 'الكابتن قبل الطلب',
      'arriving': 'الكابتن في الطريق',
      'arrived': 'الكابتن وصل',
      'started': 'الرحلة بدأت',
    };
    return labels[status] ?? status;
  }

  @override
  Widget build(BuildContext context) {
    final status = activeTrip['trip_status'] as String? ?? '';
    final pickup = activeTrip['pickup_address'] as String? ?? '';
    final destination = activeTrip['destination_address'] as String? ?? '';
    final fare = activeTrip['total_fare'];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.gold.withAlpha(26), AppTheme.gold.withAlpha(13)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.gold.withAlpha(77)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withAlpha(51),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 8,
                        height: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppTheme.gold,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _statusLabel(status),
                        style: const TextStyle(
                          
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.gold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.arrow_back_ios_rounded,
                  color: AppTheme.gold,
                  size: 14,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.radio_button_checked_rounded,
                  color: AppTheme.successLight,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    pickup,
                    style: TextStyle(
                      
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: AppTheme.errorLight,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    destination,
                    style: TextStyle(
                      
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (fare != null)
                  Text(
                    '$fare ج',
                    style: const TextStyle(
                      
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.gold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 13),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: AppTheme.gold,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    const {'requested', 'offer_received'}.contains(status)
                        ? Icons.radar_rounded
                        : Icons.directions_car_rounded,
                    color: AppTheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 9),
                  Flexible(
                    child: Text(
                      const {'requested', 'offer_received'}.contains(status)
                          ? 'متابعة البحث أو إلغاء الطلب'
                          : 'متابعة الرحلة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_back_rounded,
                    color: AppTheme.primary,
                    size: 19,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
