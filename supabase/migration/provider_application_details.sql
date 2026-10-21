-- Form-pages audit M5 / Panelist 18: provider registration
-- collects role-specific details (specialisation, fee, services,
-- beds…) that had nowhere to live on provider_applications, so
-- approval could only create a bare name/phone record. One
-- JSONB column carries them; the app degrades gracefully
-- (submits without details) until this is applied.
ALTER TABLE public.provider_applications
  ADD COLUMN IF NOT EXISTS details JSONB NOT NULL DEFAULT '{}'::jsonb;
