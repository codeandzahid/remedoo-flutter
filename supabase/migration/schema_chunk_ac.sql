  status TEXT NOT NULL DEFAULT 'pending', -- pending, approved, rejected, paid
  bank_details JSONB,
  admin_notes TEXT,
  requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  reviewed_at TIMESTAMPTZ,
  reviewed_by UUID,
  paid_at TIMESTAMPTZ,
  transaction_reference TEXT
);

ALTER TABLE public.payout_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage all payouts"
ON public.payout_requests FOR ALL
USING (public.has_role(auth.uid(), 'admin'))
WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Providers can view own payouts"
ON public.payout_requests FOR SELECT
USING (user_id = auth.uid());

CREATE POLICY "Providers can create own payouts"
ON public.payout_requests FOR INSERT
WITH CHECK (user_id = auth.uid());

-- =============================================
-- 5. MEDICINE BATCH + EXPIRY TRACKING
-- =============================================
ALTER TABLE public.medicines
ADD COLUMN IF NOT EXISTS batch_number TEXT,
ADD COLUMN IF NOT EXISTS expiry_date DATE,
ADD COLUMN IF NOT EXISTS low_stock_threshold INTEGER DEFAULT 10,
ADD COLUMN IF NOT EXISTS manufacturer TEXT;

-- =============================================
-- 6. LAB SAMPLE COLLECTIONS
-- =============================================
CREATE TABLE public.lab_sample_collections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  appointment_id UUID NOT NULL REFERENCES appointments(id),
  lab_id UUID NOT NULL REFERENCES labs(id),
  patient_id UUID NOT NULL,
  test_name TEXT NOT NULL,
  sample_type TEXT NOT NULL DEFAULT 'Blood',
  collection_type TEXT NOT NULL DEFAULT 'walk_in', -- walk_in, home
  collection_address TEXT,
  scheduled_date DATE NOT NULL,
  scheduled_time TIME,
  collected_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'scheduled', -- scheduled, collected, processing, completed, cancelled
  collector_name TEXT,
  collector_phone TEXT,
  report_url TEXT,
  report_version INTEGER NOT NULL DEFAULT 1,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.lab_sample_collections ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage all samples"
ON public.lab_sample_collections FOR ALL
USING (public.has_role(auth.uid(), 'admin'))
WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Labs can manage own samples"
ON public.lab_sample_collections FOR ALL
USING (lab_id IN (SELECT id FROM labs WHERE user_id = auth.uid()))
WITH CHECK (lab_id IN (SELECT id FROM labs WHERE user_id = auth.uid()));

CREATE POLICY "Patients can view own samples"
ON public.lab_sample_collections FOR SELECT
USING (patient_id = auth.uid());

-- =============================================
-- 7. SUPPORT TICKETS
-- =============================================
CREATE TABLE public.support_tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  subject TEXT NOT NULL,
  description TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'general', -- general, payment, appointment, order, technical
  priority TEXT NOT NULL DEFAULT 'medium', -- low, medium, high, urgent
  status TEXT NOT NULL DEFAULT 'open', -- open, in_progress, resolved, closed
  admin_response TEXT,
  resolved_by UUID,
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage all tickets"
ON public.support_tickets FOR ALL
USING (public.has_role(auth.uid(), 'admin'))
WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Users can create own tickets"
ON public.support_tickets FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view own tickets"
ON public.support_tickets FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can update own tickets"
ON public.support_tickets FOR UPDATE
USING (auth.uid() = user_id);

-- =============================================
-- 8. SUSPICIOUS ACTIVITY LOGS
-- =============================================
CREATE TABLE public.suspicious_activity_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID,
  activity_type TEXT NOT NULL, -- failed_login, unusual_access, rate_limit, data_anomaly
  description TEXT NOT NULL,
  ip_address TEXT,
  severity TEXT NOT NULL DEFAULT 'low', -- low, medium, high, critical
  resolved BOOLEAN NOT NULL DEFAULT false,
  resolved_by UUID,
  resolved_at TIMESTAMPTZ,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.suspicious_activity_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Only admins can manage suspicious logs"
ON public.suspicious_activity_logs FOR ALL
USING (public.has_role(auth.uid(), 'admin'))
WITH CHECK (public.has_role(auth.uid(), 'admin'));

-- =============================================
-- 9. COMMISSION ENGINE: Auto-create earnings on appointment completion
-- =============================================
CREATE OR REPLACE FUNCTION public.auto_create_provider_earning()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_commission_percent NUMERIC := 10;
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

    -- Get commission rate from config
    SELECT commission_percent INTO v_commission_percent
    FROM platform_commission_config
    WHERE provider_type = v_provider_type AND service_type = 'appointment' AND is_active = true
    LIMIT 1;
    v_commission_percent := COALESCE(v_commission_percent, 10);

    IF v_gross > 0 THEN
      -- Insert earning (ignore if duplicate)
      INSERT INTO provider_earnings (provider_type, provider_id, reference_type, reference_id, gross_amount, commission_percent, commission_amount, net_amount, description)
      VALUES (v_provider_type, v_provider_id, 'appointment', NEW.id, v_gross, v_commission_percent, ROUND(v_gross * v_commission_percent / 100, 2), ROUND(v_gross * (100 - v_commission_percent) / 100, 2), NEW.service_type || ' appointment')
      ON CONFLICT (reference_type, reference_id) DO NOTHING;

      -- Upsert wallet
      INSERT INTO provider_wallets (provider_type, provider_id, user_id, total_earned, available_balance)
      SELECT v_provider_type, v_provider_id, 
        CASE v_provider_type WHEN 'doctor' THEN (SELECT user_id FROM doctors WHERE id = v_provider_id) WHEN 'lab' THEN (SELECT user_id FROM labs WHERE id = v_provider_id) END,
        ROUND(v_gross * (100 - v_commission_percent) / 100, 2),
        ROUND(v_gross * (100 - v_commission_percent) / 100, 2)
      ON CONFLICT (provider_type, provider_id) DO UPDATE SET
        total_earned = provider_wallets.total_earned + ROUND(v_gross * (100 - v_commission_percent) / 100, 2),
        available_balance = provider_wallets.available_balance + ROUND(v_gross * (100 - v_commission_percent) / 100, 2),
        updated_at = now();
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_auto_provider_earning
BEFORE UPDATE ON public.appointments
FOR EACH ROW
EXECUTE FUNCTION public.auto_create_provider_earning();

