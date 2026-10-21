import 'package:flutter/material.dart';
import '../../l10n/strings.dart';

/// Presentation only; existing booking state and server quotes remain authoritative.
class GrowthBookingProgress extends StatelessWidget {
  const GrowthBookingProgress({super.key, required this.stage});
  final int stage;
  // Compatibility metadata for existing callers; displayed text is localized.
  static const labels = ['المسار', 'الخدمة', 'التأكيد', 'البحث'];
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final labels = [context.strings.bookingProgressRoute, context.strings.bookingProgressService,
      context.strings.bookingProgressConfirm, context.strings.bookingProgressSearch];
    return Semantics(
      label: '${context.strings.flowStep(stage + 1, 4)}: ${labels[stage]}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: reduced
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i <= stage
                            ? const Color(0xFFFFC400)
                            : const Color(0xFF30415C),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        
                        fontSize: 11,
                        color: i == stage
                            ? const Color(0xFFFFC400)
                            : Theme.of(context).colorScheme.onSurfaceVariant,
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
