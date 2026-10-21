# VETO SANYA 3 — rollout and rollback

The supplied V31 ZIP (2.0.0+31) is the baseline. This implementation is 3.0.0+32.
The original public Flutter env.json remains intact. No server credential or signing
key is included. Open this folder containing pubspec.yaml, run flutter pub get,
then RUN_FLUTTER.cmd or the supplied VS Code launch configuration.

## Database status

Production wbdjvzaomtlojttjnfhp was inspected read-only. Category schema, category
prices, approvals and safety PIN changes have NOT been deployed to Production.
The four inspected referral/settlement functions remain byte-for-byte equivalent
by PostgreSQL function-definition MD5. No reward amount or historical balance was
changed. Production still uses its existing services until rollout approval.

Staging wujynritxanyzrkdyamt contains the additive category layer, private safety
tables, promise confirmations and the route-price-quote-v3 Edge Function. The six
proposed prices from the brief were seeded only on Staging. Existing Production
service identifiers remain car_ride, motorcycle_ride, package and vito_market.
VETO Market retains its original order and merchant pricing flow.

SQL was developed and verified on Staging using transactional execute_sql steps.
The supplied consolidated migration is a FIRST-INSTALL script for a database that
does not contain the V3 objects; it must not be rerun on the current Staging schema.
The migration filename was created using the Supabase CLI. No fake migration
history entry was added to suggest the consolidated file ran as one migration.
The final narrow V28 category retry guard was subsequently applied through
apply_migration on Staging as v3_timeout_retry_category_guard. It is included in
the FIRST-INSTALL SQL for a fresh compatible target. Do not apply it twice just
because it also appears in that consolidated delivery. Older V2 migrations in
the supplied project were preserved; inspect their history before any deploy.

During initial Staging development, an overly broad LIKE 'v3_%' permission query
also matched 47 legacy v33-v39 functions. This was discovered and corrected:
definitions were compared with Production, the three affected client/PUBLIC ACLs
were restored to their Production reference, and all 47 sets rechecked equal.
The consolidated SQL uses explicit new-function names. Production was never
modified by this incident. The repair script is not a Production migration.

## Production rollout (requires pricing/operations approval)

1. Back up database definitions, current Edge source and current application.
2. Verify all referenced existing V4/V10/V13/V25/Growth functions match the audited
   compatible signatures. Check that V3 objects do not already exist.
3. Apply the consolidated SQL in one transaction. It creates DISABLED categories
   and no price rows. It does not rewrite historical rides or financial rules.
4. Deploy supabase/functions/route-price-quote-v3 with verify_jwt=true, preserving
   the existing protected route-price-quote. Configure the existing operated OSRM
   endpoint and origin allowlist as on the protected original function.
5. Have an authorized owner enter approved category/zone prices. Do not import the
   Staging seed into Production without explicit business approval.
6. Review each captain's vehicle, documents, insurance and identity. Approve their
   highest tier, allowed exceptions and blocks. Ladies verification is separate;
   never infer gender from a photograph. Complete legal/insurance/safety review
   before public Ladies activation. It serves adult women, with accompanied
   children under 12 only. Child seats are offered only with approved equipment
   and current eligible availability, and require captain confirmation.
7. Enable categories gradually; verify real devices, push delivery and pickup PINs.
   New requests use selected-category pricing. Higher-tier captains retain that fare.

Encrypted drafts preserve category and preference identifiers only; they never
restore a stale price, wallet hold, discount or financial request. Restored and
disabled Ladies choices cannot silently become Economy. A timeout retry retains
its original category, trusted current quote and the unchanged V28 ten-percent
retry rule. The server guard also covers callers using the old quote endpoint.
Choosing another service/category explicitly makes a normal new request.

## Safe rollback

Pause new category requests using the owner controls. Do not drop category tables,
new trip columns, PIN guards or snapshots while category rides are pending/active.
Keep the deployed category-capable client for active rides so captains can verify
their pickup codes. Settle/cancel outstanding requests using existing authorized
workflows. Restore a previous app only after category rides finish. Retain the
schema, audit history and immutable pricing snapshots for receipts. Do not erase
ledgers, backfill rewards or recompute old trip prices as a rollback technique.

## Referral issue remains a separate financial decision

The V31 referral diagnosis is preserved in REFERRAL_UX_V31_README.md. Its 15 EGP
policy is authoritative today. A legacy/non-Growth booking can lack the reservation
on which referral payout depends. This category layer delegates to the existing
Growth V2/V1 path, preserving promotions and earned credit; choosing to skip an
earned benefit still follows the existing legacy path. No retroactive reward fix
is claimed. A repair should reserve/issue the FIRST qualifying settled referral
reward idempotently, independent of whether the invitee chose an immediate discount,
fund it from the approved campaign, and write the existing audited reward ledger.
Test duplicate callbacks, parallel completions, cancellation, no/self referral,
budget exhaustion, existing 15 EGP awards and retries before approving deployment.
Changing 15 to 20 EGP or backfilling historical credit needs explicit approval.

## Figma

Existing library: https://www.figma.com/design/wyAPBW8hh7Kz5Th8x6M4CB
The Starter MCP limit was still active. No V3 Figma changes were published.
Local tokens, SVG assets, source mapping and the editable Flutter components are
included. This is not represented as a completed live Figma library.