-- =============================================
-- 10. Auto-commission for pharmacy orders on delivery
-- =============================================
CREATE OR REPLACE FUNCTION public.auto_create_pharmacy_earning()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_commission_percent NUMERIC := 8;
  v_gross NUMERIC;
  v_user_id UUID;
BEGIN
  IF NEW.status = 'delivered' AND (OLD.status IS DISTINCT FROM 'delivered') THEN
    v_gross := NEW.subtotal;

    SELECT commission_percent INTO v_commission_percent
    FROM platform_commission_config
    WHERE provider_type = 'pharmacy' AND service_type = 'order' AND is_active = true
    LIMIT 1;
    v_commission_percent := COALESCE(v_commission_percent, 8);

    SELECT user_id INTO v_user_id FROM pharmacies WHERE id = NEW.pharmacy_id;

    INSERT INTO provider_earnings (provider_type, provider_id, reference_type, reference_id, gross_amount, commission_percent, commission_amount, net_amount, description)
    VALUES ('pharmacy', NEW.pharmacy_id, 'order', NEW.id, v_gross, v_commission_percent, ROUND(v_gross * v_commission_percent / 100, 2), ROUND(v_gross * (100 - v_commission_percent) / 100, 2), 'Order delivery')
    ON CONFLICT (reference_type, reference_id) DO NOTHING;

    INSERT INTO provider_wallets (provider_type, provider_id, user_id, total_earned, available_balance)
    VALUES ('pharmacy', NEW.pharmacy_id, v_user_id, ROUND(v_gross * (100 - v_commission_percent) / 100, 2), ROUND(v_gross * (100 - v_commission_percent) / 100, 2))
    ON CONFLICT (provider_type, provider_id) DO UPDATE SET
      total_earned = provider_wallets.total_earned + ROUND(v_gross * (100 - v_commission_percent) / 100, 2),
      available_balance = provider_wallets.available_balance + ROUND(v_gross * (100 - v_commission_percent) / 100, 2),
      updated_at = now();
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_auto_pharmacy_earning
BEFORE UPDATE ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.auto_create_pharmacy_earning();

-- =============================================
-- 11. Auto-commission for ambulance trips
-- =============================================
CREATE OR REPLACE FUNCTION public.auto_create_ambulance_earning()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_commission_percent NUMERIC := 5;
  v_gross NUMERIC;
BEGIN
  IF NEW.status = 'completed' AND (OLD.status IS DISTINCT FROM 'completed') AND NOT COALESCE(NEW.is_free, false) THEN
    v_gross := COALESCE(NEW.total_fare, 0);
    IF v_gross <= 0 THEN RETURN NEW; END IF;

    SELECT commission_percent INTO v_commission_percent
    FROM platform_commission_config
    WHERE provider_type = 'hospital' AND service_type = 'ambulance' AND is_active = true
    LIMIT 1;
    v_commission_percent := COALESCE(v_commission_percent, 5);

    -- Insert into hospital_earnings (existing table)
    INSERT INTO hospital_earnings (hospital_id, type, amount, platform_commission, net_earning, appointment_id, description)
    VALUES (NEW.hospital_id, 'ambulance', v_gross, ROUND(v_gross * v_commission_percent / 100, 2), ROUND(v_gross * (100 - v_commission_percent) / 100, 2), NULL, 'Ambulance trip #' || LEFT(NEW.id::text, 8));
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_auto_ambulance_earning
BEFORE UPDATE ON public.ambulance_trips
FOR EACH ROW
EXECUTE FUNCTION public.auto_create_ambulance_earning();

-- =============================================
-- 12. LAB TEST PACKAGES
-- =============================================
CREATE TABLE public.lab_test_packages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lab_id UUID NOT NULL REFERENCES labs(id),
  name TEXT NOT NULL,
  description TEXT,
  tests JSONB NOT NULL DEFAULT '[]'::jsonb, -- array of {test_id, test_name}
  package_price NUMERIC NOT NULL DEFAULT 0,
  discount_percent NUMERIC DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.lab_test_packages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Everyone can view active packages"
ON public.lab_test_packages FOR SELECT USING (true);

CREATE POLICY "Lab admins can manage own packages"
ON public.lab_test_packages FOR ALL
USING (lab_id IN (SELECT id FROM labs WHERE user_id = auth.uid()))
WITH CHECK (lab_id IN (SELECT id FROM labs WHERE user_id = auth.uid()));

CREATE POLICY "Admins can manage all packages"
ON public.lab_test_packages FOR ALL
USING (public.has_role(auth.uid(), 'admin'))
WITH CHECK (public.has_role(auth.uid(), 'admin'));

-- =============================================
-- 13. Enable realtime for key tables
-- =============================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.support_tickets;
ALTER PUBLICATION supabase_realtime ADD TABLE public.payout_requests;
ALTER PUBLICATION supabase_realtime ADD TABLE public.suspicious_activity_logs;

-- Updated_at triggers
CREATE TRIGGER update_commission_config_ts BEFORE UPDATE ON public.platform_commission_config FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_sample_collections_ts BEFORE UPDATE ON public.lab_sample_collections FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_support_tickets_ts BEFORE UPDATE ON public.support_tickets FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ===== 20260302141301_fdf903de-f37e-44ad-830e-b148359e7cfb.sql =====

-- Dashboard Quick Actions (configurable from admin)
CREATE TABLE public.dashboard_quick_actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  label text NOT NULL,
  icon_name text NOT NULL DEFAULT 'Calendar',
  emoji text,
  gradient text DEFAULT 'from-primary to-[hsl(190,70%,45%)]',
  path text NOT NULL DEFAULT '/',
  sort_order integer DEFAULT 0,
  active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);
