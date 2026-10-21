-- Form-pages audit (M14 / Panelist 5): doctor_blocked_slots had
-- zero app references, and its RLS only lets the doctor (and
-- admins) read rows — so the patient booking flow could never
-- see which slots are blocked. This SECURITY DEFINER function
-- exposes only the availability shape (date + times + full-day
-- flag, never the doctor's private reason) for one doctor.
-- The app degrades gracefully until this is applied: no rows
-- returned, booking falls back to working-hours slots only.
CREATE OR REPLACE FUNCTION public.doctor_blocked_slots_for(
  p_doctor_id uuid,
  p_from date DEFAULT NULL
)
RETURNS TABLE (
  blocked_date date,
  start_time time,
  end_time time,
  is_full_day boolean
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT blocked_date, start_time, end_time, is_full_day
  FROM public.doctor_blocked_slots
  WHERE doctor_id = p_doctor_id
    AND blocked_date >= COALESCE(p_from, CURRENT_DATE)
  ORDER BY blocked_date;
$$;

GRANT EXECUTE ON FUNCTION public.doctor_blocked_slots_for(uuid, date)
  TO authenticated, anon;
