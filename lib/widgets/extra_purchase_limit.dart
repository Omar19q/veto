import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../l10n/strings.dart';

String normalizePurchaseAmount(String input) => String.fromCharCodes(
  input.trim().runes.map(
    (r) => r >= 0x660 && r <= 0x669
        ? r - 0x660 + 48
        : r >= 0x6f0 && r <= 0x6f9
        ? r - 0x6f0 + 48
        : r,
  ),
).replaceAll('٫', '.');
String? validateExtraPurchaseAmount(
  String? input, {
  AppLocalizations? strings,
}) {
  final text = normalizePurchaseAmount(input ?? '');
  if (text.isEmpty) return null;
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text))
    return strings?.extraInvalidAmount ??
        'اكتب مبلغ صحيح بالجنيه، بحد أقصى رقمين بعد العلامة';
  final value = double.tryParse(text);
  if (value == null || !value.isFinite || value < 0)
    return strings?.extraInvalidAmount ?? 'اكتب مبلغ صحيح';
  if (value > 500)
    return strings?.bookingFinalCopyb60ed4c8 ??
        'الطلبات الإضافية يجب ألا تتجاوز 500 جنيه';
  return null;
}

class ExtraPurchaseLimitBanner extends StatelessWidget {
  const ExtraPurchaseLimitBanner({super.key});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0x66EDBA47)),
    ),
    child: Row(
      children: [
        Icon(
          Icons.shopping_bag_outlined,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            context.strings.bookingFinalCopyb60ed4c8,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    ),
  );
}