ALTER TABLE public.dashboard_quick_actions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read quick actions" ON public.dashboard_quick_actions FOR SELECT USING (true);
CREATE POLICY "Admins manage quick actions" ON public.dashboard_quick_actions FOR ALL USING (has_role(auth.uid(), 'admin'::app_role)) WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

-- Dashboard Services (Browse Services section)
CREATE TABLE public.dashboard_services (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text,
  icon_name text NOT NULL DEFAULT 'Stethoscope',
  path text NOT NULL DEFAULT '/',
  color text DEFAULT 'text-primary',
  bg_color text DEFAULT 'bg-primary/10',
  sort_order integer DEFAULT 0,
  active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);
ALTER TABLE public.dashboard_services ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read services" ON public.dashboard_services FOR SELECT USING (true);
CREATE POLICY "Admins manage services" ON public.dashboard_services FOR ALL USING (has_role(auth.uid(), 'admin'::app_role)) WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

-- Dashboard Health Tips
CREATE TABLE public.dashboard_health_tips (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text NOT NULL,
  icon_name text NOT NULL DEFAULT 'Heart',
  color text DEFAULT 'text-primary',
  bg_color text DEFAULT 'bg-primary/10',
  sort_order integer DEFAULT 0,
  active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);
ALTER TABLE public.dashboard_health_tips ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read health tips" ON public.dashboard_health_tips FOR SELECT USING (true);
CREATE POLICY "Admins manage health tips" ON public.dashboard_health_tips FOR ALL USING (has_role(auth.uid(), 'admin'::app_role)) WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

-- Add featured flags to doctors and medicines
ALTER TABLE public.doctors ADD COLUMN IF NOT EXISTS is_featured boolean DEFAULT false;
ALTER TABLE public.doctors ADD COLUMN IF NOT EXISTS featured_sort_order integer DEFAULT 0;

ALTER TABLE public.medicines ADD COLUMN IF NOT EXISTS is_featured boolean DEFAULT false;
ALTER TABLE public.medicines ADD COLUMN IF NOT EXISTS featured_sort_order integer DEFAULT 0;

-- Seed default quick actions
INSERT INTO public.dashboard_quick_actions (label, icon_name, emoji, gradient, path, sort_order) VALUES
  ('Book\nAppointment', 'Calendar', '📅', 'from-primary to-[hsl(190,70%,45%)]', '/doctors', 1),
  ('Emergency\nSOS', 'AlertTriangle', '🚨', 'from-emergency to-[hsl(15,80%,50%)]', '/emergency', 2),
  ('Order\nMedicines', 'Pill', '💊', 'from-success to-[hsl(160,55%,48%)]', '/pharmacies', 3),
  ('Favorites', 'Heart', '❤️', 'from-warning to-[hsl(25,90%,55%)]', '/favorites', 4);

-- Seed default services
INSERT INTO public.dashboard_services (title, description, icon_name, path, color, bg_color, sort_order) VALUES
  ('Doctors', 'Find specialists', 'Stethoscope', '/doctors', 'text-primary', 'bg-primary/10', 1),
  ('Hospitals', 'Nearby facilities', 'Building2', '/hospitals', 'text-emergency', 'bg-emergency/10', 2),
  ('Labs', 'Book tests', 'FlaskConical', '/labs', 'text-success', 'bg-success/10', 3),
  ('Pharmacies', 'Order medicines', 'Store', '/pharmacies', 'text-warning', 'bg-warning/10', 4);

-- Seed default health tips
INSERT INTO public.dashboard_health_tips (title, description, icon_name, color, bg_color, sort_order) VALUES
  ('Stay Hydrated', 'Drink 8+ glasses of water daily for optimal organ function.', 'Droplets', 'text-blue-500', 'bg-blue-500/10', 1),
  ('Quality Sleep', '7-9 hours of sleep improves immunity and cognitive function.', 'Moon', 'text-violet-500', 'bg-violet-500/10', 2),
  ('Balanced Diet', 'Include fruits, vegetables, and whole grains in every meal.', 'Apple', 'text-success', 'bg-success/10', 3),
  ('Stay Active', '30 minutes of daily exercise reduces heart disease risk by 35%.', 'Dumbbell', 'text-warning', 'bg-warning/10', 4),
  ('Mental Health', 'Practice mindfulness or meditation for 10 minutes daily.', 'Brain', 'text-primary', 'bg-primary/10', 5),
  ('Vitamin D', '15 minutes of morning sunlight boosts bone health and mood.', 'Sun', 'text-amber-500', 'bg-amber-500/10', 6),
  ('Heart Health', 'Regular checkups help detect cardiovascular issues early.', 'Heart', 'text-emergency', 'bg-emergency/10', 7),
  ('Deep Breathing', 'Practice 4-7-8 breathing technique to reduce stress and anxiety.', 'Wind', 'text-teal-500', 'bg-teal-500/10', 8);

-- ===== 20260302161311_27759afb-beb9-484d-93a0-d60fdb1ed6c8.sql =====

-- Create a public storage bucket for slider images
INSERT INTO storage.buckets (id, name, public) VALUES ('slider-images', 'slider-images', true);

-- Allow anyone to view slider images
CREATE POLICY "Slider images are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'slider-images');

-- Allow admins to upload slider images
CREATE POLICY "Admins can upload slider images"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'slider-images' AND public.has_role(auth.uid(), 'admin'::public.app_role));

-- Allow admins to update slider images
CREATE POLICY "Admins can update slider images"
ON storage.objects FOR UPDATE
USING (bucket_id = 'slider-images' AND public.has_role(auth.uid(), 'admin'::public.app_role));

-- Allow admins to delete slider images
CREATE POLICY "Admins can delete slider images"
ON storage.objects FOR DELETE
USING (bucket_id = 'slider-images' AND public.has_role(auth.uid(), 'admin'::public.app_role));

-- ===== 20260303024325_12d6ddc6-eeb9-4a49-af34-182b37817247.sql =====
-- Create storage bucket for lab reports
INSERT INTO storage.buckets (id, name, public) VALUES ('lab-reports', 'lab-reports', false)
ON CONFLICT (id) DO NOTHING;

