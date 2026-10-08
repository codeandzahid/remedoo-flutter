-- Razorpay Route: Direct-to-provider split payments
-- Run this in Supabase Dashboard > SQL Editor

-- Add Route account columns to provider tables
ALTER TABLE doctors ADD COLUMN IF NOT EXISTS razorpay_account_id TEXT;
ALTER TABLE doctors ADD COLUMN IF NOT EXISTS route_onboarding_status TEXT DEFAULT 'not_started';

ALTER TABLE hospitals ADD COLUMN IF NOT EXISTS razorpay_account_id TEXT;
ALTER TABLE hospitals ADD COLUMN IF NOT EXISTS route_onboarding_status TEXT DEFAULT 'not_started';

ALTER TABLE labs ADD COLUMN IF NOT EXISTS razorpay_account_id TEXT;
ALTER TABLE labs ADD COLUMN IF NOT EXISTS route_onboarding_status TEXT DEFAULT 'not_started';

ALTER TABLE pharmacies ADD COLUMN IF NOT EXISTS razorpay_account_id TEXT;
ALTER TABLE pharmacies ADD COLUMN IF NOT EXISTS route_onboarding_status TEXT DEFAULT 'not_started';

-- Track Route payments with transfer details
CREATE TABLE IF NOT EXISTS route_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  razorpay_payment_id TEXT UNIQUE NOT NULL,
  razorpay_order_id TEXT,
  amount DECIMAL(10,2),
  currency TEXT DEFAULT 'INR',
  status TEXT DEFAULT 'created',
  transfer_id TEXT,
  transfer_status TEXT,
  transfers JSONB,
  raw_payload JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS for route_payments (admin only)
ALTER TABLE route_payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admin can view route payments" ON route_payments;
CREATE POLICY "Admin can view route payments" ON route_payments
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_roles.user_id = auth.uid()
      AND user_roles.role = 'admin'
    )
  );

-- Allow providers to read their own Route account ID
DROP POLICY IF EXISTS "Providers can read own razorpay account" ON doctors;
CREATE POLICY "Providers can read own razorpay account" ON doctors
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Providers can read own razorpay account" ON hospitals;
CREATE POLICY "Providers can read own razorpay account" ON hospitals
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Providers can read own razorpay account" ON labs;
CREATE POLICY "Providers can read own razorpay account" ON labs
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Providers can read own razorpay account" ON pharmacies;
CREATE POLICY "Providers can read own razorpay account" ON pharmacies
  FOR SELECT USING (true);
