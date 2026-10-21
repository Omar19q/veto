import '../../../l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/supabase_service.dart';

class ChangeTransferWidget extends StatefulWidget {
  final String tripId;
  const ChangeTransferWidget({super.key, required this.tripId});

  @override
  State<ChangeTransferWidget> createState() => _ChangeTransferWidgetState();
}

class _ChangeTransferWidgetState extends State<ChangeTransferWidget> {
  final _amount = TextEditingController();
  bool _busy = false;
  bool _done = false;
  String? _message;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _transfer() async {
    if (_busy || _done) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await SupabaseService.instance.transferChangeToCustomer(
        tripId: widget.tripId,
        amount: _amount.text,
      );
      if (!mounted) return;
      setState(() {
        _done = true;
        final balance = (result['captain_balance'] as num?)?.toDouble() ?? 0;
        _message =
            context.strings.changeTransferSuccess(result['amount']?.toString() ?? '—',
              balance < 0 ? context.strings.changeTransferDebt : context.strings.changeTransferBalance,
              balance.abs().toStringAsFixed(2));
      });
    } on FormatException {
      if (mounted) setState(() => _message = context.strings.changeTransferInvalidAmount);
    } on PostgrestException catch (error) {
      final text = switch (error.message) {
        'change_already_transferred' =>
          context.strings.changeTransferAlready,
        'completed_cash_trip_required' =>
          context.strings.changeTransferCashOnly,
        'not_assigned_captain' => context.strings.changeTransferAssignedOnly,
        _ => context.strings.changeTransferFailed,
      };
      if (mounted) setState(() => _message = text);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = context.strings.changeTransferUnconfirmed,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _amount,
          enabled: !_busy && !_done,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: context.strings.changeTransferAmount,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _busy || _done ? null : _transfer,
          icon: const Icon(Icons.account_balance_wallet_outlined),
          label: Text(_busy ? context.strings.changeTransferBusy : context.strings.changeTransferAction),
        ),
        if (_message != null) Text(_message!, textDirection: Directionality.of(context)),
      ],
    );
  }
}