-- Lab admins can upload reports
CREATE POLICY "Lab admins can upload reports"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'lab-reports'
  AND EXISTS (
    SELECT 1 FROM labs WHERE user_id = auth.uid()
  )
);

-- Lab admins can update reports
CREATE POLICY "Lab admins can update reports"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'lab-reports'
  AND EXISTS (
    SELECT 1 FROM labs WHERE user_id = auth.uid()
  )
);

-- Patients can download their own reports (path starts with their user_id)
CREATE POLICY "Patients can view own lab reports"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'lab-reports'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Admins can manage all lab reports
CREATE POLICY "Admins can manage lab reports"
ON storage.objects FOR ALL
USING (
  bucket_id = 'lab-reports'
  AND has_role(auth.uid(), 'admin'::app_role)
)
WITH CHECK (
  bucket_id = 'lab-reports'
  AND has_role(auth.uid(), 'admin'::app_role)
);
-- ===== 20260303040438_2b1b4db3-eeac-4355-9be4-3dab13dcd960.sql =====
ALTER TABLE public.medicines ADD COLUMN brand_name text;
-- ===== 20260303112014_b857299a-b749-429a-a3f4-be7f4c775c0d.sql =====

-- Create internal config table for shared secrets (no public access)
CREATE TABLE IF NOT EXISTS public.internal_config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS and deny all public access
ALTER TABLE public.internal_config ENABLE ROW LEVEL SECURITY;
-- No RLS policies = no public access, only SECURITY DEFINER functions can read

-- Insert a random internal push secret
INSERT INTO public.internal_config (key, value)
VALUES ('push_secret', encode(gen_random_bytes(32), 'hex'))
ON CONFLICT (key) DO NOTHING;

-- Update push_notify_appointment_confirmed to use internal secret
CREATE OR REPLACE FUNCTION public.push_notify_appointment_confirmed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  provider_name TEXT;
  notif_title TEXT;
  notif_message TEXT;
  internal_secret TEXT;
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status AND NEW.status IN ('confirmed', 'cancelled', 'completed') THEN
    IF NEW.doctor_id IS NOT NULL THEN
      SELECT name INTO provider_name FROM doctors WHERE id = NEW.doctor_id;
    ELSIF NEW.hospital_id IS NOT NULL THEN
      SELECT name INTO provider_name FROM hospitals WHERE id = NEW.hospital_id;
    ELSIF NEW.lab_id IS NOT NULL THEN
      SELECT name INTO provider_name FROM labs WHERE id = NEW.lab_id;
    ELSIF NEW.pharmacy_id IS NOT NULL THEN
      SELECT name INTO provider_name FROM pharmacies WHERE id = NEW.pharmacy_id;
    END IF;
    provider_name := COALESCE(provider_name, 'your provider');

    notif_title := CASE NEW.status
      WHEN 'confirmed' THEN 'Appointment Confirmed ✅'
      WHEN 'cancelled' THEN 'Appointment Cancelled ❌'
      WHEN 'completed' THEN 'Appointment Completed 🎉'
    END;
    notif_message := 'Your ' || NEW.service_type || ' appointment with ' || provider_name || ' on ' || NEW.appointment_date || ' at ' || NEW.appointment_time || ' has been ' || NEW.status || '.';

    SELECT value INTO internal_secret FROM public.internal_config WHERE key = 'push_secret';

    PERFORM net.http_post(
      url := 'https://zjlznbgcfzpcveqyjglf.supabase.co/functions/v1/send-push-notification',
      body := jsonb_build_object(
        'user_id', NEW.patient_id,
        'title', notif_title,
        'message', notif_message,
        'path', '/appointments'
      ),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer internal',
        'x-internal-secret', COALESCE(internal_secret, '')
      )
    );
  END IF;
  RETURN NEW;
END;
$function$;

-- Update push_notify_order_status to use internal secret
CREATE OR REPLACE FUNCTION public.push_notify_order_status()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  notif_title TEXT;
  notif_message TEXT;
  internal_secret TEXT;
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status AND NEW.status IN ('confirmed', 'out_for_delivery', 'delivered', 'cancelled') THEN
    notif_title := CASE NEW.status
      WHEN 'confirmed' THEN 'Order Confirmed ✅'
      WHEN 'out_for_delivery' THEN 'Order Out for Delivery 🚚'
      WHEN 'delivered' THEN 'Order Delivered 📦'
      WHEN 'cancelled' THEN 'Order Cancelled ❌'
    END;
    notif_message := 'Your order (₹' || NEW.total || ') is now ' || replace(NEW.status, '_', ' ') || '.';

    SELECT value INTO internal_secret FROM public.internal_config WHERE key = 'push_secret';

    PERFORM net.http_post(
      url := 'https://zjlznbgcfzpcveqyjglf.supabase.co/functions/v1/send-push-notification',
      body := jsonb_build_object(
        'user_id', NEW.user_id,
        'title', notif_title,
        'message', notif_message,
        'path', '/order/' || NEW.id
      ),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer internal',
        'x-internal-secret', COALESCE(internal_secret, '')
      )
    );
  END IF;
  RETURN NEW;
END;
$function$;

-- ===== 20260303115142_825f52de-59a6-4f3e-9e30-d0220bc364e8.sql =====

-- Rate limiting table for edge functions
CREATE TABLE public.rate_limits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_key text NOT NULL,
  endpoint text NOT NULL,
  request_count integer NOT NULL DEFAULT 1,
  window_start timestamptz NOT NULL DEFAULT now()
);

-- Index for fast lookups
CREATE UNIQUE INDEX idx_rate_limits_key_endpoint ON public.rate_limits (user_key, endpoint);

-- Enable RLS (no public access)
ALTER TABLE public.rate_limits ENABLE ROW LEVEL SECURITY;

