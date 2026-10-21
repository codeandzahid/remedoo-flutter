# One Supabase dashboard sitting — everything waiting, in order

Prepared 2026-10-21. All of the items below need the same one step first:
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

## Step 2 — Run these 9 SQL files, in this order

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

Until these run, the app still works — each new feature just stays
off or falls back (that is how the all-76 form fixes were built).

## Step 3 — Quick checks after the sitting

- Ask for a new signup code and confirm it lives 60 minutes.
- In an admin form, type a known patient's mobile → the autofill
  popup should appear with Fill / Cancel.
- Book a lab test with home collection → the choice should be saved.

## Oct 30 note (checked 2026-10-21)

Supabase emailed on 2026-10-20: from October 30, NEW tables in
"public" need an explicit GRANT to be reachable by the API.
Checked: none of the 9 files above creates a table (they add
columns, one function, and policies), and existing tables keep
their grants — so this deadline does not break the sitting,
before or after Oct 30. For any future file that does create a
table, the grant template is ready in the same folder:
`zz_oct30_grants_template.sql`.
