# VETO SANYA 3.0 verification report — 20 October 2026

## Identity and scope

Source of truth: VETO_SANYA_REFERRAL_UI_V31_FULL.zip (447 original files,
2.0.0+31). It was backed up and committed before changes. This delivery is
3.0.0+32, built from that working source, not a renamed V2 archive. The original
env.json bytes are unchanged. Public client configuration is included; no server
service key, private test credential, signing key or cached build directory is
part of the source ZIP. The file manifest and changed-file list are supplied.

## Automated results

| Check | Actual result |
|---|---|
| Full Flutter suite | 597 passed, 0 failed; release_tests.log, final line at 01:59 |
| Staging transactional SQL regression | 82 passed; backend_categories.json lists every case |
| Flutter analyzer | 0 errors, 29 warnings, 654 informational findings; exit 1, not a clean analyzer pass |
| APK build | Success, assembleDebug 39.2s, Production public env, com.vetosanya.app 3.0.0+32 |
| AAB build | Success, bundleRelease 97.3s, Production public env, unsigned |
| Production-configured Web build | Success, 66.4s compiler phase |
| Staging Web build for final visual pass | Success, 65.6s compiler phase |
| New category card matrix | 32 cases: 320/360/390/430 widths, Arabic/English, dark/light, 100/200% text |
| Captain/owner control screen matrix and owner form saves | 68 cases including 320px Arabic digits and 200% text |
| Draft identifier restoration | 3 cases; recognized categories/preferences only, no financial state |

V31 contained no test directory. 494 regression tests from the existing earlier
workspace were brought forward, then adapted to V31's explicit pickup-confirmation
flow. The first baseline run was 465 pass / 29 fail; it was not represented as a
passing V31 baseline. Cache-path mocks, obsolete journey expectations, real text
overflow and referral visible-balance regressions were corrected. The final 597
result is from the whole current suite, not a sum of isolated partial passes.

New UI tests load the real bundled Cairo font and vehicle art. HTTP control-screen
fixtures are synthetic; their screenshots are labeled SYNTHETIC. An owner dialog
controller disposal error found by save/close tests was fixed and rechecked.

The 82 backend checks cover all six ride fares, immutable category/price snapshots,
Growth booking/cancellation, cash and wallet reservation/refund, settled-once
behavior, real dispatch/offer/acceptance, Premium inheritance, explicit blocks,
Ladies separate approval/terms, identity/documents/insurance, child-seat approval,
PIN Arabic digits/wrong attempts/lock/replay/start guard, preferences, owner roles
and auditing, disabled categories and quote-free estimates. Retry tests verify
Ladies identity, legacy endpoint downgrade refusal, unchanged V28 ten-percent
adjustment, lineage and idempotence. Synthetic SQL rows all roll back.

## Browser use, beyond widget tests

A real local Flutter Web build connected to Staging was exercised using a headless
Edge browser. Customer login used a synthetic confirmed test account; it did not
prove real SMS delivery. The actual booking UI selected Comfort with a quiet-ride
preference, obtained the trusted 45 EGP quote and created request
ec407ff0-b968-41cf-b750-591cceed99ff. The search game opened and started. A synthetic
approved Premium captain received a real offer through process_dispatch_waves and
accepted through the existing authenticated acceptance RPC. Acceptance closed the
game and recovered the same trip after page reload. The customer PIN was verified
with the assigned captain session, the quiet preference confirmed, and the existing
arrived/start/complete lifecycle executed through authorized RPCs.

Final Staging receipt: fare 45, cash 45, wallet debit 0, commission 3.15, captain
amount 41.85, financial settlement timestamp present; customer wallet remained 200.
Captain status transitions were controlled RPC operations, not simulated taps on
a physical driver's phone. The actual captain dashboard/category page was also
opened at 320px and showed all seven category states. The browser had no page
JavaScript errors during that journey. This synthetic completed accounting history
is retained rather than deleted as cleanup.

