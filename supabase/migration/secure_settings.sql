-- Secure settings table for sensitive config (admin-only access)
-- Run once in Supabase Dashboard > SQL Editor

CREATE TABLE IF NOT EXISTS secure_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  updated_by UUID
);

ALTER TABLE secure_settings ENABLE ROW LEVEL SECURITY;

-- Only admins can read/write
DROP POLICY IF EXISTS "Admin only secure_settings" ON secure_settings;
CREATE POLICY "Admin only secure_settings" ON secure_settings
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_roles.user_id = auth.uid()
      AND user_roles.role = 'admin'
    )
  );

-- Service role bypasses RLS automatically, so Edge Functions can read it
