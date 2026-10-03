-- chunk 1
-- ===== 20260227173137_88fd199c-71e9-4375-9632-072f12d639af.sql =====

-- Create profiles table
CREATE TABLE public.profiles (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  email TEXT,
  phone TEXT,
  avatar_url TEXT,
  language TEXT DEFAULT 'en',
  dark_mode BOOLEAN DEFAULT false,
  notification_preferences JSONB DEFAULT '{"email": true, "push": true}'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- RLS policies
CREATE POLICY "Users can view their own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own profile"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Auto-create profile on signup trigger
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (user_id, full_name, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data ->> 'full_name', ''),
    NEW.email
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Updated_at trigger
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ===== 20260227174926_8918f32a-2c99-4115-bd08-25335841eead.sql =====

-- Hospitals table
CREATE TABLE public.hospitals (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  location TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  beds INTEGER DEFAULT 0,
  icu_available BOOLEAN DEFAULT false,
  working_hours JSONB DEFAULT '{"mon-fri": "08:00-20:00", "sat": "09:00-14:00", "sun": "closed"}'::jsonb,
  holidays TEXT[],
  phone TEXT,
  image_url TEXT,
  rating NUMERIC(2,1) DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.hospitals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Hospitals are viewable by everyone" ON public.hospitals FOR SELECT USING (true);

-- Doctors table
CREATE TABLE public.doctors (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  specialization TEXT,
  rating NUMERIC(2,1) DEFAULT 0,
  hospital_id UUID REFERENCES public.hospitals(id) ON DELETE SET NULL,
  working_hours JSONB DEFAULT '{"mon-fri": "09:00-17:00"}'::jsonb,
  vacation_dates TEXT[],
  phone TEXT,
  image_url TEXT,
  bio TEXT,
  consultation_fee NUMERIC(10,2) DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.doctors ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Doctors are viewable by everyone" ON public.doctors FOR SELECT USING (true);

-- Labs table
CREATE TABLE public.labs (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  services TEXT[],
  working_hours JSONB DEFAULT '{"mon-fri": "07:00-18:00", "sat": "08:00-13:00"}'::jsonb,
  phone TEXT,
  location TEXT,
  image_url TEXT,
  rating NUMERIC(2,1) DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.labs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Labs are viewable by everyone" ON public.labs FOR SELECT USING (true);

-- Pharmacies table
CREATE TABLE public.pharmacies (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  inventory JSONB DEFAULT '[]'::jsonb,
  working_hours JSONB DEFAULT '{"mon-sat": "08:00-22:00", "sun": "09:00-18:00"}'::jsonb,
  phone TEXT,
  location TEXT,
  image_url TEXT,
  rating NUMERIC(2,1) DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.pharmacies ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Pharmacies are viewable by everyone" ON public.pharmacies FOR SELECT USING (true);

-- Appointments table
CREATE TABLE public.appointments (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  patient_id UUID NOT NULL,
  doctor_id UUID REFERENCES public.doctors(id) ON DELETE SET NULL,
  hospital_id UUID REFERENCES public.hospitals(id) ON DELETE SET NULL,
  lab_id UUID REFERENCES public.labs(id) ON DELETE SET NULL,
  pharmacy_id UUID REFERENCES public.pharmacies(id) ON DELETE SET NULL,
  service_type TEXT NOT NULL CHECK (service_type IN ('doctor', 'hospital', 'lab', 'pharmacy')),
  appointment_date DATE NOT NULL,
  appointment_time TIME NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'completed', 'cancelled')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own appointments" ON public.appointments FOR SELECT USING (auth.uid() = patient_id);
CREATE POLICY "Users can create own appointments" ON public.appointments FOR INSERT WITH CHECK (auth.uid() = patient_id);
CREATE POLICY "Users can update own appointments" ON public.appointments FOR UPDATE USING (auth.uid() = patient_id);
CREATE POLICY "Users can delete own appointments" ON public.appointments FOR DELETE USING (auth.uid() = patient_id);

CREATE TRIGGER update_appointments_updated_at BEFORE UPDATE ON public.appointments
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Favorites table
CREATE TABLE public.favorites (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  provider_type TEXT NOT NULL CHECK (provider_type IN ('doctor', 'hospital', 'lab', 'pharmacy')),
  provider_id UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, provider_type, provider_id)
);
ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own favorites" ON public.favorites FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can add favorites" ON public.favorites FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can remove favorites" ON public.favorites FOR DELETE USING (auth.uid() = user_id);

-- Slider media table
CREATE TABLE public.slider_media (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  type TEXT NOT NULL DEFAULT 'image' CHECK (type IN ('image', 'video')),
  url TEXT NOT NULL,
  target_link TEXT,
  title TEXT,
  description TEXT,
  sort_order INTEGER DEFAULT 0,
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.slider_media ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Slider media viewable by everyone" ON public.slider_media FOR SELECT USING (true);

-- Ads table
CREATE TABLE public.ads (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  type TEXT NOT NULL DEFAULT 'banner' CHECK (type IN ('banner', 'interstitial')),
  content_url TEXT NOT NULL,
  target_link TEXT,
  placement TEXT,
  title TEXT,
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.ads ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Ads viewable by everyone" ON public.ads FOR SELECT USING (true);

-- ===== 20260228050206_4b630fc2-6d78-4d2b-936e-dfc75fc9534e.sql =====

-- Medicines catalog linked to pharmacies
CREATE TABLE public.medicines (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  pharmacy_id UUID NOT NULL REFERENCES public.pharmacies(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  generic_name TEXT,
  category TEXT NOT NULL DEFAULT 'General',
  description TEXT,
  price NUMERIC NOT NULL DEFAULT 0,
  discount_percent NUMERIC DEFAULT 0,
  image_url TEXT,
  requires_prescription BOOLEAN DEFAULT false,
  in_stock BOOLEAN DEFAULT true,
  stock_quantity INTEGER DEFAULT 0,
  unit TEXT DEFAULT 'strip',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.medicines ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Medicines viewable by everyone"
  ON public.medicines FOR SELECT USING (true);

CREATE INDEX idx_medicines_pharmacy ON public.medicines(pharmacy_id);
CREATE INDEX idx_medicines_category ON public.medicines(category);
CREATE INDEX idx_medicines_name ON public.medicines USING gin(to_tsvector('english', name));

-- Orders table
CREATE TABLE public.orders (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  pharmacy_id UUID NOT NULL REFERENCES public.pharmacies(id),
  status TEXT NOT NULL DEFAULT 'placed',
  payment_method TEXT NOT NULL DEFAULT 'cod',
  payment_status TEXT NOT NULL DEFAULT 'pending',
  stripe_payment_id TEXT,
  subtotal NUMERIC NOT NULL DEFAULT 0,
  delivery_fee NUMERIC NOT NULL DEFAULT 0,
  total NUMERIC NOT NULL DEFAULT 0,
  delivery_address TEXT,
  notes TEXT,
  prescription_url TEXT,
  estimated_delivery TEXT,
  placed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  confirmed_at TIMESTAMPTZ,
  out_for_delivery_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own orders"
  ON public.orders FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can create own orders"
  ON public.orders FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own orders"
  ON public.orders FOR UPDATE USING (auth.uid() = user_id);

-- Order items
CREATE TABLE public.order_items (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  medicine_id UUID NOT NULL REFERENCES public.medicines(id),
  medicine_name TEXT NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 1,
  unit_price NUMERIC NOT NULL DEFAULT 0,
  total_price NUMERIC NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own order items"
  ON public.order_items FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.orders WHERE orders.id = order_items.order_id AND orders.user_id = auth.uid()));
CREATE POLICY "Users can create own order items"
  ON public.order_items FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM public.orders WHERE orders.id = order_items.order_id AND orders.user_id = auth.uid()));

-- Prescription storage bucket
INSERT INTO storage.buckets (id, name, public) VALUES ('prescriptions', 'prescriptions', false);

CREATE POLICY "Users can upload prescriptions"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'prescriptions' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can view own prescriptions"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'prescriptions' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Trigger for updated_at on orders
CREATE TRIGGER update_orders_updated_at
  BEFORE UPDATE ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Enable realtime for orders (for live tracking)
ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;

-- ===== 20260228063602_0ca11a5b-2b08-4870-be27-5901b1a19ba9.sql =====

-- Create payments/wallet table
CREATE TABLE public.payments (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  type TEXT NOT NULL DEFAULT 'payment',
  amount NUMERIC NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'completed',
  description TEXT,
  category TEXT DEFAULT 'general',
  reference_id UUID,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own payments" ON public.payments FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can create own payments" ON public.payments FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Create emergency_requests table
CREATE TABLE public.emergency_requests (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  patient_id UUID NOT NULL,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  status TEXT NOT NULL DEFAULT 'pending',
  assigned_ambulance_id UUID,
  response_time_minutes NUMERIC,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

ALTER TABLE public.emergency_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own emergency requests" ON public.emergency_requests FOR SELECT USING (auth.uid() = patient_id);
CREATE POLICY "Users can create own emergency requests" ON public.emergency_requests FOR INSERT WITH CHECK (auth.uid() = patient_id);
CREATE POLICY "Users can update own emergency requests" ON public.emergency_requests FOR UPDATE USING (auth.uid() = patient_id);

-- Create ambulances table
CREATE TABLE public.ambulances (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  vehicle_number TEXT NOT NULL,
  driver_name TEXT,
  driver_phone TEXT,
  current_latitude DOUBLE PRECISION,
  current_longitude DOUBLE PRECISION,
  status TEXT NOT NULL DEFAULT 'available',
  assigned_patient_id UUID,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

ALTER TABLE public.ambulances ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Ambulances viewable by everyone" ON public.ambulances FOR SELECT USING (true);

-- Enable realtime for ambulances (for tracking)
ALTER PUBLICATION supabase_realtime ADD TABLE public.ambulances;
ALTER PUBLICATION supabase_realtime ADD TABLE public.emergency_requests;

-- Add trigger for updated_at
CREATE TRIGGER update_emergency_requests_updated_at BEFORE UPDATE ON public.emergency_requests FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_ambulances_updated_at BEFORE UPDATE ON public.ambulances FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ===== 20260228073651_e0a02dac-3b50-413d-8839-5c0296bcc36e.sql =====

-- Create role enum
CREATE TYPE public.app_role AS ENUM ('admin', 'moderator', 'user');

-- Create user_roles table
CREATE TABLE public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  role app_role NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE (user_id, role)
);

-- Enable RLS
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- Security definer function to check roles
CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role app_role)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id AND role = _role
  )
$$;

-- RLS: admins can view all roles
CREATE POLICY "Admins can view all roles"
ON public.user_roles FOR SELECT
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- RLS: admins can manage roles
CREATE POLICY "Admins can insert roles"
ON public.user_roles FOR INSERT
TO authenticated
WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can delete roles"
ON public.user_roles FOR DELETE
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- Admin policies for doctors table
CREATE POLICY "Admins can insert doctors"
ON public.doctors FOR INSERT
TO authenticated
WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can update doctors"
ON public.doctors FOR UPDATE
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can delete doctors"
ON public.doctors FOR DELETE
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- Admin policies for hospitals table
CREATE POLICY "Admins can insert hospitals"
ON public.hospitals FOR INSERT
TO authenticated
WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can update hospitals"
ON public.hospitals FOR UPDATE
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can delete hospitals"
ON public.hospitals FOR DELETE
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- Admin policies for labs table
CREATE POLICY "Admins can insert labs"
ON public.labs FOR INSERT
TO authenticated
WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can update labs"
ON public.labs FOR UPDATE
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can delete labs"
ON public.labs FOR DELETE
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- Admin policies for pharmacies table
CREATE POLICY "Admins can insert pharmacies"
ON public.pharmacies FOR INSERT
TO authenticated
WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can update pharmacies"
ON public.pharmacies FOR UPDATE
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can delete pharmacies"
ON public.pharmacies FOR DELETE
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- Admin policies for medicines table
CREATE POLICY "Admins can insert medicines"
ON public.medicines FOR INSERT
TO authenticated
WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can update medicines"
ON public.medicines FOR UPDATE
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can delete medicines"
ON public.medicines FOR DELETE
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- Admin policies for slider_media table
CREATE POLICY "Admins can insert slider_media"
ON public.slider_media FOR INSERT
TO authenticated
WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can update slider_media"
ON public.slider_media FOR UPDATE
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can delete slider_media"
ON public.slider_media FOR DELETE
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- Admin policies for ads table
CREATE POLICY "Admins can insert ads"
ON public.ads FOR INSERT
TO authenticated
WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can update ads"
ON public.ads FOR UPDATE
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can delete ads"
ON public.ads FOR DELETE
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- Admin can view all appointments
CREATE POLICY "Admins can view all appointments"
ON public.appointments FOR SELECT
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- Admin can update all appointments
CREATE POLICY "Admins can update all appointments"
ON public.appointments FOR UPDATE
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- Admin can view all orders
CREATE POLICY "Admins can view all orders"
ON public.orders FOR SELECT
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- Admin can update all orders
CREATE POLICY "Admins can update all orders"
ON public.orders FOR UPDATE
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- Admin can view all order items
CREATE POLICY "Admins can view all order items"
ON public.order_items FOR SELECT
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- Admin can view all profiles
CREATE POLICY "Admins can view all profiles"
ON public.profiles FOR SELECT
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- Admin can view all payments
CREATE POLICY "Admins can view all payments"
ON public.payments FOR SELECT
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- Admin can view all emergency requests
CREATE POLICY "Admins can view all emergency requests"
ON public.emergency_requests FOR SELECT
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- Admin can view all favorites
CREATE POLICY "Admins can view all favorites"
ON public.favorites FOR SELECT
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- ===== 20260228113910_e338488e-7c22-43e9-ac90-e5e801a743a1.sql =====

-- Create notifications table
CREATE TABLE public.notifications (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  type TEXT NOT NULL DEFAULT 'system',
  title TEXT NOT NULL,
  message TEXT,
  path TEXT,
  read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own notifications"
  ON public.notifications FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own notifications"
  ON public.notifications FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own notifications"
  ON public.notifications FOR DELETE
  USING (auth.uid() = user_id);

CREATE POLICY "System can insert notifications"
  ON public.notifications FOR INSERT
  WITH CHECK (true);

CREATE INDEX idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX idx_notifications_read ON public.notifications(user_id, read);

-- Create push_subscriptions table
CREATE TABLE public.push_subscriptions (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  endpoint TEXT NOT NULL,
  p256dh TEXT NOT NULL,
  auth TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(user_id, endpoint)
);

ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own subscriptions"
  ON public.push_subscriptions FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Enable realtime for notifications
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

-- Trigger function: create notification on appointment status change
CREATE OR REPLACE FUNCTION public.notify_appointment_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status) THEN
    INSERT INTO public.notifications (user_id, type, title, message, path)
    VALUES (
      NEW.patient_id,
      'appointment',
      CASE
        WHEN NEW.status = 'confirmed' THEN 'Appointment Confirmed ✅'
        WHEN NEW.status = 'cancelled' THEN 'Appointment Cancelled ❌'
        WHEN NEW.status = 'completed' THEN 'Appointment Completed 🎉'
        ELSE 'Appointment Update 📋'
      END,
      'Your ' || NEW.service_type || ' appointment on ' || NEW.appointment_date || ' at ' || NEW.appointment_time || ' is now ' || NEW.status || '.',
      '/appointments'
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_appointment_change
  AFTER INSERT OR UPDATE ON public.appointments
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_appointment_change();

-- Trigger function: create notification on order status change
CREATE OR REPLACE FUNCTION public.notify_order_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status) THEN
    INSERT INTO public.notifications (user_id, type, title, message, path)
    VALUES (
      NEW.user_id,
      'order',
      CASE
        WHEN NEW.status = 'confirmed' THEN 'Order Confirmed ✅'
        WHEN NEW.status = 'out_for_delivery' THEN 'Order Out for Delivery 🚚'
        WHEN NEW.status = 'delivered' THEN 'Order Delivered 📦'
        WHEN NEW.status = 'cancelled' THEN 'Order Cancelled ❌'
        ELSE 'Order Update 🛒'
      END,
      'Your order (₹' || NEW.total || ') is now ' || NEW.status || '.',
      '/order/' || NEW.id
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_order_change
  AFTER INSERT OR UPDATE ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_order_change();

-- ===== 20260228113935_61a7e039-577e-493c-a692-58efe2febbdc.sql =====

-- Drop the overly permissive insert policy and replace with admin + service-role only
DROP POLICY "System can insert notifications" ON public.notifications;

-- Only allow inserts via service role (triggers use SECURITY DEFINER which bypasses RLS)
-- Users should not be able to insert notifications directly
CREATE POLICY "Admins can insert notifications"
  ON public.notifications FOR INSERT
  WITH CHECK (has_role(auth.uid(), 'admin'));

-- ===== 20260228140639_30fe63e0-3d55-4532-9c35-2cd14ad1706f.sql =====

-- Create avatars storage bucket (public so images are accessible)
INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true);

-- Allow anyone to view avatars
CREATE POLICY "Avatar images are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

-- Users can upload their own avatar (folder = user_id)
CREATE POLICY "Users can upload their own avatar"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Users can update their own avatar
CREATE POLICY "Users can update their own avatar"
ON storage.objects FOR UPDATE
USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Users can delete their own avatar
CREATE POLICY "Users can delete their own avatar"
ON storage.objects FOR DELETE
USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- ===== 20260228163922_18db1c0f-3985-4448-a9eb-38985cadb9f6.sql =====

-- Fix labs RLS: drop restrictive policy and create permissive one
DROP POLICY IF EXISTS "Labs are viewable by everyone" ON public.labs;
CREATE POLICY "Labs are viewable by everyone" ON public.labs FOR SELECT USING (true);

-- Fix hospitals RLS
DROP POLICY IF EXISTS "Hospitals are viewable by everyone" ON public.hospitals;
CREATE POLICY "Hospitals are viewable by everyone" ON public.hospitals FOR SELECT USING (true);

-- Fix doctors RLS
DROP POLICY IF EXISTS "Doctors are viewable by everyone" ON public.doctors;
CREATE POLICY "Doctors are viewable by everyone" ON public.doctors FOR SELECT USING (true);

-- Fix pharmacies RLS
DROP POLICY IF EXISTS "Pharmacies are viewable by everyone" ON public.pharmacies;
CREATE POLICY "Pharmacies are viewable by everyone" ON public.pharmacies FOR SELECT USING (true);

-- Fix medicines RLS
DROP POLICY IF EXISTS "Medicines viewable by everyone" ON public.medicines;
CREATE POLICY "Medicines viewable by everyone" ON public.medicines FOR SELECT USING (true);

-- Fix ads RLS
DROP POLICY IF EXISTS "Ads viewable by everyone" ON public.ads;
CREATE POLICY "Ads viewable by everyone" ON public.ads FOR SELECT USING (true);

-- Fix slider_media RLS
DROP POLICY IF EXISTS "Slider media viewable by everyone" ON public.slider_media;
CREATE POLICY "Slider media viewable by everyone" ON public.slider_media FOR SELECT USING (true);

-- Fix ambulances RLS
DROP POLICY IF EXISTS "Ambulances viewable by everyone" ON public.ambulances;
CREATE POLICY "Ambulances viewable by everyone" ON public.ambulances FOR SELECT USING (true);

-- ===== 20260228172819_f1a49cee-9d62-4b54-89db-b43529c39de6.sql =====

-- Create a trigger function to send push notification on appointment confirmation
CREATE OR REPLACE FUNCTION public.push_notify_appointment_confirmed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  provider_name TEXT;
  function_url TEXT;
  service_role_key TEXT;
BEGIN
  -- Only fire when status changes to 'confirmed'
  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'confirmed' THEN
    -- Resolve provider name
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

    -- Call the edge function
    function_url := rtrim(current_setting('app.settings.supabase_url', true), '/') || '/functions/v1/send-push-notification';
    service_role_key := current_setting('app.settings.service_role_key', true);

    -- Use pg_net for async HTTP call if available, otherwise use net.http_post
    PERFORM net.http_post(
      url := function_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || service_role_key
      ),
      body := jsonb_build_object(
        'user_id', NEW.patient_id,
        'title', 'Appointment Confirmed ✅',
        'message', 'Your ' || NEW.service_type || ' appointment with ' || provider_name || ' on ' || NEW.appointment_date || ' at ' || NEW.appointment_time || ' has been confirmed.',
        'path', '/appointments'
      )
    );
  END IF;
  RETURN NEW;
END;
$$;

-- Create the trigger
CREATE TRIGGER trigger_push_notify_appointment_confirmed
AFTER UPDATE ON public.appointments
FOR EACH ROW
EXECUTE FUNCTION public.push_notify_appointment_confirmed();

-- ===== 20260228173219_732306de-839e-4f67-b52c-f734f7912624.sql =====

CREATE OR REPLACE FUNCTION public.push_notify_order_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  function_url TEXT;
  service_role_key TEXT;
  notif_title TEXT;
  notif_message TEXT;
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status AND NEW.status IN ('confirmed', 'out_for_delivery', 'delivered') THEN
    notif_title := CASE NEW.status
      WHEN 'confirmed' THEN 'Order Confirmed ✅'
      WHEN 'out_for_delivery' THEN 'Order Out for Delivery 🚚'
      WHEN 'delivered' THEN 'Order Delivered 📦'
    END;

    notif_message := 'Your order (₹' || NEW.total || ') is now ' || replace(NEW.status, '_', ' ') || '.';

    function_url := rtrim(current_setting('app.settings.supabase_url', true), '/') || '/functions/v1/send-push-notification';
    service_role_key := current_setting('app.settings.service_role_key', true);

    PERFORM net.http_post(
      url := function_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || service_role_key
      ),
      body := jsonb_build_object(
        'user_id', NEW.user_id,
        'title', notif_title,
        'message', notif_message,
        'path', '/order/' || NEW.id
      )
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_push_notify_order_status
AFTER UPDATE ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.push_notify_order_status();

-- ===== 20260228173557_a18325b9-c637-4edd-9123-84381b137331.sql =====

-- Enable the pg_net extension for async HTTP calls from triggers
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- Recreate order trigger function using extensions.http_post
CREATE OR REPLACE FUNCTION public.push_notify_order_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  function_url TEXT;
  service_role_key TEXT;
  notif_title TEXT;
  notif_message TEXT;
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status AND NEW.status IN ('confirmed', 'out_for_delivery', 'delivered') THEN
    notif_title := CASE NEW.status
      WHEN 'confirmed' THEN 'Order Confirmed ✅'
      WHEN 'out_for_delivery' THEN 'Order Out for Delivery 🚚'
      WHEN 'delivered' THEN 'Order Delivered 📦'
    END;

    notif_message := 'Your order (₹' || NEW.total || ') is now ' || replace(NEW.status, '_', ' ') || '.';

    function_url := rtrim(current_setting('app.settings.supabase_url', true), '/') || '/functions/v1/send-push-notification';
    service_role_key := current_setting('app.settings.service_role_key', true);

    PERFORM extensions.http_post(
      url := function_url,
      body := jsonb_build_object(
        'user_id', NEW.user_id,
        'title', notif_title,
        'message', notif_message,
        'path', '/order/' || NEW.id
      ),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || service_role_key
      )
    );
  END IF;
  RETURN NEW;
END;
$$;

-- Recreate appointment trigger function using extensions.http_post
CREATE OR REPLACE FUNCTION public.push_notify_appointment_confirmed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  provider_name TEXT;
  function_url TEXT;
  service_role_key TEXT;
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'confirmed' THEN
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

    function_url := rtrim(current_setting('app.settings.supabase_url', true), '/') || '/functions/v1/send-push-notification';
    service_role_key := current_setting('app.settings.service_role_key', true);

    PERFORM extensions.http_post(
      url := function_url,
      body := jsonb_build_object(
        'user_id', NEW.patient_id,
        'title', 'Appointment Confirmed ✅',
        'message', 'Your ' || NEW.service_type || ' appointment with ' || provider_name || ' on ' || NEW.appointment_date || ' at ' || NEW.appointment_time || ' has been confirmed.',
        'path', '/appointments'
      ),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || service_role_key
      )
    );
  END IF;
  RETURN NEW;
END;
$$;

-- ===== 20260228173640_cba11ead-ce1e-4c0d-8eeb-104b8542333f.sql =====

CREATE OR REPLACE FUNCTION public.push_notify_order_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  function_url TEXT;
  service_role_key TEXT;
  notif_title TEXT;
  notif_message TEXT;
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status AND NEW.status IN ('confirmed', 'out_for_delivery', 'delivered') THEN
    notif_title := CASE NEW.status
      WHEN 'confirmed' THEN 'Order Confirmed ✅'
      WHEN 'out_for_delivery' THEN 'Order Out for Delivery 🚚'
      WHEN 'delivered' THEN 'Order Delivered 📦'
    END;
    notif_message := 'Your order (₹' || NEW.total || ') is now ' || replace(NEW.status, '_', ' ') || '.';
    function_url := rtrim(current_setting('app.settings.supabase_url', true), '/') || '/functions/v1/send-push-notification';
    service_role_key := current_setting('app.settings.service_role_key', true);

    PERFORM net.http_post(
      url := function_url,
      body := jsonb_build_object(
        'user_id', NEW.user_id,
        'title', notif_title,
        'message', notif_message,
        'path', '/order/' || NEW.id
      ),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || service_role_key
      )
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.push_notify_appointment_confirmed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  provider_name TEXT;
  function_url TEXT;
  service_role_key TEXT;
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'confirmed' THEN
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
    function_url := rtrim(current_setting('app.settings.supabase_url', true), '/') || '/functions/v1/send-push-notification';
    service_role_key := current_setting('app.settings.service_role_key', true);

    PERFORM net.http_post(
      url := function_url,
      body := jsonb_build_object(
        'user_id', NEW.patient_id,
        'title', 'Appointment Confirmed ✅',
        'message', 'Your ' || NEW.service_type || ' appointment with ' || provider_name || ' on ' || NEW.appointment_date || ' at ' || NEW.appointment_time || ' has been confirmed.',
        'path', '/appointments'
      ),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || service_role_key
      )
    );
  END IF;
  RETURN NEW;
END;
$$;

-- ===== 20260228173741_490379e3-8ce5-4900-bff1-10bd190a1fe2.sql =====

CREATE OR REPLACE FUNCTION public.push_notify_order_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  notif_title TEXT;
  notif_message TEXT;
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status AND NEW.status IN ('confirmed', 'out_for_delivery', 'delivered') THEN
    notif_title := CASE NEW.status
      WHEN 'confirmed' THEN 'Order Confirmed ✅'
      WHEN 'out_for_delivery' THEN 'Order Out for Delivery 🚚'
      WHEN 'delivered' THEN 'Order Delivered 📦'
    END;
    notif_message := 'Your order (₹' || NEW.total || ') is now ' || replace(NEW.status, '_', ' ') || '.';

    -- Insert a notification record; the existing in-app system handles display
    -- Push notification will be sent via the notify_order_change trigger's in-app notification
    -- We call the edge function directly with hardcoded project URL
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
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1aWNxcGZpam5zb3J0Y3N6cWVwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIyMDc4MjQsImV4cCI6MjA4Nzc4MzgyNH0.teNIccPIhtIoPmAHd9OtNHi0XyPOXsJcoiHygjuA1RQ'
      )
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.push_notify_appointment_confirmed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  provider_name TEXT;
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'confirmed' THEN
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

    PERFORM net.http_post(
      url := 'https://zjlznbgcfzpcveqyjglf.supabase.co/functions/v1/send-push-notification',
      body := jsonb_build_object(
        'user_id', NEW.patient_id,
        'title', 'Appointment Confirmed ✅',
        'message', 'Your ' || NEW.service_type || ' appointment with ' || provider_name || ' on ' || NEW.appointment_date || ' at ' || NEW.appointment_time || ' has been confirmed.',
        'path', '/appointments'
      ),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1aWNxcGZpam5zb3J0Y3N6cWVwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIyMDc4MjQsImV4cCI6MjA4Nzc4MzgyNH0.teNIccPIhtIoPmAHd9OtNHi0XyPOXsJcoiHygjuA1RQ'
      )
    );
  END IF;
  RETURN NEW;
