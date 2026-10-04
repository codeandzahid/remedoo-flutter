-- Remedoo security hardening. Idempotent: safe to re-run.
--
-- Closes over-broad RLS policies found in the 2026-10-04 security audit:
--   1. user_roles: drop the dead "self-assign provider role" policy. It could
--      never succeed ('doctor' etc. are not valid app_role enum values, so the
--      cast always failed), but it was confusing and would become a live
--      privilege path if the enum were ever extended. The app never inserts
--      into user_roles directly (roles are granted via SQL by the owner).
--   2. orders: patients have no legitimate update path (only admins update
--      orders). The old "Users can update own orders" policy let a malicious
--      client rewrite total/status/payment fields on their own orders.
--   3. appointments: patients may ONLY cancel their own appointments. The old
--      policy allowed rewriting any column (doctor, fee, ...). Replaced with a
--      cancel-scoped policy plus a trigger that hard-blocks any other change.
--   4. support_tickets: patients never update tickets via the app (only admins
--      do). The old policy let a malicious client forge admin_response or
--      flip status on their own tickets.

-- 1. Drop dead self-assign role policy.
DROP POLICY IF EXISTS "Users can self-assign provider role"
  ON public.user_roles;

-- 2. Orders: admin-only updates.
DROP POLICY IF EXISTS "Users can update own orders"
  ON public.orders;

-- 3a. Appointments: cancel-only policy for patients.
DROP POLICY IF EXISTS "Users can update own appointments"
  ON public.appointments;
DROP POLICY IF EXISTS "Users can cancel own appointments"
  ON public.appointments;
CREATE POLICY "Users can cancel own appointments"
  ON public.appointments FOR UPDATE
  TO authenticated
  USING (auth.uid() = patient_id)
  WITH CHECK (auth.uid() = patient_id AND status = 'cancelled');

-- 3b. Trigger: hard enforcement — for non-admins, no column besides
-- status/updated_at may change, and status may only become 'cancelled'.
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
  IF to_jsonb(NEW) - '{status,updated_at}' IS DISTINCT FROM
     to_jsonb(OLD) - '{status,updated_at}' THEN
    RAISE EXCEPTION 'Only appointment cancellation is allowed';
  END IF;
  IF NEW.status IS DISTINCT FROM OLD.status
     AND NEW.status <> 'cancelled' THEN
    RAISE EXCEPTION 'Appointments can only be cancelled';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_patient_appointment_cancel
  ON public.appointments;
CREATE TRIGGER trg_patient_appointment_cancel
  BEFORE UPDATE ON public.appointments
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_patient_appointment_cancel();

-- 4. Support tickets: admin-only updates.
DROP POLICY IF EXISTS "Users can update own tickets"
  ON public.support_tickets;
