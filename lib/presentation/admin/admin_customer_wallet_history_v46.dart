import 'package:flutter/material.dart';

import '../../services/supabase_service.dart';
import '../../theme/admin_theme.dart';

/// Read-only, permission-gated history. No wallet writes or balance calculations.
class AdminCustomerWalletHistoryV46 extends StatefulWidget {
  final String customerId;
  const AdminCustomerWalletHistoryV46({super.key, required this.customerId});

  @override
  State<AdminCustomerWalletHistoryV46> createState() =>
      _AdminCustomerWalletHistoryV46State();
}

class _AdminCustomerWalletHistoryV46State
    extends State<AdminCustomerWalletHistoryV46> {
  late Future<List<Map<String, dynamic>>> _records = _load();

  Future<List<Map<String, dynamic>>> _load() =>
      SupabaseService.instance.getWalletTransactions(widget.customerId,
          limit: 100);

  void _refresh() => setState(() => _records = _load());

  String _date(dynamic raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (d == null) return '—';
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(d.day)}/${pad(d.month)}/${d.year} · ${pad(d.hour)}:${pad(d.minute)}';
  }

  bool _credit(String type) =>
      const {'credit', 'promo', 'refund', 'change_transfer'}.contains(type);

  String _label(String type) => switch (type) {
    'credit' => 'إضافة رصيد',
    'promo' => 'مكافأة',
    'penalty' => 'غرامة',
    'debit' => 'خصم',
    'refund' => 'استرداد',
    'change_transfer' => 'فكة',
    'adjustment' => 'تعديل إداري',
    _ => 'عملية محفظة',
  };

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: FutureBuilder<List<Map<String, dynamic>>>(
      future: _records,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(16),
            child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('تعذر عرض سجل المحفظة. راجع صلاحية عرض المعاملات.',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
            TextButton.icon(onPressed: _refresh,
                icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
          ]);
        }
        final rows = snapshot.data ?? [];
        if (rows.isEmpty) return const Padding(
          padding: EdgeInsets.all(16),
          child: Text('لا توجد معاملات مسجلة',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
        );
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: Text('آخر ${rows.length} عملية',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700,
                  color: AdminTheme.ink))),
            IconButton(onPressed: _refresh,
                tooltip: 'تحديث السجل', icon: const Icon(Icons.refresh)),
          ]),
          ...rows.map((tx) {
            final type = tx['tx_type']?.toString() ?? '';
            final amount = num.tryParse('${tx['amount'] ?? 0}') ?? 0;
            final balance = num.tryParse('${tx['balance_after'] ?? ''}');
            final positive = _credit(type);
            final detail = tx['description']?.toString().trim() ?? '';
            return Card(
              color: AdminTheme.surfaceSoft,
              child: Padding(padding: const EdgeInsets.all(10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(positive ? Icons.add_circle_outline : Icons.receipt_long,
                      color: positive ? const Color(0xFF25815D) : AdminTheme.goldDark,
                      size: 19),
                    const SizedBox(width: 9),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(detail.isEmpty ? _label(type) : detail,
                          style: TextStyle(fontFamily: 'Cairo',
                            fontWeight: FontWeight.w700, color: AdminTheme.ink,
                            fontSize: 12)),
                        Text(_date(tx['created_at']), style: TextStyle(
                          fontFamily: 'Cairo', fontSize: 11, color: AdminTheme.muted)),
                        if (balance != null) Text(
                          'الرصيد بعد العملية: ${balance.toStringAsFixed(2)} ج',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 11,
                            color: AdminTheme.muted)),
                      ],
                    )),
                    const SizedBox(width: 8),
                    Text('${positive ? '+' : '−'}${amount.abs().toStringAsFixed(2)} ج',
                      style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: positive ? const Color(0xFF25815D) : AdminTheme.ink)),
                  ],
                ),
              ),
            );
          }),
        ]);
      },
    ),
  );
}