-- Function to check and increment rate limit
-- Returns TRUE if request is allowed, FALSE if rate limited
CREATE OR REPLACE FUNCTION public.check_rate_limit(
  _user_key text,
  _endpoint text,
  _max_requests integer,
  _window_seconds integer
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  _current_count integer;
  _window_start timestamptz;
BEGIN
  -- Try to get existing record
  SELECT request_count, window_start INTO _current_count, _window_start
  FROM rate_limits
  WHERE user_key = _user_key AND endpoint = _endpoint;

  IF NOT FOUND THEN
    -- First request, create record
    INSERT INTO rate_limits (user_key, endpoint, request_count, window_start)
    VALUES (_user_key, _endpoint, 1, now())
    ON CONFLICT (user_key, endpoint) DO UPDATE
    SET request_count = 1, window_start = now();
    RETURN true;
  END IF;

  -- Check if window has expired
  IF _window_start + (_window_seconds || ' seconds')::interval < now() THEN
    -- Reset window
    UPDATE rate_limits
    SET request_count = 1, window_start = now()
    WHERE user_key = _user_key AND endpoint = _endpoint;
    RETURN true;
  END IF;

  -- Check if under limit
  IF _current_count < _max_requests THEN
    UPDATE rate_limits
    SET request_count = request_count + 1
    WHERE user_key = _user_key AND endpoint = _endpoint;
    RETURN true;
  END IF;

  -- Rate limited
  RETURN false;
END;
$$;

-- Cleanup old rate limit entries (older than 24 hours)
CREATE OR REPLACE FUNCTION public.cleanup_rate_limits()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  DELETE FROM rate_limits WHERE window_start < now() - interval '24 hours';
$$;

-- Create a view for doctors that excludes sensitive fields
CREATE OR REPLACE VIEW public.doctors_public AS
SELECT 
  id, name, specialization, bio, consultation_fee, consultation_duration,
  experience_years, hospital_id, department_id, image_url, rating,
  working_hours, is_featured, featured_sort_order, emergency_available,
  max_appointments_per_day, approval_status, account_status, created_at,
  vacation_dates
FROM public.doctors;

-- ===== 20260303115208_2f33d441-adef-4bdb-b4cb-61f6ad4aa3fb.sql =====

-- Fix the view to use SECURITY INVOKER (safe)
DROP VIEW IF EXISTS public.doctors_public;
CREATE VIEW public.doctors_public
WITH (security_invoker = true)
AS
SELECT 
  id, name, specialization, bio, consultation_fee, consultation_duration,
  experience_years, hospital_id, department_id, image_url, rating,
  working_hours, is_featured, featured_sort_order, emergency_available,
  max_appointments_per_day, approval_status, account_status, created_at,
  vacation_dates
FROM public.doctors;

-- ===== 20260303120938_62f8463f-2b87-4273-bf4a-a52d0170f6e0.sql =====

ALTER TABLE public.internal_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can read internal config"
  ON public.internal_config
  FOR SELECT
  TO authenticated
  USING (public.has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can manage internal config"
  ON public.internal_config
  FOR ALL
  TO authenticated
  USING (public.has_role(auth.uid(), 'admin'::app_role))
  WITH CHECK (public.has_role(auth.uid(), 'admin'::app_role));

-- ===== 20260303123903_2907c237-aabb-4cc6-bab7-49aaf1cf4665.sql =====
-- Fix lab report upload policy to verify ownership via appointment
DROP POLICY IF EXISTS "Lab admins can upload reports" ON storage.objects;

CREATE POLICY "Lab admins can upload reports for their patients"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'lab-reports'
  AND EXISTS (
    SELECT 1 FROM appointments a
    JOIN labs l ON a.lab_id = l.id
    WHERE l.user_id = auth.uid()
    AND a.patient_id::text = (storage.foldername(name))[1]
    AND a.status IN ('confirmed', 'completed')
  )
);
-- ===== 20260303124051_532d9fb7-817f-4006-b98c-bc390b7ecfea.sql =====
-- 1. Create public views that hide PII for hospitals, labs, pharmacies, ambulances

-- Hospitals public view (hides phone, emergency_contact, platform_commission_percent)
CREATE OR REPLACE VIEW public.hospitals_public WITH (security_invoker = true) AS
SELECT id, name, location, image_url, rating, beds, available_beds, icu_available,
       available_icu_beds, total_beds, total_icu_beds, is_government, latitude, longitude,
       working_hours, holidays, approval_status, created_at
FROM public.hospitals;

-- Labs public view (hides phone)
CREATE OR REPLACE VIEW public.labs_public WITH (security_invoker = true) AS
SELECT id, name, location, image_url, rating, services, working_hours,
       latitude, longitude, approval_status, created_at
FROM public.labs;

-- Pharmacies public view (hides phone)
CREATE OR REPLACE VIEW public.pharmacies_public WITH (security_invoker = true) AS
SELECT id, name, location, image_url, rating, working_hours,
       latitude, longitude, approval_status, created_at
FROM public.pharmacies;

-- Ambulances public view (hides driver_name, driver_phone, assigned_patient_id)
CREATE OR REPLACE VIEW public.ambulances_public WITH (security_invoker = true) AS
SELECT id, vehicle_number, vehicle_type, status, hospital_id,
       current_latitude, current_longitude, equipment_details, created_at, updated_at
FROM public.ambulances;

-- 2. Add RLS policies to rate_limits table (admin only)
CREATE POLICY "Only admins can access rate limits"
ON public.rate_limits FOR ALL
TO authenticated
USING (public.has_role(auth.uid(), 'admin'::app_role))
WITH CHECK (public.has_role(auth.uid(), 'admin'::app_role));

-- 3. Ensure profiles table doesn't have public SELECT - verify existing policies
-- profiles already has user-specific and admin policies, no public SELECT exists
-- No changes needed for profiles RLS
-- ===== 20260303124231_5acae8dc-d1b0-4a20-b099-5d8d37139394.sql =====
-- Step 1: Recreate public views WITHOUT security_invoker (defaults to definer mode)
-- This allows the views to work for anonymous users while base tables are locked down

DROP VIEW IF EXISTS public.hospitals_public;
CREATE VIEW public.hospitals_public AS
SELECT id, name, location, image_url, rating, beds, available_beds, icu_available,
       available_icu_beds, total_beds, total_icu_beds, is_government, latitude, longitude,
       working_hours, holidays, approval_status, created_at
FROM public.hospitals;

DROP VIEW IF EXISTS public.labs_public;
CREATE VIEW public.labs_public AS
SELECT id, name, location, image_url, rating, services, working_hours,
       latitude, longitude, approval_status, created_at
FROM public.labs;

DROP VIEW IF EXISTS public.pharmacies_public;
CREATE VIEW public.pharmacies_public AS
SELECT id, name, location, image_url, rating, working_hours,
       latitude, longitude, approval_status, created_at
FROM public.pharmacies;

DROP VIEW IF EXISTS public.ambulances_public;
CREATE VIEW public.ambulances_public AS
SELECT id, vehicle_number, vehicle_type, status, hospital_id,
       current_latitude, current_longitude, equipment_details, created_at, updated_at
FROM public.ambulances;

-- Recreate doctors_public without security_invoker
DROP VIEW IF EXISTS public.doctors_public;
CREATE VIEW public.doctors_public AS
SELECT id, name, specialization, bio, image_url, experience_years, consultation_fee,
       consultation_duration, rating, working_hours, hospital_id, department_id,
       is_featured, featured_sort_order, vacation_dates, max_appointments_per_day,
       emergency_available, account_status, approval_status, created_at
FROM public.doctors;

-- Step 2: Remove "viewable by everyone" policies from base tables
DROP POLICY IF EXISTS "Doctors are viewable by everyone" ON public.doctors;
DROP POLICY IF EXISTS "Hospitals are viewable by everyone" ON public.hospitals;
DROP POLICY IF EXISTS "Labs are viewable by everyone" ON public.labs;
DROP POLICY IF EXISTS "Ambulances viewable by everyone" ON public.ambulances;

-- Check if pharmacies has a similar policy
DROP POLICY IF EXISTS "Pharmacies are viewable by everyone" ON public.pharmacies;
DROP POLICY IF EXISTS "Pharmacies viewable by everyone" ON public.pharmacies;

-- Step 3: Add authenticated-only SELECT policies to base tables
CREATE POLICY "Authenticated users can view doctors"
ON public.doctors FOR SELECT TO authenticated
USING (true);

CREATE POLICY "Authenticated users can view hospitals"
ON public.hospitals FOR SELECT TO authenticated
USING (true);

CREATE POLICY "Authenticated users can view labs"
ON public.labs FOR SELECT TO authenticated
USING (true);

CREATE POLICY "Authenticated users can view pharmacies"
ON public.pharmacies FOR SELECT TO authenticated
USING (true);

CREATE POLICY "Authenticated users can view ambulances"
ON public.ambulances FOR SELECT TO authenticated
USING (true);
-- ===== 20260303124306_8f46a98a-147b-4f9b-8a35-98731aed79b6.sql =====
-- Recreate views with security_invoker = true (Supabase best practice)
DROP VIEW IF EXISTS public.hospitals_public;
CREATE VIEW public.hospitals_public WITH (security_invoker = true) AS
SELECT id, name, location, image_url, rating, beds, available_beds, icu_available,
       available_icu_beds, total_beds, total_icu_beds, is_government, latitude, longitude,
       working_hours, holidays, approval_status, created_at
FROM public.hospitals;

DROP VIEW IF EXISTS public.labs_public;
CREATE VIEW public.labs_public WITH (security_invoker = true) AS
SELECT id, name, location, image_url, rating, services, working_hours,
       latitude, longitude, approval_status, created_at
FROM public.labs;

DROP VIEW IF EXISTS public.pharmacies_public;
CREATE VIEW public.pharmacies_public WITH (security_invoker = true) AS
SELECT id, name, location, image_url, rating, working_hours,
       latitude, longitude, approval_status, created_at
FROM public.pharmacies;

DROP VIEW IF EXISTS public.ambulances_public;
CREATE VIEW public.ambulances_public WITH (security_invoker = true) AS
SELECT id, vehicle_number, vehicle_type, status, hospital_id,
       current_latitude, current_longitude, equipment_details, created_at, updated_at
FROM public.ambulances;

DROP VIEW IF EXISTS public.doctors_public;
CREATE VIEW public.doctors_public WITH (security_invoker = true) AS
SELECT id, name, specialization, bio, image_url, experience_years, consultation_fee,
       consultation_duration, rating, working_hours, hospital_id, department_id,
       is_featured, featured_sort_order, vacation_dates, max_appointments_per_day,
       emergency_available, account_status, approval_status, created_at
FROM public.doctors;

-- Restore "viewable by everyone" on base tables (needed for views with security_invoker)
-- The authenticated-only policies already exist from previous migration, drop them first
DROP POLICY IF EXISTS "Authenticated users can view doctors" ON public.doctors;
DROP POLICY IF EXISTS "Authenticated users can view hospitals" ON public.hospitals;
DROP POLICY IF EXISTS "Authenticated users can view labs" ON public.labs;
DROP POLICY IF EXISTS "Authenticated users can view pharmacies" ON public.pharmacies;
DROP POLICY IF EXISTS "Authenticated users can view ambulances" ON public.ambulances;

CREATE POLICY "Doctors are viewable by everyone"
ON public.doctors FOR SELECT USING (true);

CREATE POLICY "Hospitals are viewable by everyone"
ON public.hospitals FOR SELECT USING (true);

CREATE POLICY "Labs are viewable by everyone"
ON public.labs FOR SELECT USING (true);

CREATE POLICY "Pharmacies are viewable by everyone"
ON public.pharmacies FOR SELECT USING (true);

CREATE POLICY "Ambulances viewable by everyone"
ON public.ambulances FOR SELECT USING (true);
-- ===== 20260303124622_588ae64f-e44f-4e14-8715-b5f36dd56e62.sql =====
-- 1. Fix profiles: Ensure no public SELECT exists (verify existing policies)
-- profiles should only be readable by the user themselves and admins
-- Check existing policies - they should already restrict to user_id = auth.uid()

-- 2. Restrict ambulances base table: remove public SELECT, keep authenticated
DROP POLICY IF EXISTS "Ambulances viewable by everyone" ON public.ambulances;
CREATE POLICY "Authenticated users can view ambulances"
ON public.ambulances FOR SELECT TO authenticated
USING (true);

-- 3. Restrict cancellation_otp_settings to authenticated users only
DROP POLICY IF EXISTS "Anyone can read OTP settings" ON public.cancellation_otp_settings;
CREATE POLICY "Authenticated users can read OTP settings"
ON public.cancellation_otp_settings FOR SELECT TO authenticated
USING (true);

-- 4. Restrict platform_commission_config to authenticated providers
DROP POLICY IF EXISTS "Providers can view commission config" ON public.platform_commission_config;
CREATE POLICY "Authenticated users can view commission config"
ON public.platform_commission_config FOR SELECT TO authenticated
USING (true);

-- 5. Recreate ambulances_public as security definer function instead of view
-- to allow anonymous access to safe fields only
DROP VIEW IF EXISTS public.ambulances_public;
CREATE OR REPLACE FUNCTION public.get_ambulances_public()
RETURNS TABLE (
  id uuid,
  vehicle_number text,
  vehicle_type text,
  status text,
  hospital_id uuid,
  current_latitude double precision,
  current_longitude double precision,
  equipment_details text
)
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT id, vehicle_number, vehicle_type, status, hospital_id,
         current_latitude, current_longitude, equipment_details
  FROM public.ambulances;
$$;
-- ===== 20260304104436_f18f1130-fb4a-4a62-b2eb-56da4341479d.sql =====

-- Table for Info Cards Row (My Prescriptions, Lab Reports, My Orders, Favorites)
CREATE TABLE public.dashboard_info_cards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  label text NOT NULL,
  icon_name text NOT NULL DEFAULT 'FileText',
  icon_bg text DEFAULT 'bg-primary/10',
  icon_color text DEFAULT 'text-primary',
  path text NOT NULL DEFAULT '/',
  sort_order integer DEFAULT 0,
  active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now()
);

