import '../l10n/strings.dart';
import 'ride_preference_label.dart';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

/// Decorative only: rating/level always comes from authenticated RPC, never from
/// a client-side completed-trip counter. A missing RPC does not block a trip.
class CustomerFrameAvatarV29 extends StatelessWidget {
  final String? photo;
  final String? accentHex;
  final String? glyph;
  final double size;
  const CustomerFrameAvatarV29({
    super.key,
    this.photo,
    this.accentHex,
    this.glyph,
    this.size = 64,
  });

  static Color parseColor(String? raw) {
    final hex = (raw ?? '').replaceFirst('#', '');
    final value = hex.length == 6 ? int.tryParse('FF$hex', radix: 16) : null;
    return Color(value ?? 0xFFE7B433);
  }

  static IconData iconFor(String? glyph) => switch (glyph) {
    'crown' => Icons.workspace_premium_rounded,
    'diamond' => Icons.diamond_rounded,
    'shield' => Icons.shield_rounded,
    'sparkles' => Icons.auto_awesome_rounded,
    _ => Icons.star_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final color = parseColor(accentHex);
    return SizedBox(
      width: size + 12,
      height: size + 18,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size + 10,
            height: size + 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: .55),
                  color,
                  Colors.white.withValues(alpha: .75),
                  color,
                ],
              ),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: .25), blurRadius: 14),
              ],
            ),
            padding: const EdgeInsets.all(4),
            child: CircleAvatar(
              backgroundColor: const Color(0xFF18233B),
              backgroundImage: photo != null && photo!.startsWith('https://')
                  ? NetworkImage(photo!)
                  : null,
              child: photo == null || !photo!.startsWith('https://')
                  ? Icon(
                      Icons.person_rounded,
                      color: Colors.white70,
                      size: size * .52,
                    )
                  : null,
            ),
          ),
          Positioned(
            bottom: 0,
            child: Container(
              width: 28,
              height: 23,
              decoration: BoxDecoration(
                color: const Color(0xFF10182B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color, width: 1.5),
              ),
              child: Icon(iconFor(glyph), color: color, size: 17),
            ),
          ),
        ],
      ),
    );
  }
}

class CaptainCustomerBadgeV29 extends StatefulWidget {
  final String tripId;
  final Future<Map<String, dynamic>?> Function(String)? loadBadge;
  final String? customerName;
  final String? customerPhoto;
  final String? customerPhone;
  const CaptainCustomerBadgeV29({
    super.key,
    required this.tripId,
    this.customerName,
    this.customerPhoto,
    this.customerPhone,
    this.loadBadge,
  });
  @override
  State<CaptainCustomerBadgeV29> createState() =>
      _CaptainCustomerBadgeV29State();
}

class _CaptainCustomerBadgeV29State extends State<CaptainCustomerBadgeV29> {
  late Future<Map<String, dynamic>?> _future = _load();
  Future<Map<String, dynamic>?> _load() async {
    if (widget.loadBadge != null) return widget.loadBadge!(widget.tripId);
    try {
      final userId = SupabaseService.instance.currentUser?.id;
      final response = await SupabaseService.instance.client
          .rpc(
            'captain_customer_badge_v29',
            params: {'p_trip_id': widget.tripId},
          )
          .timeout(const Duration(seconds: 8));
      if (response is! Map) return null;
      final data = Map<String, dynamic>.from(response);
      // Optional V31 privacy-filtered ride preferences. V29 works without it.
      try {
        final preferences = await SupabaseService.instance.client
            .rpc(
              'captain_trip_customer_preferences_v31',
              params: {'p_trip_id': widget.tripId},
            )
            .timeout(const Duration(seconds: 5));
        if (preferences is Map) data['interests'] = preferences['interests'];
      } catch (_) {
        /* No access outside an active assigned trip. */
      }
      if (SupabaseService.instance.currentUser?.id != userId) return null;
      return data;
    } catch (_) {
      return null;
    }
  }

  @override
  void didUpdateWidget(covariant CaptainCustomerBadgeV29 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tripId != widget.tripId) _future = _load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(
    key: ValueKey(widget.tripId),
    future: _future,
    builder: (context, snapshot) {
      final data = snapshot.data ?? const <String, dynamic>{};
      final rating = (data['rating'] as num?)?.toDouble();
      final count = (data['rating_count'] as num?)?.toInt() ?? 0;
      final accent = data['accent_hex']?.toString();
      final accentColor = CustomerFrameAvatarV29.parseColor(accent);
      final photo = data['photo']?.toString().isNotEmpty == true
          ? data['photo'].toString()
          : widget.customerPhoto;
      final name = (widget.customerName?.trim().isNotEmpty == true)
          ? widget.customerName!.trim()
          : context.strings.chatCustomer;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF141D31)
              : Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accentColor.withValues(alpha: .55)),
        ),
        child: Row(
          children: [
            CustomerFrameAvatarV29(
              size: 56,
              photo: photo,
              accentHex: accent,
              glyph: data['glyph']?.toString(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          data['frame_title']?.toString() ??
                              context.strings.profile05f99bc8,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            
                            fontSize: 11,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? accentColor
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        count > 0 && rating != null
                            ? '★ ${rating.toStringAsFixed(1)}'
                            : context.strings.profiled51f9d8d,
                        style: TextStyle(
                          
                          fontSize: 11,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFFFD47A)
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  if (widget.customerPhone?.isNotEmpty == true)
                    Text(
                      widget.customerPhone!,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if ((data['interests'] as List?)?.isNotEmpty == true)
                    Text(
                      (data['interests'] as List)
                          .whereType<String>()
                          .map((value) => ridePreferenceLabel(context, value))
                          .join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        
                        fontSize: 10,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFC7D0DD)
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
