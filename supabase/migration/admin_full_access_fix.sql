-- ============================================================
-- FIX (2026-10-18): "Admin full access" infinite recursion
--
-- The super-admin grant created the "Admin full access" policy
-- with an EXISTS (SELECT ... FROM user_roles ...) condition.
-- On user_roles itself — and via policy chains from every other
-- table — that subquery re-enters the same policy, so Postgres
-- aborts ANY authenticated query touching it with:
--   ERROR 42P17: infinite recursion detected in policy
-- The app's role check then failed silently and every login
-- (admin included) fell through to the patient shell.
--
-- Fix: express the same rule with the project's existing
-- SECURITY DEFINER helper has_role(uid, 'admin'), whose inner
-- read of user_roles bypasses RLS, so no recursion is possible.
-- Same authority, no loop. Also applied to the storage policy
-- and to the staff_permissions admin policy (same EXISTS flaw).
-- ============================================================

DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT tablename FROM pg_tables WHERE schemaname = 'public'
  LOOP
    EXECUTE format(
      'DROP POLICY IF EXISTS "Admin full access" ON public.%I',
      r.tablename);
    EXECUTE format(
      'CREATE POLICY "Admin full access" ON public.%I FOR ALL '
      'USING (has_role(auth.uid(), ''admin''::app_role)) '
      'WITH CHECK (has_role(auth.uid(), ''admin''::app_role))',
      r.tablename);
  END LOOP;
END $$;

DROP POLICY IF EXISTS "Admin full access storage" ON storage.objects;
CREATE POLICY "Admin full access storage" ON storage.objects FOR ALL
  USING (has_role(auth.uid(), 'admin'::app_role))
  WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

DROP POLICY IF EXISTS "Admins manage staff permissions"
  ON public.staff_permissions;
CREATE POLICY "Admins manage staff permissions"
  ON public.staff_permissions FOR ALL
  USING (has_role(auth.uid(), 'admin'::app_role))
  WITH CHECK (has_role(auth.uid(), 'admin'::app_role));
