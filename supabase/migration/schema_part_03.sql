-- chunk 3
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
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  message text NOT NULL,
  target_audience text NOT NULL DEFAULT 'all',
  sent_by uuid NOT NULL,
  sent_at timestamp with time zone NOT NULL DEFAULT now(),
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.broadcast_notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage broadcasts"
ON public.broadcast_notifications FOR ALL TO authenticated
USING (has_role(auth.uid(), 'admin'::app_role))
WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

-- Create faq table
CREATE TABLE IF NOT EXISTS public.faqs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  question text NOT NULL,
  answer text NOT NULL,
  category text DEFAULT 'general',
  sort_order integer DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.faqs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage FAQs"
ON public.faqs FOR ALL TO authenticated
USING (has_role(auth.uid(), 'admin'::app_role))
WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Public can view active FAQs"
ON public.faqs FOR SELECT
USING (is_active = true);

-- Create legal_pages table
CREATE TABLE IF NOT EXISTS public.legal_pages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  title text NOT NULL,
  content text NOT NULL DEFAULT '',
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_by uuid
);

ALTER TABLE public.legal_pages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage legal pages"
ON public.legal_pages FOR ALL TO authenticated
USING (has_role(auth.uid(), 'admin'::app_role))
WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Public can view legal pages"
ON public.legal_pages FOR SELECT
USING (true);

-- Create subscription_plans table
CREATE TABLE IF NOT EXISTS public.subscription_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  provider_type text NOT NULL DEFAULT 'doctor',
  price numeric NOT NULL DEFAULT 0,
  duration_days integer NOT NULL DEFAULT 30,
  features jsonb DEFAULT '[]'::jsonb,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage plans"
ON public.subscription_plans FOR ALL TO authenticated
USING (has_role(auth.uid(), 'admin'::app_role))
WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Public can view active plans"
ON public.subscription_plans FOR SELECT
USING (is_active = true);

-- Create provider_subscriptions table
CREATE TABLE IF NOT EXISTS public.provider_subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid REFERENCES public.subscription_plans(id) NOT NULL,
  provider_type text NOT NULL,
  provider_id uuid NOT NULL,
  user_id uuid NOT NULL,
  starts_at timestamp with time zone NOT NULL DEFAULT now(),
  expires_at timestamp with time zone NOT NULL,
  status text NOT NULL DEFAULT 'active',
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.provider_subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage subscriptions"
ON public.provider_subscriptions FOR ALL TO authenticated
USING (has_role(auth.uid(), 'admin'::app_role))
WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Users can view own subscriptions"
ON public.provider_subscriptions FOR SELECT TO authenticated
USING (auth.uid() = user_id);

-- ===== 20260306063040_33b8a2d4-920e-40fd-a421-a0ab6e515839.sql =====

-- Lab ambulance config table (mirrors hospital_ambulance_config)
CREATE TABLE public.lab_ambulance_config (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lab_id uuid NOT NULL REFERENCES public.labs(id) ON DELETE CASCADE UNIQUE,
  service_enabled boolean DEFAULT false,
  service_type text NOT NULL DEFAULT 'free',
  base_fare numeric DEFAULT 0,
  per_km_charge numeric DEFAULT 0,
  emergency_surcharge numeric DEFAULT 0,
  night_surcharge numeric DEFAULT 0,
  minimum_charge numeric DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.lab_ambulance_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage all lab ambulance configs" ON public.lab_ambulance_config FOR ALL TO authenticated
  USING (has_role(auth.uid(), 'admin'::app_role))
  WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Lab admins can manage own ambulance config" ON public.lab_ambulance_config FOR ALL TO authenticated
  USING (lab_id IN (SELECT id FROM public.labs WHERE user_id = auth.uid()))
  WITH CHECK (lab_id IN (SELECT id FROM public.labs WHERE user_id = auth.uid()));

-- Add lab_id to ambulances table so labs can also own ambulances
ALTER TABLE public.ambulances ADD COLUMN IF NOT EXISTS lab_id uuid REFERENCES public.labs(id) ON DELETE SET NULL;

-- Allow lab admins to manage their own ambulances
CREATE POLICY "Lab admins can manage own ambulances" ON public.ambulances FOR ALL TO authenticated
  USING (lab_id IN (SELECT id FROM public.labs WHERE user_id = auth.uid()))
  WITH CHECK (lab_id IN (SELECT id FROM public.labs WHERE user_id = auth.uid()));

-- Add lab_id to ambulance_trips so labs can have trips
ALTER TABLE public.ambulance_trips ADD COLUMN IF NOT EXISTS lab_id uuid REFERENCES public.labs(id) ON DELETE SET NULL;

-- Make hospital_id nullable since labs can also have trips
ALTER TABLE public.ambulance_trips ALTER COLUMN hospital_id DROP NOT NULL;

-- Allow lab admins to manage their own trips
CREATE POLICY "Lab admins can manage own trips" ON public.ambulance_trips FOR ALL TO authenticated
  USING (lab_id IN (SELECT id FROM public.labs WHERE user_id = auth.uid()))
  WITH CHECK (lab_id IN (SELECT id FROM public.labs WHERE user_id = auth.uid()));

-- ===== 20260306064453_a16bbe7a-a86f-44d8-bdb8-907ad237d84d.sql =====

-- Add pricing_model and night charge fields to hospital_ambulance_config
ALTER TABLE public.hospital_ambulance_config 
  ADD COLUMN IF NOT EXISTS pricing_model text NOT NULL DEFAULT 'per_km',
  ADD COLUMN IF NOT EXISTS flat_price numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS night_charge_enabled boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS night_charge_amount numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS night_charge_start time DEFAULT '22:00',
  ADD COLUMN IF NOT EXISTS night_charge_end time DEFAULT '06:00';

-- Add pricing_model and night charge fields to lab_ambulance_config
ALTER TABLE public.lab_ambulance_config 
  ADD COLUMN IF NOT EXISTS pricing_model text NOT NULL DEFAULT 'per_km',
  ADD COLUMN IF NOT EXISTS flat_price numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS night_charge_enabled boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS night_charge_amount numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS night_charge_start time DEFAULT '22:00',
  ADD COLUMN IF NOT EXISTS night_charge_end time DEFAULT '06:00';

-- Create ambulance_distance_ranges table for both hospitals and labs
CREATE TABLE public.ambulance_distance_ranges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid REFERENCES public.hospitals(id) ON DELETE CASCADE,
  lab_id uuid REFERENCES public.labs(id) ON DELETE CASCADE,
  min_km numeric NOT NULL DEFAULT 0,
  max_km numeric NOT NULL DEFAULT 0,
  price numeric NOT NULL DEFAULT 0,
  sort_order integer DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT provider_check CHECK (
    (hospital_id IS NOT NULL AND lab_id IS NULL) OR 
    (hospital_id IS NULL AND lab_id IS NOT NULL)
  )
);

