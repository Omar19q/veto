import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class CaptainToggleWidget extends StatefulWidget {
  final bool isOnline;
  final ValueChanged<bool> onToggle;

  const CaptainToggleWidget({
    required this.isOnline,
    required this.onToggle,
    super.key,
  });

  @override
  State<CaptainToggleWidget> createState() => _CaptainToggleWidgetState();
}

class _CaptainToggleWidgetState extends State<CaptainToggleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.isOnline) _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(CaptainToggleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOnline && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isOnline && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color statusColor = widget.isOnline
        ? AppTheme.successLight
        : AppTheme.textMuted;
    final Color bgColor = widget.isOnline
        ? const Color(0xFF0D2B1A)
        : AppTheme.surfaceVariant;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: widget.isOnline
              ? AppTheme.successLight.withAlpha(80)
              : AppTheme.cardBorder,
          width: 1.5,
        ),
        boxShadow: widget.isOnline
            ? [
                BoxShadow(
                  color: AppTheme.successLight.withAlpha(40),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          // Pulse indicator
          if (widget.isOnline)
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (context, child) => Transform.scale(
                scale: _pulseAnim.value,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppTheme.successLight,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.successLight.withAlpha(120),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppTheme.textMuted,
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isOnline ? 'متصل الآن' : 'غير متصل',
                  style: TextStyle(
                    
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
                Text(
                  widget.isOnline
                      ? 'أنت مرئي للعملاء وتستقبل الطلبات'
                      : 'لن تستقبل أي طلبات جديدة',
                  style: TextStyle(
                    
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => widget.onToggle(!widget.isOnline),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: 56,
              height: 30,
              decoration: BoxDecoration(
                color: widget.isOnline
                    ? AppTheme.successLight
                    : AppTheme.textMuted,
                borderRadius: BorderRadius.circular(15.0),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                alignment: widget.isOnline
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
