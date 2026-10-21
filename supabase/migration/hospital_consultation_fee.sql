-- Form-pages audit (Patient 19): the hospital booking fee was
-- hardcoded ₹300 in the app (hospital detail + emergency entry
-- points) because hospitals had no fee column. Adds the column
-- the app now reads as Hospital.fee / writes from Admin > Hospitals
-- and the hospital profile form. Default 0 = no set fee (shown as
-- Free); existing behaviour is unchanged until a fee is set.
ALTER TABLE public.hospitals
  ADD COLUMN IF NOT EXISTS consultation_fee NUMERIC(10,2) DEFAULT 0;
