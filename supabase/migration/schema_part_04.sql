-- chunk 4
-- ===== 20260306071222_1297a87e-38a7-44ed-aaa6-b59a2514cfd2.sql =====

-- 1. Remedoo Pharmacy Inventory
CREATE TABLE public.remedoo_pharmacy_inventory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  generic_name TEXT,
  category TEXT NOT NULL DEFAULT 'General',
  price NUMERIC NOT NULL DEFAULT 0,
  mrp NUMERIC,
  stock_quantity INTEGER NOT NULL DEFAULT 0,
  batch_number TEXT,
  expiry_date DATE,
  supplier_name TEXT,
  supplier_contact TEXT,
  requires_prescription BOOLEAN NOT NULL DEFAULT false,
  description TEXT,
  image_url TEXT,
  discount_percent NUMERIC DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.remedoo_pharmacy_inventory ENABLE ROW LEVEL SECURITY;

-- Admin full access
CREATE POLICY "Admin full access remedoo inventory" ON public.remedoo_pharmacy_inventory
  FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'admin'))
  WITH CHECK (public.has_role(auth.uid(), 'admin'));

-- Public read for active items
CREATE POLICY "Public read active remedoo inventory" ON public.remedoo_pharmacy_inventory
  FOR SELECT TO authenticated
  USING (is_active = true);

-- 2. Delivery Drivers
CREATE TABLE public.delivery_drivers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  phone TEXT,
  vehicle_type TEXT DEFAULT 'bike',
  vehicle_number TEXT,
  license_number TEXT,
  license_url TEXT,
  status TEXT NOT NULL DEFAULT 'offline' CHECK (status IN ('available', 'on_delivery', 'offline')),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.delivery_drivers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admin full access delivery drivers" ON public.delivery_drivers
  FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'admin'))
  WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Driver reads own record" ON public.delivery_drivers
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Driver updates own record" ON public.delivery_drivers
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- 3. Remedoo Orders (separate from partner pharmacy orders)
CREATE TABLE public.remedoo_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  items JSONB NOT NULL DEFAULT '[]',
  subtotal NUMERIC NOT NULL DEFAULT 0,
  delivery_fee NUMERIC NOT NULL DEFAULT 0,
  total NUMERIC NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'placed' CHECK (status IN ('placed', 'prescription_verification', 'preparing', 'out_for_delivery', 'delivered', 'cancelled')),
  payment_method TEXT NOT NULL DEFAULT 'cod',
  payment_status TEXT NOT NULL DEFAULT 'pending',
  prescription_url TEXT,
  delivery_address TEXT,
  notes TEXT,
  placed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.remedoo_orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admin full access remedoo orders" ON public.remedoo_orders
  FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'admin'))
  WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "User reads own remedoo orders" ON public.remedoo_orders
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "User creates own remedoo orders" ON public.remedoo_orders
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

-- 4. Delivery Orders (links orders to drivers)
CREATE TABLE public.delivery_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES public.remedoo_orders(id) ON DELETE CASCADE NOT NULL,
  driver_id UUID REFERENCES public.delivery_drivers(id),
  pickup_address TEXT DEFAULT 'Remedoo Pharmacy Warehouse',
  delivery_address TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'assigned', 'picked_up', 'in_transit', 'delivered', 'cancelled')),
  driver_latitude NUMERIC,
  driver_longitude NUMERIC,
  estimated_delivery_minutes INTEGER,
  delivered_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.delivery_orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admin full access delivery orders" ON public.delivery_orders
  FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'admin'))
  WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Driver reads assigned deliveries" ON public.delivery_orders
  FOR SELECT TO authenticated
  USING (driver_id IN (SELECT id FROM public.delivery_drivers WHERE user_id = auth.uid()));

CREATE POLICY "Driver updates assigned deliveries" ON public.delivery_orders
  FOR UPDATE TO authenticated
  USING (driver_id IN (SELECT id FROM public.delivery_drivers WHERE user_id = auth.uid()))
  WITH CHECK (driver_id IN (SELECT id FROM public.delivery_drivers WHERE user_id = auth.uid()));

CREATE POLICY "User reads own delivery orders" ON public.delivery_orders
  FOR SELECT TO authenticated
  USING (order_id IN (SELECT id FROM public.remedoo_orders WHERE user_id = auth.uid()));

-- Enable realtime for delivery tracking
ALTER PUBLICATION supabase_realtime ADD TABLE public.delivery_orders;
ALTER PUBLICATION supabase_realtime ADD TABLE public.remedoo_orders;

-- ===== 20260306082016_57d6c771-2f2d-4e32-be88-36441b5053fe.sql =====

