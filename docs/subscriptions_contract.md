# AI Studio plans: contract (2026-10-30)

Approved by the owner (client approved): AI Room Studio renders are the only gated feature.
Catalogue, quotes, samples, Live AR, Aarna stay free. Applies to all users.

## Plans

| Plan | Price | AI renders | Notes |
|---|---|---|---|
| trial | free | 10 per day, no monthly cap | first 7 days after sign-up (auth.users.created_at) |
| free | free | 3 per calendar month (IST) | after the trial |
| plus | Rs 499 / month | 60 per month, 10 per day | store product `grazia_plus_monthly` |
| pro | Rs 1,499 / month | 200 per month, 25 per day | store product `grazia_pro_monthly`; "3x Plus" |

Limits live in ONE place: `public.ai_plan_limits` table (seeded by the migration) so they can change without
an app release. Prices come from the store (never hard-coded in the UI; show the store's localized price).

Payments: Google Play Billing (Android) and Apple In-App Purchase (iOS) only. Digital features may not be
sold through Razorpay on either store.

## Database (supabase/migrations/20261030000000_ai_plans.sql)

- `public.ai_plan_limits(plan text pk, monthly_limit int null, daily_limit int not null)`; rows: trial(null,10),
  free(3,3), plus(60,10), pro(200,25). Read: everyone authenticated. Write: admins only.
- `public.subscriptions(user_id uuid pk -> auth.users, plan text check in ('plus','pro'), source text check in
  ('google_play','app_store','admin'), status text check in ('active','canceled','expired'), product_id text,
  purchase_token text, period_end timestamptz not null, note text, granted_by uuid, updated_at timestamptz)`.
  RLS: user selects own row; admins select all. No client insert/update (service role / admin RPC only).
- `ai_credits` gains `month_count int default 0`, `month_key text` ('YYYY-MM' IST).
- `public.get_ai_usage(p_user uuid)` -> one row: plan ('trial'|'free'|'plus'|'pro'), source, period_end,
  trial_ends_at, monthly_limit, monthly_used, daily_limit, daily_used, resets_at. Effective plan = active
  subscription with period_end > now(), else trial if now() < created_at + 7 days, else free.
- `public.consume_ai_render(p_user uuid)` -> ok, reason ('daily_limit'|'monthly_limit'|null) + the same usage
  fields after spending. `public.refund_ai_render(p_user uuid)` gives one back. Both SECURITY DEFINER,
  execute granted to service_role only (like consume_ai_credit).
- `public.admin_set_plan(p_user uuid, p_plan text, p_days int, p_note text)`: caller must be admin (same check
  the existing admin policies use); p_plan 'plus'|'pro' upserts source 'admin', period_end now()+p_days;
  p_plan 'free' expires the row. `public.admin_find_user(p_email text)` returns id, email, created_at, usage.
- Old `consume_ai_credit` / `refund_ai_credit` stay for old app builds.

## Vercel API (api/)

- `POST /api/ai-quota` (existing, auth required) -> `{plan, source, periodEnd, trialEndsAt, monthlyLimit,
  monthlyUsed, dailyLimit, dailyUsed, resetsAt}`. Keep old keys `creditsRemaining`, `dailyRemaining`,
  `dailyLimit` for old builds.
- `generate-visualization` spends with `consume_ai_render`; on refusal returns 402
  `{code: 'daily_limit'|'monthly_limit', usage: {...}}`.
- `POST /api/verify-purchase` (auth required) body `{platform: 'android'|'ios', productId, purchaseToken}`
  (iOS: purchaseToken = transaction id). Android: Google Play Developer API
  `purchases.subscriptionsv2.get` with the service account in env `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`.
  iOS: App Store Server API with env `APPSTORE_ISSUER_ID`, `APPSTORE_KEY_ID`, `APPSTORE_PRIVATE_KEY`,
  `APPSTORE_BUNDLE_ID`; if missing -> 503 `{code:'ios_verification_not_configured'}`. On a valid, active
  purchase upsert `subscriptions` (service role) and return the usage object. Never trust the client's
  claimed plan; map productId -> plan server-side. Reject a token already bound to another user.

## App

- Paywall `/pro` (existing route if present): Plus | Pro segmented switch, feature list, store price,
  "Auto-renews monthly. Cancel anytime in Google Play / App Store.", Restore purchases, Terms + Privacy.
- Usage chip in AI Studio and Profile: "Plus · 12 of 60 renders this month" / "Free trial · 4 days left".
- 402 from generation opens the paywall.
- Admin: "Plans" screen: find user by email, show usage, grant Plus/Pro for N days or revoke.

## Deploy steps

Nothing below has been done yet. Each step needs the owner's go-ahead.

1. **Apply the migration.** Run `supabase/migrations/20261030000000_ai_plans.sql` on the Grazia Supabase project
   (SQL editor or `supabase db push`). It is idempotent. Test it first locally with
   `tool/plans/run_sql_tests.sh` (throwaway Postgres, never touches Supabase). Deploy the API only after the
   migration is applied: the new API calls `consume_ai_render` / `get_ai_usage`, which do not exist before it.
2. **Vercel env vars** (project grazia-stones, Production + Preview):
   - `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`: full JSON key of a Google Cloud service account that has been invited in
     Play Console > Users and permissions with "View financial data" and "Manage orders and subscriptions".
   - `APPSTORE_ISSUER_ID`, `APPSTORE_KEY_ID`, `APPSTORE_PRIVATE_KEY` (the .p8 contents; literal `\n` is fine),
     `APPSTORE_BUNDLE_ID`: from App Store Connect > Users and Access > Integrations > In-App Purchase key.
     Without them iOS verification returns 503 `ios_verification_not_configured`.
   - Already present and still required: `SUPABASE_URL`, `SUPABASE_ANON_KEY` (or `SUPABASE_PUBLISHABLE_KEY`),
     `SUPABASE_SERVICE_ROLE_KEY` (or `SUPABASE_SECRET_KEY`).
3. **Play Console products** (app `com.graziastones.grazia_stones` > Monetize > Subscriptions):
   `grazia_plus_monthly` and `grazia_pro_monthly`, each with one auto-renewing monthly base plan
   (Rs 499 and Rs 1,499). The product ids must match exactly; the server maps them to plans.
4. **App Store Connect products**: an auto-renewable subscription group with `grazia_plus_monthly` and
   `grazia_pro_monthly` (monthly, same prices), plus the paid apps agreement and banking/tax set up.
5. **Later: Real-time developer notifications (RTDN).** Today a subscription is refreshed only when the app calls
   `/api/verify-purchase` (purchase or restore); renewals extend access only after the next call, and refunds or
   cancellations are not seen until `period_end` passes. Add a Pub/Sub topic + push endpoint for Google RTDN and
   App Store Server Notifications V2 to keep `subscriptions` in sync.