ALTER TABLE public.ambulance_distance_ranges ENABLE ROW LEVEL SECURITY;

-- RLS policies
CREATE POLICY "Admins can manage all distance ranges"
  ON public.ambulance_distance_ranges FOR ALL
  TO authenticated
  USING (has_role(auth.uid(), 'admin'::app_role))
  WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Hospital admins can manage own distance ranges"
  ON public.ambulance_distance_ranges FOR ALL
  TO authenticated
  USING (hospital_id IN (SELECT id FROM hospitals WHERE user_id = auth.uid()))
  WITH CHECK (hospital_id IN (SELECT id FROM hospitals WHERE user_id = auth.uid()));

CREATE POLICY "Lab admins can manage own distance ranges"
  ON public.ambulance_distance_ranges FOR ALL
  TO authenticated
  USING (lab_id IN (SELECT id FROM labs WHERE user_id = auth.uid()))
  WITH CHECK (lab_id IN (SELECT id FROM labs WHERE user_id = auth.uid()));

CREATE POLICY "Authenticated can view distance ranges"
  ON public.ambulance_distance_ranges FOR SELECT
  TO authenticated
  USING (true);

-- ===== 20260306065938_69cc6516-1154-4008-a8ca-052c6e783fff.sql =====

-- Driver locations table for real-time GPS tracking
CREATE TABLE public.driver_locations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id uuid REFERENCES public.ambulance_trips(id) ON DELETE CASCADE NOT NULL,
  driver_user_id uuid NOT NULL,
  latitude double precision NOT NULL,
  longitude double precision NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Index for fast lookups
CREATE INDEX idx_driver_locations_trip ON public.driver_locations(trip_id, created_at DESC);

-- Enable RLS
ALTER TABLE public.driver_locations ENABLE ROW LEVEL SECURITY;

-- Driver can insert own locations
CREATE POLICY "Drivers can insert own locations" ON public.driver_locations
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = driver_user_id);

-- Driver can view own locations
CREATE POLICY "Drivers can view own locations" ON public.driver_locations
  FOR SELECT TO authenticated
  USING (auth.uid() = driver_user_id);

-- Patient can view locations for their trips
CREATE POLICY "Patients can view trip locations" ON public.driver_locations
  FOR SELECT TO authenticated
  USING (trip_id IN (SELECT id FROM public.ambulance_trips WHERE patient_id = auth.uid()));

-- Hospital admins can view locations for their trips
CREATE POLICY "Hospital admins can view trip locations" ON public.driver_locations
  FOR SELECT TO authenticated
  USING (trip_id IN (SELECT id FROM public.ambulance_trips WHERE hospital_id IN (SELECT id FROM public.hospitals WHERE user_id = auth.uid())));

-- Lab admins can view locations for their trips
CREATE POLICY "Lab admins can view trip locations" ON public.driver_locations
  FOR SELECT TO authenticated
  USING (trip_id IN (SELECT id FROM public.ambulance_trips WHERE lab_id IN (SELECT id FROM public.labs WHERE user_id = auth.uid())));

-- Admins can view all
CREATE POLICY "Admins can view all driver locations" ON public.driver_locations
  FOR SELECT TO authenticated
  USING (has_role(auth.uid(), 'admin'));

-- Enable realtime for driver_locations
ALTER PUBLICATION supabase_realtime ADD TABLE public.driver_locations;

-- Also add driver_user_id to ambulance_trips for driver panel auth
ALTER TABLE public.ambulance_trips ADD COLUMN IF NOT EXISTS driver_user_id uuid;

-- Policy: drivers can view and update their own trips
CREATE POLICY "Drivers can view own trips" ON public.ambulance_trips
  FOR SELECT TO authenticated
  USING (driver_user_id = auth.uid());

CREATE POLICY "Drivers can update own trips" ON public.ambulance_trips
  FOR UPDATE TO authenticated
  USING (driver_user_id = auth.uid());

