import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Convenience only: no account data is changed by copying.
class AdminCopyButton extends StatelessWidget {
  final String text;
  final String description;
  const AdminCopyButton({super.key, required this.text,
      this.description = 'نسخ'});

  @override
  Widget build(BuildContext context) => IconButton(
    icon: const Icon(Icons.copy_rounded, color: AppTheme.gold, size: 18),
    tooltip: description,
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    onPressed: text.trim().isEmpty || text == '—' || text == 'غير متوفر' ? null : () async {
      await Clipboard.setData(ClipboardData(text: text.trim()));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('تم النسخ: $description',
            style: const TextStyle(fontFamily: 'Cairo')),
        duration: const Duration(seconds: 2),
      ));
    },
  );
}
