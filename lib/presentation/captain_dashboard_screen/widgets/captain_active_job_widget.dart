import '../../../l10n/strings.dart';
import 'package:flutter/material.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/app_theme.dart';

class CaptainActiveJobWidget extends StatefulWidget {
  final Map<String, dynamic>? activeJob;
  final VoidCallback? onViewTap;
  final VoidCallback? onStatusChanged;

  const CaptainActiveJobWidget({
    this.activeJob,
    this.onViewTap,
    this.onStatusChanged,
    super.key,
  });

  @override
  State<CaptainActiveJobWidget> createState() => _CaptainActiveJobWidgetState();
}

class _CaptainActiveJobWidgetState extends State<CaptainActiveJobWidget> {
  bool _isUpdating = false;

  Future<void> _advanceStatus(String tripId, String newStatus) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      await SupabaseService.instance.advanceTripStatus(tripId, newStatus);
      widget.onStatusChanged?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.strings.activeCaptain9b2f45b6,
              style: TextStyle( color: Colors.white),
              textDirection: Directionality.of(context),
            ),
            backgroundColor: AppTheme.errorLight,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  double? _number(dynamic value) {
    final n = value is num ? value.toDouble() : double.tryParse('$value');
    return n != null && n.isFinite && n >= 0 ? n : null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.activeJob == null) return const SizedBox.shrink();

    final job = widget.activeJob!;
    // Use real DB column names
    final String tripId = job['id'] as String? ?? '';
    final String status = job['trip_status'] as String? ?? 'accepted';
    final String pickup = job['pickup_address'] as String? ?? '';
    final String destination = job['destination_address'] as String? ?? '';
    final double? fare = _number(job['total_fare'] ?? job['base_fare']);
    final double? incentive = _number(job['incentive_amount']);
    final String serviceType = job['service_type'] as String? ?? 'car_ride';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryAccent = isDark ? AppTheme.gold : Theme.of(context).colorScheme.primary;
    final fareColor = isDark ? AppTheme.gold : const Color(0xFF10B981);

    final (Color statusColor, String statusLabel, IconData statusIcon) =
        _getStatusInfo(status);

    // Determine next action button
    final (String? nextStatus, String? nextLabel) = _getNextAction(status);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isDark ? AppTheme.gold.withAlpha(60) : Theme.of(context).colorScheme.outlineVariant,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? AppTheme.gold.withAlpha(20) : Colors.black.withAlpha(15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: primaryAccent.withAlpha(isDark ? 20 : 15),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16.0),
                topRight: Radius.circular(16.0),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  serviceType == 'motorcycle_ride'
                      ? Icons.two_wheeler_rounded
                      : serviceType == 'package'
                      ? Icons.inventory_2_rounded
                      : serviceType == 'vito_market'
                      ? Icons.shopping_bag_rounded
                      : Icons.directions_car_rounded,
                  color: primaryAccent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.strings.activeCaptain99f2c8a6,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: primaryAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(color: statusColor.withAlpha(80)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Route info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (pickup.isNotEmpty)
                  _RouteRow(
                    icon: Icons.radio_button_checked,
                    iconColor: AppTheme.successLight,
                    label: context.strings.activeCaptainae7ae56d,
                    value: pickup,
                  ),
                if (pickup.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Container(
                      width: 1,
                      height: 16,
                      color: AppTheme.cardBorder,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                    ),
                  ),
                if (destination.isNotEmpty)
                  _RouteRow(
                    icon: Icons.location_on_rounded,
                    iconColor: AppTheme.errorLight,
                    label: context.strings.activeCaptain8b068efc,
                    value: destination,
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _InfoChip(
                        label: context.strings.activeCaptain45a9a436,
                        value: fare == null
                            ? context.strings.historyAmountUnavailable
                            : context.strings.moneyValue(
                                fare.toStringAsFixed(0),
                              ),
                        color: fareColor,
                      ),
                    ),
                    if (incentive != null && incentive > 0) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _InfoChip(
                          label: context.strings.activeCaptain3eab5144,
                          value:
                              '+${context.strings.moneyValue(incentive.toStringAsFixed(0))}',
                          color: AppTheme.successLight,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                // Status action button
                if (nextStatus != null && tripId.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isUpdating
                          ? null
                          : () => _advanceStatus(tripId, nextStatus),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryAccent,
                        foregroundColor: isDark ? AppTheme.primary : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: primaryAccent.withAlpha(100),
                      ),
                      child: _isUpdating
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark ? AppTheme.primary : Colors.white,
                              ),
                            )
                          : Text(
                              nextLabel!,
                              style: TextStyle(
                                
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (Color, String, IconData) _getStatusInfo(String status) {
    return switch (status) {
      'accepted' => (
        AppTheme.gold,
        context.strings.activeCaptainf69cdd96,
        Icons.thumb_up_rounded,
      ),
      'arriving' => (
        AppTheme.gold,
        context.strings.activeCaptain3a7baec4,
        Icons.navigation_rounded,
      ),
      'arrived' => (
        AppTheme.successLight,
        context.strings.activeCaptainceb508b1,
        Icons.check_circle_rounded,
      ),
      'started' => (
        const Color(0xFF64B5F6),
        context.strings.activeCaptain888bd5a4,
        Icons.play_circle_rounded,
      ),
      _ => (
        Theme.of(context).colorScheme.onSurfaceVariant,
        context.strings.activeCaptainc20f27ab,
        Icons.circle_rounded,
      ),
    };
  }

  (String?, String?) _getNextAction(String status) {
    return switch (status) {
      'accepted' => ('arriving', context.strings.activeCaptaineef4662a),
      'arriving' => ('arrived', context.strings.activeCaptainceb508b1),
      'arrived' => ('started', context.strings.activeCaptain2cb6f5f1),
      'started' => ('completed', context.strings.activeCaptain11c70484),
      _ => (null, null),
    };
  }
}

class _RouteRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _RouteRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
