import 'dart:math';

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class BookingRadarWidget extends StatefulWidget {
  final int currentIncentive;
  final bool showIncentive;
  final ValueChanged<int> onIncreaseIncentive;
  final VoidCallback onCancel;

  const BookingRadarWidget({
    super.key,
    this.currentIncentive = 0,
    this.showIncentive = true,
    required this.onIncreaseIncentive,
    required this.onCancel,
  });

  @override
  State<BookingRadarWidget> createState() => _BookingRadarWidgetState();
}

class _BookingRadarWidgetState extends State<BookingRadarWidget>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _rotateController;
  late final AnimationController _discoveryController;
  final List<_DiscoveryDot> _dots = [];

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _discoveryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // The pulse is decorative search progress. Captain presence is supplied
    // only by the authenticated server aggregate in ProductSearchingView.
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    _discoveryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final incentive = widget.currentIncentive < 0 ? 0 : widget.currentIncentive;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Most handsets show everything without scrolling. Very short landscape
        // and accessibility layouts retain a scrollable fallback, not overflow.
        final compact = constraints.maxHeight < 520;
        final veryShort = constraints.maxHeight < 455;
        final radarDiameter = compact ? 104.0 : 185.0;

        Widget radar(double diameter) => SizedBox(
              width: diameter,
              height: diameter,
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _pulseController,
                  _rotateController,
                  _discoveryController,
                ]),
                builder: (context, child) => CustomPaint(
                  painter: _RadarPainter(
                    pulseValue: _pulseController.value,
                    rotateValue: _rotateController.value,
                    dots: _dots,
                    discoveryValue: _discoveryController.value,
                  ),
                  child: child,
                ),
                child: Center(
                  child: Container(
                    width: compact ? 48 : 64,
                    height: compact ? 48 : 64,
                    decoration: BoxDecoration(
                      color: AppTheme.gold,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.gold.withAlpha(100),
                          blurRadius: 22,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.local_taxi_rounded,
                      color: AppTheme.primary,
                      size: compact ? 23 : 30,
                    ),
                  ),
                ),
              ),
            );

        Widget incentiveOption(int value) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Semantics(
                  button: true,
                  selected: incentive == value,
                  label: incentive >= value ? 'الحافز الحالي $incentive جنيه' : 'اختيار حافز إجمالي بقيمة $value جنيه',
                  child: InkWell(
                    onTap: incentive >= value ? null : () => widget.onIncreaseIncentive(value),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      constraints: const BoxConstraints(minHeight: 43),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: incentive == value
                            ? AppTheme.gold
                            : AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: incentive == value
                              ? AppTheme.gold
                              : AppTheme.cardBorder,
                        ),
                      ),
                      child: Text(
                        '+$value ج',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: incentive == value
                              ? AppTheme.primary
                              : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );

        Widget incentivePanel() => Container(
              width: double.infinity,
              padding: EdgeInsets.all(compact ? 10 : 14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.gold.withAlpha(110)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt_rounded, color: AppTheme.gold, size: 23),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'خلّي فرص قبول طلبك أعلى',
                          style: TextStyle(
                            
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        incentive == 0 ? 'بدون حافز' : '+$incentive ج حاليًا',
                        style: const TextStyle(
                          
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.gold,
                        ),
                      ),
                    ],
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 3),
                    const Text(
                      'اختار قيمة الحافز الإجمالية اللي تناسبك. لو ضغطت نفس القيمة تاني مش هتتحسب مرتين.',
                      style: TextStyle(
                        
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(children: [5, 10, 15].map(incentiveOption).toList()),
                  const SizedBox(height: 7),
                  Row(children: [20, 30, 50].map(incentiveOption).toList()),
                ],
              ),
            );

        Widget cancelButton() => SizedBox(
              height: 42,
              width: double.infinity,
              child: TextButton.icon(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text(
                  'إلغاء طلب الرحلة',
                  style: TextStyle(
                    
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(color: AppTheme.cardBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            );

        final header = Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppTheme.gold.withAlpha(35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.radar_rounded, size: 20, color: AppTheme.gold),
            ),
            const SizedBox(width: 9),
            const Expanded(
              child: Text(
                'بنبحث لك عن كابتن دلوقتي',
                maxLines: 2,
                style: TextStyle(
                  
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(
              width: 19,
              height: 19,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.gold,
              ),
            ),
          ],
        );

        final content = <Widget>[
          header,
          SizedBox(height: compact ? 6 : 12),
          if (veryShort)
            Center(child: radar(radarDiameter))
          else
            Expanded(
              child: Center(
                child: LayoutBuilder(
                  builder: (_, box) {
                    final size = min(radarDiameter, min(box.maxWidth, box.maxHeight));
                    return radar(size.clamp(0.0, radarDiameter).toDouble());
                  },
                ),
              ),
            ),
          SizedBox(height: compact ? 6 : 12),
          if (widget.showIncentive) incentivePanel(),
          if (!veryShort) ...[
            const SizedBox(height: 9),
            cancelButton(),
          ],
        ];
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(12, compact ? 10 : 14, 12, 9),
            decoration: BoxDecoration(
              color: AppTheme.backgroundDark.withAlpha(246),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.gold.withAlpha(65)),
            ),
            child: veryShort
                ? Column(children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: content,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    cancelButton(), // Stays visible even with large text/short screen.
                  ])
                : Column(children: content),
          ),
        );
      },
    );
  }
}

class _DiscoveryDot {
  final double angle;
  final double radius;
  final double delay;

  const _DiscoveryDot({
    required this.angle,
    required this.radius,
    required this.delay,
  });
}

class _RadarPainter extends CustomPainter {
  final double pulseValue;
  final double rotateValue;
  final List<_DiscoveryDot> dots;
  final double discoveryValue;

  _RadarPainter({
    required this.pulseValue,
    required this.rotateValue,
    required this.dots,
    required this.discoveryValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Draw radar rings
    for (int i = 1; i <= 3; i++) {
      final ringRadius = maxRadius * (i / 3);
      final ringPaint = Paint()
        ..color = AppTheme.gold.withValues(alpha: 0.08 + (i * 0.04))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(center, ringRadius, ringPaint);
    }

    // Pulse ring
    final pulsePaint = Paint()
      ..color = AppTheme.gold.withValues(alpha: (1 - pulseValue) * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, maxRadius * pulseValue * 0.9, pulsePaint);

    // Rotating sweep
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          AppTheme.gold.withAlpha(77),
          Colors.transparent,
        ],
        stops: const [0.0, 0.15, 0.3],
        startAngle: 0,
        endAngle: 2 * pi,
        transform: GradientRotation(rotateValue * 2 * pi),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, maxRadius * 0.9, sweepPaint);

    // Discovery dots
    for (final dot in dots) {
      final dotProgress = ((discoveryValue - dot.delay / 2000) % 1.0).clamp(
        0.0,
        1.0,
      );
      if (dotProgress > 0.1) {
        final x = center.dx + cos(dot.angle) * dot.radius * (maxRadius / 150);
        final y = center.dy + sin(dot.angle) * dot.radius * (maxRadius / 150);
        final dotPaint = Paint()
          ..color = AppTheme.gold.withValues(
            alpha: (dotProgress * 0.8).clamp(0.0, 1.0),
          )
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x, y), 4, dotPaint);

        // Glow
        final glowPaint = Paint()
          ..color = AppTheme.gold.withValues(
            alpha: (dotProgress * 0.2).clamp(0.0, 1.0),
          )
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x, y), 8, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => true;
}