ALTER TABLE public.dashboard_info_cards ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins manage info cards" ON public.dashboard_info_cards FOR ALL
  USING (has_role(auth.uid(), 'admin'::app_role))
  WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Public read info cards" ON public.dashboard_info_cards FOR SELECT
  USING (true);

-- Table for Quick Access More grid
CREATE TABLE public.dashboard_quick_access (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  subtitle text DEFAULT '',
  extra_text text DEFAULT '',
  icon_name text NOT NULL DEFAULT 'Stethoscope',
  gradient text DEFAULT 'from-primary to-primary/80',
  text_color text DEFAULT 'text-white',
  path text NOT NULL DEFAULT '/',
  sort_order integer DEFAULT 0,
  active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now()
);

ALTER TABLE public.dashboard_quick_access ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins manage quick access" ON public.dashboard_quick_access FOR ALL
  USING (has_role(auth.uid(), 'admin'::app_role))
  WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Public read quick access" ON public.dashboard_quick_access FOR SELECT
  USING (true);

-- Seed default info cards
INSERT INTO public.dashboard_info_cards (label, icon_name, icon_bg, icon_color, path, sort_order) VALUES
('My Prescriptions', 'FileText', 'bg-[hsl(215,60%,92%)]', 'text-primary', '/medical-history', 1),
('Lab Reports', 'Microscope', 'bg-[hsl(200,65%,90%)]', 'text-[hsl(200,65%,40%)]', '/lab-reports', 2),
('My Orders', 'ShoppingBag', 'bg-[hsl(145,50%,90%)]', 'text-[hsl(145,50%,35%)]', '/my-orders', 3),
('Favorites', 'Heart', 'bg-[hsl(0,70%,92%)]', 'text-[hsl(0,70%,50%)]', '/favorites', 4);

