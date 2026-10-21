import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../theme/app_theme.dart';

/// V37 route-first home surface: destinations before choosing a vehicle.
/// Reuses the existing booking route and live pricing; no duplicate trip logic.
class HomeRouteFirstV36 extends StatelessWidget {
  final bool premium;
  final String pickupCaption;
  final VoidCallback onStart;
  final VoidCallback onMarketTap;
  const HomeRouteFirstV36({
    super.key,
    required this.onStart,
    required this.onMarketTap,
    this.premium = false,
    this.pickupCaption = 'اختار مكان الركوب',
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppTheme.gold.withAlpha(95)),
      color: const Color(0xFF18233B),
      gradient: premium
          ? const LinearGradient(
              colors: [Color(0xFF182E45), Color(0xFF111A2D)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            )
          : null,
    ),
    padding: const EdgeInsets.all(15),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (premium) ...[
          Row(
            children: [
              SvgPicture.asset(
                'assets/images/veto_sanya_logo_mark.svg',
                width: 42,
                height: 42,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'مشوارك يبدأ بخطوة بسيطة',
                  style: TextStyle(
                    color: AppTheme.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'اختار المسار، ثم شوف الخدمات والأسعار المتاحة في منطقتك.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
        ],
        const Text(
          'رايح فين؟',
          style: TextStyle(
            
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 13),
        Material(
          color: const Color(0xFF242F48),
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            onTap: onStart,
            borderRadius: BorderRadius.circular(15),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              child: Row(
                children: [
                  Icon(
                    Icons.my_location_rounded,
                    color: Color(0xFF43D2A4),
                    size: 23,
                  ),
                  SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'من',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          pickupCaption,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.edit_location_alt_outlined,
                    color: AppTheme.gold,
                    size: 19,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 9),
        Material(
          color: const Color(0xFF242F48),
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            onTap: onStart,
            borderRadius: BorderRadius.circular(15),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.flag_rounded, color: AppTheme.gold, size: 23),
                  SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      'حدد وجهتك',
                      style: TextStyle(
                        
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 15,
                    color: AppTheme.gold,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 49,
          child: FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.route_rounded, size: 20),
            label: const Text(
              'شوف أسعار المشوار',
              style: TextStyle(
                
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.gold,
              foregroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: TextButton.icon(
            onPressed: onMarketTap,
            icon: const Icon(Icons.shopping_basket_outlined, size: 17),
            label: const Text(
              'فيتو ماركت',
              style: TextStyle( fontSize: 12),
            ),
          ),
        ),
      ],
    ),
  );
}
