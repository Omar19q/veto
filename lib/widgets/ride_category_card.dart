import 'package:flutter/material.dart';
import '../services/ride_categories.dart';

class RideCategoryCard extends StatelessWidget {
  const RideCategoryCard({
    super.key,
    required this.category,
    this.selected = false,
    this.loading = false,
    this.fare,
    this.onTap,
    this.status,
  });
  final RideCategory category;
  final bool selected, loading;
  final num? fare;
  final VoidCallback? onTap;
  final String? status;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      enabled: onTap != null,
      child: Material(
        color: selected ? category.accent.withAlpha(28) : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? category.accent : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Image.asset(
                  category.asset,
                  width: 78,
                  height: 58,
                  fit: BoxFit.contain,
                  cacheWidth: 192,
                  excludeFromSemantics: true,
                  errorBuilder: (_, e, s) => SizedBox(
                    width: 78,
                    height: 58,
                    child: Icon(
                      Icons.directions_car_outlined,
                      color: category.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        category.name(context),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        status ?? category.description(context),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (fare != null)
                        Text(
                          '${fare!.toStringAsFixed(2)} ${categoryCopy(context, 'ج.م', 'EGP')}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: colors.onSurface,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    selected
                        ? Icons.check_circle
                        : onTap == null
                        ? Icons.lock_outline
                        : Icons.radio_button_unchecked,
                    color: selected ? category.accent : colors.onSurfaceVariant,
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
