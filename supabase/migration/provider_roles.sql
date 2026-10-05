-- Add provider roles to the app_role enum.
-- Run this in the Supabase SQL editor.

-- Add new values to the enum (IF NOT EXISTS pattern for enums)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'doctor' AND enumtypid = 'public.app_role'::regtype) THEN
    ALTER TYPE public.app_role ADD VALUE 'doctor';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'pharmacy' AND enumtypid = 'public.app_role'::regtype) THEN
    ALTER TYPE public.app_role ADD VALUE 'pharmacy';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'lab' AND enumtypid = 'public.app_role'::regtype) THEN
    ALTER TYPE public.app_role ADD VALUE 'lab';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'hospital' AND enumtypid = 'public.app_role'::regtype) THEN
    ALTER TYPE public.app_role ADD VALUE 'hospital';
  END IF;
END
$$;

-- Providers can view their own roles (already covered by "Users can view own roles" policy)
-- No additional RLS changes needed: existing policies use has_role() which works with any role value.
