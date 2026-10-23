# One Supabase dashboard sitting — everything waiting, in order

Prepared 2026-10-21, updated 2026-10-22 (items 10, Step 2b and Step 2c
added — the account-deletion build and the admin full-edit build both
joined this same sitting; later the same day the full end-to-end check
added items 11–14 and two more function redeploys — Step 2d). All of
the items below need the same one step first:
the owner signs in to the Supabase dashboard in Muse's browser
(the saved supabase.com login does not work, so Muse cannot go in alone).
After that one sign-in, everything here is done in one go.

## Step 1 — Email time back to 60 minutes

- Supabase dashboard → Authentication → Sign In / Providers → Email
- Set "Email OTP expiration" from 300 back to 3600 seconds. Save.
- Why: the owner chose 60 minutes on 2026-10-21 (5 minutes is too short
  for real signups on slow email). The email templates already print
  "60 minutes", so no template edit is needed.
- Status: still 300 seconds as of 2026-10-21 05:30 EDT — do not report
  this as done until a dashboard save is seen.

## Step 2 — Run these 14 SQL files, in this order

Dashboard → SQL Editor → paste the whole file → Run. One file at a time,
in this order. All files are in `supabase/migration/` in this repo.

1. `lookup_user_for_form.sql` — turns ON the patient autofill popup
   (type an email or mobile in an admin/panel form → popup with the
   patient's saved details → Fill or Cancel). Patient data only.
2. `hospital_consultation_fee.sql` — hospitals get a real fee field
   (the app no longer uses the fixed ₹300 in code).
3. `doctor_blocked_slots_public.sql` — patients can see a doctor's
   blocked times when booking (only date/time, never the reason).
4. `provider_application_details.sql` — a new provider's sign-up
   details (specialisation, fee, services…) are kept, not thrown away.
5. `pharmacy_medicines_policy.sql` — a pharmacy can manage its own
   medicines and stock from the partner side.
6. `appointments_collection_type.sql` — lab bookings save the
   walk-in / home-collection choice and address.
7. `driver_role.sql` — accounts can hold the driver role, so the
   driver side of the app can be reached at all.
8. `provider_application_decided_by.sql` — approve/reject of a
   provider records who made the decision.
9. `orders_coupon.sql` — orders save the coupon code and discount
   amount used at checkout.
10. `account_deletion_72h.sql` — turns ON the 72-hour account
    deletion flow built 2026-10-22: the deletion stamp on profiles,
    the hourly automatic erase (pg_cron, guarded if unavailable),
    admin/support reactivation, and the `email_outbox` table the
    deletion/reactivation emails wait in. Until this runs, the
    Delete button safely says it could not schedule and nothing
    is deleted.
11. `appointment_trigger_widen.sql` — widens the appointment
    guard trigger so providers can save a cancel reason,
    consultation notes, follow-up date and refund fields, and
    patients can save reschedule + refund-request fields. Until
    this runs, those saves are blocked by the database.
12. `provider_patient_contacts.sql` — gives a provider the name
    and phone of patients who have appointments with them (and
    nobody else). Until this runs, provider appointment lists
    show no patient names.
13. `delivery_orders_link_orders.sql` — points delivery orders
    at the real `orders` table and lets a pharmacy assign a
    driver. Until this runs, the driver side receives nothing.
14. `commission_flat_fee.sql` — the commission engine starts
    applying the flat fee from each commission rule (percent +
    flat fee, capped at the amount). Until this runs, only the
    percent part is taken.

Until these run, the app still works — each new feature just stays
off or falls back (that is how the all-76 form fixes were built).

## Step 2b — Deploy two Edge Functions (same sitting)

Dashboard → Edge Functions → deploy from the repo copies in
`supabase/functions/`:

1. `account-notify` — NEW. Sends the queued deletion/reactivation
   emails ("scheduled for deletion" warning + "your account is
   back") from `email_outbox` via Resend. Also set the secret
   `RESEND_API_KEY` (Edge Functions → Secrets) or no email sends —
   the rows just wait in the queue.
2. `admin-staff` — REDEPLOY the extended version. The new
   `update_email` / `set_password` actions power the admin Users
   full edit (change any account's login email or password, after
   the admin's own email OTP). The `create_user` action (added
   2026-10-23) powers Support → Users → Add user (creates a plain
   'user' account). Until this redeploy, photo and all
   other detail edits save normally, but email/password saves
   return the function's "Unknown action" error, and Add user in
   Support shows the same error and creates nothing.

## Step 2c — Quick checks for the new items

- Admin → Users → edit a test account's email (with admin OTP) →
  it should save, not show "Unknown action".
- Delete flow on a test account → it should schedule (not say
  "could not schedule") and a row should appear in `email_outbox`.

## Step 2d — Two more function redeploys (same sitting, from the full check)

3. `payment-create` — REDEPLOY. Central (storefront) payments
   now use the admin's saved Remedoo Pay UPI ID and payee name
   when the payment is not for one specific provider. Until this
   redeploy, those two saved settings are ignored.
4. `route-create-account` — REDEPLOY. A failed bank-account step
   or a failed database save now returns an honest failure
   instead of "success" (Razorpay itself is parked by the owner's
   order — this only matters when Route is used again).

## Step 3 — Quick checks after the sitting

- Ask for a new signup code and confirm it lives 60 minutes.
- In an admin form, type a known patient's mobile → the autofill
  popup should appear with Fill / Cancel.
- Book a lab test with home collection → the choice should be saved.

## Oct 30 note (checked 2026-10-21)

Supabase emailed on 2026-10-20: from October 30, NEW tables in
"public" need an explicit GRANT to be reachable by the API.
Checked: the first 9 files create no table (they add columns, one
function, and policies), and existing tables keep their grants.
Files 11–14 also create no table (functions, one foreign-key
change, and policies on existing tables), so the same applies.
File 10 does create one table, `email_outbox` — it is deliberately
NOT granted to clients (the file says so; only the service role /
account-notify function touches it), so the Oct 30 rule does not
break it either. For any future file that does create a
client-facing table, the grant template is ready in the same
folder: `zz_oct30_grants_template.sql`.
