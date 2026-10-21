-- Audit-76 Batch 9 (Patient gap 18): orders gain the coupon
-- fields so a checkout discount is stored on the order itself
-- (code + amount), not just shown on screen. The app includes
-- them only when a coupon was applied and retries without them
-- until this runs.

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS discount_amount NUMERIC NOT NULL DEFAULT 0;

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS coupon_code TEXT;
