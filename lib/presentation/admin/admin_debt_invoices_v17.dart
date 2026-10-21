import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/staff_access_v16.dart';
import '../../services/supabase_service.dart';

class AdminDebtInvoicesV17 extends StatefulWidget {
  const AdminDebtInvoicesV17({super.key});
  @override
  State<AdminDebtInvoicesV17> createState() => _AdminDebtInvoicesV17State();
}

class _AdminDebtInvoicesV17State extends State<AdminDebtInvoicesV17> {
  bool loading = true;
  bool owner = false;
  String? error;
  List<Map<String, dynamic>> rows = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final access = await StaffAccessV16.load();
      if (!access.can('finance.view')) throw StateError('not_authorized');
      final response = await Supabase.instance.client.rpc('v17_admin_debt_overview');
      final entries = (response as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
      if (mounted) setState(() { rows = entries; owner = access.owner; });
    } catch (_) {
      if (mounted) setState(() => error = 'غير مصرح أو تعذر تحميل الفواتير. تأكد من نشر SQL V17.');
    } finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> _confirm(Map<String, dynamic> invoice) async {
    // Distinct request ID per approved receipt: same ID used for retry within
    // this dialog, and the server enforces exactly-once ledger posting.
    final operationId = SupabaseService.newFinancialRequestId();
    final amount = TextEditingController();
    bool busy = false;
    String? message;
    try {
      await showDialog<void>(context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
          title: const Text('تأكيد تحصيل مالي فعلي'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('الفاتورة: ${invoice['invoice_number'] ?? ''}'),
            Text('المديونية الحالية: ${invoice['amount_due']} جنيه'),
            const SizedBox(height: 10),
            TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'المبلغ الذي تم استلامه فعليًا')),
            const SizedBox(height: 8),
            const Text('ممنوع اعتماد مبلغ لم يتم استلامه. الإجراء يسجل التسوية في دفتر V9 القديم.'),
            if (message != null) Text(message!, style: const TextStyle(color: Colors.red)),
          ]),
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(onPressed: busy ? null : () async {
              final paid = double.tryParse(amount.text.trim());
              if (paid == null || !paid.isFinite || paid <= 0 ||
                  !RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(amount.text.trim())) {
                update(() => message = 'أدخل مبلغًا صحيحًا حتى منزلتين عشريتين.');
                return;
              }
              update(() { busy = true; message = null; });
              try {
                final result = await Supabase.instance.client.rpc('v17_confirm_captain_payment', params: {
                  'p_invoice_id': invoice['invoice_id'], 'p_amount': paid, 'p_operation_id': operationId,
                });
                final data = Map<String, dynamic>.from(result as Map);
                if (data['success'] != true) throw StateError(data['error']?.toString() ?? 'payment_failed');
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) _load();
              } catch (_) {
                if (ctx.mounted) update(() => message = 'فشل التأكيد. راجع سجل الحركة قبل إعادة المحاولة بنفس رقم العملية.');
              } finally { if (ctx.mounted) update(() => busy = false); }
            }, child: Text(busy ? 'جارٍ الاعتماد' : 'تأكيد استلام المبلغ')),
          ],
        )));
    } finally { amount.dispose(); }
  }

  Future<void> _openInvoice(Map<String, dynamic> entry) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'v17_admin_open_debt_invoice',
        params: {'p_captain_id': entry['captain_id']},
      );
      final data = Map<String, dynamic>.from(response as Map);
      if (data['success'] != true) throw StateError('invoice_unavailable');
      await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إنشاء الفاتورة.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Column(children: [
      ListTile(title: const Text('فواتير ومديونية الكباتن'),
        subtitle: const Text('يظهر هنا من اقترب من الحد (80%) ومن لديه فاتورة مفتوحة. لا يتم تخفيض المديونية بدون تحصيل فعلي مؤكد.'),
        trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: _load)),
      if (loading) const LinearProgressIndicator(),
      if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
      Expanded(child: rows.isEmpty && !loading
        ? const Center(child: Text('لا توجد فواتير مفتوحة أو مديونيات قريبة من الحد'))
        : ListView.builder(itemCount: rows.length, itemBuilder: (ctx, i) {
            final item = rows[i];
            final due = (item['amount_due'] as num?)?.toDouble() ?? 0;
            final limit = (item['debt_limit'] as num?)?.toDouble() ?? 150;
            final near = limit > 0 && due >= limit * .8;
            return Card(child: ListTile(
              title: Text('${item['captain_name'] ?? 'كابتن'} — ${due.toStringAsFixed(2)} ج'),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('الحد: ${limit.toStringAsFixed(2)} ج • ${near ? 'مقترب من حد المديونية / غير مسدد' : 'مديونية قائمة'}'),
                Text('الهاتف: ${item['captain_phone'] ?? ''}'),
                Text('الفاتورة: ${item['invoice_number'] ?? 'لم تُفتح بعد'}'),
              ]),
              isThreeLine: true,
              trailing: owner && due > 0
                ? item['invoice_id'] != null
                    ? FilledButton(onPressed: () => _confirm(item), child: const Text('اعتماد سداد'))
                    : OutlinedButton(onPressed: () => _openInvoice(item), child: const Text('إنشاء فاتورة'))
                : null,
            ));
          })),
    ]),
  );
}
