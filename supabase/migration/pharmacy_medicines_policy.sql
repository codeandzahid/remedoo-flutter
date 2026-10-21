-- Form-pages audit Panelist 3 / M-pharmacy: medicines had only
-- admin write policies, so a pharmacy could never manage its own
-- catalogue from the partner app. Mirror the lab_tests pattern:
-- a pharmacy manages rows whose pharmacy_id is one of its own
-- records. Public read already exists ("Medicines viewable by
-- everyone"). Until this is applied, partner-app medicine writes
-- fail closed and the app shows "could not save".
DROP POLICY IF EXISTS "Pharmacies can manage own medicines" ON public.medicines;
CREATE POLICY "Pharmacies can manage own medicines"
  ON public.medicines FOR ALL
  USING (pharmacy_id IN (SELECT id FROM public.pharmacies WHERE user_id = auth.uid()))
  WITH CHECK (pharmacy_id IN (SELECT id FROM public.pharmacies WHERE user_id = auth.uid()));
