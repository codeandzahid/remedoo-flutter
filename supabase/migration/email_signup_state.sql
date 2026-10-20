-- Signup email state for the duplicate-email guard (Live Test 3 fix,
-- 2026-10-20).
-- The signup form's guard used public.email_registered(check_email),
-- which answers only true/false for ANY auth user with the email.
-- The first OTP send creates the (unconfirmed, passwordless) auth
-- user, so from that moment the guard hard-blocked the very person
-- trying to sign up: "Resend code" answered "This email is already
-- used. Please log in instead." — and login was impossible, because
-- no password is set until signup Step 2. A permanent dead-end.
--
-- This function reports the email's signup STATE instead:
--   'new'        no account with this email
--   'incomplete' an account exists but signup was never finished:
--                no name on the profiles row, no name in the auth
--                user's metadata, and no row in user_roles (the
--                completion signal signup Step 2 itself uses is a
--                non-empty profiles.full_name). The app lets the
--                owner resume and finish the SAME account.
--   'complete'   a finished account (named profile, a signup-time
--                metadata name, or any assigned role). The guard
--                blocks signup for these and points to login.
-- Only one of those three words is returned — no account data is
-- exposed. Apply in the Supabase SQL editor; until applied, the app
-- falls back to email_registered (existing emails read as complete).

CREATE OR REPLACE FUNCTION public.email_signup_state(check_email text)
RETURNS text
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE
    WHEN NOT EXISTS (
      SELECT 1 FROM auth.users u
      WHERE lower(u.email) = lower(check_email)
    ) THEN 'new'
    WHEN EXISTS (
      SELECT 1
      FROM auth.users u
      LEFT JOIN public.profiles p ON p.user_id = u.id
      WHERE lower(u.email) = lower(check_email)
        AND (
          COALESCE(trim(p.full_name), '') <> ''
          OR COALESCE(trim(u.raw_user_meta_data ->> 'display_name'), '') <> ''
          OR COALESCE(trim(u.raw_user_meta_data ->> 'full_name'), '') <> ''
          OR EXISTS (
            SELECT 1 FROM public.user_roles r WHERE r.user_id = u.id
          )
        )
    ) THEN 'complete'
    ELSE 'incomplete'
  END;
$$;

GRANT EXECUTE ON FUNCTION public.email_signup_state(text) TO anon, authenticated;