-- Add new columns to remedoo_pharmacy_inventory
ALTER TABLE public.remedoo_pharmacy_inventory
  ADD COLUMN IF NOT EXISTS manufacturing_date text,
  ADD COLUMN IF NOT EXISTS dosage_info text,
  ADD COLUMN IF NOT EXISTS side_effects text,
  ADD COLUMN IF NOT EXISTS usage_instructions text,
  ADD COLUMN IF NOT EXISTS drug_category text DEFAULT 'otc',
  ADD COLUMN IF NOT EXISTS low_stock_threshold integer DEFAULT 10,
  ADD COLUMN IF NOT EXISTS manufacturer text,
  ADD COLUMN IF NOT EXISTS brand_name text;

-- Add prescription verification and refund columns to remedoo_orders
ALTER TABLE public.remedoo_orders
  ADD COLUMN IF NOT EXISTS prescription_status text DEFAULT 'not_required',
  ADD COLUMN IF NOT EXISTS prescription_verified_by uuid,
  ADD COLUMN IF NOT EXISTS prescription_verified_at timestamptz,
  ADD COLUMN IF NOT EXISTS prescription_rejection_reason text,
  ADD COLUMN IF NOT EXISTS cancelled_at timestamptz,
  ADD COLUMN IF NOT EXISTS refund_status text,
  ADD COLUMN IF NOT EXISTS refund_amount numeric DEFAULT 0;

-- Insert delivery fee settings into platform_settings
INSERT INTO public.platform_settings (key, value, label, category, type) VALUES
  ('remedoo_base_delivery_fee', '30', 'Base Delivery Fee (₹)', 'pharmacy', 'number'),
  ('remedoo_free_delivery_threshold', '499', 'Free Delivery Above (₹)', 'pharmacy', 'number'),
  ('remedoo_per_km_delivery_fee', '5', 'Per KM Delivery Fee (₹)', 'pharmacy', 'number')
ON CONFLICT (key) DO NOTHING;

-- ===== 20260306085519_a18b8d4c-a5b9-4d83-ba4d-a84672f7cab3.sql =====

