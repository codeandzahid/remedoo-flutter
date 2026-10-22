-- Account deletion with a 72-hour safety window (owner order 2026-10-22).
--
-- Flow:
--   1. The user confirms with an email OTP in the app and taps Delete.
--      The app calls request_account_deletion(): the account is marked
--      (profiles.deletion_requested_at = now) and signed out. Nothing is
--      erased yet.
--   2. For 72 hours the account stays closed. If the user logs in, the
--      app shows the "scheduled for deletion" page instead of the app;
--      from there (after another email OTP) the user can file a support
--      request asking for reactivation.
--   3. An admin, or a staff member holding the 'support' section, calls
--      reactivate_account(user_id): the mark is cleared and the user can
--      log in again.
--   4. purge_expired_account_deletions() hard-erases every account whose
--      72 hours have passed (same erase as delete_my_account). A pg_cron
--      job runs it hourly when pg_cron is available; an admin can also
--      run it by hand from SQL.
--
-- Emails: both events queue a row in public.email_outbox. The Edge
-- Function supabase/functions/account-notify sends queued rows (needs
-- the RESEND_API_KEY secret; until then rows simply wait in the queue).

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS deletion_requested_at timestamptz;

-- ---------------------------------------------------------------- outbox

CREATE TABLE IF NOT EXISTS public.email_outbox (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  to_email text NOT NULL,
  subject text NOT NULL,
  body text NOT NULL,
  kind text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  sent_at timestamptz
);

ALTER TABLE public.email_outbox ENABLE ROW LEVEL SECURITY;
-- No client policies: only SECURITY DEFINER functions write rows and the
-- service-role Edge Function reads/marks them.

-- ------------------------------------------------------- internal erase

