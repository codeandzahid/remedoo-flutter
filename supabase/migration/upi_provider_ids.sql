-- UPI payment integration: providers set their own UPI ID so patient
-- payments go directly to the doctor/hospital/lab/pharmacy.
ALTER TABLE public.doctors ADD COLUMN IF NOT EXISTS upi_id TEXT;
ALTER TABLE public.hospitals ADD COLUMN IF NOT EXISTS upi_id TEXT;
ALTER TABLE public.labs ADD COLUMN IF NOT EXISTS upi_id TEXT;
ALTER TABLE public.pharmacies ADD COLUMN IF NOT EXISTS upi_id TEXT;

-- Allow providers to update their own UPI ID (they already have
-- update policies on their own rows via the existing provider policies).
-- Public read is already enabled via the existing SELECT policies.