-- Notification trigger for remedoo_orders status changes
CREATE OR REPLACE FUNCTION public.notify_remedoo_order_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status) THEN
    INSERT INTO public.notifications (user_id, type, title, message, path)
    VALUES (
      NEW.user_id,
      'order',
      CASE
        WHEN NEW.status = 'placed' THEN 'Order Placed ✅'
        WHEN NEW.status = 'prescription_verification' THEN 'Prescription Under Review 📋'
        WHEN NEW.status = 'preparing' THEN 'Order Being Prepared 🧪'
        WHEN NEW.status = 'out_for_delivery' THEN 'Order Out for Delivery 🚚'
        WHEN NEW.status = 'delivered' THEN 'Order Delivered 📦'
        WHEN NEW.status = 'cancelled' THEN 'Order Cancelled ❌'
        ELSE 'Order Update 🛒'
      END,
      'Your Remedoo order (₹' || COALESCE(NEW.total::text, '0') || ') is now ' || replace(NEW.status, '_', ' ') || '.',
      '/remedoo-order/' || NEW.id
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_remedoo_order ON public.remedoo_orders;
CREATE TRIGGER trg_notify_remedoo_order
  AFTER INSERT OR UPDATE OF status ON public.remedoo_orders
  FOR EACH ROW EXECUTE FUNCTION public.notify_remedoo_order_change();

-- Push notification trigger for remedoo_orders
CREATE OR REPLACE FUNCTION public.push_notify_remedoo_order()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  notif_title TEXT;
  notif_message TEXT;
  internal_secret TEXT;
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status AND NEW.status IN ('placed', 'preparing', 'out_for_delivery', 'delivered', 'cancelled') THEN
    notif_title := CASE NEW.status
      WHEN 'placed' THEN 'Order Confirmed ✅'
      WHEN 'preparing' THEN 'Order Being Prepared 🧪'
      WHEN 'out_for_delivery' THEN 'Out for Delivery 🚚'
      WHEN 'delivered' THEN 'Order Delivered 📦'
      WHEN 'cancelled' THEN 'Order Cancelled ❌'
    END;
    notif_message := 'Your Remedoo order (₹' || COALESCE(NEW.total::text, '0') || ') is now ' || replace(NEW.status, '_', ' ') || '.';

    SELECT value INTO internal_secret FROM public.internal_config WHERE key = 'push_secret';

    PERFORM net.http_post(
      url := 'https://zjlznbgcfzpcveqyjglf.supabase.co/functions/v1/send-push-notification',
      body := jsonb_build_object(
        'user_id', NEW.user_id,
        'title', notif_title,
        'message', notif_message,
        'path', '/remedoo-order/' || NEW.id
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
$$;

DROP TRIGGER IF EXISTS trg_push_notify_remedoo_order ON public.remedoo_orders;
CREATE TRIGGER trg_push_notify_remedoo_order
  AFTER UPDATE OF status ON public.remedoo_orders
  FOR EACH ROW EXECUTE FUNCTION public.push_notify_remedoo_order();

-- ===== 20260306094121_f7902d62-3390-4ab9-91b1-f8f9d8331c95.sql =====

-- Symptoms catalog
CREATE TABLE public.symptoms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  symptom_name TEXT NOT NULL,
  category TEXT DEFAULT 'general',
  is_emergency BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.symptoms ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read symptoms" ON public.symptoms FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins manage symptoms" ON public.symptoms FOR ALL TO authenticated USING (
  EXISTS (SELECT 1 FROM admin_team WHERE user_id = auth.uid() AND is_active = true)
);

-- Follow-up questions per symptom
CREATE TABLE public.symptom_questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  symptom_id UUID REFERENCES public.symptoms(id) ON DELETE CASCADE NOT NULL,
  question_text TEXT NOT NULL,
  answer_options JSONB DEFAULT '[]',
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.symptom_questions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read symptom_questions" ON public.symptom_questions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins manage symptom_questions" ON public.symptom_questions FOR ALL TO authenticated USING (
  EXISTS (SELECT 1 FROM admin_team WHERE user_id = auth.uid() AND is_active = true)
);

-- Rule engine: symptom combos -> specialization
CREATE TABLE public.symptom_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_name TEXT NOT NULL,
  symptom_combination TEXT[] NOT NULL,
  recommended_specialization TEXT NOT NULL,
  priority INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.symptom_rules ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read symptom_rules" ON public.symptom_rules FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins manage symptom_rules" ON public.symptom_rules FOR ALL TO authenticated USING (
  EXISTS (SELECT 1 FROM admin_team WHERE user_id = auth.uid() AND is_active = true)
);

-- Conversation history
CREATE TABLE public.symptom_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  conversation_data JSONB NOT NULL DEFAULT '[]',
  symptoms_identified TEXT[] DEFAULT '{}',
  result_specialization TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.symptom_conversations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own conversations" ON public.symptom_conversations FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY "Users insert own conversations" ON public.symptom_conversations FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY "Admins read all conversations" ON public.symptom_conversations FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM admin_team WHERE user_id = auth.uid() AND is_active = true)
);

-- Emergency trigger keywords
CREATE TABLE public.emergency_triggers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  symptom_keyword TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.emergency_triggers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read emergency_triggers" ON public.emergency_triggers FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins manage emergency_triggers" ON public.emergency_triggers FOR ALL TO authenticated USING (
  EXISTS (SELECT 1 FROM admin_team WHERE user_id = auth.uid() AND is_active = true)
);

-- ===== 20260306095635_01426dd3-c217-44d9-8647-6dde73e5b17e.sql =====

-- Family members table
CREATE TABLE public.family_members (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  relationship TEXT NOT NULL,
  gender TEXT,
  date_of_birth DATE,
  blood_group TEXT,
  allergies TEXT,
  chronic_conditions TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.family_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own family members" ON public.family_members
  FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Health reminders table
CREATE TABLE public.health_reminders (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  family_member_id UUID REFERENCES public.family_members(id) ON DELETE CASCADE,
  type TEXT NOT NULL DEFAULT 'medicine',
  title TEXT NOT NULL,
  description TEXT,
  reminder_date DATE NOT NULL,
  reminder_time TIME,
  recurrence TEXT DEFAULT 'none',
  is_completed BOOLEAN DEFAULT false,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.health_reminders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own reminders" ON public.health_reminders
  FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Add family_member_id to appointments for booking on behalf
ALTER TABLE public.appointments ADD COLUMN IF NOT EXISTS family_member_id UUID REFERENCES public.family_members(id) ON DELETE SET NULL;

-- ===== 20260306103850_82b0b77b-4f96-4475-81a7-90c756bd2bbc.sql =====

-- 1. Healthcare Packages table
CREATE TABLE public.healthcare_packages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_type TEXT NOT NULL DEFAULT 'hospital' CHECK (provider_type IN ('hospital', 'lab')),
  provider_id UUID NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  tests_included JSONB DEFAULT '[]',
  original_price NUMERIC NOT NULL DEFAULT 0,
  discounted_price NUMERIC,
  duration_days INTEGER DEFAULT 1,
  is_active BOOLEAN DEFAULT true,
  bookings_count INTEGER DEFAULT 0,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.healthcare_packages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public can view active packages" ON public.healthcare_packages
  FOR SELECT USING (is_active = true);
CREATE POLICY "Providers can manage own packages" ON public.healthcare_packages
  FOR ALL USING (
    (provider_type = 'hospital' AND provider_id IN (SELECT id FROM hospitals WHERE user_id = auth.uid()))
    OR (provider_type = 'lab' AND provider_id IN (SELECT id FROM labs WHERE user_id = auth.uid()))
  );

-- 2. Transactions table (consolidated ledger)
CREATE TABLE public.transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  provider_type TEXT,
  provider_id UUID,
  service_type TEXT NOT NULL,
  reference_id UUID,
  amount NUMERIC NOT NULL DEFAULT 0,
  platform_commission NUMERIC DEFAULT 0,
  provider_payout NUMERIC DEFAULT 0,
  payment_method TEXT DEFAULT 'online',
  payment_status TEXT DEFAULT 'pending',
  currency TEXT DEFAULT 'INR',
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users see own transactions" ON public.transactions
  FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Admins manage transactions" ON public.transactions
  FOR ALL USING (public.has_role(auth.uid(), 'admin'));

-- 3. Corporate Health Plans
CREATE TABLE public.corporate_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_name TEXT NOT NULL,
  contact_email TEXT,
  contact_phone TEXT,
  plan_type TEXT DEFAULT 'basic' CHECK (plan_type IN ('basic', 'premium', 'enterprise')),
  max_employees INTEGER DEFAULT 50,
  monthly_price NUMERIC NOT NULL DEFAULT 0,
  services_included JSONB DEFAULT '["consultations", "checkups", "emergency"]',
  is_active BOOLEAN DEFAULT true,
  start_date DATE,
  end_date DATE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.corporate_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins manage corporate plans" ON public.corporate_plans
  FOR ALL USING (public.has_role(auth.uid(), 'admin'));

-- 4. Featured flags for hospitals, labs, pharmacies
ALTER TABLE public.hospitals ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT false;
ALTER TABLE public.hospitals ADD COLUMN IF NOT EXISTS featured_sort_order INTEGER DEFAULT 0;
ALTER TABLE public.labs ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT false;
ALTER TABLE public.labs ADD COLUMN IF NOT EXISTS featured_sort_order INTEGER DEFAULT 0;
ALTER TABLE public.pharmacies ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT false;
ALTER TABLE public.pharmacies ADD COLUMN IF NOT EXISTS featured_sort_order INTEGER DEFAULT 0;

-- 5. Ad campaign tracking columns
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS clicks INTEGER DEFAULT 0;
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS impressions INTEGER DEFAULT 0;
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS start_date DATE;
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS end_date DATE;
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS budget NUMERIC DEFAULT 0;
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS advertiser_name TEXT;
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS advertiser_type TEXT;

-- 6. Video consultation fields on doctors
ALTER TABLE public.doctors ADD COLUMN IF NOT EXISTS video_consultation_enabled BOOLEAN DEFAULT false;
ALTER TABLE public.doctors ADD COLUMN IF NOT EXISTS video_consultation_fee NUMERIC DEFAULT 0;
ALTER TABLE public.doctors ADD COLUMN IF NOT EXISTS video_consultation_duration INTEGER DEFAULT 15;

-- 7. Video consultation type in appointments
ALTER TABLE public.appointments ADD COLUMN IF NOT EXISTS is_video_consultation BOOLEAN DEFAULT false;
ALTER TABLE public.appointments ADD COLUMN IF NOT EXISTS video_meeting_link TEXT;

-- 8. Package bookings table
CREATE TABLE public.package_bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  package_id UUID REFERENCES public.healthcare_packages(id) NOT NULL,
  user_id UUID NOT NULL,
  family_member_id UUID REFERENCES public.family_members(id),
  status TEXT DEFAULT 'booked' CHECK (status IN ('booked', 'in_progress', 'completed', 'cancelled')),
  payment_status TEXT DEFAULT 'pending',
  payment_method TEXT DEFAULT 'online',
  amount_paid NUMERIC DEFAULT 0,
  booking_date DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.package_bookings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users see own package bookings" ON public.package_bookings
  FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users can book packages" ON public.package_bookings
  FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Admins manage package bookings" ON public.package_bookings
  FOR ALL USING (public.has_role(auth.uid(), 'admin'));

-- 9. Transaction trigger for appointments
CREATE OR REPLACE FUNCTION public.log_appointment_transaction()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_commission_percent NUMERIC := 10;
  v_fee NUMERIC := 0;
  v_provider_type TEXT;
  v_provider_id UUID;
BEGIN
  IF NEW.status = 'completed' AND (OLD.status IS DISTINCT FROM 'completed') THEN
    IF NEW.doctor_id IS NOT NULL THEN
      v_provider_type := 'doctor';
      v_provider_id := NEW.doctor_id;
      SELECT consultation_fee INTO v_fee FROM doctors WHERE id = NEW.doctor_id;
    ELSIF NEW.lab_id IS NOT NULL THEN
      v_provider_type := 'lab';
      v_provider_id := NEW.lab_id;
    ELSIF NEW.hospital_id IS NOT NULL THEN
      v_provider_type := 'hospital';
      v_provider_id := NEW.hospital_id;
    ELSE
      RETURN NEW;
    END IF;

    v_fee := COALESCE(v_fee, 0);
    IF v_fee <= 0 THEN RETURN NEW; END IF;

    SELECT commission_percent INTO v_commission_percent
    FROM platform_commission_config
    WHERE provider_type = v_provider_type AND is_active = true
    LIMIT 1;
    v_commission_percent := COALESCE(v_commission_percent, 10);

    INSERT INTO transactions (user_id, provider_type, provider_id, service_type, reference_id, amount, platform_commission, provider_payout, payment_method, payment_status)
    VALUES (NEW.patient_id, v_provider_type, v_provider_id, NEW.service_type, NEW.id, v_fee, ROUND(v_fee * v_commission_percent / 100, 2), ROUND(v_fee * (100 - v_commission_percent) / 100, 2), NEW.payment_method, NEW.payment_status)
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_log_appointment_transaction
  AFTER UPDATE ON public.appointments
  FOR EACH ROW EXECUTE FUNCTION public.log_appointment_transaction();

-- 10. Increment package bookings count trigger
CREATE OR REPLACE FUNCTION public.increment_package_bookings()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  UPDATE healthcare_packages SET bookings_count = bookings_count + 1 WHERE id = NEW.package_id;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_increment_package_bookings
  AFTER INSERT ON public.package_bookings
  FOR EACH ROW EXECUTE FUNCTION public.increment_package_bookings();

-- ===== 20260306105310_3d89f172-69f7-4321-aa80-22bb8ea13bd6.sql =====

-- Provider payment accounts table
CREATE TABLE public.provider_payment_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_type TEXT NOT NULL CHECK (provider_type IN ('doctor', 'hospital', 'lab', 'pharmacy')),
  provider_id UUID NOT NULL,
  user_id UUID NOT NULL,
  payment_method TEXT NOT NULL DEFAULT 'upi' CHECK (payment_method IN ('upi', 'bank_account')),
  upi_id TEXT,
  account_holder_name TEXT,
  bank_account_number TEXT,
  ifsc_code TEXT,
  bank_name TEXT,
  approval_status TEXT NOT NULL DEFAULT 'pending' CHECK (approval_status IN ('pending', 'approved', 'rejected')),
  admin_notes TEXT,
  reviewed_by UUID,
  reviewed_at TIMESTAMPTZ,
  is_active BOOLEAN NOT NULL DEFAULT false,
  change_count INTEGER NOT NULL DEFAULT 0,
  last_change_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (provider_type, provider_id)
);

ALTER TABLE public.provider_payment_accounts ENABLE ROW LEVEL SECURITY;

-- Providers can read/update their own payment account
CREATE POLICY "Providers can view own payment account"
  ON public.provider_payment_accounts FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Providers can insert own payment account"
  ON public.provider_payment_accounts FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Providers can update own payment account"
  ON public.provider_payment_accounts FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid());

-- Admin can do everything via has_role
CREATE POLICY "Admins can manage all payment accounts"
  ON public.provider_payment_accounts FOR ALL
  TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));