END;
$$;

-- ===== 20260228173847_2af3c470-0460-4e95-b687-cd1d3618f690.sql =====

CREATE OR REPLACE FUNCTION public.push_notify_order_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  notif_title TEXT;
  notif_message TEXT;
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status AND NEW.status IN ('confirmed', 'out_for_delivery', 'delivered', 'cancelled') THEN
    notif_title := CASE NEW.status
      WHEN 'confirmed' THEN 'Order Confirmed ✅'
      WHEN 'out_for_delivery' THEN 'Order Out for Delivery 🚚'
      WHEN 'delivered' THEN 'Order Delivered 📦'
      WHEN 'cancelled' THEN 'Order Cancelled ❌'
    END;
    notif_message := 'Your order (₹' || NEW.total || ') is now ' || replace(NEW.status, '_', ' ') || '.';

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
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1aWNxcGZpam5zb3J0Y3N6cWVwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIyMDc4MjQsImV4cCI6MjA4Nzc4MzgyNH0.teNIccPIhtIoPmAHd9OtNHi0XyPOXsJcoiHygjuA1RQ'
      )
    );
  END IF;
  RETURN NEW;
END;
$$;

-- ===== 20260228174155_8d288878-7b04-44cb-bd81-8ce72b97b920.sql =====

CREATE OR REPLACE FUNCTION public.push_notify_appointment_confirmed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  provider_name TEXT;
  notif_title TEXT;
  notif_message TEXT;
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status AND NEW.status IN ('confirmed', 'cancelled') THEN
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
    END;
    notif_message := 'Your ' || NEW.service_type || ' appointment with ' || provider_name || ' on ' || NEW.appointment_date || ' at ' || NEW.appointment_time || ' has been ' || NEW.status || '.';

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
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1aWNxcGZpam5zb3J0Y3N6cWVwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIyMDc4MjQsImV4cCI6MjA4Nzc4MzgyNH0.teNIccPIhtIoPmAHd9OtNHi0XyPOXsJcoiHygjuA1RQ'
      )
    );
  END IF;
  RETURN NEW;
