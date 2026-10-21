import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class VetoAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBack;
  final VoidCallback? onBack;
  final bool useGradient;

  const VetoAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBack = false,
    this.onBack,
    this.useGradient = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: useGradient
            ? const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0B0F1A), Color(0xFF13182A)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              )
            : null,
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 16,
          leading: showBack
              ? IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppTheme.textPrimary,
                    size: 20,
                  ),
                  onPressed: onBack ?? () => Navigator.of(context).pop(),
                )
              : null,
          title: Text(
            title,
            style: const TextStyle(
              
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          actions: actions,
        ),
      ),
    );
  }
}