-- Provider patient contacts (full-check fix, 2026-10-22).
--
-- Doctor / hospital / lab appointment cards showed every patient as
-- literally "Patient": appointments carry patient_id, but profiles
-- RLS lets a provider read only their own profile, so the app cannot
-- join names client-side. This SECURITY DEFINER function returns the
-- name + phone of ONLY the patients who have an appointment with a
-- provider record the caller owns (doctors / hospitals / labs /
-- pharmacies link to their login through their user_id column).
-- Nothing else about those patients is exposed.

CREATE OR REPLACE FUNCTION public.provider_patient_contacts()
RETURNS TABLE (patient_id uuid, full_name text, phone text)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT DISTINCT a.patient_id, p.full_name, p.phone
    FROM public.appointments a
    JOIN public.profiles p ON p.user_id = a.patient_id
   WHERE (a.doctor_id IN (SELECT id FROM public.doctors WHERE user_id = auth.uid())
       OR a.hospital_id IN (SELECT id FROM public.hospitals WHERE user_id = auth.uid())
       OR a.lab_id IN (SELECT id FROM public.labs WHERE user_id = auth.uid())
       OR a.pharmacy_id IN (SELECT id FROM public.pharmacies WHERE user_id = auth.uid()));
$$;

REVOKE ALL ON FUNCTION public.provider_patient_contacts() FROM public;
GRANT EXECUTE ON FUNCTION public.provider_patient_contacts() TO authenticated;
