import '../services/ride_categories.dart';
import '../l10n/strings.dart';
import 'package:flutter/material.dart';

/// Final trip invoice. It is intentionally rendered only after trip completion
/// by the customer/captain live screens. All amounts come from the server.
class TripFinancialCardV11 extends StatelessWidget {
  final Map<String, dynamic> trip;
  final bool captain;

  const TripFinancialCardV11({
    super.key,
    required this.trip,
    this.captain = false,
  });

  double _money(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  @override
  Widget build(BuildContext context) {
    if (trip['trip_status'] == 'cancelled') {
      final raw = trip['cancellation_receipt'] ?? trip['financial_preview_v11'];
      return CancellationReceiptCard(
        receipt: raw is Map ? Map<String, dynamic>.from(raw) : null,
      );
    }
    // Defense in depth: no caller may expose the final bill before completion.
    if (trip['trip_status'] != 'completed') return const SizedBox.shrink();
    final raw = trip['financial_preview_v11'];
    final amounts = raw is Map ? Map<String, dynamic>.from(raw) : trip;
    bool validAmount(dynamic value) {
      final number = value is num
          ? value.toDouble()
          : double.tryParse('$value');
      return number != null && number.isFinite && number >= 0;
    }

    final settlementUnavailable =
        trip.containsKey('financial_settled_at') &&
        trip['financial_settled_at'] == null;
    final rawUnavailable = [
      'total_fare',
      'wallet_amount',
      if (captain) 'commission_amount',
      if (captain) 'captain_earnings',
    ].any((key) => trip.containsKey(key) && !validAmount(trip[key]));
    if (settlementUnavailable ||
        rawUnavailable ||
        !validAmount(amounts['total_fare']) ||
        !validAmount(amounts['wallet_amount']) ||
        (captain &&
            (!validAmount(amounts['commission_amount']) ||
                !validAmount(amounts['captain_earnings'])))) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
          if(tripCategoryLabel(context,trip,'').isNotEmpty) Padding(padding:const EdgeInsets.only(bottom:8),child:Text(tripCategoryLabel(context,trip,''),style:Theme.of(context).textTheme.titleSmall)),
              Text(
                context.strings.financialCard82963d4d,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(context.strings.financialCarde62437f7),
            ],
          ),
        ),
      );
    }
    final cashRaw = trip.containsKey('cash_amount')
        ? trip['cash_amount']
        : (amounts['cash_collected'] ?? amounts['cash_amount']);
    final double? cash = validAmount(cashRaw) ? _money(cashRaw) : null;
    final wallet = _money(amounts['wallet_amount']);
    final total = _money(amounts['total_fare']);
    final incentive = _money(trip['incentive_amount']);
    final discount = _money(trip['promo_discount']);
    final waiting = _money(amounts['waiting_charge']);
    final previousDue = _money(
      amounts['previous_due_collected'] ?? trip['customer_previous_due'],
    );
    final changeRaw = trip['change_transfer'];
    final double change = changeRaw is Map ? _money(changeRaw['amount']) : 0.0;

    final ink = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFF8FAFF)
        : Theme.of(context).colorScheme.onSurface;
    final muted = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFB8C3D8)
        : Theme.of(context).colorScheme.onSurfaceVariant;
    const gold = Color(0xFFFFC400);

    Widget line(
      String label,
      double value, {
      bool negative = false,
      bool showZero = false,
    }) {
      if (!showZero && value.abs() < .005) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  
                  color: muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              context.strings.moneyValue(
                '${negative ? '− ' : ''}${value.abs().toStringAsFixed(2)}',
              ),
              style: TextStyle(
                
                color: ink,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF111A2D)
            : Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: gold.withValues(alpha: .55)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if(tripCategoryLabel(context,trip,'').isNotEmpty) Text(tripCategoryLabel(context,trip,''),style:Theme.of(context).textTheme.titleSmall),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: gold),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.strings.financialCard5164d8be,
                      style: TextStyle(
                        
                        color: ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      context.strings.financialCard02d58fca,
                      style: TextStyle(
                        
                        color: muted,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF202D48)
                  : Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    captain
                        ? context.strings.financialCard8b296d76
                        : context.strings.financialCarda98cf68f,
                    style: TextStyle(
                      
                      color: ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  cash == null
                      ? context.strings.financialCard82963d4d
                      : context.strings.moneyValue(cash.toStringAsFixed(2)),
                  style: TextStyle(
                    
                    color: gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          line(context.strings.financialCardc5496762, total),
          line(context.strings.financialCard4dcfdfe9, wallet),
          line(context.strings.financialCard3eab5144, incentive),
          line(context.strings.financialCarde8ea6cc8, waiting),
          line(context.strings.financialCardcfea168e, previousDue),
          line(context.strings.financialCardb593a645, discount, negative: true),
          if (change > 0) line(context.strings.financialCard10217aa6, change),
          if (captain) ...[
            const Divider(height: 18, color: Color(0xFF394966)),
            line(
              context.strings.financialCard3bdc9404,
              _money(amounts['commission_amount']),
              showZero: true,
            ),
            line(
              context.strings.financialCardc3b788c0,
              _money(amounts['captain_incentive_amount']),
            ),
            line(
              context.strings.financialCard986f250b,
              _money(amounts['captain_earnings']),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            cash == null
                ? context.strings.financialCardf22ebe52
                : wallet > 0
                ? context.strings.financialCardf9ba759e
                : context.strings.financialCard16361e3f,
            style: TextStyle(
              
              color: muted,
              fontSize: 10.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Read-only server receipt. Unknown values are never rendered as zero.
class CancellationReceiptCard extends StatelessWidget {
  const CancellationReceiptCard({super.key, required this.receipt});
  final Map<String, dynamic>? receipt;
  String amount(BuildContext context, dynamic value) {
    final parsed = value is num ? value.toDouble() : double.tryParse('$value');
    return parsed != null && parsed.isFinite && parsed >= 0
        ? context.strings.moneyValue(parsed.toStringAsFixed(2))
        : context.strings.financialCard82963d4d;
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.strings.financialCard6392399b,
            style: TextStyle(
              
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (receipt == null) Text(context.strings.financialCardef59f590),
          Text(context.strings.financialCard95d3accb),
          Text(amount(context, receipt?['wallet_refund'])),
          Text(context.strings.financialCardb4549ee9),
          Text(
            amount(
              context,
              receipt?['compensation'] ?? receipt?['cancellation_fee'],
            ),
          ),
          Text(context.strings.financialCard1da6648d),
        ],
      ),
    ),
  );
}
