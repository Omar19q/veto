# Application and maintenance map

Baseline: supplied V31, upgraded in place to 3.0.0+32. This is one Flutter app
with customer, captain, merchant/Market and owner routes, not separate new apps.

## Customer journey

Login/OTP -> original role/session checks -> home map -> explicit pickup
confirmation -> destination -> trusted route quote -> category picker -> fare and
existing promotion/wallet split -> request -> offers/search/game -> accepted ride
-> pickup PIN verification by assigned captain -> started -> completed -> receipt
and rating. Closing/reopening restores the active ride instead of inserting a
second financial request. Booking drafts are account-scoped and encrypted.

Home service artwork maps to original car/moto/parcel/Market routes. Market
retains its merchant catalog, cart, encrypted draft, checkout and order lifecycle;
its prices are not calculated by the ride category fare formula.

## Code entry points

| Concern | Source |
|---|---|
| Bootstrap/config/locales | lib/main.dart, lib/core, lib/l10n |
| Navigation/role routes | lib/routes/app_routes.dart |
| Home services/map | lib/presentation/home_screen/widgets/product_home_panel.dart, lib/widgets/customer_map_home.dart |
| Booking state/category/draft/retry | lib/presentation/trip_booking_screen/trip_booking_screen.dart |
| Catalog and safe draft identifiers | lib/services/ride_categories.dart |
| Trusted quote client | lib/services/zone_pricing_service.dart |
| Financial booking delegation | lib/services/supabase_service.dart |
| Reusable category cards | lib/widgets/ride_category_card.dart |
| PIN and Trip Promise views | lib/widgets/trip_safety_code.dart, lib/widgets/trip_promise_panel.dart |
| Customer active trip/receipt | lib/presentation/trip_booking_screen/live_trip_screen.dart, lib/widgets/trip_financial_card_v11.dart |
| Captain dashboard/dedicated active ride | lib/presentation/captain_dashboard_screen |
| Captain permissions view | lib/presentation/categories/captain_categories_screen.dart |
| Owner configuration | lib/presentation/categories/admin_categories_screen.dart |
| Runtime vehicle illustrations | assets/vehicles/veto_*.webp |
| Functional vector icons | assets/icons/v3_*.svg |
| Regression source and SQL | test/ |
| Final result logs/previews | verification/ |

## Backend responsibility

route-price-quote-v3 authenticates the bearer token, routes via the operated OSRM
server, enforces origin and existing quote limits, and calls the server-only V3
quote issuer. Client distance/prices/permissions are never trusted.

v3_category_catalog/v3_category_estimates read enabled catalog/current prices and
real eligible availability. Estimates reuse a trusted unexpired route quote.
v3_book_category validates terms/preferences, stamps immutable pricing/category
snapshots and delegates to existing Growth V2/V1 or intentional legacy booking.
Existing ledgers, reservation, cancellation, commission and settlement remain the
accounting authority. The V28 retry guard adds category identity validation only.

Eligibility is checked before dispatch, offer creation/acceptance and assignment.
Verified Premium may inherit lower car tiers if enabled and not blocked. Ladies
approval is separate. Private pickup PINs are customer-readable and assigned-
captain-verifiable, expire, lock after five wrong attempts and prevent start
until verified. Arabic/Persian digits are normalized server-side.

Owner RPCs require the existing server-controlled admin role and current session.
Direct client table writes are revoked. Audit rows preserve configuration changes.
Approvals lock the captain row to coordinate with the existing accept engine.

## Maintenance cautions

Keep service IDs distinct from category IDs. Never infer authorization from a
widget, photo or user-editable metadata. Do not recompute an old receipt using
today's category names/prices; use its snapshot. No child-seat surcharge is added.
Do not drop safety guards while category rides remain active. The rollout document
explains the separate Staging/Production status and approval gates.