-- Payment change request log
CREATE TABLE public.payment_change_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_account_id UUID REFERENCES public.provider_payment_accounts(id) ON DELETE CASCADE NOT NULL,
  provider_type TEXT NOT NULL,
  provider_id UUID NOT NULL,
  user_id UUID NOT NULL,
  old_details JSONB,
  new_details JSONB NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  admin_notes TEXT,
  reviewed_by UUID,
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.payment_change_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Providers view own change requests"
  ON public.payment_change_requests FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Providers insert own change requests"
  ON public.payment_change_requests FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Admins manage all change requests"
  ON public.payment_change_requests FOR ALL
  TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));

-- Add verification fields to transactions table
ALTER TABLE public.transactions
  ADD COLUMN IF NOT EXISTS payment_verification_status TEXT DEFAULT 'unverified' CHECK (payment_verification_status IN ('verified', 'unverified', 'failed')),
  ADD COLUMN IF NOT EXISTS payment_gateway_response JSONB,
  ADD COLUMN IF NOT EXISTS transaction_timestamp TIMESTAMPTZ DEFAULT now();

-- Trigger to update updated_at
CREATE TRIGGER update_provider_payment_accounts_updated_at
  BEFORE UPDATE ON public.provider_payment_accounts
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ===== 20260306112056_f82a818c-5894-47f2-98af-791e2ddf424d.sql =====