-- Seed default quick access items
INSERT INTO public.dashboard_quick_access (title, subtitle, extra_text, icon_name, gradient, text_color, path, sort_order) VALUES
('Find Doctors', '400+ Available', '', 'Stethoscope', 'from-[hsl(215,70%,50%)] to-[hsl(215,65%,40%)]', 'text-white', '/doctors', 1),
('Ambulance Service', '10 min Guaranteed', '₹200', 'Ambulance', 'from-muted to-[hsl(205,30%,94%)]', 'text-foreground', '/emergency', 2),
('Medicine Delivery', 'Fast Home Delivery', '', 'Pill', 'from-[hsl(152,55%,40%)] to-[hsl(152,50%,32%)]', 'text-white', '/pharmacies', 3),
('Health Packages', 'Full Body Checkups', 'Starting From ₹999', 'FlaskConical', 'from-[hsl(270,40%,92%)] to-[hsl(280,35%,88%)]', 'text-foreground', '/labs', 4);

-- Seed default quick actions (primary action grid) if empty
INSERT INTO public.dashboard_quick_actions (label, icon_name, path, gradient, sort_order, active)
SELECT * FROM (VALUES
  ('Book Appointment', 'Calendar', '/doctors', 'from-[hsl(215,70%,50%)] to-[hsl(215,65%,40%)]', 1, true),
  ('Order Medicine', 'ClipboardList', '/pharmacies', 'from-[hsl(152,55%,40%)] to-[hsl(152,50%,32%)]', 2, true),
  ('Lab Tests', 'FlaskConical', '/labs', 'from-[hsl(200,65%,48%)] to-[hsl(200,60%,38%)]', 3, true),
  ('Emergency', 'AlertTriangle', '/emergency', 'from-[hsl(0,70%,52%)] to-[hsl(0,65%,42%)]', 4, true)
) AS v(label, icon_name, path, gradient, sort_order, active)
WHERE NOT EXISTS (SELECT 1 FROM public.dashboard_quick_actions LIMIT 1);

-- ===== 20260304140243_af655924-037c-42c8-be52-78fac711ae6c.sql =====
UPDATE dashboard_quick_actions SET label = E'My\nFavorites' WHERE path = '/favorites';
-- ===== 20260304161708_28b1d614-067d-4902-833f-dd0bc4562e57.sql =====
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS gender text DEFAULT NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS address text DEFAULT NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS latitude double precision DEFAULT NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS longitude double precision DEFAULT NULL;
-- ===== 20260305045012_0d707fb7-1dfa-46ce-8446-1d99c984a845.sql =====

