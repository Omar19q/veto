import 'package:flutter/material.dart';
import '../../l10n/strings.dart';

/// Controller ownership follows the dialog route lifecycle, including its exit animation.
class CustomerNameEditor extends StatefulWidget {
  const CustomerNameEditor({super.key, required this.initialName});
  final String initialName;
  @override
  State<CustomerNameEditor> createState() => _CustomerNameEditorState();
}

class _CustomerNameEditorState extends State<CustomerNameEditor> {
  late final TextEditingController controller = TextEditingController(
    text: widget.initialName,
  );
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Theme.of(context).colorScheme.surface,
    title: Text(
      context.strings.profile9cb77234,
      style: const TextStyle(),
    ),
    content: TextField(
      controller: controller,
      maxLength: 75,
      style: TextStyle(
        
        color: Theme.of(context).colorScheme.onSurface,
      ),
      decoration: InputDecoration(labelText: context.strings.profileecc98e31),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.strings.profilecb822418),
      ),
      FilledButton(
        onPressed: () {
          final value = controller.text.trim();
          if (value.length >= 2) Navigator.pop(context, value);
        },
        child: Text(context.strings.profileddfcaf9d),
      ),
    ],
  );
}