-- Platform branding table for admin-managed theme customization
CREATE TABLE public.platform_branding (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT UNIQUE NOT NULL,
  value TEXT NOT NULL DEFAULT '',
  label TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'logos',
  type TEXT NOT NULL DEFAULT 'text',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by UUID REFERENCES auth.users(id)
);

ALTER TABLE public.platform_branding ENABLE ROW LEVEL SECURITY;

-- Anyone can read branding (needed to apply theme across all panels)
CREATE POLICY "Anyone can read branding" ON public.platform_branding FOR SELECT USING (true);

-- Only authenticated admins can update
CREATE POLICY "Admins can update branding" ON public.platform_branding FOR UPDATE TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can insert branding" ON public.platform_branding FOR INSERT TO authenticated
  WITH CHECK (public.has_role(auth.uid(), 'admin'));

-- Trigger for updated_at
CREATE TRIGGER update_platform_branding_updated_at
  BEFORE UPDATE ON public.platform_branding
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Seed default branding values
INSERT INTO public.platform_branding (key, value, label, category, type) VALUES
  -- Logos
  ('logo_main', '', 'Main App Logo', 'logos', 'image'),
  ('logo_splash', '', 'Splash Screen Logo', 'logos', 'image'),
  ('logo_header', '', 'Header Logo', 'logos', 'image'),
  ('logo_footer', '', 'Footer Logo', 'logos', 'image'),
  ('favicon', '', 'Favicon', 'logos', 'image'),
  -- Colors
  ('color_primary_h', '24', 'Primary Hue', 'colors', 'number'),
  ('color_primary_s', '85', 'Primary Saturation', 'colors', 'number'),
  ('color_primary_l', '50', 'Primary Lightness', 'colors', 'number'),
  ('color_secondary_h', '30', 'Secondary Hue', 'colors', 'number'),
  ('color_secondary_s', '20', 'Secondary Saturation', 'colors', 'number'),
  ('color_secondary_l', '95', 'Secondary Lightness', 'colors', 'number'),
  ('color_background_h', '30', 'Background Hue', 'colors', 'number'),
  ('color_background_s', '15', 'Background Saturation', 'colors', 'number'),
  ('color_background_l', '97', 'Background Lightness', 'colors', 'number'),
  ('color_foreground_h', '20', 'Foreground Hue', 'colors', 'number'),
  ('color_foreground_s', '25', 'Foreground Saturation', 'colors', 'number'),
  ('color_foreground_l', '10', 'Foreground Lightness', 'colors', 'number'),
  -- Graphics
  ('graphic_onboarding_1', '', 'Onboarding Slide 1', 'graphics', 'image'),
  ('graphic_onboarding_2', '', 'Onboarding Slide 2', 'graphics', 'image'),
  ('graphic_onboarding_3', '', 'Onboarding Slide 3', 'graphics', 'image'),
  ('graphic_empty_state', '', 'Empty State Illustration', 'graphics', 'image'),
  ('graphic_error_page', '', 'Error Page Illustration', 'graphics', 'image');

