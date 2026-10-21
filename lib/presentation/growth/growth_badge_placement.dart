import 'package:flutter/material.dart';

class GrowthBadgePlacement extends StatefulWidget {
  const GrowthBadgePlacement({super.key});
  @override
  State<GrowthBadgePlacement> createState() => _GrowthBadgePlacementState();
}

class _GrowthBadgePlacementState extends State<GrowthBadgePlacement> {
  bool motorcycle = false;
  bool placed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => placed = true);
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: const Text('ظهر مقعد السيارة'),
            selected: !motorcycle,
            onSelected: (_) => setState(() => motorcycle = false),
          ),
          ChoiceChip(
            label: const Text('حقيبة توصيل الموتوسيكل'),
            selected: motorcycle,
            onSelected: (_) => setState(() => motorcycle = true),
          ),
        ],
      ),
      SizedBox(
        height: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: const Color(0xFF30415C),
                borderRadius: BorderRadius.circular(motorcycle ? 12 : 35),
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    motorcycle
                        ? Icons.delivery_dining
                        : Icons.airline_seat_recline_normal,
                    color: Colors.white54,
                  ),
                ),
              ),
            ),
            AnimatedSlide(
              offset: placed ? Offset.zero : const Offset(.8, -.6),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              child: Container(
                width: 58,
                height: 74,
                color: Colors.white,
                child: const Icon(
                  Icons.qr_code_2,
                  color: Colors.black,
                  size: 44,
                ),
              ),
            ),
          ],
        ),
      ),
      TextButton(
        onPressed: () async {
          setState(() => placed = false);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          if (mounted) setState(() => placed = true);
        },
        child: const Text('عرض طريقة تثبيت البادج'),
      ),
      const Text('الرسم يوضح موضع البطاقة؛ استخدم QR الحقيقي المطبوع أدناه.'),
    ],
  );
}
