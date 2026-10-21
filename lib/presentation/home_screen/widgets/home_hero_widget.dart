import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class HomeHeroWidget extends StatelessWidget {
  final VoidCallback onBookTap;

  const HomeHeroWidget({super.key, required this.onBookTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onBookTap,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1400), Color(0xFF2B2102), Color(0xFF1B1605)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          border: Border.all(color: AppTheme.gold.withAlpha(70), width: 1),
          boxShadow: [
            BoxShadow(
              color: AppTheme.gold.withAlpha(26),
              blurRadius: 22,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: -20,
              top: -15,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.gold.withAlpha(10),
                ),
              ),
            ),
            Positioned(
              left: 25,
              bottom: -35,
              child: Container(
                width: 85,
                height: 85,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.gold.withAlpha(12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.gold.withAlpha(32),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppTheme.gold.withAlpha(70)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on_rounded, size: 14, color: AppTheme.gold),
                              SizedBox(width: 4),
                              Text(
                                'التغطية الحالية: حدائق الأهرام',
                                style: TextStyle(
                                  
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.gold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'وجهتك فين النهارده؟',
                          style: TextStyle(
                            
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'اطلب عربيتك بسهولة داخل حدائق الأهرام، بسرعة وتجربة أوضح من أول لمسة.',
                          style: TextStyle(
                            
                            fontSize: 12,
                            height: 1.4,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.gold,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_rounded, color: AppTheme.primary, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'حدد وجهتك',
                                style: TextStyle(
                                  
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withAlpha(24),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.gold.withAlpha(51), width: 1),
                    ),
                    child: const Icon(
                      Icons.directions_car_rounded,
                      color: AppTheme.gold,
                      size: 40,
                    ),
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
