import 'package:flutter/material.dart';
import '../../../l10n/strings.dart';

class SearchPriceSuggestionV9 extends StatelessWidget {
  final double total;
  final bool busy;
  final VoidCallback onContinue;
  final VoidCallback onImprove;
  const SearchPriceSuggestionV9({
    super.key,
    required this.total,
    required this.busy,
    required this.onContinue,
    required this.onImprove,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .5),
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.strings.suggestedFareTitle,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.primary,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.strings.suggestedFareHelp,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.strings.suggestedFareValue(
            total.toStringAsFixed(2),
          ),
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 19,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final buttons = [
              OutlinedButton(
                onPressed: busy ? null : onContinue,
                child: Text(context.strings.keepCurrentFare),
              ),
              FilledButton(
                onPressed: busy ? null : onImprove,
                child: Text(
                  busy
                      ? context.strings.confirmingRequest
                      : context.strings.useSuggestedFare,
                ),
              ),
            ];
            return constraints.maxWidth < 480
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      buttons[0],
                      const SizedBox(height: 6),
                      buttons[1],
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: buttons[0]),
                      const SizedBox(width: 8),
                      Expanded(child: buttons[1]),
                    ],
                  );
          },
        ),
      ],
    ),
  );
}
