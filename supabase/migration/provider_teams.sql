-- Provider teams (owner order 2026-10-24): every panelist
-- (doctor / hospital / lab / pharmacy) can create a team, and
-- hospitals, labs and pharmacies can also add drivers.
--
-- A team member is a real login account with the SAME role as the
-- provider, linked to the provider's record through
-- provider_team_members. The partner panels resolve the provider
-- record through that link, so a member opens the same panel as
-- the owner, gated by their per-tab access map:
--   access: { "<tab>": "full" | "view" | "none" }
-- Tab keys per panel:
--   doctor:   visits, profile, payments, reviews
--   hospital: appointments, profile, payments, reviews
--   lab:      bookings, my_tests, profile, payments, reviews
--   pharmacy: orders, medicines, profile, payments, reviews
-- Drivers are an extra key ('drivers') on hospital/lab/pharmacy
-- teams. The owner always has full access; the Team tab itself is
-- owner-only (team members never manage the team).
--
-- Idempotent: safe to re-run. Additive policies only — existing
-- owner policies are untouched.
-- Run in Supabase SQL editor (dashboard sitting item 17).

-- ============ TEAM MEMBERSHIP TABLE ============
CREATE TABLE IF NOT EXISTS public.provider_team_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_type TEXT NOT NULL
    CHECK (provider_type IN ('doctor', 'hospital', 'lab', 'pharmacy')),
  provider_id UUID NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  -- Display snapshot (the owner's list reads membership rows, not
  -- other users' profile rows, which RLS would block).
  name TEXT NOT NULL DEFAULT '',
  email TEXT NOT NULL DEFAULT '',
  access JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (provider_type, provider_id, user_id)
);
ALTER TABLE public.provider_team_members ENABLE ROW LEVEL SECURITY;

-- Oct 30 rule: new tables need explicit API grants (RLS still
-- decides which rows each caller sees or changes).
GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.provider_team_members TO authenticated, service_role;

-- ============ HELPERS ============
-- Provider record id for a user: their own record, or the record
-- they are an active team member of. NULL when neither.
CREATE OR REPLACE FUNCTION public.provider_team_provider_id(
  p_type TEXT, p_uid UUID
) RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id FROM (
    SELECT id FROM public.doctors
      WHERE p_type = 'doctor' AND user_id = p_uid
    UNION ALL
    SELECT id FROM public.hospitals
      WHERE p_type = 'hospital' AND user_id = p_uid
    UNION ALL
    SELECT id FROM public.labs
      WHERE p_type = 'lab' AND user_id = p_uid
    UNION ALL
    SELECT id FROM public.pharmacies
      WHERE p_type = 'pharmacy' AND user_id = p_uid
    UNION ALL
    SELECT provider_id AS id FROM public.provider_team_members
      WHERE provider_type = p_type AND user_id = p_uid AND is_active
  ) s
  LIMIT 1;
$$;

-- Access level for a user on one tab of a provider panel:
-- 'full' for the owner, the stored level for a team member,
-- 'none' otherwise.
CREATE OR REPLACE FUNCTION public.provider_team_access(
  p_type TEXT, p_uid UUID, p_tab TEXT
) RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE
    WHEN EXISTS (
      SELECT 1 FROM public.doctors
        WHERE p_type = 'doctor' AND user_id = p_uid
    ) OR EXISTS (
      SELECT 1 FROM public.hospitals
        WHERE p_type = 'hospital' AND user_id = p_uid
    ) OR EXISTS (
      SELECT 1 FROM public.labs
        WHERE p_type = 'lab' AND user_id = p_uid
    ) OR EXISTS (
      SELECT 1 FROM public.pharmacies
        WHERE p_type = 'pharmacy' AND user_id = p_uid
    ) THEN 'full'
    ELSE COALESCE((
      SELECT access ->> p_tab FROM public.provider_team_members
        WHERE provider_type = p_type AND user_id = p_uid AND is_active
        LIMIT 1
    ), 'none')
  END;
