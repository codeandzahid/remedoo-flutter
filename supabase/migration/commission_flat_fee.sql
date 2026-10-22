-- Commission flat fee (full-check fix 2026-10-22)
-- ============================================================
-- platform_commission_config.flat_fee could be entered in the
-- admin Commission screen and was stored, but none of the three
-- commission trigger functions ever read it — only
-- commission_percent was applied. This migration replaces all
-- three functions with versions that apply BOTH:
--
--   commission = percent part + flat fee, capped at the gross
--   amount (a flat fee can never make the provider's net
--   negative); net = gross - commission.
--
-- Everything else in each function is unchanged from
-- schema_part_02.sql. Safe to re-run.

-- 1. Appointments (doctor / lab) ------------------------------
CREATE OR REPLACE FUNCTION public.auto_create_provider_earning()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_commission_percent NUMERIC := 10;
  v_flat_fee NUMERIC := 0;
  v_commission NUMERIC := 0;
  v_gross NUMERIC := 0;
  v_provider_type TEXT;
  v_provider_id UUID;
  v_config RECORD;
  v_wallet RECORD;
BEGIN
  -- Only trigger on completion
  IF NEW.status = 'completed' AND (OLD.status IS DISTINCT FROM 'completed') THEN
    -- Determine provider
    IF NEW.doctor_id IS NOT NULL THEN
      v_provider_type := 'doctor';
      v_provider_id := NEW.doctor_id;
      SELECT consultation_fee INTO v_gross FROM doctors WHERE id = NEW.doctor_id;
      v_gross := COALESCE(v_gross, 0);
    ELSIF NEW.lab_id IS NOT NULL THEN
      v_provider_type := 'lab';
      v_provider_id := NEW.lab_id;
      v_gross := 0; -- Lab tests priced differently
    ELSE
      RETURN NEW;
    END IF;

    -- Get commission rate from config (percent + flat fee)
    SELECT commission_percent, flat_fee
      INTO v_commission_percent, v_flat_fee
    FROM platform_commission_config
    WHERE provider_type = v_provider_type AND service_type = 'appointment' AND is_active = true
    LIMIT 1;
    v_commission_percent := COALESCE(v_commission_percent, 10);
    v_flat_fee := COALESCE(v_flat_fee, 0);

    IF v_gross > 0 THEN
      v_commission := LEAST(v_gross,
          ROUND(v_gross * v_commission_percent / 100, 2) + v_flat_fee);
      -- Insert earning (ignore if duplicate)
      INSERT INTO provider_earnings (provider_type, provider_id, reference_type, reference_id, gross_amount, commission_percent, commission_amount, net_amount, description)
      VALUES (v_provider_type, v_provider_id, 'appointment', NEW.id, v_gross, v_commission_percent, v_commission, v_gross - v_commission, NEW.service_type || ' appointment')
      ON CONFLICT (reference_type, reference_id) DO NOTHING;

      -- Upsert wallet
      INSERT INTO provider_wallets (provider_type, provider_id, user_id, total_earned, available_balance)
      SELECT v_provider_type, v_provider_id,
        CASE v_provider_type WHEN 'doctor' THEN (SELECT user_id FROM doctors WHERE id = v_provider_id) WHEN 'lab' THEN (SELECT user_id FROM labs WHERE id = v_provider_id) END,
        v_gross - v_commission,
        v_gross - v_commission
      ON CONFLICT (provider_type, provider_id) DO UPDATE SET
        total_earned = provider_wallets.total_earned + (v_gross - v_commission),
        available_balance = provider_wallets.available_balance + (v_gross - v_commission),
        updated_at = now();
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- 2. Pharmacy orders ------------------------------------------
CREATE OR REPLACE FUNCTION public.auto_create_pharmacy_earning()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_commission_percent NUMERIC := 8;
  v_flat_fee NUMERIC := 0;
  v_commission NUMERIC := 0;
  v_gross NUMERIC;
  v_user_id UUID;
BEGIN
  IF NEW.status = 'delivered' AND (OLD.status IS DISTINCT FROM 'delivered') THEN
    v_gross := NEW.subtotal;

    SELECT commission_percent, flat_fee
      INTO v_commission_percent, v_flat_fee
    FROM platform_commission_config
    WHERE provider_type = 'pharmacy' AND service_type = 'order' AND is_active = true
    LIMIT 1;
    v_commission_percent := COALESCE(v_commission_percent, 8);
    v_flat_fee := COALESCE(v_flat_fee, 0);
    v_commission := LEAST(v_gross,
        ROUND(v_gross * v_commission_percent / 100, 2) + v_flat_fee);

    SELECT user_id INTO v_user_id FROM pharmacies WHERE id = NEW.pharmacy_id;

    INSERT INTO provider_earnings (provider_type, provider_id, reference_type, reference_id, gross_amount, commission_percent, commission_amount, net_amount, description)
    VALUES ('pharmacy', NEW.pharmacy_id, 'order', NEW.id, v_gross, v_commission_percent, v_commission, v_gross - v_commission, 'Order delivery')
    ON CONFLICT (reference_type, reference_id) DO NOTHING;

    INSERT INTO provider_wallets (provider_type, provider_id, user_id, total_earned, available_balance)
    VALUES ('pharmacy', NEW.pharmacy_id, v_user_id, v_gross - v_commission, v_gross - v_commission)
    ON CONFLICT (provider_type, provider_id) DO UPDATE SET
      total_earned = provider_wallets.total_earned + (v_gross - v_commission),
      available_balance = provider_wallets.available_balance + (v_gross - v_commission),
      updated_at = now();
  END IF;
  RETURN NEW;
END;
$$;

-- 3. Ambulance trips ------------------------------------------
CREATE OR REPLACE FUNCTION public.auto_create_ambulance_earning()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_commission_percent NUMERIC := 5;
  v_flat_fee NUMERIC := 0;
  v_commission NUMERIC := 0;
  v_gross NUMERIC;
BEGIN
  IF NEW.status = 'completed' AND (OLD.status IS DISTINCT FROM 'completed') AND NOT COALESCE(NEW.is_free, false) THEN
    v_gross := COALESCE(NEW.total_fare, 0);
    IF v_gross <= 0 THEN RETURN NEW; END IF;

    SELECT commission_percent, flat_fee
      INTO v_commission_percent, v_flat_fee
    FROM platform_commission_config
    WHERE provider_type = 'hospital' AND service_type = 'ambulance' AND is_active = true
    LIMIT 1;
    v_commission_percent := COALESCE(v_commission_percent, 5);
    v_flat_fee := COALESCE(v_flat_fee, 0);
    v_commission := LEAST(v_gross,
        ROUND(v_gross * v_commission_percent / 100, 2) + v_flat_fee);

    -- Insert into hospital_earnings (existing table)
    INSERT INTO hospital_earnings (hospital_id, type, amount, platform_commission, net_earning, appointment_id, description)
    VALUES (NEW.hospital_id, 'ambulance', v_gross, v_commission, v_gross - v_commission, NULL, 'Ambulance trip #' || LEFT(NEW.id::text, 8));
  END IF;
  RETURN NEW;
END;
$$;
