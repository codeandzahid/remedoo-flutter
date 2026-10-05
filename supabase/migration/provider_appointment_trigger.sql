-- Allow providers to manage appointment status on their own bookings.
-- The original trigger (security_hardening.sql) was written for patients:
-- non-admins could only cancel. Providers (doctor/hospital/lab roles) now
-- need confirm/complete/cancel on their own appointments for the Partner app.
-- RLS policies still gate WHICH rows each provider can touch; this trigger
-- only governs WHAT a non-admin may change on rows they can already update.
-- Idempotent: safe to re-run. Run in Supabase SQL editor.

CREATE OR REPLACE FUNCTION public.enforce_patient_appointment_cancel()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Admins bypass (RLS already gates who may update at all).
  IF has_role(auth.uid(), 'admin'::app_role) THEN
    RETURN NEW;
  END IF;

  -- Providers may change status (confirm / complete / cancel) on appointments
  -- RLS already restricts to their own. Still limited to status/updated_at.
  -- NOTE: use explicit ARRAY[...] — the '{a,b}' literal can resolve to
  -- jsonb - text (single-key removal) instead of jsonb - text[], which would
  -- compare status as well and wrongly reject every update.
  IF has_role(auth.uid(), 'doctor'::app_role)
     OR has_role(auth.uid(), 'hospital'::app_role)
     OR has_role(auth.uid(), 'lab'::app_role) THEN
    IF to_jsonb(NEW) - ARRAY['status','updated_at'] IS DISTINCT FROM
       to_jsonb(OLD) - ARRAY['status','updated_at'] THEN
      RAISE EXCEPTION 'Only appointment status may be changed';
    END IF;
    RETURN NEW;
  END IF;

  -- Patients: only cancellation allowed (original behavior, unchanged).
  -- Same ARRAY[...] fix as above.
  IF to_jsonb(NEW) - ARRAY['status','updated_at'] IS DISTINCT FROM
     to_jsonb(OLD) - ARRAY['status','updated_at'] THEN
    RAISE EXCEPTION 'Only appointment cancellation is allowed';
  END IF;
  IF NEW.status IS DISTINCT FROM OLD.status
     AND NEW.status <> 'cancelled' THEN
    RAISE EXCEPTION 'Appointments can only be cancelled';
  END IF;
  RETURN NEW;
END;
$$;