END;
$$;

-- ===== 20260228174411_b8943079-e2f0-45e3-80a4-95e5d719c7cb.sql =====

CREATE OR REPLACE FUNCTION public.push_notify_appointment_confirmed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  provider_name TEXT;
  notif_title TEXT;
  notif_message TEXT;
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
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1aWNxcGZpam5zb3J0Y3N6cWVwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIyMDc4MjQsImV4cCI6MjA4Nzc4MzgyNH0.teNIccPIhtIoPmAHd9OtNHi0XyPOXsJcoiHygjuA1RQ'
      )
    );
  END IF;
  RETURN NEW;
END;
$$;

-- ===== 20260228181734_2cbe7bf1-5a2d-4c1c-a2cb-4a711c892837.sql =====

-- Add approval_status to provider tables
ALTER TABLE public.doctors ADD COLUMN IF NOT EXISTS approval_status text NOT NULL DEFAULT 'approved';
ALTER TABLE public.hospitals ADD COLUMN IF NOT EXISTS approval_status text NOT NULL DEFAULT 'approved';
ALTER TABLE public.labs ADD COLUMN IF NOT EXISTS approval_status text NOT NULL DEFAULT 'approved';
ALTER TABLE public.pharmacies ADD COLUMN IF NOT EXISTS approval_status text NOT NULL DEFAULT 'approved';

