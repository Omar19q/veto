import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? ctaLabel;
  final VoidCallback? onCta;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.ctaLabel,
    this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Icon(icon, size: 36, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(
                  
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              if (ctaLabel != null && onCta != null) ...[
                const SizedBox(height: 24),
                ElevatedButton(onPressed: onCta, child: Text(ctaLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}