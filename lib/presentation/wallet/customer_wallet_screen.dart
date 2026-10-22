import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/strings.dart';
import '../../routes/app_routes.dart';
import '../../services/supabase_service.dart';

class CustomerWalletScreen extends StatefulWidget {
  const CustomerWalletScreen({super.key});

  @override
  State<CustomerWalletScreen> createState() => _CustomerWalletScreenState();
}

class _CustomerWalletScreenState extends State<CustomerWalletScreen> {
  double _balance = 0;
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadFailed = false;
      });
    }
    try {
      final svc = SupabaseService.instance;
      final user = svc.currentUser;
      if (user == null) throw StateError('wallet_requires_session');
      final customer = await svc.getCustomerByUserId(user.id);
      if (customer == null) throw StateError('wallet_customer_unavailable');
      final cid = customer['id'] as String;
      final balance = await svc
          .getWalletBalance(cid)
          .timeout(const Duration(seconds: 15));
      final txs = await svc
          .getWalletTransactions(cid)
          .timeout(const Duration(seconds: 15));
      if (svc.currentUser?.id != user.id) {
        throw StateError('wallet_session_changed');
      }
      if (mounted) {
        setState(() {
          _balance = balance;
          _transactions = txs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadFailed = true;
        });
      }
    }
  }

  String _txTypeLabel(String type, [String? description]) {
    final d = description?.trim() ?? '';
    if (d.contains('استرداد حجز المحفظة') ||
        d.contains('استرداد مبلغ المحفظة')) {
      return context.strings.wallet30454aef;
    }
    if (d.contains('تعويض العميل عن إلغاء الكابتن')) {
      return context.strings.wallet94d8f009;
    }
    if (d.contains('تعويض الكابتن عن الإلغاء') ||
        d.contains('رسوم إلغاء الرحلة')) {
      return context.strings.wallet08b4509e;
    }
    if (d.contains('تصحيح استرداد مكرر')) {
      return context.strings.wallet73a173f7;
    }
    if (type == 'promo' && description?.startsWith('مكافأة شحن ترويجية') == true) {
      return context.strings.wallet7a70ab91;
    }
    if (type == 'credit' && description?.startsWith('شحن محفظة - مبلغ مدفوع') == true) {
      return context.strings.wallet4626aabc;
    }
    final labels = {
      'credit': context.strings.wallet9da2b774,
      'change_transfer': context.strings.walletdd1bba5b,
      'debit': context.strings.walletec9ccd93,
      'promo': context.strings.walletf11b8c52,
      'trip': context.strings.walleta674a023,
      'adjustment': context.strings.wallet113d570d,
      'commission': context.strings.wallet1cae7479,
      'penalty': context.strings.wallete343e4a4,
      'settlement_credit': context.strings.walleta94f951d,
      'settlement_payment': context.strings.wallete1853a0c,
      'incentive': context.strings.wallet6432e51d,
    };
    return labels[type] ?? type;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final primaryAccent = isDark ? const Color(0xFFFFC107) : colorScheme.primary;
    final moneyColor = isDark ? const Color(0xFFFFC107) : const Color(0xFF10B981);

    return Directionality(
      textDirection: Directionality.of(context),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: _loadFailed
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(context.strings.accountLoadFailed),
                      TextButton(
                        onPressed: _load,
                        child: Text(context.strings.retry),
                      ),
                    ],
                  ),
                )
              : _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: primaryAccent),
                )
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? const [Color(0xFF1A1400), Color(0xFF2A2000)]
                                : [
                                    colorScheme.surface,
                                    colorScheme.surfaceContainerHighest,
                                  ],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFFFFC107).withAlpha(77)
                                : colorScheme.outlineVariant,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.strings.wallet40c7d7e2,
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.strings.moneyValue(
                                _balance.toStringAsFixed(2),
                              ),
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                color: moneyColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.strings.wallet9b7f8de8,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await context.push(AppRoutes.walletTopup);
                                  if (mounted) _load();
                                },
                                icon: const Icon(Icons.add_circle_outline),
                                label: Text(
                                  context.strings.wallet6a50382f,
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryAccent,
                                  foregroundColor: isDark
                                      ? const Color(0xFF0B1428)
                                      : Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Text(
                          context.strings.walletaf7fb819,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    if (_transactions.isEmpty)
                      SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              context.strings.walletf0795392,
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final tx = _transactions[index];
                          final type = tx['tx_type'] as String? ?? '';
                          final amount =
                              (tx['amount'] as num?)?.toDouble() ?? 0;
                          final isCredit =
                              type == 'credit' ||
                              type == 'change_transfer' ||
                              type == 'promo' ||
                              type == 'settlement_credit' ||
                              type == 'incentive';
                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color:
                                        (isCredit
                                                ? const Color(0xFF4CAF50)
                                                : const Color(0xFFEF5350))
                                            .withAlpha(31),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isCredit
                                        ? Icons.arrow_downward_rounded
                                        : Icons.arrow_upward_rounded,
                                    color: isCredit
                                        ? const Color(0xFF4CAF50)
                                        : const Color(0xFFEF5350),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _txTypeLabel(
                                          type,
                                          tx['description']?.toString(),
                                        ),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                        ),
                                      ),
                                      if (tx['description'] != null)
                                        Text(
                                          tx['description'] as String,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  context.strings.moneyValue(
                                    '${isCredit ? '+' : '-'}${amount.toStringAsFixed(2)}',
                                  ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isCredit
                                        ? const Color(0xFF4CAF50)
                                        : const Color(0xFFEF5350),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }, childCount: _transactions.length),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
        ),
      ),
    );
  }
}