-- Add status to profiles for user management
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active';

-- Add indexes for filtering
CREATE INDEX IF NOT EXISTS idx_doctors_approval ON public.doctors(approval_status);
CREATE INDEX IF NOT EXISTS idx_hospitals_approval ON public.hospitals(approval_status);
CREATE INDEX IF NOT EXISTS idx_labs_approval ON public.labs(approval_status);
CREATE INDEX IF NOT EXISTS idx_pharmacies_approval ON public.pharmacies(approval_status);
CREATE INDEX IF NOT EXISTS idx_profiles_status ON public.profiles(status);

-- Allow admins to manage emergency_requests (update status, assign ambulance)
CREATE POLICY "Admins can update emergency requests"
ON public.emergency_requests
FOR UPDATE
USING (has_role(auth.uid(), 'admin'::app_role));

-- Allow admins to manage ambulances
CREATE POLICY "Admins can update ambulances"
ON public.ambulances
FOR UPDATE
USING (has_role(auth.uid(), 'admin'::app_role));

-- Allow admins to delete appointments
CREATE POLICY "Admins can delete appointments"
ON public.appointments
FOR DELETE
USING (has_role(auth.uid(), 'admin'::app_role));

-- ===== 20260301005104_7908edf2-cfd9-4ca5-aaa2-caad771e25ee.sql =====