-- Storage bucket for branding assets
INSERT INTO storage.buckets (id, name, public) VALUES ('branding', 'branding', true);

-- Storage policies for branding bucket
CREATE POLICY "Anyone can view branding assets" ON storage.objects FOR SELECT USING (bucket_id = 'branding');
CREATE POLICY "Admins can upload branding assets" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'branding' AND public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins can update branding assets" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'branding' AND public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins can delete branding assets" ON storage.objects FOR DELETE TO authenticated USING (bucket_id = 'branding' AND public.has_role(auth.uid(), 'admin'));

-- ===== 20260306125223_e6a4d10f-8f36-47b6-9c26-d87dc09d751c.sql =====
ALTER TABLE public.admin_team ADD COLUMN IF NOT EXISTS avatar_url TEXT;
-- ===== 20260306130431_d8d6fe03-12e6-4b89-beb3-3d9d73491d69.sql =====

CREATE TABLE public.platform_api_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key_name TEXT NOT NULL UNIQUE,
  key_value TEXT NOT NULL DEFAULT '',
  display_label TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'general',
  is_masked BOOLEAN NOT NULL DEFAULT true,
  last_changed_at TIMESTAMPTZ,
  changed_by UUID,
  cooldown_minutes INTEGER NOT NULL DEFAULT 30,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.platform_api_keys ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage api keys"
ON public.platform_api_keys
FOR ALL
TO authenticated
USING (public.has_role(auth.uid(), 'admin'))
WITH CHECK (public.has_role(auth.uid(), 'admin'));

INSERT INTO public.platform_api_keys (key_name, display_label, category, cooldown_minutes) VALUES
  ('RAZORPAY_KEY_ID', 'Razorpay Key ID', 'payment', 30),
  ('RAZORPAY_KEY_SECRET', 'Razorpay Key Secret', 'payment', 60),
  ('MSG91_AUTH_KEY', 'MSG91 Auth Key', 'messaging', 30),
  ('WHATSAPP_ACCESS_TOKEN', 'WhatsApp Access Token', 'messaging', 30),
  ('WHATSAPP_PHONE_NUMBER_ID', 'WhatsApp Phone Number ID', 'messaging', 30),
  ('TWILIO_ACCOUNT_SID', 'Twilio Account SID', 'messaging', 30),
  ('TWILIO_AUTH_TOKEN', 'Twilio Auth Token', 'messaging', 60),
  ('TWILIO_PHONE_NUMBER', 'Twilio Phone Number', 'messaging', 15),
  ('TWILIO_WHATSAPP_NUMBER', 'Twilio WhatsApp Number', 'messaging', 15),
  ('GOOGLE_MAPS_API_KEY', 'Google Maps API Key', 'maps', 30);

-- ===== 20260307041030_54db7363-4662-4ae2-b6c6-945cc2780ad8.sql =====

CREATE TABLE public.support_ticket_messages (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  ticket_id UUID NOT NULL REFERENCES public.support_tickets(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL,
  sender_role TEXT NOT NULL DEFAULT 'user',
  message TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.support_ticket_messages ENABLE ROW LEVEL SECURITY;

-- Users can read messages on their own tickets
CREATE POLICY "Users can read own ticket messages"
  ON public.support_ticket_messages FOR SELECT
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.support_tickets st WHERE st.id = ticket_id AND st.user_id = auth.uid())
    OR public.has_role(auth.uid(), 'admin')
  );

