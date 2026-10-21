import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import 'captain_fare_preview_widget.dart';

class CaptainIncomingOfferWidget extends StatefulWidget {
  final List<Map<String, dynamic>> offers;
  final Function(String offerId) onAccept;
  final Function(String offerId) onDecline;

  const CaptainIncomingOfferWidget({
    required this.offers,
    required this.onAccept,
    required this.onDecline,
    super.key,
  });

  @override
  State<CaptainIncomingOfferWidget> createState() =>
      _CaptainIncomingOfferWidgetState();
}

class _CaptainIncomingOfferWidgetState extends State<CaptainIncomingOfferWidget>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );
    _fadeAnim = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    );
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.offers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppTheme.gold,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'عروض واردة',
              style: TextStyle(
                
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.gold.withAlpha(30),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Text(
                '${widget.offers.length}',
                style: TextStyle(
                  
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.gold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SlideTransition(
          position: _slideAnim,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: widget.offers
                  .map(
                    (offer) => _OfferCard(
                      offer: offer,
                      onAccept: () => widget.onAccept(offer['id'] ?? ''),
                      onDecline: () => widget.onDecline(offer['id'] ?? ''),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _OfferCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _OfferCard({
    required this.offer,
    required this.onAccept,
    required this.onDecline,
  });

  /// Extract trip data — offer may have a nested 'trips' map from the DB join.
  Map<String, dynamic>? get _trip {
    final t = offer['trips'];
    if (t is Map<String, dynamic>) return t;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Real data from DB — no hardcoded fallbacks
    final trip = _trip;
    final String pickup =
        trip?['pickup_address'] as String? ??
        offer['pickup_address'] as String? ??
        '';
    final String destination =
        trip?['destination_address'] as String? ??
        offer['destination_address'] as String? ??
        '';
    final double distanceKm =
        ((offer['captain_distance_km'] ?? trip?['distance_km'] ?? 0) as num)
            .toDouble();
    final int etaMinutes = ((offer['eta_minutes'] ?? 0) as num).toInt();
    final String serviceType = (trip?['service_type'] as String?) ?? 'car_ride';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: AppTheme.gold.withAlpha(100), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.gold.withAlpha(25),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          if(trip?['ride_category_id_v3']!=null) Padding(padding:const EdgeInsets.all(12),child:Column(children:[
            Text('${trip?['category_config_v3']?[Localizations.localeOf(context).languageCode=='ar'?'name_ar':'name_en']??''}',style:Theme.of(context).textTheme.titleMedium),
            if((trip?['trip_promises_v3'] as List? ?? []).isNotEmpty) Text((trip!['trip_promises_v3'] as List).map((p)=>const {'quiet':'مشوار هادي / Quiet','no_music':'بدون أغاني / No music','ac':'تكييف / A/C','child':'طفل بمرافقة / Child accompanied','baggage':'مساعدة الشنط / Baggage help','child_seat':'كرسي طفل / Child seat'}[p]??p).join(' · ')),
          ])),
          // Top bar with service type
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.gold.withAlpha(15),
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
                      : Icons.directions_car_rounded,
                  color: AppTheme.gold,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  serviceType == 'motorcycle_ride'
                      ? 'مشوار موتوسيكل'
                      : serviceType == 'package'
                      ? 'طرد'
                      : serviceType == 'vito_market'
                      ? 'طلب سوق'
                      : 'مشوار سيارة',
                  style: TextStyle(
                    
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.gold,
                  ),
                ),
                const Spacer(),
                // Show distance to pickup
                if (distanceKm > 0)
                  Text(
                    '${distanceKm.toStringAsFixed(1)} كم منك',
                    style: TextStyle(
                      
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Route
                if (pickup.isNotEmpty || destination.isNotEmpty)
                  Row(
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.successLight,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            color: AppTheme.cardBorder,
                          ),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.errorLight,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pickup.isNotEmpty ? pickup : 'نقطة الانطلاق',
                              style: TextStyle(
                                
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              destination.isNotEmpty ? destination : 'الوجهة',
                              style: TextStyle(
                                
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 14),
                if (etaMinutes > 0)
                  Align(
                    alignment: Alignment.centerRight,
                    child: _StatBadge(
                      icon: Icons.access_time_rounded,
                      value: '$etaMinutes دقيقة للوصول',
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 10),
                CaptainFarePreviewWidget(offer: offer),
                const SizedBox(height: 14),
                // Two unambiguous actions, with a single high-contrast
                // primary accept button and generous tap targets for drivers.
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDecline,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('تخطي'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: onAccept,
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('اقبل المشوار'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _StatBadge({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
