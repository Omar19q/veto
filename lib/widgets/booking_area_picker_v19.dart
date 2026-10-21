import '../l10n/strings.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The entire yellow selection card is tappable; avoids a tiny dropdown arrow.
class BookingAreaPickerV19 extends StatelessWidget {
  final String? selected;
  final List<String> areas;
  final ValueChanged<String> onSelected;
  final String placeLabel;

  const BookingAreaPickerV19({
    super.key,
    required this.selected,
    required this.areas,
    required this.onSelected,
    required this.placeLabel,
  });

  Future<void> _chooseArea(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.backgroundDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => Directionality(
        textDirection: Directionality.of(context),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Icon(Icons.touch_app_rounded,
                    size: 36, color: AppTheme.gold)),
                  const SizedBox(height: 8),
                  Text(context.strings.areaChooseLetter,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary)),
                  const SizedBox(height: 5),
                  Text(context.strings.areaChooseBuildingLetter,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                  Flexible(
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 9,
                        crossAxisSpacing: 9,
                        childAspectRatio: 1.3,
                      ),
                      itemCount: areas.length,
                      itemBuilder: (_, index) {
                        final letter = areas[index];
                        final isSelected = letter == selected;
                        return Material(
                          color: isSelected ? AppTheme.gold : AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Navigator.of(sheet).pop(letter),
                            child: Center(child: Text(letter,
                              style: TextStyle( fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: isSelected ? AppTheme.backgroundDark : AppTheme.textPrimary))),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (result != null) onSelected(result);
  }

  @override
  Widget build(BuildContext context) => Material(
    color: AppTheme.gold.withAlpha(24),
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: () => _chooseArea(context),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(minHeight: 96),
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.gold, width: 2.2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(children: [
          const Icon(Icons.touch_app_rounded, color: AppTheme.gold, size: 34),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(selected == null
                ? 'اضغط هنا لاختيار منطقة $placeLabel'
                : 'منطقة $selected — اضغط للتغيير',
                style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary)),
              const SizedBox(height: 4),
              Text(context.strings.areaShowLetters,
                style: TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary)),
            ],
          )),
          const Icon(Icons.arrow_drop_down_circle_rounded,
            size: 28, color: AppTheme.gold),
        ]),
      ),
    ),
  );
}