-- Add new provider roles to the app_role enum
ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'doctor';
ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'hospital_admin';
ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'lab_admin';
ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'pharmacy_admin';

-- Add user_id column to doctors table
ALTER TABLE public.doctors ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL;

-- Add user_id column to hospitals table
ALTER TABLE public.hospitals ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL;

-- Add user_id column to labs table
ALTER TABLE public.labs ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL;

-- Add user_id column to pharmacies table
ALTER TABLE public.pharmacies ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL;

-- Create indexes for user_id lookups
CREATE INDEX IF NOT EXISTS idx_doctors_user_id ON public.doctors(user_id);
CREATE INDEX IF NOT EXISTS idx_hospitals_user_id ON public.hospitals(user_id);
CREATE INDEX IF NOT EXISTS idx_labs_user_id ON public.labs(user_id);
CREATE INDEX IF NOT EXISTS idx_pharmacies_user_id ON public.pharmacies(user_id);

-- RLS: Allow providers to view/update their own records
CREATE POLICY "Doctors can view own record" ON public.doctors FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Doctors can update own record" ON public.doctors FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Hospital admins can view own record" ON public.hospitals FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Hospital admins can update own record" ON public.hospitals FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Lab admins can view own record" ON public.labs FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Lab admins can update own record" ON public.labs FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Pharmacy admins can view own record" ON public.pharmacies FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Pharmacy admins can update own record" ON public.pharmacies FOR UPDATE USING (auth.uid() = user_id);

