/// Distinct invitation namespaces; team/partner codes are never customer
/// onboarding referral codes. No Flutter value ever controls financial rules.
enum GrowthReferralKind { captain, friend, legacyCustomer, empty, invalid }

GrowthReferralKind classifyGrowthReferral(String raw) {
  final code = raw.trim().toUpperCase();
  if (code.isEmpty) return GrowthReferralKind.empty;
  if (RegExp(r'^[0-9]{4,19}$').hasMatch(code)) {
    return BigInt.parse(code) >= BigInt.from(1001)
        ? GrowthReferralKind.captain : GrowthReferralKind.invalid;
  }
  if (RegExp(r'^F[0-9]{6,12}$').hasMatch(code)) {
    return GrowthReferralKind.friend;
  }
  if (RegExp(r'^C(?:[0-9A-F]{12}|[0-9A-F]{32})$').hasMatch(code)) {
    return GrowthReferralKind.legacyCustomer;
  }
  return GrowthReferralKind.invalid;
}

String growthReferralHint(GrowthReferralKind kind, {required bool english}) {
  switch (kind) {
    case GrowthReferralKind.captain:
      return english ? 'Captain code. Discounts follow the active campaign terms.'
          : 'كود كابتن: الخصومات حسب العرض الساري.';
    case GrowthReferralKind.friend:
    case GrowthReferralKind.legacyCustomer:
      return english ? 'Friend invitation: 50% off your first eligible ride only.'
          : 'كود صديق: خصم 50% على أول رحلة مؤهلة فقط.';
    case GrowthReferralKind.empty:
      return english ? 'Optional: enter a captain or friend invitation code.'
          : 'اختياري: اكتب كود كابتن أو صديق، أو اضغط تخطي.';
    case GrowthReferralKind.invalid:
      return english ? 'Check the invitation code. Team codes are not accepted here.'
          : 'راجع كود الدعوة. كود الفريق غير صالح في الخانة دي.';
  }
}
