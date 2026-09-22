# Rewards

The rewards page follows Figma node `787:176`: cream background, blue points wallet,
All / My rewards selector, compact white offer cards, and coral redemption actions.
The shared bottom navigation is still owned by HomeScreen. The neutral thumbnails
are intentionally blank in the supplied design. Offer names, prices and balances
come from Supabase; sample Figma offers and distances are not inserted into the app.

## Preserved behaviour

- Read the signed-in user's `profiles.total_points` and the `rewards` catalogue.
- Offer titles, partners, prices and both existing categories remain available.
  The catalogue is now one All list; tapping a card displays its category/details.
- Disable redemption for insufficient points. Final validation remains the server's job.
- Redeem through the existing CheckInScreen: show the first dog's name (or “your dog”),
  swipe at the counter, call `redeem_reward(p_reward_id)`, block concurrent requests,
  show the returned promo code and Collected state, and return with Done.
- Refresh the wallet after leaving check-in, including via the Back button.
- Retain the previous Active Adventurer / 2,000-point Gold preview in the wallet's
  tap-to-open detail dialog. It is still a preview, not a real membership system.
- Existing walking/weight points rules, RPCs and authentication are unchanged.

## New behaviour

- All shows the complete catalogue, including both Partner Vouchers and Premium Perks.
- My rewards reads `redeemed_rewards` filtered by the signed-in `user_id`, and displays
  each saved `reward_title`. View code opens its existing `promo_code`, with copy support.
  Opening a saved code never invokes redemption or deducts points.
- History is fetched when My rewards is selected and after check-in. Pull-to-refresh
  and re-entering the Rewards navigation tab update the balance and loaded history.
- Loading, empty and failed states are distinct. Each failed list has a retry action;
  a failed history request does not prevent browsing All.
- The main wallet progress targets the next catalogue price above the current balance.
  If all offers are affordable, it says so. It does not use Figma's sample balance,
  sample distance labels or inconsistent hard-coded locked states.
- Screen updates ignore responses received after disposal, and older overlapping loads.

## Database contract and verification

`SupabaseRewardsRepository` uses the existing schema; no database mutation or migration
is included. The original redemption implementation in commit `d6a7f96` wrote
`redeemed_rewards(user_id, reward_title, promo_code)`. A read-only live API request
confirmed those columns exist on 2026-09-22; a separate request confirmed there is no
`reward_id` column on that table. Historical entries therefore do not guess partner,
price, category or redemption date by matching titles against the current catalogue.

Anonymous requests return no visible records. Signed-in end-to-end testing is still
needed to confirm SELECT policies allow owners to read their rows and that the current
`redeem_reward` RPC inserts a history row on every successful redemption. The app does
not create a second client-side history row, which could duplicate server records or
misrepresent a failed redemption. No expiry, merchant usage status or redemption limits
are claimed because those fields and workflows have not been verified.

## Validation

`flutter test test/rewards_screen_test.dart` covers tab switching, saved-code viewing
and copying, affordability, category/tier access, retry and empty states, refresh on
navigation, late responses, and small-screen/large-text layout.
