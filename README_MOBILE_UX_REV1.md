# VETO SANYA 2.0 — Mobile UX Revision 1

**Version:** `2.0.0+30` (first candidate for user acceptance, **not** a verified release build)

## What changed

- Simplified the map-first home: compact pickup card, prominent destination action, four compact service SVG icons, and a much smaller admin-driven banner.
- Home prefers a live GPS position over saved addresses; a saved default is a fallback only when GPS is unavailable. A verified building name is used only if the backend lookup accepts a 200m radius. Otherwise an approved landmark within 200m or a reverse-geocoded address may appear. If none is available, the customer sees a generic current-location label.
- Tap the location label or pickup card to open booking and explicitly confirm the pickup. A prefilled GPS pin does not silently skip confirmation.
- Pickup confirmation is map-first with small location shortcuts; a manual map pin requires a human-readable description if reverse geocoding cannot produce one. The passenger note still flows into the existing booking model and captain-facing trip logic.
- Destination starts with direct search, shortcuts to the map, buildings, favorite places, and approved landmarks; recent destinations are loaded from the customer's own trip history where available.
- Removed the extra full-screen service-only confirmation stage from the standard new-booking route. Fare comparison and actual server-quoted price remain in the final review. Rebalanced map/fare sheet heights to prioritize the transaction details.
- Searching shows status and persisted server price ahead of optional incentive controls; extra controls are expandable. Existing game, refresh and free-before-acceptance cancellation remain.
- Improved FlutterMap fallback pickup/destination symbols; vector map points use a dark fill with a gold outline rather than an all-gold dot.
- Added original audio cues for chat, offer, notification, and confirmation. Market-order 15-second audio and admin-verification audio remain unchanged.

## Protected / unchanged

No edits were made to Supabase SQL, RPC implementations, wallet accounting, discount calculations, captain commissions, or production data. The original `env.json` and application integrations are preserved. This revision only changes Flutter UI, audio assets, and the local app version.

## Run locally

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome --dart-define-from-file=env.json
```

To test on Android, build from your authorized Android environment. Do **not** upload this untested candidate to Google Play or assume a new AAB exists.

## Critical tests on a real phone before release

1. Check home at 320/360/390/430 logical pixels, including text scaling and keyboard.
2. GPS on/off, permission denied, saved fallback, nearest building within 200m and unknown location descriptions.
3. Manual pickup via map and area/building selector; confirm the note is visible to captain on the offer.
4. Choose destination via search, recent trip, landmark, favorite, outside-city and manually adjusted pin.
5. Switch car/motorcycle/package; confirm quoted price and final discount / wallet / cash against **Staging** backend data.
6. Start searching, expand incentive controls, play/pause game, accept captain, cancel, refresh and resume the app.
7. Hear sounds on a physical Android device in foreground/background. Browser autoplay policies can prevent sound without an initial tap.
8. Check Arabic and English; newly rewritten customer prompts are Arabic-first and need a localization pass before an English-language release.

## Limitations of this handoff

The editing environment did not provide the Flutter/Dart SDK or an Android emulator. A source-level structural check and ZIP integrity check were run, but **Flutter compilation, Flutter analyzer, automated widget tests, screenshot comparisons, actual GPS and Push verification have not been executed here**. This is an implementation candidate for testing, not a claimed bug-free APK. The vector renderer's native pin still uses a styled circle; a fully custom sprite icon there requires a separately verified MapLibre asset/style integration.

## Rollback

Keep `veto sanya 3.zip` unchanged. Restoring that archive returns the original source. This candidate does not require a database migration.
