import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class CaptainEarningsWidget extends StatelessWidget {
  final double todayEarnings;
  final double weekEarnings;
  final double monthEarnings;
  final int todayTrips;
  final double settlementDebt;
  final double debtThreshold;
  final VoidCallback? onSupportTap;

  const CaptainEarningsWidget({
    required this.todayEarnings,
    required this.weekEarnings,
    required this.monthEarnings,
    required this.todayTrips,
    required this.settlementDebt,
    required this.debtThreshold,
    this.onSupportTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasDebt = settlementDebt > 0;
    final bool debtWarning =
        debtThreshold > 0 && settlementDebt >= debtThreshold * 0.7;
    final bool debtBlocked =
        debtThreshold > 0 && settlementDebt >= debtThreshold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFF252525), Color(0xFF1D1D1D)],
            ),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.gold.withAlpha(25),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: AppTheme.gold,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'أرباحي',
                      style: TextStyle(
                        
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.directions_car_rounded,
                            color: AppTheme.textSecondary,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$todayTrips رحلة اليوم',
                            style: TextStyle(
                              
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      todayEarnings.toStringAsFixed(0),
                      style: TextStyle(
                        
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.gold,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'جنيه',
                        style: TextStyle(
                          
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'اليوم',
                          style: TextStyle(
                            
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Icon(
                          Icons.trending_up_rounded,
                          color: AppTheme.successLight,
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: AppTheme.cardBorder),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _EarningPeriod(
                        label: 'هذا الأسبوع',
                        amount: weekEarnings,
                        icon: Icons.calendar_view_week_rounded,
                      ),
                    ),
                    Container(width: 1, height: 40, color: AppTheme.cardBorder),
                    Expanded(
                      child: _EarningPeriod(
                        label: 'هذا الشهر',
                        amount: monthEarnings,
                        icon: Icons.calendar_month_rounded,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SettlementCard(
          debt: settlementDebt,
          threshold: debtThreshold,
          hasDebt: hasDebt,
          debtWarning: debtWarning,
          debtBlocked: debtBlocked,
          onSupportTap: onSupportTap,
        ),
      ],
    );
  }
}

class _EarningPeriod extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;

  const _EarningPeriod({
    required this.label,
    required this.amount,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 16),
        const SizedBox(height: 4),
        Text(
          '${amount.toStringAsFixed(0)} ج',
          style: TextStyle(
            
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SettlementCard extends StatelessWidget {
  final double debt;
  final double threshold;
  final bool hasDebt;
  final bool debtWarning;
  final bool debtBlocked;
  final VoidCallback? onSupportTap;

  const _SettlementCard({
    required this.debt,
    required this.threshold,
    required this.hasDebt,
    required this.debtWarning,
    required this.debtBlocked,
    this.onSupportTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color cardColor = debtBlocked
        ? const Color(0xFF2B0D0D)
        : debtWarning
        ? const Color(0xFF2B1A00)
        : AppTheme.surface;

    final Color borderColor = debtBlocked
        ? AppTheme.errorLight.withAlpha(100)
        : debtWarning
        ? AppTheme.gold.withAlpha(100)
        : AppTheme.cardBorder;

    final Color accentColor = debtBlocked
        ? AppTheme.errorLight
        : debtWarning
        ? AppTheme.gold
        : AppTheme.successLight;

    final double progressValue = hasDebt && threshold > 0
        ? (debt / threshold).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Icon(
                  debtBlocked
                      ? Icons.block_rounded
                      : debtWarning
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_rounded,
                  color: accentColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'حالة التسوية',
                      style: TextStyle(
                        
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      debtBlocked
                          ? 'تجاوزت الحد — لا يمكن استقبال طلبات'
                          : debtWarning
                          ? 'اقتربت من الحد المسموح'
                          : 'وضعك المالي جيد',
                      style: TextStyle(
                        
                        fontSize: 11,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasDebt)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${debt.toStringAsFixed(0)} ج',
                      style: TextStyle(
                        
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                    Text(
                      'مستحق',
                      style: TextStyle(
                        
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (hasDebt && threshold > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4.0),
                    child: LinearProgressIndicator(
                      value: progressValue,
                      backgroundColor: AppTheme.cardBorder,
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${threshold.toStringAsFixed(0)} ج حد',
                  style: TextStyle(
                    
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
          if (debtBlocked && onSupportTap != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onSupportTap,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.errorLight.withAlpha(20),
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: AppTheme.errorLight.withAlpha(80)),
                ),
                child: Center(
                  child: Text(
                    'تواصل مع الدعم للتسوية',
                    style: TextStyle(
                      
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.errorLight,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
