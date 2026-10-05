-- Provider-scoped RLS for the Remedoo Partner app.
-- Lets each provider see and manage ONLY their own records.
-- Idempotent: safe to re-run.
-- Run in Supabase SQL editor.

-- Helper: does the current user own this provider record?
-- (doctors, hospitals, labs, pharmacies all have a user_id column)

-- ============ APPOINTMENTS ============
-- Doctors see their own appointments
DROP POLICY IF EXISTS "Doctors can view own appointments" ON public.appointments;
CREATE POLICY "Doctors can view own appointments"
  ON public.appointments FOR SELECT
  USING (
    has_role(auth.uid(), 'doctor'::app_role)
    AND doctor_id IN (SELECT id FROM public.doctors WHERE user_id = auth.uid())
  );

-- Doctors can update status on their own appointments (confirm/complete/cancel)
DROP POLICY IF EXISTS "Doctors can update own appointments" ON public.appointments;
CREATE POLICY "Doctors can update own appointments"
  ON public.appointments FOR UPDATE
  USING (
    has_role(auth.uid(), 'doctor'::app_role)
    AND doctor_id IN (SELECT id FROM public.doctors WHERE user_id = auth.uid())
  )
  WITH CHECK (
    has_role(auth.uid(), 'doctor'::app_role)
    AND doctor_id IN (SELECT id FROM public.doctors WHERE user_id = auth.uid())
  );

-- Hospitals see their own appointments
DROP POLICY IF EXISTS "Hospitals can view own appointments" ON public.appointments;
CREATE POLICY "Hospitals can view own appointments"
  ON public.appointments FOR SELECT
  USING (
    has_role(auth.uid(), 'hospital'::app_role)
    AND hospital_id IN (SELECT id FROM public.hospitals WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS "Hospitals can update own appointments" ON public.appointments;
CREATE POLICY "Hospitals can update own appointments"
  ON public.appointments FOR UPDATE
  USING (
    has_role(auth.uid(), 'hospital'::app_role)
    AND hospital_id IN (SELECT id FROM public.hospitals WHERE user_id = auth.uid())
  )
  WITH CHECK (
    has_role(auth.uid(), 'hospital'::app_role)
    AND hospital_id IN (SELECT id FROM public.hospitals WHERE user_id = auth.uid())
  );

-- Labs see their own bookings (lab appointments)
DROP POLICY IF EXISTS "Labs can view own bookings" ON public.appointments;
CREATE POLICY "Labs can view own bookings"
  ON public.appointments FOR SELECT
  USING (
    has_role(auth.uid(), 'lab'::app_role)
    AND lab_id IN (SELECT id FROM public.labs WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS "Labs can update own bookings" ON public.appointments;
CREATE POLICY "Labs can update own bookings"
  ON public.appointments FOR UPDATE
  USING (
    has_role(auth.uid(), 'lab'::app_role)
    AND lab_id IN (SELECT id FROM public.labs WHERE user_id = auth.uid())
  )
  WITH CHECK (
    has_role(auth.uid(), 'lab'::app_role)
    AND lab_id IN (SELECT id FROM public.labs WHERE user_id = auth.uid())
  );

-- ============ ORDERS (pharmacy) ============
DROP POLICY IF EXISTS "Pharmacies can view own orders" ON public.orders;
CREATE POLICY "Pharmacies can view own orders"
  ON public.orders FOR SELECT
  USING (
    has_role(auth.uid(), 'pharmacy'::app_role)
    AND pharmacy_id IN (SELECT id FROM public.pharmacies WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS "Pharmacies can update own orders" ON public.orders;
CREATE POLICY "Pharmacies can update own orders"
  ON public.orders FOR UPDATE
  USING (
    has_role(auth.uid(), 'pharmacy'::app_role)
    AND pharmacy_id IN (SELECT id FROM public.pharmacies WHERE user_id = auth.uid())
  )
  WITH CHECK (
    has_role(auth.uid(), 'pharmacy'::app_role)
    AND pharmacy_id IN (SELECT id FROM public.pharmacies WHERE user_id = auth.uid())
  );

-- Pharmacies can view items of their own orders
DROP POLICY IF EXISTS "Pharmacies can view own order items" ON public.order_items;
CREATE POLICY "Pharmacies can view own order items"
  ON public.order_items FOR SELECT
  USING (
    has_role(auth.uid(), 'pharmacy'::app_role)
    AND order_id IN (
      SELECT o.id FROM public.orders o
      JOIN public.pharmacies p ON p.id = o.pharmacy_id
      WHERE p.user_id = auth.uid()
    )
  );

-- ============ PROVIDER PROFILES (own record) ============
-- Doctors manage their own profile
DROP POLICY IF EXISTS "Doctors can view own profile" ON public.doctors;
CREATE POLICY "Doctors can view own profile"
  ON public.doctors FOR SELECT
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Doctors can update own profile" ON public.doctors;
CREATE POLICY "Doctors can update own profile"
  ON public.doctors FOR UPDATE
  USING (
    has_role(auth.uid(), 'doctor'::app_role)
    AND user_id = auth.uid()
  )
  WITH CHECK (
    has_role(auth.uid(), 'doctor'::app_role)
    AND user_id = auth.uid()
  );

-- Pharmacies manage their own profile
DROP POLICY IF EXISTS "Pharmacies can view own profile" ON public.pharmacies;
CREATE POLICY "Pharmacies can view own profile"
  ON public.pharmacies FOR SELECT
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Pharmacies can update own profile" ON public.pharmacies;
CREATE POLICY "Pharmacies can update own profile"
  ON public.pharmacies FOR UPDATE
  USING (
    has_role(auth.uid(), 'pharmacy'::app_role)
    AND user_id = auth.uid()
  )
  WITH CHECK (
    has_role(auth.uid(), 'pharmacy'::app_role)
    AND user_id = auth.uid()
  );

-- Labs manage their own profile
DROP POLICY IF EXISTS "Labs can view own profile" ON public.labs;
CREATE POLICY "Labs can view own profile"
  ON public.labs FOR SELECT
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Labs can update own profile" ON public.labs;
CREATE POLICY "Labs can update own profile"
  ON public.labs FOR UPDATE
  USING (
    has_role(auth.uid(), 'lab'::app_role)
    AND user_id = auth.uid()
  )
  WITH CHECK (
    has_role(auth.uid(), 'lab'::app_role)
    AND user_id = auth.uid()
  );

-- Hospitals manage their own profile
DROP POLICY IF EXISTS "Hospitals can view own profile" ON public.hospitals;
CREATE POLICY "Hospitals can view own profile"
  ON public.hospitals FOR SELECT
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Hospitals can update own profile" ON public.hospitals;
CREATE POLICY "Hospitals can update own profile"
  ON public.hospitals FOR UPDATE
  USING (
    has_role(auth.uid(), 'hospital'::app_role)
    AND user_id = auth.uid()
  )
  WITH CHECK (
    has_role(auth.uid(), 'hospital'::app_role)
    AND user_id = auth.uid()
  );

-- Providers can view their own roles (needed for the partner app login check)
DROP POLICY IF EXISTS "Users can view own roles" ON public.user_roles;
CREATE POLICY "Users can view own roles"
  ON public.user_roles FOR SELECT
  USING (auth.uid() = user_id);
