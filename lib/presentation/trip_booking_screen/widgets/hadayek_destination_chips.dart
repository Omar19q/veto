import 'package:flutter/material.dart';

class HadayekDestination {
  final String name;
  final double latitude;
  final double longitude;
  final String? areaLetter;
  const HadayekDestination(
    this.name,
    this.latitude,
    this.longitude, {
    this.areaLetter,
  });
}

const hadayekDestinations = <HadayekDestination>[
  HadayekDestination('البوابة الأولى', 29.97764, 31.11210),
  HadayekDestination('البوابة الثانية', 29.96428, 31.10828),
  HadayekDestination('البوابة الرابعة', 29.95199, 31.08819),
  HadayekDestination('منطقة ب', 29.97782, 31.10586, areaLetter: 'ب'),
  HadayekDestination('منطقة ج', 29.97517, 31.10844, areaLetter: 'ج'),
  HadayekDestination('منطقة د', 29.97577, 31.10332, areaLetter: 'د'),
];

class HadayekDestinationChips extends StatelessWidget {
  final ValueChanged<HadayekDestination> onSelected;
  final bool enabled;
  const HadayekDestinationChips({
    super.key,
    required this.onSelected,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('وجهات سريعة داخل حدائق الأهرام'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: hadayekDestinations
              .map(
                (destination) => ActionChip(
                  avatar: const Icon(Icons.place_outlined, size: 18),
                  label: Text(destination.name),
                  onPressed: enabled ? () => onSelected(destination) : null,
                ),
              )
              .toList(),
        ),
        const Text(
          'اختيار منطقة يحدد نقطة عامة فيها؛ اختر العمارة للعنوان الدقيق.',
        ),
      ],
    );
  }
}