-- Hard-erases one user's data + auth login. Shared by delete_my_account
-- (immediate, legacy) and the 72-hour purge. NOT granted to clients:
-- callers go through the guarded functions below.
CREATE OR REPLACE FUNCTION public._erase_user_account(p_uid uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  t text;
BEGIN
  IF p_uid IS NULL THEN
    RAISE EXCEPTION 'No user id';
  END IF;

  FOR t IN
    SELECT DISTINCT table_name
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND column_name = 'user_id'
  LOOP
    BEGIN
      EXECUTE format('DELETE FROM public.%I WHERE user_id = $1', t)
        USING p_uid;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END LOOP;

  BEGIN
    DELETE FROM public.user_roles WHERE user_id = p_uid;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  BEGIN
    DELETE FROM public.profiles WHERE user_id = p_uid;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  DELETE FROM auth.users WHERE id = p_uid;
END;
$$;

REVOKE ALL ON FUNCTION public._erase_user_account(uuid) FROM public;

-- delete_my_account keeps its old contract, now via the shared erase.
CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid uuid := auth.uid();
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Not signed in';
  END IF;
  PERFORM public._erase_user_account(uid);
END;
$$;

REVOKE ALL ON FUNCTION public.delete_my_account() FROM public;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;

-- ------------------------------------------------- request the deletion

-- Marks the caller's account for deletion and returns the exact moment
-- the data will be erased (request time + 72 hours). Also queues the
-- "scheduled for deletion" warning email.
CREATE OR REPLACE FUNCTION public.request_account_deletion()
RETURNS timestamptz
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid uuid := auth.uid();
  v_email text;
  v_requested timestamptz := now();
  v_erase timestamptz := now() + interval '72 hours';
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Not signed in';
  END IF;

  UPDATE public.profiles
     SET deletion_requested_at = v_requested
   WHERE user_id = uid
  RETURNING email INTO v_email;

  IF v_email IS NOT NULL AND v_email <> '' THEN
    INSERT INTO public.email_outbox (to_email, subject, body, kind)
    VALUES (
      v_email,
      'Your Remedoo account is scheduled for deletion',
      'Hello,' || chr(10) || chr(10) ||
      'Your Remedoo account was scheduled for deletion. Everything in ' ||
      'your account will be erased from our server forever at ' ||
      to_char(v_erase, 'DD Mon YYYY, HH24:MI') || ' (72 hours from the ' ||
      'request).' || chr(10) || chr(10) ||
      'If this was not you, or you changed your mind, log in to Remedoo ' ||
      'and tap "Reactivate my account" on the deletion page, or contact ' ||
      'support before that time.' || chr(10) || chr(10) ||
      '— Team Remedoo',
      'deletion_scheduled'
    );
  END IF;

  RETURN v_erase;
END;
$$;

REVOKE ALL ON FUNCTION public.request_account_deletion() FROM public;
GRANT EXECUTE ON FUNCTION public.request_account_deletion() TO authenticated;

-- ------------------------------------------------------------ reactivate

-- Clears the deletion mark for [p_user_id]. Caller must be an admin
-- (app_role 'admin') or a staff member holding the 'support' section —
-- the same people who see Admin > Support. Queues the "your account is
-- back" email.
CREATE OR REPLACE FUNCTION public.reactivate_account(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not signed in';
  END IF;
  IF NOT (public.has_role(auth.uid(), 'admin'::app_role)
          OR public.staff_has_section('support')) THEN
    RAISE EXCEPTION 'Only admin or support can reactivate accounts';
  END IF;

  UPDATE public.profiles
     SET deletion_requested_at = NULL
   WHERE user_id = p_user_id
     AND deletion_requested_at IS NOT NULL
  RETURNING email INTO v_email;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF v_email IS NOT NULL AND v_email <> '' THEN
    INSERT INTO public.email_outbox (to_email, subject, body, kind)
    VALUES (
      v_email,
      'Your Remedoo account is back',
      'Hello,' || chr(10) || chr(10) ||
      'Good news — your Remedoo account was reactivated by our support ' ||
      'team. The scheduled deletion is cancelled and nothing was ' ||
      'erased.' || chr(10) || chr(10) ||
      'You can now login again with your email and password.' ||
      chr(10) || chr(10) || '— Team Remedoo',
      'account_reactivated'
    );
  END IF;

  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.reactivate_account(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.reactivate_account(uuid) TO authenticated;

-- ----------------------------------------------------------------- purge

-- Hard-erases every account whose 72-hour window has passed. Returns
-- how many accounts were erased. A signed-in caller must be an admin;
-- the pg_cron job (no auth context) is allowed.
CREATE OR REPLACE FUNCTION public.purge_expired_account_deletions()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r record;
  v_count integer := 0;
BEGIN
  IF auth.uid() IS NOT NULL
     AND NOT public.has_role(auth.uid(), 'admin'::app_role) THEN
    RAISE EXCEPTION 'Only admin can run the purge';
  END IF;

  FOR r IN
    SELECT user_id
      FROM public.profiles
     WHERE deletion_requested_at IS NOT NULL
       AND deletion_requested_at < now() - interval '72 hours'
  LOOP
    PERFORM public._erase_user_account(r.user_id);
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.purge_expired_account_deletions() FROM public;
GRANT EXECUTE ON FUNCTION public.purge_expired_account_deletions()
  TO authenticated;

-- Hourly automatic purge. Guarded: if pg_cron is not enabled on this
-- project the migration still succeeds and the purge can be run by hand
-- (select public.purge_expired_account_deletions();).
DO $$
BEGIN
  CREATE EXTENSION IF NOT EXISTS pg_cron;
  PERFORM cron.unschedule('purge-expired-account-deletions');
EXCEPTION WHEN OTHERS THEN
  NULL;
END;
$$;

DO $$
BEGIN
  PERFORM cron.schedule(
    'purge-expired-account-deletions',
    '17 * * * *',
    'select public.purge_expired_account_deletions();'
  );
EXCEPTION WHEN OTHERS THEN
  NULL;
END;
$$;
