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
                gradient: const LinearGradient(
                  colors: [Color(0xFF111827), Color(0xFF080B12)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: AppTheme.gold.withAlpha(155),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.gold.withAlpha(64),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
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
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Veto ',
                    style: TextStyle(
                      
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text: 'Sanya',
                    style: TextStyle(
                      
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.gold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'فيتو ثانية',
              style: TextStyle(
                
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 30,
                  height: 1,
                  color: AppTheme.gold.withAlpha(102),
                ),
                const SizedBox(width: 8),
                const Text(
                  'دايماً أقرب إليك',
                  style: TextStyle(
                    
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 30,
                  height: 1,
                  color: AppTheme.gold.withAlpha(102),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
