import '../../../l10n/strings.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Customer-only booking entry. No pricing or trip mutation is performed here.
class HomeQuickBookingWidget extends StatelessWidget {
  final ValueChanged<String> onServiceSelected;
  final VoidCallback onMarketTap;

  const HomeQuickBookingWidget({
    super.key,
    required this.onServiceSelected,
    required this.onMarketTap,
  });

  @override
  Widget build(BuildContext context) {
    final services = <_QuickService>[
      _QuickService('car', context.strings.quickCar, context.strings.quickCarCaption, Icons.directions_car_filled_rounded,
          AppTheme.gold),
      _QuickService('motorcycle', context.strings.quickMotorcycle, context.strings.quickMotorcycleCaption, Icons.two_wheeler_rounded,
          Color(0xFF73C5FF)),
      _QuickService('package', context.strings.quickPackage, context.strings.quickPackageCaption,
          Icons.inventory_2_rounded, Color(0xFFA88AFF)),
      _QuickService('market', context.strings.quickMarket, context.strings.quickMarketCaption,
          Icons.shopping_basket_rounded, Color(0xFF75E6AC)),
    ];
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: AppTheme.gold.withAlpha(90)),
        gradient: const LinearGradient(
          colors: [Color(0xFF182138), Color(0xFF101522), Color(0xFF231C11)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 28,
            offset: const Offset(0, 14),
            color: Colors.black.withAlpha(65),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(15, 17, 15, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withAlpha(28),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.route_rounded, color: AppTheme.gold,
                    size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.strings.quickBookingTitle, style: TextStyle(
                      color: AppTheme.textPrimary, 
                      fontWeight: FontWeight.w900, fontSize: 21,
                    )),
                    Text(context.strings.quickBookingSubtitle,
                        style: TextStyle(color: AppTheme.textSecondary,
                             fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_back_rounded, color: AppTheme.gold,
                  size: 22),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(170),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on_rounded, size: 16, color: AppTheme.gold),
                SizedBox(width: 5),
                Expanded(child: Text(context.strings.quickBookingCoverage,
                  style: TextStyle( fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary))),
                Icon(Icons.verified_rounded, size: 15, color: Color(0xFF75E6AC)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(context.strings.quickBookingService, style: TextStyle(
            color: AppTheme.textPrimary, fontSize: 15,
            fontWeight: FontWeight.w800, 
          )),
          const SizedBox(height: 9),
          LayoutBuilder(builder: (context, layout) {
            final tileWidth = (layout.maxWidth - 9) / 2;
            return Wrap(
              spacing: 9,
              runSpacing: 9,
              children: services.map((service) {
                return SizedBox(
                  width: tileWidth,
                  child: Material(
                    color: const Color(0xFF202A41),
                    borderRadius: BorderRadius.circular(17),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(17),
                      onTap: () => service.id == 'market'
                          ? onMarketTap()
                          : onServiceSelected(service.id),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 106),
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                            color: service.accent.withAlpha(100),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                width: 33, height: 33,
                                decoration: BoxDecoration(
                                  color: service.accent.withAlpha(28),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(service.icon, size: 19,
                                    color: service.accent),
                              ),
                              const Spacer(),
                              Icon(Icons.arrow_back_ios_new_rounded,
                                color: service.accent, size: 12),
                            ]),
                            const SizedBox(height: 9),
                            Text(service.title, maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 13,
                                color: AppTheme.textPrimary)),
                            Text(service.subtitle, maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          }),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _FlowBadge('١', 'الخدمة', true),
              Icon(Icons.chevron_left_rounded, color: AppTheme.textSecondary,
                  size: 13),
              _FlowBadge('٢', 'الانطلاق', false),
              Icon(Icons.chevron_left_rounded, color: AppTheme.textSecondary,
                  size: 13),
              _FlowBadge('٣', 'الوجهة', false),
              Icon(Icons.chevron_left_rounded, color: AppTheme.textSecondary,
                  size: 13),
              _FlowBadge('٤', 'التأكيد', false),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickService {
  final String id, title, subtitle;
  final IconData icon;
  final Color accent;
  const _QuickService(this.id, this.title, this.subtitle, this.icon, this.accent);
}

class _FlowBadge extends StatelessWidget {
  final String number, label;
  final bool active;
  const _FlowBadge(this.number, this.label, this.active);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 19, height: 19, alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppTheme.gold : AppTheme.surfaceVariant,
          shape: BoxShape.circle,
        ),
        child: Text(number, style: TextStyle(
          color: active ? AppTheme.primary : AppTheme.textSecondary,
          fontSize: 10, fontWeight: FontWeight.w900, 
        )),
      ),
      const SizedBox(width: 3),
      Text(label, style: TextStyle( fontSize: 9,
        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
        color: active ? AppTheme.gold : AppTheme.textSecondary)),
    ],
  );
}
