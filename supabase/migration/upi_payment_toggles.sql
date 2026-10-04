-- Provider payment method toggles: providers can enable/disable
-- "pay in clinic" (At Clinic / Cash on Delivery) and UPI options.
ALTER TABLE public.doctors ADD COLUMN IF NOT EXISTS pay_in_clinic_enabled BOOLEAN DEFAULT true;
ALTER TABLE public.doctors ADD COLUMN IF NOT EXISTS upi_enabled BOOLEAN DEFAULT true;
ALTER TABLE public.hospitals ADD COLUMN IF NOT EXISTS pay_in_clinic_enabled BOOLEAN DEFAULT true;
ALTER TABLE public.hospitals ADD COLUMN IF NOT EXISTS upi_enabled BOOLEAN DEFAULT true;
ALTER TABLE public.labs ADD COLUMN IF NOT EXISTS pay_in_clinic_enabled BOOLEAN DEFAULT true;
ALTER TABLE public.labs ADD COLUMN IF NOT EXISTS upi_enabled BOOLEAN DEFAULT true;
ALTER TABLE public.pharmacies ADD COLUMN IF NOT EXISTS pay_in_clinic_enabled BOOLEAN DEFAULT true;
ALTER TABLE public.pharmacies ADD COLUMN IF NOT EXISTS upi_enabled BOOLEAN DEFAULT true;