$$;

-- Helper functions are called from RLS policies (which run as the
-- table owner) and from the app's own checks — grant execute so
-- the API role can use them directly too.
GRANT EXECUTE ON FUNCTION public.provider_team_provider_id(TEXT, UUID)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.provider_team_access(TEXT, UUID, TEXT)
  TO authenticated;

-- ============ TEAM MEMBERSHIP RLS ============
DROP POLICY IF EXISTS "Team owner manages members"
  ON public.provider_team_members;
CREATE POLICY "Team owner manages members"
  ON public.provider_team_members FOR ALL TO authenticated
  USING (
    public.has_role(auth.uid(), 'admin')
    OR (provider_type = 'doctor' AND provider_id IN (
      SELECT id FROM public.doctors WHERE user_id = auth.uid()))
    OR (provider_type = 'hospital' AND provider_id IN (
      SELECT id FROM public.hospitals WHERE user_id = auth.uid()))
    OR (provider_type = 'lab' AND provider_id IN (
      SELECT id FROM public.labs WHERE user_id = auth.uid()))
    OR (provider_type = 'pharmacy' AND provider_id IN (
      SELECT id FROM public.pharmacies WHERE user_id = auth.uid()))
  )
  WITH CHECK (
    public.has_role(auth.uid(), 'admin')
    OR (provider_type = 'doctor' AND provider_id IN (
      SELECT id FROM public.doctors WHERE user_id = auth.uid()))
    OR (provider_type = 'hospital' AND provider_id IN (
      SELECT id FROM public.hospitals WHERE user_id = auth.uid()))
    OR (provider_type = 'lab' AND provider_id IN (
      SELECT id FROM public.labs WHERE user_id = auth.uid()))
    OR (provider_type = 'pharmacy' AND provider_id IN (
      SELECT id FROM public.pharmacies WHERE user_id = auth.uid()))
  );

DROP POLICY IF EXISTS "Team member reads own row"
  ON public.provider_team_members;
CREATE POLICY "Team member reads own row"
  ON public.provider_team_members FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- ============ APPOINTMENTS (doctor / hospital / lab) ============
-- Work-tab keys: doctor 'visits', hospital 'appointments', lab 'bookings'.
DROP POLICY IF EXISTS "Team can view appointments"
  ON public.appointments;
CREATE POLICY "Team can view appointments"
  ON public.appointments FOR SELECT TO authenticated
  USING (
    (public.has_role(auth.uid(), 'doctor'::app_role)
      AND doctor_id = public.provider_team_provider_id('doctor', auth.uid())
      AND public.provider_team_access('doctor', auth.uid(), 'visits') IN ('view', 'full'))
    OR (public.has_role(auth.uid(), 'hospital'::app_role)
      AND hospital_id = public.provider_team_provider_id('hospital', auth.uid())
      AND public.provider_team_access('hospital', auth.uid(), 'appointments') IN ('view', 'full'))
    OR (public.has_role(auth.uid(), 'lab'::app_role)
      AND lab_id = public.provider_team_provider_id('lab', auth.uid())
      AND public.provider_team_access('lab', auth.uid(), 'bookings') IN ('view', 'full'))
  );

DROP POLICY IF EXISTS "Team can update appointments"
  ON public.appointments;