The final source was rebuilt for Staging and the completed receipt/rating, home,
pickup confirmation, recent destination, fresh quote, six priced category choices
and captain category list were revisited. Actual 320/390px browser screenshots
are in verification/previews/BROWSER_STAGING_*.png. Fresh fares were 35/45/65/45/
25/35 EGP for that route; the unavailable Ladies state was explicit. No second
trip was booked in this last visual pass.

## Visual changes reviewed

Home service art, compact initial map sheet, explicit pickup step, city-picker
empty state, category cards, price confirmation, captain category authorization,
owner forms, completed receipt and game-to-accepted-trip navigation were viewed.
Category selection displays the trusted fare and real availability; no fictitious
captain ETA/count is inserted. Repeated fare totals were removed when no discount
exists. The pickup secret and stale arrival banner disappear after the trip's
applicable lifecycle. Active/restored category names use their immutable snapshot.

The picture at 200% owner text scaling deliberately uses a scrollable form. It is
not expected to fit every field on one screen; Save/Back remain reachable. Widget
tests also cover legacy wallet, news, home, Market, captain, navigation and game
surfaces. This is not a claim that every possible account/data combination was
manually reviewed on a real device.

## Security and Production state

New category tables have RLS and no direct anonymous/authenticated writes. Owner
actions use server-controlled admin metadata plus current-session checks. Quote
issuance is server-only. PIN storage is in a private schema. Dispatch and acceptance
revalidate eligibility; client category chips grant no permissions.

Production was read-only for this V3 task. Category schema/prices/PIN/dispatch
changes are NOT active there. The final read confirmed no ride_categories_v3 table.
The four inspected financial/referral function MD5s match their pre-work baseline:

| Function | MD5 |
|---|---|
| public.create_trip_growth_v1 | b0d7bbb9264eeda006de8e809f0e5946 |
| veto_growth_private.credit_friend_reward_v54 | b24eb76f75f80108c40c57ad63c22ef8 |
| veto_growth_private.settle_promo | 18736dd6f4adc86c28f1781256dbe538 |
| public.v54_my_friend_code | d3e32617c97c81cb49984b3e3eff039d |

No new reward amount/backfill was authorized. The V31 referral diagnosis remains
documented separately. No claim is made that this task resolves that distinct
financial-policy issue. A Stage-only broad ACL matching mistake was corrected
and the 47 legacy ACL sets reverified; see VETO_3_ROLLOUT.md for full disclosure.

## Assets and performance evidence

Seven individually generated transparent vehicle/Market illustrations, 39 original
functional SVG icons, four vehicle sizes and 24/32/48px icon sizes, full-resolution masters,
Arabic labels and dark/light/selected previews are included separately. The asset
manifest contains 267 image/vector files. Every raster decodes and every SVG root
parses. Runtime vehicle WebP files total 159,570 bytes. Category cards request small
decode sizes; estimated fares reuse one trusted route quote instead of making six
parallel route requests. These are measured payload and implementation facts,
not invented FPS, memory or startup benchmark results.

## Remaining gates and limitations

- Real Android hardware, native GPS, background push/OneSignal delivery, audible
  speaker output, long-duration battery/memory and frame-time benchmarks were not
  available. Test these before public activation.
- APK is debug signed. The release AAB is unsigned because the original release
  key was not supplied. No replacement signing key was created; do not upload the
  unsigned AAB to Play as a signed production artifact.
- Production category pricing, captain approvals and Ladies operating/legal review
  require explicit business approval. The included Production-configured app keeps
  legacy services usable until the additive V3 backend is deliberately deployed.
- Figma Starter MCP quota blocked live V3 publication. Existing file and local
  tokens/source map are included; a completed V3 live Figma file is not claimed.
- The analyzer retains the 29 warnings and 654 informational findings described
  above. There is no unqualified claim of zero lint issues or exhaustive security
  certification.

See VETO_3_ROLLOUT.md for safe first installation, Staging history and rollback;
VETO_3_APPLICATION_MAP.md explains the code and backend responsibilities.