-- Allow providers to view their own appointments
CREATE POLICY "Doctors can view their appointments" ON public.appointments FOR SELECT USING (
  doctor_id IN (SELECT id FROM public.doctors WHERE user_id = auth.uid())
);
CREATE POLICY "Doctors can update their appointments" ON public.appointments FOR UPDATE USING (
  doctor_id IN (SELECT id FROM public.doctors WHERE user_id = auth.uid())
);

CREATE POLICY "Hospital admins can view their appointments" ON public.appointments FOR SELECT USING (
  hospital_id IN (SELECT id FROM public.hospitals WHERE user_id = auth.uid())
);

CREATE POLICY "Lab admins can view their appointments" ON public.appointments FOR SELECT USING (
  lab_id IN (SELECT id FROM public.labs WHERE user_id = auth.uid())
);

CREATE POLICY "Pharmacy admins can view their appointments" ON public.appointments FOR SELECT USING (
  pharmacy_id IN (SELECT id FROM public.pharmacies WHERE user_id = auth.uid())
);

-- Allow pharmacy admins to view orders for their pharmacy
CREATE POLICY "Pharmacy admins can view their orders" ON public.orders FOR SELECT USING (
  pharmacy_id IN (SELECT id FROM public.pharmacies WHERE user_id = auth.uid())
);
CREATE POLICY "Pharmacy admins can update their orders" ON public.orders FOR UPDATE USING (
  pharmacy_id IN (SELECT id FROM public.pharmacies WHERE user_id = auth.uid())
);

