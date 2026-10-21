import 'package:flutter/widgets.dart';
import '../l10n/strings.dart';

/// Canonical Arabic V31 values remain unchanged in the database.
/// Only recognized system labels are localized; unknown customer content stays verbatim.
String ridePreferenceLabel(BuildContext context, String canonical) =>
    switch (canonical) {
      'أفضل الهدوء' => context.strings.profileInterest0,
      'بدون موسيقى' => context.strings.profileInterest1,
      'أفضل التكييف الهادئ' => context.strings.profileInterest2,
      'أفضل عدم المكالمات' => context.strings.profileInterest3,
      'أفضل الطريق الأسرع' => context.strings.profileInterest4,
      'مساعدة في حمل الأمتعة' => context.strings.profileInterest5,
      _ => canonical,
    };
