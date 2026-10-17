# Remedoo Pay — Cloudflare Worker

A Cloudflare-native version of the YouPI PG self-hosted UPI gateway
(the original YouPI server needs an always-on Node host, so it cannot
run on Cloudflare Workers). Same product behaviour:

- **0% fees** — customers pay straight to the merchant's own UPI ID.
- **Hosted checkout page** — QR code + "Pay with any UPI app" button,
  auto-confirms when the payment lands.
- **One payment at a time — no queue** — a new payment cannot start
  until the current one is paid, cancelled, or expires (1-minute
  window), so bank SMS credits can be matched to the right session.
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

- Matching is by exact amount against the single ACTIVE session
  (only one payment is ever open, so this is reliable).
- If the phone/observer is off, a payment stays unverified until the
  SMS is forwarded; the session expires after 1 minute and the
  customer can retry.