CREATE POLICY "Team can update appointments"
  ON public.appointments FOR UPDATE TO authenticated
  USING (
    (public.has_role(auth.uid(), 'doctor'::app_role)
      AND doctor_id = public.provider_team_provider_id('doctor', auth.uid())
      AND public.provider_team_access('doctor', auth.uid(), 'visits') = 'full')
    OR (public.has_role(auth.uid(), 'hospital'::app_role)
      AND hospital_id = public.provider_team_provider_id('hospital', auth.uid())
      AND public.provider_team_access('hospital', auth.uid(), 'appointments') = 'full')
    OR (public.has_role(auth.uid(), 'lab'::app_role)
      AND lab_id = public.provider_team_provider_id('lab', auth.uid())
      AND public.provider_team_access('lab', auth.uid(), 'bookings') = 'full')
  )
  WITH CHECK (
    (public.has_role(auth.uid(), 'doctor'::app_role)
      AND doctor_id = public.provider_team_provider_id('doctor', auth.uid())
      AND public.provider_team_access('doctor', auth.uid(), 'visits') = 'full')
    OR (public.has_role(auth.uid(), 'hospital'::app_role)
      AND hospital_id = public.provider_team_provider_id('hospital', auth.uid())
      AND public.provider_team_access('hospital', auth.uid(), 'appointments') = 'full')
    OR (public.has_role(auth.uid(), 'lab'::app_role)
      AND lab_id = public.provider_team_provider_id('lab', auth.uid())
      AND public.provider_team_access('lab', auth.uid(), 'bookings') = 'full')
  );

-- ============ ORDERS + ORDER ITEMS (pharmacy) ============
DROP POLICY IF EXISTS "Team can view orders" ON public.orders;
CREATE POLICY "Team can view orders"
  ON public.orders FOR SELECT TO authenticated
  USING (
    public.has_role(auth.uid(), 'pharmacy'::app_role)
    AND pharmacy_id = public.provider_team_provider_id('pharmacy', auth.uid())
    AND public.provider_team_access('pharmacy', auth.uid(), 'orders') IN ('view', 'full')
  );

DROP POLICY IF EXISTS "Team can update orders" ON public.orders;
CREATE POLICY "Team can update orders"
  ON public.orders FOR UPDATE TO authenticated
  USING (
    public.has_role(auth.uid(), 'pharmacy'::app_role)
    AND pharmacy_id = public.provider_team_provider_id('pharmacy', auth.uid())
    AND public.provider_team_access('pharmacy', auth.uid(), 'orders') = 'full'
  )
  WITH CHECK (
    public.has_role(auth.uid(), 'pharmacy'::app_role)
    AND pharmacy_id = public.provider_team_provider_id('pharmacy', auth.uid())
    AND public.provider_team_access('pharmacy', auth.uid(), 'orders') = 'full'
  );

DROP POLICY IF EXISTS "Team can view order items" ON public.order_items;
CREATE POLICY "Team can view order items"
  ON public.order_items FOR SELECT TO authenticated
  USING (
    public.has_role(auth.uid(), 'pharmacy'::app_role)
    AND order_id IN (
      SELECT o.id FROM public.orders o
      WHERE o.pharmacy_id =
        public.provider_team_provider_id('pharmacy', auth.uid())
    )
    AND public.provider_team_access('pharmacy', auth.uid(), 'orders') IN ('view', 'full')
  );

-- ============ PROVIDER PROFILES ============
-- Team members read the shared profile when they have profile
-- access; writes need full profile access. (Public catalogue reads
-- already exist for hospitals/pharmacies; these cover doctors/labs
-- and keep the rule explicit everywhere.)
DROP POLICY IF EXISTS "Team can view provider profile" ON public.doctors;
CREATE POLICY "Team can view provider profile"
  ON public.doctors FOR SELECT TO authenticated
  USING (
    id = public.provider_team_provider_id('doctor', auth.uid())
    AND public.provider_team_access('doctor', auth.uid(), 'profile') IN ('view', 'full')
  );
DROP POLICY IF EXISTS "Team can update provider profile" ON public.doctors;
CREATE POLICY "Team can update provider profile"
  ON public.doctors FOR UPDATE TO authenticated
  USING (
    id = public.provider_team_provider_id('doctor', auth.uid())
    AND public.provider_team_access('doctor', auth.uid(), 'profile') = 'full'
  )
  WITH CHECK (
    id = public.provider_team_provider_id('doctor', auth.uid())
    AND public.provider_team_access('doctor', auth.uid(), 'profile') = 'full'
  );