-- Admin team members table for managing admin users with designations
CREATE TABLE public.admin_team (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  name text NOT NULL,
  email text NOT NULL,
  designation text NOT NULL DEFAULT 'Admin',
  phone text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  created_by uuid,
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.admin_team ENABLE ROW LEVEL SECURITY;

-- Only admins can manage admin team
CREATE POLICY "Admins can manage admin team"
  ON public.admin_team FOR ALL
  TO authenticated
  USING (public.has_role(auth.uid(), 'admin'))
  WITH CHECK (public.has_role(auth.uid(), 'admin'));

-- Platform settings table
CREATE TABLE public.platform_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key text UNIQUE NOT NULL,
  value text NOT NULL DEFAULT '',
  label text NOT NULL,
  category text NOT NULL DEFAULT 'general',
  type text NOT NULL DEFAULT 'text',
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_by uuid
);

ALTER TABLE public.platform_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage platform settings"
  ON public.platform_settings FOR ALL
  TO authenticated
  USING (public.has_role(auth.uid(), 'admin'))
  WITH CHECK (public.has_role(auth.uid(), 'admin'));

-- Seed default settings
INSERT INTO public.platform_settings (key, value, label, category, type) VALUES
  ('platform_name', 'Remedoo', 'Platform Name', 'general', 'text'),
  ('support_email', 'support@remedoo.com', 'Support Email', 'general', 'text'),
  ('support_phone', '+91 9876543210', 'Support Phone', 'general', 'text'),
  ('maintenance_mode', 'false', 'Maintenance Mode', 'general', 'toggle'),
  ('new_registrations', 'true', 'Allow New Registrations', 'general', 'toggle'),
  ('default_commission', '10', 'Default Commission (%)', 'finance', 'number'),
  ('min_order_amount', '100', 'Minimum Order Amount (₹)', 'finance', 'number'),
  ('delivery_fee', '40', 'Delivery Fee (₹)', 'finance', 'number'),
  ('free_delivery_above', '500', 'Free Delivery Above (₹)', 'finance', 'number'),
  ('max_appointments_per_day', '50', 'Max Appointments/Day', 'appointments', 'number'),
  ('appointment_buffer_minutes', '15', 'Appointment Buffer (min)', 'appointments', 'number'),
  ('auto_cancel_hours', '24', 'Auto-Cancel Pending After (hrs)', 'appointments', 'number'),
  ('emergency_radius_km', '25', 'Emergency Search Radius (km)', 'emergency', 'number'),
  ('ambulance_timeout_minutes', '30', 'Ambulance Timeout (min)', 'emergency', 'number'),
  ('terms_url', '', 'Terms & Conditions URL', 'legal', 'text'),
  ('privacy_url', '', 'Privacy Policy URL', 'legal', 'text'),
  ('refund_policy_url', '', 'Refund Policy URL', 'legal', 'text');

-- Updated_at trigger
CREATE TRIGGER update_platform_settings_updated_at
  BEFORE UPDATE ON public.platform_settings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_admin_team_updated_at
  BEFORE UPDATE ON public.admin_team
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ===== 20260305053647_c5981f68-609b-4de2-b7b3-82f9680b7a07.sql =====
CREATE TABLE public.admin_permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_team_id uuid NOT NULL REFERENCES public.admin_team(id) ON DELETE CASCADE,
  page_path text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(admin_team_id, page_path)
);

ALTER TABLE public.admin_permissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage permissions"
ON public.admin_permissions
FOR ALL
TO authenticated
USING (has_role(auth.uid(), 'admin'::app_role))
WITH CHECK (has_role(auth.uid(), 'admin'::app_role));
-- ===== 20260305143727_9e6ccf6a-3f9c-42f8-92f2-70f2d2ece8cb.sql =====
ALTER TABLE public.doctors ADD COLUMN IF NOT EXISTS gender text DEFAULT null;
-- ===== 20260306054314_94439a76-2211-40f3-98ac-6403452b250f.sql =====

-- Add moderation columns to reviews (policy already exists)
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'approved';
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS admin_notes text;

-- Create coupons table
CREATE TABLE IF NOT EXISTS public.coupons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  description text,
  discount_type text NOT NULL DEFAULT 'percentage',
  discount_value numeric NOT NULL DEFAULT 0,
  min_order_amount numeric DEFAULT 0,
  max_discount_amount numeric,
  usage_limit integer,
  used_count integer NOT NULL DEFAULT 0,
  applicable_for text NOT NULL DEFAULT 'all',
  valid_from timestamp with time zone NOT NULL DEFAULT now(),
  valid_until timestamp with time zone,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.coupons ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage coupons"
ON public.coupons FOR ALL TO authenticated
USING (has_role(auth.uid(), 'admin'::app_role))
WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Authenticated users can view active coupons"
ON public.coupons FOR SELECT TO authenticated
USING (is_active = true);

-- Create coupon_usage table
CREATE TABLE IF NOT EXISTS public.coupon_usage (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coupon_id uuid REFERENCES public.coupons(id) ON DELETE CASCADE NOT NULL,
  user_id uuid NOT NULL,
  order_id uuid,
  appointment_id uuid,
  discount_applied numeric NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.coupon_usage ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage coupon usage"
ON public.coupon_usage FOR ALL TO authenticated
USING (has_role(auth.uid(), 'admin'::app_role))
WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Users can view own coupon usage"
ON public.coupon_usage FOR SELECT TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own coupon usage"
ON public.coupon_usage FOR INSERT TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Create service_areas table
CREATE TABLE IF NOT EXISTS public.service_areas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  type text NOT NULL DEFAULT 'city',
  parent_id uuid REFERENCES public.service_areas(id),
  latitude numeric,
  longitude numeric,
  radius_km numeric,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.service_areas ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage service areas"
ON public.service_areas FOR ALL TO authenticated
USING (has_role(auth.uid(), 'admin'::app_role))
WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Public can view active service areas"
ON public.service_areas FOR SELECT
USING (is_active = true);

-- Create broadcast_notifications table
CREATE TABLE IF NOT EXISTS public.broadcast_notifications (
