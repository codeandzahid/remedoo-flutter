-- Existing-patient lookup for admin/panel form autofill (owner order,
-- 2026-10-21: "When admin and panelist types email or mobile number
-- the form will fill automatically for that user and pop up details
-- already found for this email or number and fill and cancel options";
-- scope correction the same day: "This rule only applies for patent
-- data not panalists" — patient data only, never panelist data).
--
-- Admin and panelist (doctor/hospital/lab/pharmacy) forms that enter
-- a patient's email or mobile number call this when the typed value
-- is complete. On an EXACT match it returns the one patient's form
-- details so the app can offer "Existing user found — Fill / Cancel".
--
-- Two gates, both enforced here in the database (the app never sees
-- data this function does not return):
--
--   CALLER gate — only admin / staff / provider roles may call it.
--   A patient (or anon) caller always gets an empty result, so a
--   patient can never read another user's data through this path.
--
--   PATIENT-only data (owner's scope correction) — a match is
--   returned ONLY for patient accounts: users whose single role is
--   'user' or who hold no role at all (the app's account rules treat
--   role-less accounts as patients; one email = one account, one
--   role per user). If the typed email/mobile belongs to a doctor,
--   hospital, lab, pharmacy, driver, admin or staff account, the
--   result is EMPTY — no popup, no fill, provider data is never
--   offered by this feature.
--
-- Matching: email compares case-insensitively against the profile
-- email and the auth email; a mobile compares on the last 10 digits
-- (a leading +91 country code or 0 trunk prefix is ignored on both
-- sides). Only the form-relevant columns are returned — nothing
-- else about the account is exposed.
--
-- Apply in the Supabase SQL editor. Until applied, the app's calls
-- fail soft (repository catches) and forms simply never pop up.

CREATE OR REPLACE FUNCTION public.lookup_user_for_form(lookup_value text)
RETURNS TABLE (
  user_id uuid,
  full_name text,
  email text,
  phone text,
  address text,
  gender text,
  date_of_birth date
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v text := trim(coalesce(lookup_value, ''));
  digits text;
BEGIN
  -- Caller gate: admin / staff / provider roles only.
  IF NOT (
    public.has_role(auth.uid(), 'admin'::app_role)
    OR public.has_role(auth.uid(), 'staff'::app_role)
    OR public.has_role(auth.uid(), 'doctor'::app_role)
    OR public.has_role(auth.uid(), 'hospital'::app_role)
    OR public.has_role(auth.uid(), 'lab'::app_role)
    OR public.has_role(auth.uid(), 'pharmacy'::app_role)
  ) THEN
    RETURN;
  END IF;

  -- Normalise the typed value's digits the same way the stored
  -- phone is normalised below: last 10 digits identify a mobile.
  digits := regexp_replace(v, '\D', '', 'g');
  IF length(digits) = 12 AND left(digits, 2) = '91' THEN
    digits := right(digits, 10);
  ELSIF length(digits) = 11 AND left(digits, 1) = '0' THEN
    digits := right(digits, 10);
  END IF;

  RETURN QUERY
  SELECT p.user_id,
         p.full_name,
         COALESCE(p.email, u.email),
         p.phone,
         p.address,
         p.gender,
         p.date_of_birth
  FROM public.profiles p
  JOIN auth.users u ON u.id = p.user_id
  WHERE (
      -- Exact email match (only attempted for email-shaped input).
      (position('@' in v) > 0
        AND (lower(p.email) = lower(v) OR lower(u.email) = lower(v)))
      -- Exact mobile match on the last 10 digits.
      OR (length(digits) = 10
        AND right(regexp_replace(coalesce(p.phone, ''), '\D', '', 'g'), 10)
            = digits)
    )
    -- Patient accounts only: no role row, or the 'user' role. Any
    -- provider/admin/staff/driver role excludes the account.
    AND NOT EXISTS (
      SELECT 1
      FROM public.user_roles r
      WHERE r.user_id = p.user_id
        AND r.role <> 'user'::app_role
    )
  LIMIT 1;
END;
$$;

-- Authenticated callers only (the role gate inside does the rest);
-- never anon — this is an admin/panel feature, not a public one.
GRANT EXECUTE ON FUNCTION public.lookup_user_for_form(text) TO authenticated;