DROP POLICY IF EXISTS "Team can view provider profile" ON public.hospitals;
CREATE POLICY "Team can view provider profile"
  ON public.hospitals FOR SELECT TO authenticated
  USING (
    id = public.provider_team_provider_id('hospital', auth.uid())
    AND public.provider_team_access('hospital', auth.uid(), 'profile') IN ('view', 'full')
  );
DROP POLICY IF EXISTS "Team can update provider profile" ON public.hospitals;
CREATE POLICY "Team can update provider profile"
  ON public.hospitals FOR UPDATE TO authenticated
  USING (
    id = public.provider_team_provider_id('hospital', auth.uid())
    AND public.provider_team_access('hospital', auth.uid(), 'profile') = 'full'
  )
  WITH CHECK (
    id = public.provider_team_provider_id('hospital', auth.uid())
    AND public.provider_team_access('hospital', auth.uid(), 'profile') = 'full'
  );

DROP POLICY IF EXISTS "Team can view provider profile" ON public.labs;
CREATE POLICY "Team can view provider profile"
  ON public.labs FOR SELECT TO authenticated
  USING (
    id = public.provider_team_provider_id('lab', auth.uid())
    AND public.provider_team_access('lab', auth.uid(), 'profile') IN ('view', 'full')
  );
DROP POLICY IF EXISTS "Team can update provider profile" ON public.labs;
CREATE POLICY "Team can update provider profile"
  ON public.labs FOR UPDATE TO authenticated
  USING (
    id = public.provider_team_provider_id('lab', auth.uid())
    AND public.provider_team_access('lab', auth.uid(), 'profile') = 'full'
  )
  WITH CHECK (
    id = public.provider_team_provider_id('lab', auth.uid())
    AND public.provider_team_access('lab', auth.uid(), 'profile') = 'full'
  );

DROP POLICY IF EXISTS "Team can view provider profile" ON public.pharmacies;
CREATE POLICY "Team can view provider profile"
  ON public.pharmacies FOR SELECT TO authenticated
  USING (
    id = public.provider_team_provider_id('pharmacy', auth.uid())
    AND public.provider_team_access('pharmacy', auth.uid(), 'profile') IN ('view', 'full')
  );
DROP POLICY IF EXISTS "Team can update provider profile" ON public.pharmacies;
CREATE POLICY "Team can update provider profile"
  ON public.pharmacies FOR UPDATE TO authenticated
  USING (
    id = public.provider_team_provider_id('pharmacy', auth.uid())
    AND public.provider_team_access('pharmacy', auth.uid(), 'profile') = 'full'
  )
  WITH CHECK (
    id = public.provider_team_provider_id('pharmacy', auth.uid())
    AND public.provider_team_access('pharmacy', auth.uid(), 'profile') = 'full'
  );

-- ============ PHARMACY CATALOGUE ============
DROP POLICY IF EXISTS "Team can manage medicines" ON public.medicines;
CREATE POLICY "Team can manage medicines"
  ON public.medicines FOR INSERT TO authenticated
  WITH CHECK (
    pharmacy_id = public.provider_team_provider_id('pharmacy', auth.uid())
    AND public.provider_team_access('pharmacy', auth.uid(), 'medicines') = 'full'
  );
DROP POLICY IF EXISTS "Team can update medicines" ON public.medicines;
CREATE POLICY "Team can update medicines"
  ON public.medicines FOR UPDATE TO authenticated
  USING (
    pharmacy_id = public.provider_team_provider_id('pharmacy', auth.uid())
    AND public.provider_team_access('pharmacy', auth.uid(), 'medicines') = 'full'
  )
  WITH CHECK (
    pharmacy_id = public.provider_team_provider_id('pharmacy', auth.uid())
    AND public.provider_team_access('pharmacy', auth.uid(), 'medicines') = 'full'
  );
DROP POLICY IF EXISTS "Team can delete medicines" ON public.medicines;
CREATE POLICY "Team can delete medicines"
  ON public.medicines FOR DELETE TO authenticated
  USING (
    pharmacy_id = public.provider_team_provider_id('pharmacy', auth.uid())
    AND public.provider_team_access('pharmacy', auth.uid(), 'medicines') = 'full'
  );

