import '../l10n/strings.dart';
import 'package:flutter/material.dart';

class TripLoadingV10 extends StatelessWidget {
  const TripLoadingV10({super.key});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Icon(
              Icons.map_outlined,
              size: 70,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
      Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            LinearProgressIndicator(),
            SizedBox(height: 18),
            Text(
              context.strings.rideLoadingDetails,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
