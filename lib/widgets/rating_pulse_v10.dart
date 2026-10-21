import 'package:flutter/material.dart';

class RatingPulseV10 extends StatelessWidget {
  final int? stars;
  final Widget child;
  const RatingPulseV10({super.key, required this.stars, required this.child});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(stars),
    tween: Tween(begin: stars == null ? 1 : .85, end: 1),
    duration: const Duration(milliseconds: 700),
    curve: Curves.easeOutBack,
    builder: (context, scale, _) => Transform.scale(
      scale: scale,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: stars == null
              ? null
              : Border.all(color: Colors.amber, width: 3),
          boxShadow: stars == null
              ? null
              : [const BoxShadow(color: Color(0x66FFC107), blurRadius: 14)],
        ),
        child: child,
      ),
    ),
  );
}