-- ============ LAB CATALOGUE + SAMPLES ============
DROP POLICY IF EXISTS "Team can manage lab tests" ON public.lab_tests;
CREATE POLICY "Team can manage lab tests"
  ON public.lab_tests FOR INSERT TO authenticated
  WITH CHECK (
    lab_id = public.provider_team_provider_id('lab', auth.uid())
    AND public.provider_team_access('lab', auth.uid(), 'my_tests') = 'full'
  );
DROP POLICY IF EXISTS "Team can update lab tests" ON public.lab_tests;
CREATE POLICY "Team can update lab tests"
  ON public.lab_tests FOR UPDATE TO authenticated
  USING (
    lab_id = public.provider_team_provider_id('lab', auth.uid())
    AND public.provider_team_access('lab', auth.uid(), 'my_tests') = 'full'
  )
  WITH CHECK (
    lab_id = public.provider_team_provider_id('lab', auth.uid())
    AND public.provider_team_access('lab', auth.uid(), 'my_tests') = 'full'
  );
DROP POLICY IF EXISTS "Team can delete lab tests" ON public.lab_tests;
CREATE POLICY "Team can delete lab tests"
  ON public.lab_tests FOR DELETE TO authenticated
  USING (
    lab_id = public.provider_team_provider_id('lab', auth.uid())
    AND public.provider_team_access('lab', auth.uid(), 'my_tests') = 'full'
  );

DROP POLICY IF EXISTS "Team can manage samples"
  ON public.lab_sample_collections;
CREATE POLICY "Team can manage samples"
  ON public.lab_sample_collections FOR INSERT TO authenticated
  WITH CHECK (
    lab_id = public.provider_team_provider_id('lab', auth.uid())
    AND public.provider_team_access('lab', auth.uid(), 'my_tests') = 'full'
  );
DROP POLICY IF EXISTS "Team can update samples"
  ON public.lab_sample_collections;
CREATE POLICY "Team can update samples"
  ON public.lab_sample_collections FOR UPDATE TO authenticated
  USING (
    lab_id = public.provider_team_provider_id('lab', auth.uid())
    AND public.provider_team_access('lab', auth.uid(), 'my_tests') = 'full'
  )
  WITH CHECK (
    lab_id = public.provider_team_provider_id('lab', auth.uid())
    AND public.provider_team_access('lab', auth.uid(), 'my_tests') = 'full'
  );
DROP POLICY IF EXISTS "Team can delete samples"
  ON public.lab_sample_collections;
CREATE POLICY "Team can delete samples"
  ON public.lab_sample_collections FOR DELETE TO authenticated
  USING (
    lab_id = public.provider_team_provider_id('lab', auth.uid())
    AND public.provider_team_access('lab', auth.uid(), 'my_tests') = 'full'
  );

-- ============ HOSPITAL UNITS (live in the Profile tab) ============
DROP POLICY IF EXISTS "Team can manage departments" ON public.departments;
CREATE POLICY "Team can manage departments"
  ON public.departments FOR ALL TO authenticated
  USING (
    hospital_id = public.provider_team_provider_id('hospital', auth.uid())
    AND public.provider_team_access('hospital', auth.uid(), 'profile') = 'full'
  )
  WITH CHECK (
    hospital_id = public.provider_team_provider_id('hospital', auth.uid())
    AND public.provider_team_access('hospital', auth.uid(), 'profile') = 'full'
  );
DROP POLICY IF EXISTS "Team can manage OTs" ON public.operation_theaters;
CREATE POLICY "Team can manage OTs"
  ON public.operation_theaters FOR ALL TO authenticated
  USING (
    hospital_id = public.provider_team_provider_id('hospital', auth.uid())
    AND public.provider_team_access('hospital', auth.uid(), 'profile') = 'full'
  )
  WITH CHECK (
    hospital_id = public.provider_team_provider_id('hospital', auth.uid())
    AND public.provider_team_access('hospital', auth.uid(), 'profile') = 'full'
  );
