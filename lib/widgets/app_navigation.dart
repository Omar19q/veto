import 'dart:async';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

class _TabSpec {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final int? branchIndex;

  const _TabSpec({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.branchIndex,
  });
}

class AppNavigation extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  const AppNavigation({required this.navigationShell, super.key});

  @override
  State<AppNavigation> createState() => _AppNavigationState();
}

class _AppNavigationState extends State<AppNavigation>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int get _selectedVisualIndex => widget.navigationShell.currentIndex;
  int _karizmaUnread = 0;
  Timer? _karizmaTimer;
  RealtimeChannel? _karizmaNewsChannel;

  Future<void> _refreshKarizmaUnread() async {
    if (SupabaseService.instance.currentUser == null) return;
    try {
      final count = await SupabaseService.instance.karizmaUnreadV26('customer');
      if (mounted) setState(() => _karizmaUnread = count);
    } catch (_) {
      /* Keep the previous badge during temporary disconnection. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshKarizmaUnread();
  }

  late AnimationController _animController;

  final List<_TabSpec> _tabs = const [
    _TabSpec(
      label: 'الرئيسية',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      branchIndex: 0,
    ),
    _TabSpec(
      label: 'رحلاتي',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
      branchIndex: 1,
    ),
    _TabSpec(
      label: 'المحفظة',
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet_rounded,
      branchIndex: 2,
    ),
    _TabSpec(
      label: 'الأخبار',
      icon: Icons.newspaper_outlined,
      activeIcon: Icons.newspaper_rounded,
      branchIndex: 3,
    ),
    _TabSpec(
      label: 'المزيد',
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
      branchIndex: 4,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    WidgetsBinding.instance.addObserver(this);
    _refreshKarizmaUnread();
    _karizmaTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshKarizmaUnread(),
    );
    if (SupabaseService.instance.currentUser != null) {
      _karizmaNewsChannel = SupabaseService.instance.subscribeToKarizmaNewsV26(
        () => _refreshKarizmaUnread(),
      );
    }
  }

  @override
  void dispose() {
    _karizmaTimer?.cancel();
    _karizmaNewsChannel?.unsubscribe();
    WidgetsBinding.instance.removeObserver(this);
    _animController.dispose();
    super.dispose();
  }

  void _onTabTap(int visualIndex) {
    final spec = _tabs[visualIndex];
    if (spec.branchIndex == null) return; // stub tab — silent ignore
    if (visualIndex == _selectedVisualIndex) return;
    setState(() {
      if (visualIndex == 3) _karizmaUnread = 0;
    });
    widget.navigationShell.goBranch(
      spec.branchIndex!,
      initialLocation: spec.branchIndex == widget.navigationShell.currentIndex,
    );
    if (visualIndex == 3) {
      SupabaseService.instance.karizmaCustomerOpen.value++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedVisualIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.surfaceVariant : Colors.white;
    final borderColor = isDark ? AppTheme.cardBorder : const Color(0xFFE2E8F0);
    final activeBubbleColor = isDark ? AppTheme.gold : AppTheme.primary;
    final activeIconColor = isDark ? AppTheme.primary : AppTheme.gold;
    final inactiveIconColor = isDark ? AppTheme.textPrimary : const Color(0xFF64748B);
    final activeTextColor = isDark ? AppTheme.gold : AppTheme.primary;
    final inactiveTextColor = isDark ? AppTheme.textSecondary : const Color(0xFF64748B);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: SizedBox(
          height: 88,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slot = constraints.maxWidth / _tabs.length;
              return TweenAnimationBuilder<double>(
                tween: Tween(end: (4 - selected) * slot + slot / 2),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 350),
                curve: Curves.easeInOutCubic,
                builder: (context, center, _) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _LiquidBarPainter(
                          center,
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                          isDark: isDark,
                        ),
                      ),
                    ),
                    Positioned(
                      left: center - 26,
                      top: 0,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: activeBubbleColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppTheme.backgroundDark : Colors.white,
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withAlpha(70)
                                  : activeBubbleColor.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          _tabs[selected].activeIcon,
                          color: activeIconColor,
                          size: 25,
                        ),
                      ),
                    ),
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Row(
                        children: List.generate(_tabs.length, (index) {
                          final tab = _tabs[index];
                          final active = selected == index;
                          return Expanded(
                            child: Semantics(
                              button: true,
                              selected: active,
                              label: tab.label,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _onTabTap(index),
                                child: SizedBox(
                                  height: 88,
                                  child: Column(
                                    children: [
                                      SizedBox(height: active ? 57 : 35),
                                      if (!active)
                                        Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Icon(
                                              tab.icon,
                                              color: inactiveIconColor,
                                              size: 23,
                                            ),
                                            if (index == 3 &&
                                                _karizmaUnread > 0)
                                              Positioned(
                                                top: -3,
                                                right: -4,
                                                child: Container(
                                                  width: 9,
                                                  height: 9,
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Colors.redAccent,
                                                        shape: BoxShape.circle,
                                                      ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      if (!active) const SizedBox(height: 4),
                                      Text(
                                        tab.label,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontFamily: AppTheme.productFontFamily(context),
                                          fontSize: 10,
                                          fontWeight: active
                                              ? FontWeight.w800
                                              : FontWeight.w500,
                                          color: active
                                              ? activeTextColor
                                              : inactiveTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LiquidBarPainter extends CustomPainter {
  const _LiquidBarPainter(
    this.center, {
    required this.surfaceColor,
    required this.borderColor,
    required this.isDark,
  });
  final double center;
  final Color surfaceColor;
  final Color borderColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final x = center.clamp(38.0, size.width - 38);
    final path = Path()
      ..moveTo(18, 23)
      ..lineTo(x - 40, 23)
      ..cubicTo(x - 31, 23, x - 33, 56, x, 56)
      ..cubicTo(x + 33, 56, x + 31, 23, x + 40, 23)
      ..lineTo(size.width - 18, 23)
      ..quadraticBezierTo(size.width, 23, size.width, 41)
      ..lineTo(size.width, size.height - 16)
      ..quadraticBezierTo(size.width, size.height, size.width - 16, size.height)
      ..lineTo(16, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - 16)
      ..lineTo(0, 41)
      ..quadraticBezierTo(0, 23, 18, 23)
      ..close();
    canvas.drawShadow(
      path,
      isDark ? Colors.black.withAlpha(100) : const Color(0x180F172A),
      isDark ? 8 : 12,
      false,
    );
    canvas.drawPath(path, Paint()..color = surfaceColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_LiquidBarPainter oldDelegate) =>
      center != oldDelegate.center;
}
