import '../../l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

/// Read-only payment instructions. Only an authorized admin's server-side
/// settlement receipt may change the captain's financial balance.
class CaptainDebtInvoiceV17 extends StatefulWidget {
  const CaptainDebtInvoiceV17({super.key, this.loadInvoice, this.loadSupportPhone});
  final Future<Map<String, dynamic>> Function()? loadInvoice;
  final Future<String> Function()? loadSupportPhone;
  @override
  State<CaptainDebtInvoiceV17> createState() => _CaptainDebtInvoiceV17State();
}

class _CaptainDebtInvoiceV17State extends State<CaptainDebtInvoiceV17> {
  bool loading = true;
  String? error;
  Map<String, dynamic>? invoice;
  String supportPhone = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final reply = widget.loadInvoice != null ? await widget.loadInvoice!()
          : await Supabase.instance.client.rpc('v17_captain_invoice');
      final data = Map<String, dynamic>.from(reply as Map);
      if (data['success'] != true) {
        throw StateError(data['error']?.toString() ?? 'invoice_unavailable');
      }
      final amount = num.tryParse(data['amount_due']?.toString() ?? '');
      if (amount == null || !amount.isFinite || amount < 0) {
        throw StateError('invoice_amount_unavailable');
      }
      String phone = '';
      try {
        phone = widget.loadSupportPhone != null ? await widget.loadSupportPhone!()
            : (await SupabaseService.instance.getSetting('customer_service_phone')) ?? '';
      } catch (_) {}
      if (mounted) setState(() { invoice = data; supportPhone = phone; });
    } catch (_) {
      if (mounted) setState(() => error = 'invoice_load_failed');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = invoice;
    final due = num.tryParse(v?['amount_due']?.toString() ?? '')?.toDouble();
    final ref = v?['invoice_number']?.toString() ?? '';
    final status = v?['status']?.toString() ?? '';
    return Directionality(
      textDirection: Directionality.of(context),
      child: Scaffold(
        appBar: AppBar(title: Text(context.strings.debtInvoiceTitle),
          actions: [IconButton(tooltip: context.strings.debtInvoiceRefresh, onPressed: _load,
            icon: const Icon(Icons.refresh_rounded))]),
        body: loading
            ? Center(child: CircularProgressIndicator())
            : error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(20),
                    child: Text(context.strings.debtInvoiceLoadFailed, textAlign: TextAlign.center)))
                : ListView(padding: const EdgeInsets.all(20), children: [
                    const Icon(Icons.receipt_long_outlined,
                      color: AppTheme.gold, size: 56),
                    const SizedBox(height: 16),
                    Text(context.strings.debtInvoiceAmount(due!.toStringAsFixed(2)),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (ref.isNotEmpty) ListTile(
                      title: Text(context.strings.debtInvoiceReference),
                      subtitle: SelectableText(ref),
                      trailing: IconButton(icon: const Icon(Icons.copy_rounded),
                        onPressed: () => Clipboard.setData(ClipboardData(text: ref))),
                    ),
                    ListTile(title: Text(context.strings.debtInvoiceStatus),
                      subtitle: Text(status == 'closed' || due <= 0 ? context.strings.debtInvoicePaid : context.strings.debtInvoicePending)),
                    const Divider(),
                    Text(context.strings.debtInvoiceHelp),
                    const SizedBox(height: 16),
                    if (supportPhone.isNotEmpty) FilledButton.icon(
                      icon: const Icon(Icons.call),
                      label: Text(context.strings.debtInvoiceCall(supportPhone)),
                      onPressed: () async {
                        final safe = supportPhone.replaceAll(RegExp(r'[^0-9+]'), '');
                        if (safe.isNotEmpty) await launchUrl(Uri(scheme: 'tel', path: safe));
                      },
                    ) else Text(context.strings.debtInvoiceSupportUnavailable),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: Text(context.strings.debtInvoiceAfterPayment)),
                  ]),
      ),
    );
  }
}