-- Users can insert messages on their own open tickets
CREATE POLICY "Users can send messages on own tickets"
  ON public.support_ticket_messages FOR INSERT
  TO authenticated
  WITH CHECK (
    sender_id = auth.uid() AND (
      EXISTS (SELECT 1 FROM public.support_tickets st WHERE st.id = ticket_id AND st.user_id = auth.uid() AND st.status IN ('open', 'in_progress'))
      OR public.has_role(auth.uid(), 'admin')
    )
  );

-- Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.support_ticket_messages;

-- ===== 20260307041739_ca4974d5-5eb2-473c-80da-b289a9c61983.sql =====
ALTER TABLE public.support_tickets ADD COLUMN sender_type TEXT NOT NULL DEFAULT 'patient';
-- ===== 20260307051415_cf03f517-b912-47f7-aa52-16bcbeab653f.sql =====

-- Add auto-increment ticket_number to support_tickets
ALTER TABLE public.support_tickets ADD COLUMN ticket_number SERIAL;

-- Create unique index on ticket_number
CREATE UNIQUE INDEX idx_support_tickets_ticket_number ON public.support_tickets(ticket_number);

-- ===== 20260307053741_a958e42e-0550-4a62-85cb-f4e78fa90d49.sql =====
ALTER TABLE public.support_ticket_messages ADD COLUMN IF NOT EXISTS is_read BOOLEAN NOT NULL DEFAULT false;
-- ===== 20260307070140_6996e2a4-4bb8-4d7c-9e1e-e2f114e8aecc.sql =====
INSERT INTO storage.buckets (id, name, public) VALUES ('medicine-images', 'medicine-images', true) ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Public read medicine images" ON storage.objects FOR SELECT TO public USING (bucket_id = 'medicine-images');
CREATE POLICY "Admin upload medicine images" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'medicine-images');
CREATE POLICY "Admin update medicine images" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'medicine-images');

