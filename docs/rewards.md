# Rewards: redeem, then collect

## Deployment required

Apply `supabase/migrations/202609220001_reward_collection.sql` in the project's
Supabase SQL Editor before using this updated app. This migration has been prepared
locally, not applied to the live project. It requires the existing
`public.redeem_reward(uuid)` function to return a promo code and write
`redeemed_rewards(user_id, reward_title, promo_code)`, alongside the existing
`rewards` and `profiles` tables. It checks the function signature before making changes.
It runs in a transaction; do not work around a failed preflight by removing the check.

The migration adds:

- `reward_receipts`: immutable offer snapshots and an `is_collected` boolean.
  Authenticated users can read only their own rows. Clients cannot write directly.
- `reward_redemption_requests`: private request-to-receipt mappings for safe retries.
- `redeem_offer(p_reward_id, p_request_id)`: wraps the existing redemption function.
  The catalogue supplies cost/title/partner data, and existing points validation and
  deduction remain server-side. A request retry or a second request for the same
  uncollected offer returns the saved receipt. The original redemption and the new
  receipt commit together or roll back together.
- `collect_reward(p_promo_code)`: verifies ownership and marks the offer collected.
  Repeat requests keep that same collected status; no collection time is stored.
  It does not deduct points. A duplicate historical code is rejected as ambiguous.

The app intentionally does not simulate successful redemption or collection if these
functions are unavailable. Deployment and a signed-in live smoke test are still needed.
No live points, catalogue entries or saved codes were changed during implementation.

## User flow

1. All rewards lists live offers cheapest first. Missing images use the white dog
   logo on grey. Wallet balance, affordability, categories, retry/empty states,
   pull-to-refresh and the existing 2,000-point tier preview are retained.
2. Tapping a card opens its details. REDEEM opens the Figma bottom-sheet confirmation,
   with the offer title and points cost. The cross, outside tap and drag dismiss it.
   Dismissal before pressing Redeem Offer spends nothing. Closing it after starting
   the request does not cancel a server transaction; the completed result still
   updates the details/catalogue. Repeat taps while processing are blocked.
3. Redeem Offer spends points once and saves an uncollected reward. The same sheet
   shows Redeemed!; View reward returns to the updated details with a Lucide tick
   replacing points and CHECK IN replacing REDEEM. Expiration text is omitted.
4. CHECK IN opens the redesigned Please show to staff screen. A short swipe snaps
   back. A full swipe records collection, without charging points again. Failure
   leaves the reward unconfirmed and allows a retry.
5. Collected! follows Figma `630:1311` with the check badge, order and place only.
   There is no collection time or date in the UI or data model. Reopening
   VIEW COLLECTION preserves collected status and offers no second swipe.
6. My rewards opens saved reward details. View code still displays/copies the
   original promo code. Collected and ready-to-collect entries are distinguished.

The details page retains the GO HERE placeholder; it does not request GPS or open
maps. Hours and distance remain explicitly unconfirmed. Figma's example partners,
locations, prices and times are not used as live data.

## Existing redemptions

Older `redeemed_rewards` rows have only a title and code, with no `reward_id`.
They remain available in My rewards and can be collected using their code. Missing
partner/cost information is not guessed from potentially duplicated titles. A new
receipt is created when an older code is first collected. Newly redeemed offers store
snapshots that let details and receipts be reopened even after catalogue edits.

## Validation

Widget tests cover ordering, price locks, categories/tier access, history and code
copying, failures/retries, close/outside-tap dismissal, closing during redemption,
request-ID reuse, the complete redeem-to-collect flow, reloading collected status without a time,
late responses and small-screen/large-text layouts. Figma assets are committed locally.
The SQL functions still require validation against the team's actual Supabase project;
local UI tests use a fake repository and do not prove live database behaviour.
