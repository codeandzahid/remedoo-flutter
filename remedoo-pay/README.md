# Remedoo Pay — Cloudflare Worker

A Cloudflare-native version of the YouPI PG self-hosted UPI gateway
(the original YouPI server needs an always-on Node host, so it cannot
run on Cloudflare Workers). Same product behaviour:

- **0% fees** — customers pay straight to the merchant's own UPI ID.
- **Hosted checkout page** — "Pay with any UPI app" button + a QR code
  to scan, auto-confirms when the payment lands.
- **Several payments at a time per receiving UPI (micro-paise
  allocation)** — each open session gets a unique payable amount:
  the base amount, or base +1, +2, ... paise when the base is
  already in use (5-minute window per session). Bank credits are
  matched by exact amount, so the paise offset tells sessions
  apart — two customers paying the same amount at the same moment
  no longer block each other.
- **Per-provider UPI (panelists)** — doctors / pharmacies / labs /
  hospitals add their OWN UPI ID in their panel (Payments section).
  Bookings for a provider who activated their UPI are paid straight to
  them: `payment-create` looks up the provider record and passes
  `vpa` / `payeeName` / `providerKind` / `providerId` /
  `providerUserId`, stored on the session; the checkout page uses the
  session's UPI. A provider who has NOT activated a UPI shows online
  payment as **Not Available** (no fallback to the central UPI).
  Payment options are OFF after registration — the provider activates
  Pay Online and/or Pay at Clinic (COD) in their panel, and activation
  (or changing the UPI ID) requires an email-OTP confirmation.
  Providers see their own sessions in their panel and can Confirm Paid
  (RLS: `provider_user_id = auth.uid()`).
- **Verification by bank-SMS observer** — a free SMS-forwarder app on
  the phone that receives the merchant's bank SMS POSTs every credit
  SMS to the Worker, which matches it to the active session.

## Moving parts

| Piece | Where |
|---|---|
| `worker.js` | Cloudflare Worker named `remedoo-pay` |
| Sessions | Supabase table `remedoo_pay_sessions` (see `schema.sql`) |
| Merchant config | Remedoo Admin → Settings → Payment System → Remedoo Pay card: **Server URL** (the Worker URL), **UPI ID**, **Payee Name** — stored in `app_config.payment_gateways.youpi` |
| Observer token | `secure_settings` key `remedoo_pay_observer_token` (generated from the Remedoo Pay card) |
| Worker secrets | Cloudflare dashboard → Worker → Settings → Variables: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` |

Remedoo's `payment-create` / `payment-status` Edge Functions call this
Worker at `gateways.youpi.base_url` with the YouPI API shape
(`POST /api/v1/payments`, `GET /api/v1/payments/:id`).

## Observer setup (merchant phone)

1. Install any "SMS forwarder" app that can POST incoming SMS to a URL.
2. Create a rule: forward messages from your bank's sender ID that
   contain "credited".
3. URL: `https://<worker-url>/api/v1/observer/sms`
   Header: `X-Observer-Token: <token from the Remedoo Pay card>`
   Body (JSON): `{"text": "<the SMS text>"}` — most forwarder apps let
   you use a placeholder for the message body.

## Limits

- Matching is by exact amount. Open sessions on the same UPI always
  carry different amounts (micro-paise allocation), so an exact-amount
  match is reliable even with several payments open at once.
- If the phone/observer is off, a payment stays unverified until the
  SMS is forwarded; the session expires after 5 minutes and the
  customer can retry.

## Gmail automation (no phone app)

As an alternative (or backup) to the SMS forwarder, the merchant can
connect the Gmail account that receives the bank's credit-alert
emails. A Cloudflare Cron Trigger fires the Worker's `scheduled`
handler every minute; it polls Gmail and feeds each credit email
through the SAME parser + amount matching as the SMS observer, so a
payment confirms itself with zero action by customer or panelist.

- Covers payments received on the **central UPI only** — panelists'
  own-UPI alerts go to their own email accounts and still confirm
  via their SMS app or Confirm Paid tap.
- Setup: create a Google Cloud OAuth client (Web application) with
  redirect URI `<worker-url>/api/v1/gmail/callback`, paste the
  Client ID + Secret in Remedoo Admin → Payments → Remedoo Pay →
  Gmail Automation, then tap **Connect Gmail** and sign in once.
  The refresh token is stored server-side in `secure_settings`
  (keys `gmail_*`); the app never sees it.
- Endpoints: `GET /api/v1/gmail/connect`, `GET /api/v1/gmail/callback`,
  `POST /api/v1/gmail/test`, `POST /api/v1/gmail/poll`,
  `POST /api/v1/gmail/disconnect` (test/poll/disconnect use the
  observer token, same as the SMS webhook).
- **Instant check**: the checkout page calls
  `POST /api/v1/checkout/:id/check` the moment the customer comes
  back from their UPI app (page visible / window focus). The Worker
  runs a Gmail poll right then (throttled to one per 8 seconds), so
  a payment that just landed confirms in seconds instead of waiting
  for the next 1-minute cron tick.
- Parser fixtures (SMS + email bodies, Gmail message shapes):
  `node remedoo-pay/test-parse.mjs`.

## Standalone reuse — other projects (2026-11-23)

Remedoo Pay is a separate payment system. The Remedoo app is just
its first project; any other project can use the same Worker API:

1. Run `supabase/migration/remedoo_pay_projects.sql` once
   (adds `remedoo_pay_projects` + `project_id` on sessions).
2. In the admin console (https://remedoo-app.pages.dev/remedoopayadmin
   → Projects tab) add the project: ID, name, its own UPI ID,
   payee name, and an API key.
3. The other project calls:
   - `POST /api/v1/payments` with `{orderId, amount, projectId}`
     and header `x-api-key: <key>` → returns `checkoutUrl`.
   - `GET /api/v1/payments/{id}` for status.
   - Customers pay on the hosted checkout page; confirmation is by
     the same SMS-observer / Gmail automation.

No `projectId` = the built-in `remedoo` project (unchanged
behaviour). A disabled project or a wrong API key is rejected.
