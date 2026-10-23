-- Coupon "Coupon not found" fix, part 2 (2026-10-23): the
-- coupons RLS defined in schema_part_03.sql only lets
-- AUTHENTICATED users read active coupons:
--   "Authenticated users can view active coupons" FOR SELECT
--   TO authenticated USING (is_active = true)
-- The patient cart / checkout screens (which carry the coupon
-- field) are reachable in guest mode, where the app has NO
-- Supabase user at all (guest mode is a local flag; there is no
-- anonymous sign-in), so those requests run as the anon role.
-- With RLS enabled and no anon policy, the coupons SELECT
-- silently returns zero rows — no error — and the app reports
-- "Coupon not found" for a code that exists and is active.
-- This mirrors the authenticated read for anon: active coupons
-- only, read-only. Admin write policies are unchanged.
-- The app degrades gracefully until this is applied: signed-in
-- patients can use coupons; guests still see "not found".
DROP POLICY IF EXISTS "Anyone can view active coupons" ON public.coupons;
CREATE POLICY "Anyone can view active coupons"
  ON public.coupons FOR SELECT TO anon
  USING (is_active = true);
