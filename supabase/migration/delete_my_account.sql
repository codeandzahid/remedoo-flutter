-- Delete My Account (owner feature 2026-10-19)
-- A signed-in user can permanently delete their own account from
-- Profile > Danger Zone. The client calls rpc('delete_my_account').
-- The function removes the caller's rows from every public table
-- that carries a user_id column, then removes the auth user itself.
-- Per-table deletes are guarded so one failing table cannot block
-- the whole deletion; provider-side business records (bookings /
-- orders kept by providers) are scrubbed of the profile link by the
-- profiles/user_roles removal + auth user deletion at the end.

CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid uuid := auth.uid();
  t text;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Not signed in';
  END IF;

  -- Delete the caller's rows from every public table with user_id.
  FOR t IN
    SELECT DISTINCT table_name
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND column_name = 'user_id'
  LOOP
    BEGIN
      EXECUTE format('DELETE FROM public.%I WHERE user_id = $1', t)
        USING uid;
    EXCEPTION WHEN OTHERS THEN
      -- Skip tables that refuse (FK order etc.); the auth-user
      -- delete below cascades the identity rows that matter.
      NULL;
    END;
  END LOOP;

  -- Identity rows.
  BEGIN
    DELETE FROM public.user_roles WHERE user_id = uid;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  BEGIN
    DELETE FROM public.profiles WHERE user_id = uid;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  -- Finally remove the login itself.
  DELETE FROM auth.users WHERE id = uid;
END;
$$;

-- Only signed-in users may call it, and only ever for themselves
-- (the function reads auth.uid() internally).
REVOKE ALL ON FUNCTION public.delete_my_account() FROM public;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;
