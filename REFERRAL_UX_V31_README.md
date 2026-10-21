# VETO SANYA 2.0.0+31 — Referral UI revision / finance audit

## Scope completed in this archive

- New mobile-first customer invitation interface: short hero, server-confirmed reward amount, referral code, copy, WhatsApp sharing, compact statistics, detail modal, QR modal instead of a permanent ~232px QR.
- Captain referral screen unchanged.
- Server policy remains authoritative; **no Flutter-side credit mutation** was added.
- The customer screen uses `v54_my_friend_code`'s actual `reward_for_first_completed_trip` field instead of hardcoding the requested 20 EGP.
- Converted `wallet_topup_cairo.png` to lossless `.webp`; updated its sole Flutter reference. ~1,418,466 raw asset bytes saved.

## Verified Production financial finding (read-only checks, 20 October 2026)

Production project: `wbdjvzaomtlojttjnfhp` (actual project ref).

- `v54_my_friend_code()` advertises 15 EGP per successful invitation, **not 20 EGP**.
- `create_trip_growth_v1`, `settle_promo`, `credit_friend_reward_v54`, and `v54_my_friend_invites` each depend on a 15 EGP award, so changing only the client copy or a single SQL literal will break consistency.
- `referrals`, `discounts`, and `friend_rewards` flags were enabled.
- Among two customer-bound referrals there was one completed, financially settled invited-customer trip. Binding preceded the pricing quote and trip, the active campaign covered its service and time and had budget.
- This completed trip had **no growth reservation**, **no awarded friend-credit ledger entry**, and **no applied promotion**; its quote was consumed through a valid booking. The reward issuance flow currently relies on a reservation created by the growth booking path, so the completed ride did not produce a reward.
- The exact Flutter APK / RPC call used for that historical trip was not recorded in the data inspected, so a legacy non-growth booking path is a **strong candidate**, not independently proven.

**No production or staging financial data was changed in this revision.** An already-completed missing referral should be reconciled only with an idempotent, audited server migration after staging checks and confirmation of the intended policy (15 vs 20 EGP). A standard balance adjustment is not an acceptable repair.

## Staging remediation test plan (not executed)

1. Set the approved reward policy to 20 EGP if that is the new desired amount. Update the mutually dependent reserve, settle, receipt validation, code terms and counters atomically, with legacy 15 EGP historical records remaining valid.
2. Ensure a successful, first, settled invited-customer ride is credited even if the client used a valid non-growth booking route; disallow fraud and exclude bookings without a valid referral bound before quote creation.
3. Implement idempotent payout keyed by referred customer's first qualifying settled ride; lock involved rows, write one referral award ledger and one wallet transaction; use an explicit company-funded campaign budget and audit trail.
4. Test duplicate callbacks, concurrent trip completions, canceled rides, no referral, self-referral, old referrals, exhausted budget, failed wallet updates, existing 15 EGP rewards, retry after network failure, and server-driven wallet balance updates.
5. Review and reconcile past eligible trips on Staging, then obtain approval before migrating the financially active production database.

## Testing status

- Code/asset and archive checks are possible in this environment; no Flutter/Dart binary is installed, so `flutter analyze`, Flutter widget tests, APK builds and runtime frame-rate profiling **have not been performed here**.
- Test on an Android phone, including small screen and text scale, after building.

### Suggested commands locally

```
flutter pub get
flutter analyze
flutter test
flutter run -d chrome --dart-define-from-file=env.json
flutter build apk --release --dart-define-from-file=env.json --target-platform=android-arm64 --analyze-size
```

Do not use synthetic financial mutations against Production. Do not deploy a SQL migration from this report as if it were an executed fix.
