-- Widen the appointment-update trigger (full-check fix, 2026-10-22).
--
-- enforce_patient_appointment_cancel() (security_hardening.sql,
-- last revised in provider_appointment_trigger.sql) lets a provider
-- change ONLY status/updated_at/token_number and a patient ONLY
-- status/updated_at. But the app legitimately writes more, so these
-- live flows were rejected by the trigger:
--   provider: cancel with a typed reason (rejection_reason),
--             complete with consultation_notes / follow_up_date,
--             appointment refunds (refund_status, refund_amount,
--             refund_requested_at, refund_at, refund_utr);
--   patient:  reschedule (appointment_date / appointment_time),
--             refund requests (refund_status / refund_amount /
--             refund_requested_at — never refund_at / refund_utr:
--             marking refunded stays a provider/admin act).
-- RLS still gates WHICH rows each caller may touch; this trigger
-- only governs WHAT may change on a row the caller can update.
-- Idempotent: safe to re-run. Run in the Supabase SQL editor.

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

  -- Providers: status flow + its context columns + refund handling
  -- on their own appointments (RLS restricts the rows).
  IF has_role(auth.uid(), 'doctor'::app_role)
     OR has_role(auth.uid(), 'hospital'::app_role)
     OR has_role(auth.uid(), 'lab'::app_role) THEN
    IF to_jsonb(NEW) - ARRAY['status','updated_at','token_number',
                             'rejection_reason','consultation_notes',
                             'follow_up_date',
                             'refund_status','refund_amount',
                             'refund_requested_at','refund_at',
                             'refund_utr']
       IS DISTINCT FROM
       to_jsonb(OLD) - ARRAY['status','updated_at','token_number',
                             'rejection_reason','consultation_notes',
                             'follow_up_date',
                             'refund_status','refund_amount',
                             'refund_requested_at','refund_at',
                             'refund_utr'] THEN
      RAISE EXCEPTION 'Only appointment status, notes and refund fields may be changed';
    END IF;
    RETURN NEW;
  END IF;

  -- Patients: cancellation, reschedule of their own booking, and
  -- refund REQUESTS. Nothing else.
  IF to_jsonb(NEW) - ARRAY['status','updated_at',
                           'appointment_date','appointment_time',
                           'refund_status','refund_amount',
                           'refund_requested_at']
     IS DISTINCT FROM
     to_jsonb(OLD) - ARRAY['status','updated_at',
                           'appointment_date','appointment_time',
                           'refund_status','refund_amount',
                           'refund_requested_at'] THEN
    RAISE EXCEPTION 'Only appointment cancellation, reschedule and refund requests are allowed';
  END IF;
  IF NEW.status IS DISTINCT FROM OLD.status
     AND NEW.status <> 'cancelled' THEN
    RAISE EXCEPTION 'Appointments can only be cancelled';
  END IF;
  RETURN NEW;
END;
$$;
