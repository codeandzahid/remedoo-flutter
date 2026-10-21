-- Form-pages audit Patient 11: a lab booking's collection
-- choice (walk-in vs home collection + the address) had nowhere
-- to live on the appointment. The lab reads these to create the
-- lab_sample_collections record. The app degrades gracefully
-- (books without the fields) until this is applied.
ALTER TABLE public.appointments
  ADD COLUMN IF NOT EXISTS collection_type TEXT; -- walk_in | home
ALTER TABLE public.appointments
  ADD COLUMN IF NOT EXISTS collection_address TEXT;
