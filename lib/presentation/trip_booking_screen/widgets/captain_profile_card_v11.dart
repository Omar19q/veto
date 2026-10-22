import '../../../l10n/strings.dart';
import '../../../theme/app_theme.dart';
import 'package:vetosanya/widgets/captain_photo_v16.dart';
import 'package:flutter/material.dart';

class CaptainProfileCardV11 extends StatelessWidget {
  final Map<String, dynamic> profile;
  const CaptainProfileCardV11({super.key, required this.profile});

  String _firstName(String raw, String fallback) {
    final clean = raw.trim();
    if (clean.isEmpty) return fallback;
    return clean.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final l = context.strings;
    final fullName = p['full_name']?.toString() ?? l.captainProfileDefaultName;
    final photo = p['profile_photo']?.toString().trim() ?? '';
    final rating = (p['rating'] as num?)?.toDouble() ?? 0;
    final trips = (p['total_completed_trips'] as num?)?.toInt() ?? 0;
    final ratingCount = (p['rating_count'] as num?)?.toInt() ?? 0;
    final reviews = p['reviews'] as List? ?? [];
    final vehicle = [
      p['vehicle_brand'],
      p['vehicle_model'],
      p['vehicle_color'],
    ].where((v) => v != null && '$v'.trim().isNotEmpty).join(' • ');

    final darkPalette = Theme.of(context).brightness == Brightness.dark;
    final bg = darkPalette
        ? const Color(0xFF09111F)
        : Theme.of(context).colorScheme.surface;
    final panel = darkPalette
        ? const Color(0xFF121D31)
        : Theme.of(context).colorScheme.surface;
    final panel2 = darkPalette
        ? const Color(0xFF182640)
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final gold = darkPalette
        ? const Color(0xFFFFC400)
        : Theme.of(context).colorScheme.primary;
    final ink = darkPalette
        ? const Color(0xFFF8FAFF)
        : Theme.of(context).colorScheme.onSurface;
    final muted = darkPalette
        ? const Color(0xFFADB9CF)
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final good = darkPalette
        ? const Color(0xFF55D69E)
        : const Color(0xFF10B981);

    Widget stat(IconData icon, String value, String label) => Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        decoration: BoxDecoration(
          color: panel2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: .06)),
        ),
        child: Column(
          children: [
            Icon(icon, color: gold, size: 19),
            SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                fontFamily: AppTheme.productFontFamily(context),

                color: ink,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            SizedBox(height: 1),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.productFontFamily(context),

                color: muted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );

    Widget verifiedChip(IconData icon, String label, bool ok) => Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: ok
            ? good.withValues(alpha: .12)
            : Colors.white.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: ok
              ? good.withValues(alpha: .45)
              : Colors.white.withValues(alpha: .08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: ok ? good : muted),
          SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.productFontFamily(context),

              color: ok ? ink : muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: darkPalette
              ? const Color(0xFF2A3355)
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(18, 22, 18, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: darkPalette
                    ? const [Color(0xFF213558), Color(0xFF111A2C)]
                    : [
                        Theme.of(context).colorScheme.surface,
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                      ],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                Container(
                  width: 94,
                  height: 94,
                  padding: EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [gold, Color(0xFFFFE08A)]),
                    boxShadow: [
                      BoxShadow(
                        color: gold.withValues(alpha: .18),
                        blurRadius: 22,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Container(
                      color: panel,
                      child: photo.isEmpty
                          ? Icon(Icons.person_rounded, color: ink, size: 56)
                          : Image(
                              image: captainPhotoV16(photo),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.person_rounded,
                                color: ink,
                                size: 56,
                              ),
                            ),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  _firstName(fullName, l.captainProfileDefaultName),
                  style: TextStyle(
                    fontFamily: AppTheme.productFontFamily(context),

                    color: ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
                SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star_rounded, color: gold, size: 21),
                    SizedBox(width: 4),
                    Text(
                      rating > 0
                          ? rating.toStringAsFixed(2)
                          : context.strings.captainProfileNew,
                      style: TextStyle(
                        fontFamily: AppTheme.productFontFamily(context),

                        color: ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (ratingCount > 0) ...[
                      SizedBox(width: 5),
                      Text(
                        l.captainProfileRatingCount(ratingCount),
                        style: TextStyle(
                          fontFamily: AppTheme.productFontFamily(context),

                          color: muted,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    verifiedChip(
                      Icons.verified_user_rounded,
                      l.captainProfileVerifiedIdentity,
                      p['verified'] == true,
                    ),
                    verifiedChip(
                      Icons.directions_car_filled_rounded,
                      l.captainProfileVerifiedVehicle,
                      p['vehicle_verified'] == true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    stat(
                      Icons.route_rounded,
                      '$trips',
                      l.captainProfileCompleted,
                    ),
                    SizedBox(width: 9),
                    stat(
                      Icons.workspace_premium_rounded,
                      rating > 0 ? rating.toStringAsFixed(1) : '—',
                      l.captainProfileAverage,
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: panel,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .06),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: gold.withValues(alpha: .11),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          Icons.directions_car_filled_rounded,
                          color: gold,
                        ),
                      ),
                      SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.captainProfileVehicle,
                              style: TextStyle(
                                fontFamily: AppTheme.productFontFamily(context),

                                color: muted,
                                fontSize: 10,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              vehicle.isEmpty
                                  ? l.captainProfileIncompleteVehicle
                                  : vehicle,
                              style: TextStyle(
                                fontFamily: AppTheme.productFontFamily(context),

                                color: ink,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.reviews_rounded, color: gold, size: 19),
                    SizedBox(width: 7),
                    Text(
                      l.captainProfileReviews,
                      style: TextStyle(
                        fontFamily: AppTheme.productFontFamily(context),

                        color: ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 9),
                if (reviews.isEmpty)
                  Container(
                    padding: EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: panel,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      l.captainProfileNoReviews,
                      style: TextStyle(
                        fontFamily: AppTheme.productFontFamily(context),

                        color: muted,
                        fontSize: 11.5,
                      ),
                    ),
                  )
                else
                  ...reviews.take(3).map((raw) {
                    final review = Map<String, dynamic>.from(raw as Map);
                    final stars = (review['stars'] as num?)?.toInt() ?? 0;
                    final reasons = (review['reasons'] as List? ?? [])
                        .map((e) => e.toString())
                        .where((e) => e.trim().isNotEmpty)
                        .join(' • ');
                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: panel,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .05),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ...List.generate(
                                5,
                                (i) => Icon(
                                  i < stars
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  size: 16,
                                  color: gold,
                                ),
                              ),
                              Spacer(),
                              Text(
                                review['month']?.toString() ?? '',
                                style: TextStyle(
                                  fontFamily: AppTheme.productFontFamily(
                                    context,
                                  ),

                                  color: muted,
                                  fontSize: 9.5,
                                ),
                              ),
                            ],
                          ),
                          if (reasons.isNotEmpty) ...[
                            SizedBox(height: 5),
                            Text(
                              reasons,
                              style: TextStyle(
                                fontFamily: AppTheme.productFontFamily(context),

                                color: ink,
                                fontSize: 11.5,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
