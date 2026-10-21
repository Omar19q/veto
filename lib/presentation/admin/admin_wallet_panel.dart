import '../../services/admin_directory_pager_v15.dart';
import 'package:flutter/material.dart';
import '../../widgets/admin_copy_button.dart';
import '../../services/supabase_service.dart';
import '../../theme/admin_theme.dart';

class AdminWalletPanel extends StatefulWidget {
  const AdminWalletPanel({super.key});

  @override
  State<AdminWalletPanel> createState() => _AdminWalletPanelState();
}

class _AdminWalletPanelState extends State<AdminWalletPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _captains = [];
  String _query = '';
  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> rows) => rows
      .where(
        (r) => '${r['full_name'] ?? ''} ${r['phone'] ?? ''}'
            .toLowerCase()
            .contains(_query.trim().toLowerCase()),
      )
      .toList();
  bool _isLoading = true;
  final _customerPager = AdminDirectoryPagerV15('customers');
  final _captainPager = AdminDirectoryPagerV15('captains');
  void _syncPages() {
    if (mounted)
      setState(() {
        _customers = List.of(_customerPager.rows);
        _captains = List.of(_captainPager.rows);
        _isLoading = _customerPager.loading || _captainPager.loading;
      });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _customerPager.addListener(_syncPages);
    _captainPager.addListener(_syncPages);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customerPager.dispose();
    _captainPager.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await Future.wait([_customerPager.refresh(), _captainPager.refresh()]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AdminTheme.surface,
          child: TabBar(
            controller: _tabController,
            labelColor: AdminTheme.goldDark,
            unselectedLabelColor: AdminTheme.muted,
            indicatorColor: AdminTheme.goldDark,
            labelStyle: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w700,
            ),
            tabs: [
              Tab(text: 'محافظ العملاء'),
              Tab(text: 'محافظ الكباتن'),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: TextField(
            onChanged: (v) {
              setState(() => _query = v);
              _customerPager.search(v);
              _captainPager.search(v);
            },
            style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'بحث بالاسم أو رقم الهاتف',
              hintStyle: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: AdminTheme.goldDark),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _CustomerWalletList(
                      customers: _filtered(_customers),
                      scroll: _customerPager.scroll,
                      onRefresh: _load,
                    ),
                    _CaptainWalletList(
                      captains: _filtered(_captains),
                      scroll: _captainPager.scroll,
                      onRefresh: _load,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _CustomerWalletList extends StatelessWidget {
  final List<Map<String, dynamic>> customers;
  final VoidCallback onRefresh;
  final ScrollController scroll;

  const _CustomerWalletList({
    required this.customers,
    required this.onRefresh,
    required this.scroll,
  });

  @override
  Widget build(BuildContext context) {
    if (customers.isEmpty) {
      return Center(
        child: Text(
          'لا يوجد عملاء',
          style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.muted),
        ),
      );
    }
    return ListView.separated(
      controller: scroll,
      padding: EdgeInsets.all(16),
      itemCount: customers.length,
      separatorBuilder: (_, __) => SizedBox(height: 8),
      itemBuilder: (context, i) {
        final c = customers[i];
        final balance = (c['wallet_balance'] as num?)?.toDouble() ?? 0;
        return ListTile(
          tileColor: AdminTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            c['full_name'] as String? ?? 'بدون اسم',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: AdminTheme.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Row(
            children: [
              Flexible(
                child: Text(
                  c['phone'] as String? ?? '',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: AdminTheme.muted,
                    fontSize: 12,
                  ),
                ),
              ),
              AdminCopyButton(
                text: c['phone']?.toString() ?? '',
                description: 'رقم صاحب المحفظة',
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${balance.toStringAsFixed(2)} ج',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700,
                  color: balance >= 0 ? AdminTheme.goldDark : Color(0xFFEF5350),
                ),
              ),
              SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.edit_rounded,
                  color: AdminTheme.goldDark,
                  size: 18,
                ),
                onPressed: () => _showAdjustDialog(context, c),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAdjustDialog(BuildContext context, Map<String, dynamic> customer) {
    final requestId = SupabaseService.newFinancialRequestId();
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    String txType = 'credit';
    bool isSaving = false;
    String? message;
    bool success = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AdminTheme.surface,
            title: Text(
              'تعديل محفظة: ${customer['full_name'] ?? ''}',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: AdminTheme.ink,
                fontSize: 16,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'الرصيد الحالي: ${(customer['wallet_balance'] as num?)?.toStringAsFixed(2) ?? '0'} ج',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: AdminTheme.goldDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: txType,
                  dropdownColor: AdminTheme.surfaceSoft,
                  style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
                  decoration: _inputDec('نوع العملية'),
                  items: [
                    DropdownMenuItem(
                      value: 'credit',
                      child: Text(
                        'إيداع',
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'debit',
                      child: Text('خصم', style: TextStyle(fontFamily: 'Cairo')),
                    ),
                    DropdownMenuItem(
                      value: 'adjustment',
                      child: Text(
                        'تعديل',
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                  ],
                  onChanged: (v) => setS(() => txType = v!),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
                  decoration: _inputDec('المبلغ (جنيه)'),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
                  decoration: _inputDec('السبب'),
                ),
                if (message != null) ...[
                  SizedBox(height: 12),
                  Text(
                    message!,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: success ? Color(0xFF4CAF50) : Color(0xFFEF5350),
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'إلغاء',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: AdminTheme.muted,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.goldDark,
                  foregroundColor: Color(0xFF0B0F1A),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        final amount = double.tryParse(amountCtrl.text.trim());
                        if (amount == null || amount <= 0) {
                          setS(() {
                            message = 'أدخل مبلغاً صحيحاً';
                            success = false;
                          });
                          return;
                        }
                        setS(() => isSaving = true);
                        try {
                          await SupabaseService.instance
                              .adminAdjustCustomerWallet(
                                customerId: customer['id'] as String,
                                requestId: requestId,
                                amount: amount,
                                txType: txType,
                                reason: reasonCtrl.text.trim().isNotEmpty
                                    ? reasonCtrl.text.trim()
                                    : 'تعديل إداري',
                              );
                          setS(() {
                            isSaving = false;
                            message = 'تم التعديل بنجاح ✓';
                            success = true;
                          });
                          await Future<void>.delayed(
                            Duration(milliseconds: 250),
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          onRefresh();
                        } catch (e) {
                          setS(() {
                            isSaving = false;
                            message = 'خطأ: $e';
                            success = false;
                          });
                        }
                      },
                child: isSaving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF0B0F1A),
                        ),
                      )
                    : Text(
                        'تأكيد',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDec(String label) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(
      fontFamily: 'Cairo',
      color: AdminTheme.muted,
      fontSize: 13,
    ),
    filled: true,
    fillColor: AdminTheme.surfaceSoft,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AdminTheme.borderSoft),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AdminTheme.borderSoft),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AdminTheme.goldDark),
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}

class _CaptainWalletList extends StatelessWidget {
  final List<Map<String, dynamic>> captains;
  final VoidCallback onRefresh;
  final ScrollController scroll;

  const _CaptainWalletList({
    required this.captains,
    required this.onRefresh,
    required this.scroll,
  });

  @override
  Widget build(BuildContext context) {
    if (captains.isEmpty) {
      return Center(
        child: Text(
          'لا يوجد كباتن',
          style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.muted),
        ),
      );
    }
    return ListView.separated(
      controller: scroll,
      padding: EdgeInsets.all(16),
      itemCount: captains.length,
      separatorBuilder: (_, __) => SizedBox(height: 8),
      itemBuilder: (context, i) {
        final c = captains[i];
        final earnings = (c['total_earnings'] as num?)?.toDouble() ?? 0;
        final settlement = (c['settlement_debt'] as num?)?.toDouble() ?? 0;
        final companyDue = settlement < 0 ? -settlement : 0.0;
        final captainCredit = settlement > 0 ? settlement : 0.0;
        return ListTile(
          tileColor: AdminTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            c['full_name'] as String? ?? 'بدون اسم',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: AdminTheme.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      c['phone'] as String? ?? '',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: AdminTheme.muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  AdminCopyButton(
                    text: c['phone']?.toString() ?? '',
                    description: 'رقم الكابتن',
                  ),
                ],
              ),
              Text(
                'أرباح الرحلات (تقارير): ${earnings.toStringAsFixed(2)} ج | رصيد الكابتن الموحد: ${captainCredit > 0
                    ? '+${captainCredit.toStringAsFixed(2)}'
                    : companyDue > 0
                    ? '-${companyDue.toStringAsFixed(2)}'
                    : '0.00'} ج',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: AdminTheme.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          trailing: IconButton(
            icon: Icon(
              Icons.edit_rounded,
              color: AdminTheme.goldDark,
              size: 18,
            ),
            onPressed: () => _showCaptainAdjustDialog(context, c),
          ),
        );
      },
    );
  }

  void _showCaptainAdjustDialog(
    BuildContext context,
    Map<String, dynamic> captain,
  ) {
    final requestId = SupabaseService.newFinancialRequestId();
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    String txType = 'settlement_credit';
    bool isSaving = false;
    String? message;
    bool success = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AdminTheme.surface,
            title: Text(
              'محفظة وتسوية: ${captain['full_name'] ?? ''}',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: AdminTheme.ink,
                fontSize: 16,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'الأرباح: ${(captain['total_earnings'] as num?)?.toStringAsFixed(2) ?? '0'} ج',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: AdminTheme.goldDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'رصيد المحفظة/التسوية: ${((captain['settlement_debt'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} ج',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: AdminTheme.goldDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  ((captain['settlement_debt'] as num?)?.toDouble() ?? 0) < 0
                      ? 'المستحق للشركة: ${(((captain['settlement_debt'] as num?)?.toDouble() ?? 0).abs()).toStringAsFixed(2)} ج'
                      : 'رصيد التسوية للكابتن: ${((captain['settlement_debt'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} ج',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Color(0xFFEF5350),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: txType,
                  dropdownColor: AdminTheme.surfaceSoft,
                  style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
                  decoration: _inputDec('نوع العملية'),
                  items: [
                    DropdownMenuItem(
                      value: 'credit',
                      child: Text(
                        'إضافة رصيد للكابتن',
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'debit',
                      child: Text(
                        'خصم من رصيد الكابتن',
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'settlement_payment',
                      child: Text(
                        'سداد دين التسوية',
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'penalty',
                      child: Text(
                        'إضافة دين',
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'settlement_credit',
                      child: Text(
                        'إضافة رصيد للكابتن',
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'adjustment',
                      child: Text(
                        'إضافة رصيد للكابتن',
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                  ],
                  onChanged: (v) => setS(() => txType = v!),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
                  decoration: _inputDec('المبلغ (جنيه)'),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  style: TextStyle(fontFamily: 'Cairo', color: AdminTheme.ink),
                  decoration: _inputDec('السبب'),
                ),
                if (message != null) ...[
                  SizedBox(height: 12),
                  Text(
                    message!,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: success ? Color(0xFF4CAF50) : Color(0xFFEF5350),
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'إلغاء',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: AdminTheme.muted,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.goldDark,
                  foregroundColor: Color(0xFF0B0F1A),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        final amount = double.tryParse(amountCtrl.text.trim());
                        if (amount == null || amount <= 0) {
                          setS(() {
                            message = 'أدخل مبلغاً صحيحاً';
                            success = false;
                          });
                          return;
                        }
                        setS(() => isSaving = true);
                        try {
                          await SupabaseService.instance
                              .adminAdjustCaptainWallet(
                                captainId: captain['id'] as String,
                                requestId: requestId,
                                amount: amount,
                                txType: txType,
                                reason: reasonCtrl.text.trim().isNotEmpty
                                    ? reasonCtrl.text.trim()
                                    : 'تعديل إداري',
                              );
                          setS(() {
                            isSaving = false;
                            message = 'تم التعديل بنجاح ✓';
                            success = true;
                          });
                          await Future<void>.delayed(
                            Duration(milliseconds: 250),
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          onRefresh();
                        } catch (e) {
                          setS(() {
                            isSaving = false;
                            message = 'خطأ: $e';
                            success = false;
                          });
                        }
                      },
                child: isSaving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF0B0F1A),
                        ),
                      )
                    : Text(
                        'تأكيد',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDec(String label) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(
      fontFamily: 'Cairo',
      color: AdminTheme.muted,
      fontSize: 13,
    ),
    filled: true,
    fillColor: AdminTheme.surfaceSoft,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AdminTheme.borderSoft),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AdminTheme.borderSoft),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AdminTheme.goldDark),
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}
