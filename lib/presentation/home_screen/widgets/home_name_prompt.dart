import '../../../l10n/strings.dart';
import 'package:flutter/material.dart';

import '../../../services/supabase_service.dart';

/// Small optional profile completion card.
class HomeNamePrompt extends StatelessWidget {
  final VoidCallback onAddName;
  const HomeNamePrompt({super.key, required this.onAddName});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onAddName,
        child: Ink(
          decoration: BoxDecoration(
            gradient:  LinearGradient(
              colors: [Theme.of(context).colorScheme.primaryContainer, Theme.of(context).colorScheme.surface],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Theme.of(context).colorScheme.primary.withAlpha(140)),
          ),
          padding: const EdgeInsets.all(13),
          child:  Row(
            children: [
              Icon(Icons.person_add_alt_1_rounded, color: Theme.of(context).colorScheme.primary, size: 26),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.strings.homeeb4cee6e,
                      style: TextStyle(
                        
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      context.strings.home05fb123d,
                      style: TextStyle(
                        
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_back_ios_new_rounded, color: Theme.of(context).colorScheme.primary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeNameInputSheet extends StatefulWidget {
  final String customerId;
  final ValueChanged<String> onSaved;

  const HomeNameInputSheet({
    super.key,
    required this.customerId,
    required this.onSaved,
  });

  @override
  State<HomeNameInputSheet> createState() => _HomeNameInputSheetState();
}

class _HomeNameInputSheetState extends State<HomeNameInputSheet> {
  final TextEditingController _nameController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameController.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.length < 2) {
      setState(() => _error = context.strings.home4fabeda0);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await SupabaseService.instance.updateCustomerName(widget.customerId, name);
      widget.onSaved(name);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = context.strings.home0bfd0492;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: Directionality.of(context),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          24,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
               Icon(Icons.person_pin_rounded, color: Theme.of(context).colorScheme.primary, size: 40),
              const SizedBox(height: 10),
               Text(
                context.strings.homeb658c871,
                textAlign: TextAlign.center,
                style: TextStyle(
                  
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
               Text(
                context.strings.homed017c069,
                textAlign: TextAlign.center,
                style: TextStyle(
                  
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                enabled: !_saving,
                autofocus: true,
                onSubmitted: (_) => _save(),
                style:  TextStyle( color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: context.strings.home84e2331e,
                  hintText: context.strings.home2bd32fda,
                  prefixIcon:  Icon(Icons.person_outline_rounded, color: Theme.of(context).colorScheme.primary),
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_rounded),
                label:  Text(
                  context.strings.homea49e25ed,
                  style: TextStyle( fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child:  Text(
                  context.strings.home0708df98,
                  style: TextStyle( color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
