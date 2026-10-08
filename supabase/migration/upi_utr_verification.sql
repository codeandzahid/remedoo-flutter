-- UTR-based UPI payment verification (SMM-panel style)
-- Patients submit the 12-digit UTR from their UPI app; admin verifies
-- against their bank statement before approving.

CREATE TABLE IF NOT EXISTS upi_payment_verifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  appointment_id TEXT NOT NULL,
  utr TEXT NOT NULL,
  amount NUMERIC NOT NULL,
  patient_id UUID REFERENCES auth.users(id),
  patient_name TEXT,
  provider_type TEXT NOT NULL DEFAULT 'doctor',
  provider_id TEXT,
  provider_name TEXT,
  provider_upi_id TEXT,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected')),
  admin_note TEXT,
  verified_by UUID REFERENCES auth.users(id),
  verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- One UTR can only be used once (prevents reuse fraud)
CREATE UNIQUE INDEX IF NOT EXISTS uq_upi_verifications_utr
  ON upi_payment_verifications (utr);

CREATE INDEX IF NOT EXISTS ix_upi_verifications_status
  ON upi_payment_verifications (status, created_at DESC);

CREATE INDEX IF NOT EXISTS ix_upi_verifications_appointment
  ON upi_payment_verifications (appointment_id);

ALTER TABLE upi_payment_verifications ENABLE ROW LEVEL SECURITY;

-- Patients can insert their own UTR submissions
DROP POLICY IF EXISTS "Patients can submit UTR" ON upi_payment_verifications;
CREATE POLICY "Patients can submit UTR" ON upi_payment_verifications
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = patient_id);

-- Patients can view their own submissions
DROP POLICY IF EXISTS "Patients view own UTR" ON upi_payment_verifications;
CREATE POLICY "Patients view own UTR" ON upi_payment_verifications
  FOR SELECT TO authenticated
  USING (auth.uid() = patient_id);

-- Admins can view and manage all
DROP POLICY IF EXISTS "Admin manages UTR verifications" ON upi_payment_verifications;
CREATE POLICY "Admin manages UTR verifications" ON upi_payment_verifications
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_roles.user_id = auth.uid()
        AND user_roles.role = 'admin'
    )
  );
