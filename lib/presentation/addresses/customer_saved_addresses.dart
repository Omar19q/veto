import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_service.dart';
import '../../services/booking_address_seed.dart';
import '../../l10n/strings.dart';
import 'address_suggestion_history.dart';

class CustomerSavedAddresses extends StatefulWidget {
  const CustomerSavedAddresses({super.key});
  @override
  State<CustomerSavedAddresses> createState() => _CustomerSavedAddressesState();
}

class _CustomerSavedAddressesState extends State<CustomerSavedAddresses> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true, _failed = false;
  bool _saving = false;
  String? _owner;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = SupabaseService.instance,
        owner = SupabaseService.instance.currentUser?.id;
    try {
      if (owner == null) throw StateError('authentication_required');
      final customer = await api.getCustomerByUserId(owner);
      if (customer == null) throw StateError('customer_required');
      final rows = await api.getCustomerAddresses(customer['id'].toString());
      if (mounted && owner == api.currentUser?.id)
        setState(() {
          _owner = owner;
          _rows = rows;
          _loading = false;
          _failed = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _failed = true;
          _rows = [];
        });
    }
  }

  Future<void> _edit(Map<String, dynamic> row) async {
    if (_saving || _owner != SupabaseService.instance.currentUser?.id) return;
    final l = context.strings;
    var label = row['label']?.toString() ?? '';
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.savedPlaces),
        content: TextFormField(
          initialValue: label,
          maxLength: 60,
          decoration: InputDecoration(labelText: l.savedNameHint),
          onChanged: (value) => label = value.trim(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'delete'),
            child: Text(l.savedDelete),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.savedCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: Text(l.savedSave),
          ),
        ],
      ),
    );
    if (!mounted ||
        action == null ||
        _owner != SupabaseService.instance.currentUser?.id)
      return;
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.savedDeleteTitle),
          content: Text(
            l.savedDeleteDescription(row['label']?.toString() ?? ''),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.savedCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.savedDelete),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
    } else if (label.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.savedEnterLabel)));
      return;
    }
    if (_owner != SupabaseService.instance.currentUser?.id) return;
    setState(() => _saving = true);
    try {
      final api = SupabaseService.instance;
      if (action == 'delete') {
        await api.deleteCustomerAddress(row['id'].toString());
      } else {
        await api.updateCustomerAddress(row['id'].toString(), {'label': label});
      }
      await _load();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.retry)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.strings;
    return Scaffold(
      appBar: AppBar(title: Text(l.savedPlaces)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_failed)
                  TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: Text(l.retry),
                  ),
                for (final row in _rows)
                  Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    color: Theme.of(context).colorScheme.surface,
                    child: ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.bookmark_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        '${row['label'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text('${row['display_address'] ?? ''}'),
                      trailing: IconButton(
                        tooltip: l.savedNameHint,
                        onPressed: _saving ? null : () => _edit(row),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      onTap: () {
                        final seed = BookingAddressSeed.saved(row);
                        if (seed != null) {
                          context.push(
                            '/trip-booking-screen',
                            extra: BookingAddressSelection(destination: seed),
                          );
                        }
                      },
                    ),
                  ),
                if (!_failed && _rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l.menuNoAddresses),
                  ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const AddressSuggestionHistory(),
                    ),
                  ),
                  icon: const Icon(Icons.edit_location_alt_outlined),
                  label: Text(l.menuAddressSuggestions),
                ),
              ],
            ),
    );
  }
}
