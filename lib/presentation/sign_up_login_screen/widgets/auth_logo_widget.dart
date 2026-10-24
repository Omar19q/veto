import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class AuthLogoWidget extends StatefulWidget {
  const AuthLogoWidget({super.key});

  @override
  State<AuthLogoWidget> createState() => _AuthLogoWidgetState();
}

class _AuthLogoWidgetState extends State<AuthLogoWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnim = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.5, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Column(
          children: [
            // Logo mark
            Container(
              width: 94,
              height: 94,
              decoration: BoxDecoration(
                color: isDark ? null : Colors.white,
                gradient: isDark
                    ? const LinearGradient(
                        colors: [Color(0xFF13182A), Color(0xFF0B0F1A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isDark
                      ? AppTheme.gold.withAlpha(155)
                      : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? AppTheme.gold.withAlpha(50)
                        : const Color(0x140B0F1A),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Image.asset(
                  'assets/images/veto_sanya_app_icon.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            const SizedBox(height: 16),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Veto ',
                    style: TextStyle(
                      fontFamily: AppTheme.productFontFamily(context),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: isDark ? AppTheme.textPrimary : const Color(0xFF0B0F1A),
                    ),
                  ),
                  TextSpan(
                    text: 'Sanya',
                    style: TextStyle(
                      fontFamily: AppTheme.productFontFamily(context),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: isDark ? AppTheme.gold : const Color(0xFFE5A800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'فيتو ثانية',
              style: TextStyle(
                fontFamily: AppTheme.productFontFamily(context),
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.textSecondary : const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 30,
                  height: 1,
                  color: isDark ? AppTheme.gold.withAlpha(102) : const Color(0xFFCBD5E1),
                ),
                const SizedBox(width: 8),
                Text(
                  'دايماً أقرب إليك',
                  style: TextStyle(
                    fontFamily: AppTheme.productFontFamily(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppTheme.textSecondary : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 30,
                  height: 1,
                  color: isDark ? AppTheme.gold.withAlpha(102) : const Color(0xFFCBD5E1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
