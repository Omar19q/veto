import '../../../l10n/strings.dart';
import 'package:flutter/material.dart';

/// One clear server-priced trip base fare for the captain before acceptance.
/// Never exposes customer's wallet balance, payments or historical debts.
/// Final collection and captain settlement still use the financial invoice.
class CaptainFarePreviewWidget extends StatelessWidget {
  final Map<String, dynamic> offer;
  const CaptainFarePreviewWidget({super.key, required this.offer});

  static double? _money(Object? input) {
    final number = input is num ? input.toDouble() : double.tryParse('$input');
    return number != null && number.isFinite && number >= 0 ? number : null;
  }

  @override
  Widget build(BuildContext context) {
    final trip = offer['trips'] is Map
        ? Map<String, dynamic>.from(offer['trips'] as Map)
        : <String, dynamic>{};
    final fare = _money(trip['base_fare']);
    final incentive = _money(trip['incentive_amount']);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: Theme.of(context).brightness == Brightness.dark
              ? [Color(0xFF192842), Color(0xFF0F1A2C)]
              : [
                  Theme.of(context).colorScheme.surfaceContainer,
                  Theme.of(context).colorScheme.surface,
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBE963B), width: 1.1),
      ),
      child: Column(
        children: [
          Text(
            context.strings.captainFareBase,
            style: TextStyle(
              
              fontSize: 12,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Color(0xFFB5C0D3)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            fare != null
                ? context.strings.moneyValue(fare.toStringAsFixed(2))
                : context.strings.captainFareUpdating,
            style: TextStyle(
              
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Color(0xFFFFCB50)
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
          if (incentive != null && incentive > 0)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                context.strings.captainFareIncentive(
                  incentive.toStringAsFixed(2),
                ),
                style: TextStyle(
                  
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Color(0xFF76E4AE)
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            context.strings.captainFareFinalInvoice,
            textAlign: TextAlign.center,
            style: TextStyle(
              
              fontSize: 10,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Color(0xFF97A5BE)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
