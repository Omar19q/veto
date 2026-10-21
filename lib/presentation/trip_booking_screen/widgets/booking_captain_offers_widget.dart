import 'package:vetosanya/widgets/captain_photo_v16.dart';

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class BookingCaptainOffersWidget extends StatefulWidget {
  final String tripId;
  final List<Map<String, dynamic>> offers;
  final void Function(String offerId, String captainId) onCaptainSelected;

  const BookingCaptainOffersWidget({
    super.key,
    required this.tripId,
    required this.offers,
    required this.onCaptainSelected,
  });

  @override
  State<BookingCaptainOffersWidget> createState() =>
      _BookingCaptainOffersWidgetState();
}

class _BookingCaptainOffersWidgetState
    extends State<BookingCaptainOffersWidget> {
  String? _selectedOfferId;
  bool _selecting = false;

  Map<String, dynamic>? _captain(Map<String, dynamic> offer) {
    final raw = offer['captains'];
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  Future<void> _select(
    String offerId,
    String captainId,
  ) async {
    if (_selecting) return;
    setState(() {
      _selectedOfferId = offerId;
      _selecting = true;
    });
    try {
      widget.onCaptainSelected(offerId, captainId);
    } finally {
      if (mounted) {
        setState(() => _selecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.offers.isEmpty) {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 26),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hourglass_empty_rounded,
              color: AppTheme.gold,
              size: 44,
            ),
            SizedBox(height: 10),
            Text(
              'جاري انتظار الكباتن...',
              style: TextStyle(
                
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'سيظهر لك أي كابتن يقبل طلبك هنا.',
              style: TextStyle(
                
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 520),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.cardBorder,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'اختار كابتنك',
                  style: TextStyle(
                    
                    color: AppTheme.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withAlpha(25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.offers.length} عروض',
                  style: const TextStyle(
                    
                    color: AppTheme.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: widget.offers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final offer = widget.offers[index];
                final offerId = offer['id']?.toString() ?? '';
                final captainId = offer['captain_id']?.toString() ?? '';
                final captain = _captain(offer);

                final name =
                    captain?['full_name']?.toString().trim().isNotEmpty == true
                        ? captain!['full_name'].toString()
                        : 'كابتن';
                final photo = (captain?['profile_photo_url'] ??
                        captain?['profile_photo'])
                    ?.toString();
                final rating =
                    (captain?['rating'] as num?)?.toDouble() ?? 5.0;
                final ratingCount =
                    (captain?['rating_count'] as num?)?.toInt() ?? 0;
                final vehicleType =
                    captain?['vehicle_type']?.toString() ?? '';
                final brand = captain?['vehicle_brand']?.toString() ?? '';
                final model = captain?['vehicle_model']?.toString() ?? '';
                final color = captain?['vehicle_color']?.toString() ?? '';
                final eta =
                    (offer['eta_minutes'] as num?)?.toInt() ?? 0;
                final distance =
                    (offer['captain_distance_km'] as num?)?.toDouble() ?? 0;
                final selected = _selectedOfferId == offerId;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: selected
                          ? AppTheme.gold
                          : AppTheme.cardBorder,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: photo != null && photo.isNotEmpty
                                ? Image(image: captainPhotoV16(photo),
                                    width: 62,
                                    height: 62,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _avatar(name),
                                  )
                                : _avatar(name),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    
                                    color: AppTheme.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      color: AppTheme.gold,
                                      size: 15,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${rating.toStringAsFixed(1)} ($ratingCount)',
                                      style: const TextStyle(
                                        
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  [
                                    vehicleType == 'motorcycle'
                                        ? 'موتوسيكل'
                                        : vehicleType == 'car'
                                            ? 'سيارة'
                                            : vehicleType,
                                    brand,
                                    model,
                                    color
                                  ]
                                      .where((e) => e.trim().isNotEmpty)
                                      .join(' • '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    
                                    color: AppTheme.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${eta > 0 ? eta : 0} د',
                                style: const TextStyle(
                                  
                                  color: AppTheme.gold,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${distance.toStringAsFixed(1)} كم',
                                style: const TextStyle(
                                  
                                  color: AppTheme.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          onPressed: (_selecting || captainId.isEmpty)
                              ? null
                              : () => _select(offerId, captainId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.gold,
                            foregroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: selected && _selecting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text(
                                  'اختيار الكابتن',
                                  style: TextStyle(
                                    
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(String name) {
    return Container(
      width: 62,
      height: 62,
      color: AppTheme.gold.withAlpha(24),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name.characters.first : 'ك',
        style: const TextStyle(
          
          color: AppTheme.gold,
          fontSize: 24,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