DROP POLICY IF EXISTS "Team can manage equipment" ON public.hospital_equipment;
CREATE POLICY "Team can manage equipment"
  ON public.hospital_equipment FOR ALL TO authenticated
  USING (
    hospital_id = public.provider_team_provider_id('hospital', auth.uid())
    AND public.provider_team_access('hospital', auth.uid(), 'profile') = 'full'
  )
  WITH CHECK (
    hospital_id = public.provider_team_provider_id('hospital', auth.uid())
    AND public.provider_team_access('hospital', auth.uid(), 'profile') = 'full'
  );

-- ============ DELIVERIES (pharmacy assigns drivers) ============
DROP POLICY IF EXISTS "Team can manage deliveries" ON public.delivery_orders;
CREATE POLICY "Team can manage deliveries"
  ON public.delivery_orders FOR ALL TO authenticated
  USING (
    order_id IN (
      SELECT id FROM public.orders
      WHERE pharmacy_id =
        public.provider_team_provider_id('pharmacy', auth.uid())
    )
    AND public.provider_team_access('pharmacy', auth.uid(), 'orders') = 'full'
  )
  WITH CHECK (
    order_id IN (
      SELECT id FROM public.orders
      WHERE pharmacy_id =
        public.provider_team_provider_id('pharmacy', auth.uid())
    )
    AND public.provider_team_access('pharmacy', auth.uid(), 'orders') = 'full'
  );

-- ============ DRIVERS ADDED BY A PROVIDER ============
-- Which provider added this driver (hospital / lab / pharmacy).
ALTER TABLE public.delivery_drivers
  ADD COLUMN IF NOT EXISTS added_by_provider_type TEXT
    CHECK (added_by_provider_type IN ('hospital', 'lab', 'pharmacy'));
ALTER TABLE public.delivery_drivers
  ADD COLUMN IF NOT EXISTS added_by_provider_id UUID;

-- The adding provider (owner or team with drivers access) reads and
-- manages its own drivers. Added drivers also stay visible through
-- the existing "Pharmacies read active drivers" policy.
DROP POLICY IF EXISTS "Provider manages own added drivers"
  ON public.delivery_drivers;
CREATE POLICY "Provider manages own added drivers"
  ON public.delivery_drivers FOR ALL TO authenticated
  USING (
    added_by_provider_id IS NOT NULL
    AND added_by_provider_id = public.provider_team_provider_id(
      added_by_provider_type, auth.uid())
    AND (
      -- owner: full; team: needs drivers access
      (added_by_provider_type = 'hospital' AND added_by_provider_id IN (
        SELECT id FROM public.hospitals WHERE user_id = auth.uid()))
      OR (added_by_provider_type = 'lab' AND added_by_provider_id IN (
        SELECT id FROM public.labs WHERE user_id = auth.uid()))
      OR (added_by_provider_type = 'pharmacy' AND added_by_provider_id IN (
        SELECT id FROM public.pharmacies WHERE user_id = auth.uid()))
      OR public.provider_team_access(
        added_by_provider_type, auth.uid(), 'drivers') IN ('view', 'full')
    )
  )
  WITH CHECK (
    added_by_provider_id IS NOT NULL
    AND added_by_provider_id = public.provider_team_provider_id(
      added_by_provider_type, auth.uid())
    AND (
      (added_by_provider_type = 'hospital' AND added_by_provider_id IN (
        SELECT id FROM public.hospitals WHERE user_id = auth.uid()))
      OR (added_by_provider_type = 'lab' AND added_by_provider_id IN (
        SELECT id FROM public.labs WHERE user_id = auth.uid()))
      OR (added_by_provider_type = 'pharmacy' AND added_by_provider_id IN (
        SELECT id FROM public.pharmacies WHERE user_id = auth.uid()))
      OR public.provider_team_access(
        added_by_provider_type, auth.uid(), 'drivers') = 'full'
    )
  );