-- Allow pharmacy admins to manage their medicines
CREATE POLICY "Pharmacy admins can view their medicines" ON public.medicines FOR SELECT USING (
  pharmacy_id IN (SELECT id FROM public.pharmacies WHERE user_id = auth.uid())
);
CREATE POLICY "Pharmacy admins can insert medicines" ON public.medicines FOR INSERT WITH CHECK (
  pharmacy_id IN (SELECT id FROM public.pharmacies WHERE user_id = auth.uid())
);
CREATE POLICY "Pharmacy admins can update their medicines" ON public.medicines FOR UPDATE USING (
  pharmacy_id IN (SELECT id FROM public.pharmacies WHERE user_id = auth.uid())
);
CREATE POLICY "Pharmacy admins can delete their medicines" ON public.medicines FOR DELETE USING (
  pharmacy_id IN (SELECT id FROM public.pharmacies WHERE user_id = auth.uid())
);

-- ===== 20260301010615_09e53e49-55f7-4b0f-9503-6d9814380b98.sql =====

-- Allow users to view their own roles
CREATE POLICY "Users can view own roles"
ON public.user_roles FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Allow authenticated users to insert themselves as providers (pending approval)
CREATE POLICY "Users can register as doctor"
ON public.doctors FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id AND approval_status = 'pending');

CREATE POLICY "Users can register as hospital"
ON public.hospitals FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id AND approval_status = 'pending');

CREATE POLICY "Users can register as lab"
ON public.labs FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id AND approval_status = 'pending');

CREATE POLICY "Users can register as pharmacy"
ON public.pharmacies FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id AND approval_status = 'pending');

-- Allow users to assign themselves a provider role (only provider roles, not admin)
CREATE POLICY "Users can self-assign provider role"
ON public.user_roles FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = user_id 
  AND role IN ('doctor'::app_role, 'hospital_admin'::app_role, 'lab_admin'::app_role, 'pharmacy_admin'::app_role)
);