-- ===== 20260307070346_d441e070-c380-4880-a53f-12bd5c523513.sql =====
UPDATE medicines SET image_url = 'https://zjlznbgcfzpcveqyjglf.supabase.co/storage/v1/object/public/medicine-images/antibiotics.png' WHERE category = 'Antibiotics' AND image_url IS NULL;
UPDATE medicines SET image_url = 'https://zjlznbgcfzpcveqyjglf.supabase.co/storage/v1/object/public/medicine-images/pain-relief.png' WHERE category = 'Pain Relief' AND image_url IS NULL;
UPDATE medicines SET image_url = 'https://zjlznbgcfzpcveqyjglf.supabase.co/storage/v1/object/public/medicine-images/cardiac.png' WHERE category IN ('Cardiac', 'Cardiology') AND image_url IS NULL;
UPDATE medicines SET image_url = 'https://zjlznbgcfzpcveqyjglf.supabase.co/storage/v1/object/public/medicine-images/vitamins.png' WHERE category = 'Vitamins' AND image_url IS NULL;
UPDATE medicines SET image_url = 'https://zjlznbgcfzpcveqyjglf.supabase.co/storage/v1/object/public/medicine-images/diabetes.png' WHERE category = 'Diabetes' AND image_url IS NULL;
UPDATE medicines SET image_url = 'https://zjlznbgcfzpcveqyjglf.supabase.co/storage/v1/object/public/medicine-images/respiratory.png' WHERE category = 'Respiratory' AND image_url IS NULL;
UPDATE medicines SET image_url = 'https://zjlznbgcfzpcveqyjglf.supabase.co/storage/v1/object/public/medicine-images/allergy.png' WHERE category = 'Allergy' AND image_url IS NULL;
UPDATE medicines SET image_url = 'https://zjlznbgcfzpcveqyjglf.supabase.co/storage/v1/object/public/medicine-images/gastro.png' WHERE category = 'Gastro' AND image_url IS NULL;
UPDATE medicines SET image_url = 'https://zjlznbgcfzpcveqyjglf.supabase.co/storage/v1/object/public/medicine-images/first-aid.png' WHERE category = 'First Aid' AND image_url IS NULL;
UPDATE medicines SET image_url = 'https://zjlznbgcfzpcveqyjglf.supabase.co/storage/v1/object/public/medicine-images/ayurvedic.png' WHERE category = 'Ayurvedic' AND image_url IS NULL;
UPDATE medicines SET image_url = 'https://zjlznbgcfzpcveqyjglf.supabase.co/storage/v1/object/public/medicine-images/supplements.png' WHERE category = 'Supplements' AND image_url IS NULL;
UPDATE medicines SET image_url = 'https://zjlznbgcfzpcveqyjglf.supabase.co/storage/v1/object/public/medicine-images/cold-cough.png' WHERE category IN ('Cold & Cough', 'Cold & Flu') AND image_url IS NULL;
UPDATE medicines SET image_url = 'https://zjlznbgcfzpcveqyjglf.supabase.co/storage/v1/object/public/medicine-images/antifungal.png' WHERE category = 'Antifungal' AND image_url IS NULL;
UPDATE medicines SET image_url = 'https://zjlznbgcfzpcveqyjglf.supabase.co/storage/v1/object/public/medicine-images/thyroid.png' WHERE category = 'Thyroid' AND image_url IS NULL;
UPDATE medicines SET image_url = 'https://zjlznbgcfzpcveqyjglf.supabase.co/storage/v1/object/public/medicine-images/steroids.png' WHERE category = 'Steroids' AND image_url IS NULL;
UPDATE medicines SET image_url = 'https://zjlznbgcfzpcveqyjglf.supabase.co/storage/v1/object/public/medicine-images/antiseptic.png' WHERE category = 'Antiseptic' AND image_url IS NULL;
UPDATE medicines SET image_url = 'https://zjlznbgcfzpcveqyjglf.supabase.co/storage/v1/object/public/medicine-images/rehydration.png' WHERE category = 'Rehydration' AND image_url IS NULL;
UPDATE medicines SET image_url = 'https://zjlznbgcfzpcveqyjglf.supabase.co/storage/v1/object/public/medicine-images/health-wellness.png' WHERE category = 'Health & Wellness' AND image_url IS NULL;
UPDATE medicines SET image_url = 'https://zjlznbgcfzpcveqyjglf.supabase.co/storage/v1/object/public/medicine-images/general.png' WHERE category = 'General' AND image_url IS NULL;
UPDATE medicines SET image_url = 'https://zjlznbgcfzpcveqyjglf.supabase.co/storage/v1/object/public/medicine-images/personal-care.png' WHERE category = 'Personal Care' AND image_url IS NULL;
UPDATE medicines SET image_url = 'https://zjlznbgcfzpcveqyjglf.supabase.co/storage/v1/object/public/medicine-images/anti-inflammatory.png' WHERE category = 'Anti-inflammatory' AND image_url IS NULL;
UPDATE medicines SET image_url = 'https://zjlznbgcfzpcveqyjglf.supabase.co/storage/v1/object/public/medicine-images/devices.png' WHERE category = 'Devices' AND image_url IS NULL;
UPDATE medicines SET image_url = 'https://zjlznbgcfzpcveqyjglf.supabase.co/storage/v1/object/public/medicine-images/digestive.png' WHERE category = 'Digestive' AND image_url IS NULL;
UPDATE medicines SET image_url = 'https://zjlznbgcfzpcveqyjglf.supabase.co/storage/v1/object/public/medicine-images/anti-nausea.png' WHERE category = 'Anti-nausea' AND image_url IS NULL;

-- ===== 20260313085748_31ae4b94-b30f-4e7f-a2dd-1b855425f5e1.sql =====

-- Add Authentication & Session settings
INSERT INTO platform_settings (key, value, label, category, type) VALUES
  ('single_session_enabled', 'false', 'Enforce Single Session Login', 'authentication', 'toggle'),
  ('session_timeout_minutes', '1440', 'Session Timeout (minutes)', 'authentication', 'number'),
  ('force_logout_on_password_change', 'true', 'Force Logout on Password Change', 'authentication', 'toggle'),
  ('max_login_attempts', '5', 'Max Login Attempts Before Lockout', 'authentication', 'number'),
  ('lockout_duration_minutes', '30', 'Lockout Duration (minutes)', 'authentication', 'number'),
  ('provider_email_verification', 'true', 'Require Email Verification for Providers', 'registration', 'toggle'),
  ('provider_auto_approval', 'false', 'Auto-Approve Provider Registrations', 'registration', 'toggle'),
  ('allow_doctor_registration', 'true', 'Allow Doctor Registration', 'registration', 'toggle'),
  ('allow_hospital_registration', 'true', 'Allow Hospital Registration', 'registration', 'toggle'),
  ('allow_lab_registration', 'true', 'Allow Lab Registration', 'registration', 'toggle'),
  ('allow_pharmacy_registration', 'true', 'Allow Pharmacy Registration', 'registration', 'toggle'),
  ('patient_signup_enabled', 'true', 'Allow Patient Signup', 'registration', 'toggle')
ON CONFLICT (key) DO NOTHING;

-- Create active_sessions table for session management
CREATE TABLE IF NOT EXISTS public.active_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  session_token text NOT NULL,
  device_info text,
  ip_address text,
  last_active_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  is_active boolean NOT NULL DEFAULT true
);

ALTER TABLE public.active_sessions ENABLE ROW LEVEL SECURITY;

-- Admins can view all sessions
CREATE POLICY "Admins can manage sessions" ON public.active_sessions
  FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));

-- Users can view their own sessions
CREATE POLICY "Users can view own sessions" ON public.active_sessions
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

