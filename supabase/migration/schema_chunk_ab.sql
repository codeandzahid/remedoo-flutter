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

-- ===== 20260301032454_07c293fa-22bb-4aa4-aec6-75e7ba5bcac2.sql =====

-- =============================================
-- 1. ADD COLUMNS TO DOCTORS TABLE
-- =============================================
ALTER TABLE public.doctors
  ADD COLUMN IF NOT EXISTS experience_years integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS max_appointments_per_day integer DEFAULT 20,
  ADD COLUMN IF NOT EXISTS consultation_duration integer DEFAULT 15,
  ADD COLUMN IF NOT EXISTS emergency_available boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS certificate_url text,
  ADD COLUMN IF NOT EXISTS account_status text NOT NULL DEFAULT 'active';

-- =============================================
-- 2. ADD COLUMNS TO APPOINTMENTS TABLE
-- =============================================
ALTER TABLE public.appointments
  ADD COLUMN IF NOT EXISTS consultation_notes text,
  ADD COLUMN IF NOT EXISTS prescription_url text,
  ADD COLUMN IF NOT EXISTS follow_up_date date,
  ADD COLUMN IF NOT EXISTS rejection_reason text;

-- =============================================
-- 3. CREATE AUDIT LOGS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  doctor_id uuid REFERENCES public.doctors(id) ON DELETE CASCADE,
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid,
  details jsonb DEFAULT '{}'::jsonb,
  ip_address text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Doctors can view their own logs
CREATE POLICY "Doctors can view own audit logs"
  ON public.audit_logs FOR SELECT
  USING (user_id = auth.uid());

-- Doctors can insert their own logs
CREATE POLICY "Doctors can insert own audit logs"
  ON public.audit_logs FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Admins can view all logs
CREATE POLICY "Admins can view all audit logs"
  ON public.audit_logs FOR SELECT
  USING (has_role(auth.uid(), 'admin'::app_role));

-- =============================================
-- 4. CREATE DOCTOR BLOCKED SLOTS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS public.doctor_blocked_slots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  doctor_id uuid NOT NULL REFERENCES public.doctors(id) ON DELETE CASCADE,
  blocked_date date NOT NULL,
  start_time time,
  end_time time,
  reason text,
  is_full_day boolean DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.doctor_blocked_slots ENABLE ROW LEVEL SECURITY;

-- Doctors can manage their own blocked slots
CREATE POLICY "Doctors can view own blocked slots"
  ON public.doctor_blocked_slots FOR SELECT
  USING (doctor_id IN (SELECT id FROM doctors WHERE user_id = auth.uid()));

CREATE POLICY "Doctors can insert own blocked slots"
  ON public.doctor_blocked_slots FOR INSERT
  WITH CHECK (doctor_id IN (SELECT id FROM doctors WHERE user_id = auth.uid()));

CREATE POLICY "Doctors can update own blocked slots"
  ON public.doctor_blocked_slots FOR UPDATE
  USING (doctor_id IN (SELECT id FROM doctors WHERE user_id = auth.uid()));

CREATE POLICY "Doctors can delete own blocked slots"
  ON public.doctor_blocked_slots FOR DELETE
  USING (doctor_id IN (SELECT id FROM doctors WHERE user_id = auth.uid()));

-- Admins can manage all blocked slots
CREATE POLICY "Admins can manage all blocked slots"
  ON public.doctor_blocked_slots FOR ALL
  USING (has_role(auth.uid(), 'admin'::app_role))
  WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

-- =============================================
-- 5. CREATE STORAGE BUCKET FOR PRESCRIPTIONS IF NOT EXISTS
-- =============================================
-- prescriptions bucket already exists

-- Create certificates bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('certificates', 'certificates', false)
ON CONFLICT (id) DO NOTHING;

-- RLS for certificates bucket
CREATE POLICY "Doctors can upload own certificates"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'certificates' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Doctors can view own certificates"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'certificates' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Doctors can update own certificates"
  ON storage.objects FOR UPDATE
  USING (bucket_id = 'certificates' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Admins can view all certificates"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'certificates' AND has_role(auth.uid(), 'admin'::app_role));

-- Prescription upload policy for doctors
CREATE POLICY "Doctors can upload prescriptions"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'prescriptions' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Doctors can view prescriptions they uploaded"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'prescriptions' AND auth.uid()::text = (storage.foldername(name))[1]);

-- =============================================
-- 6. INDEX FOR PERFORMANCE
-- =============================================
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON public.audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_doctor_id ON public.audit_logs(doctor_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_appointments_doctor_date ON public.appointments(doctor_id, appointment_date);
CREATE INDEX IF NOT EXISTS idx_doctor_blocked_slots_doctor_date ON public.doctor_blocked_slots(doctor_id, blocked_date);

-- ===== 20260301034740_aafaf23a-38af-48c2-baef-4cf542a9bbc4.sql =====

-- Create prescriptions table
CREATE TABLE public.prescriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  appointment_id uuid REFERENCES public.appointments(id) ON DELETE CASCADE NOT NULL,
  doctor_id uuid REFERENCES public.doctors(id) NOT NULL,
  patient_id uuid NOT NULL,
  diagnosis text,
  notes text,
  signature_data text, -- base64 e-signature
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Create prescription items (medicines)
CREATE TABLE public.prescription_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  prescription_id uuid REFERENCES public.prescriptions(id) ON DELETE CASCADE NOT NULL,
  medicine_name text NOT NULL,
  generic_name text,
  dosage text NOT NULL,
  frequency text NOT NULL,
  duration text NOT NULL,
  instructions text,
  sort_order int DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.prescriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prescription_items ENABLE ROW LEVEL SECURITY;

-- Prescriptions RLS
CREATE POLICY "Doctors can insert own prescriptions"
ON public.prescriptions FOR INSERT
WITH CHECK (doctor_id IN (SELECT id FROM doctors WHERE user_id = auth.uid()));

CREATE POLICY "Doctors can update own prescriptions"
ON public.prescriptions FOR UPDATE
USING (doctor_id IN (SELECT id FROM doctors WHERE user_id = auth.uid()));

CREATE POLICY "Doctors can view own prescriptions"
ON public.prescriptions FOR SELECT
USING (doctor_id IN (SELECT id FROM doctors WHERE user_id = auth.uid()));

CREATE POLICY "Doctors can delete own prescriptions"
ON public.prescriptions FOR DELETE
USING (doctor_id IN (SELECT id FROM doctors WHERE user_id = auth.uid()));

CREATE POLICY "Patients can view own prescriptions"
ON public.prescriptions FOR SELECT
USING (auth.uid() = patient_id);

CREATE POLICY "Admins can view all prescriptions"
ON public.prescriptions FOR SELECT
USING (has_role(auth.uid(), 'admin'::app_role));

-- Prescription items RLS
CREATE POLICY "Doctors can manage own prescription items"
ON public.prescription_items FOR ALL
USING (prescription_id IN (
  SELECT id FROM prescriptions WHERE doctor_id IN (
    SELECT id FROM doctors WHERE user_id = auth.uid()
  )
))
WITH CHECK (prescription_id IN (
  SELECT id FROM prescriptions WHERE doctor_id IN (
    SELECT id FROM doctors WHERE user_id = auth.uid()
  )
));

CREATE POLICY "Patients can view own prescription items"
ON public.prescription_items FOR SELECT
USING (prescription_id IN (
  SELECT id FROM prescriptions WHERE patient_id = auth.uid()
));

CREATE POLICY "Admins can view all prescription items"
ON public.prescription_items FOR SELECT
USING (has_role(auth.uid(), 'admin'::app_role));

-- Timestamps trigger
CREATE TRIGGER update_prescriptions_updated_at
BEFORE UPDATE ON public.prescriptions
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ===== 20260301041324_9a3d66a6-2556-43ac-9d70-e512f7643dd0.sql =====

-- Add token_number to appointments for queue management
ALTER TABLE public.appointments ADD COLUMN IF NOT EXISTS token_number integer;

-- Create a function to auto-assign token numbers per doctor per day
CREATE OR REPLACE FUNCTION public.assign_token_number()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  next_token integer;
BEGIN
  -- Only assign token when status changes to confirmed
  IF NEW.status = 'confirmed' AND (OLD.status IS NULL OR OLD.status != 'confirmed') AND NEW.token_number IS NULL THEN
    SELECT COALESCE(MAX(token_number), 0) + 1 INTO next_token
    FROM public.appointments
    WHERE doctor_id = NEW.doctor_id
      AND appointment_date = NEW.appointment_date
      AND status IN ('confirmed', 'completed')
      AND token_number IS NOT NULL;
    
    NEW.token_number := next_token;
  END IF;
  RETURN NEW;
END;
$$;

-- Create trigger for auto token assignment
DROP TRIGGER IF EXISTS assign_appointment_token ON public.appointments;
CREATE TRIGGER assign_appointment_token
  BEFORE UPDATE ON public.appointments
  FOR EACH ROW
  EXECUTE FUNCTION public.assign_token_number();

-- Also handle insert with confirmed status
DROP TRIGGER IF EXISTS assign_appointment_token_insert ON public.appointments;
CREATE TRIGGER assign_appointment_token_insert
  BEFORE INSERT ON public.appointments
  FOR EACH ROW
  EXECUTE FUNCTION public.assign_token_number();

-- Enable realtime for appointments so patients see live queue updates
ALTER PUBLICATION supabase_realtime ADD TABLE public.appointments;

-- ===== 20260301043115_0437ad8f-0031-4aca-9590-191350f23b34.sql =====

-- Table to track consultation note edit requests and history
CREATE TABLE public.consultation_edit_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  appointment_id uuid NOT NULL REFERENCES public.appointments(id) ON DELETE CASCADE,
  doctor_id uuid NOT NULL REFERENCES public.doctors(id),
  requested_by uuid NOT NULL,
  field_name text NOT NULL DEFAULT 'consultation_notes',
  old_value text,
  new_value text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  admin_notes text,
  reviewed_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  reviewed_at timestamptz
);

ALTER TABLE public.consultation_edit_requests ENABLE ROW LEVEL SECURITY;

-- Doctors can create edit requests for their own appointments
CREATE POLICY "Doctors can insert own edit requests"
ON public.consultation_edit_requests FOR INSERT
WITH CHECK (
  doctor_id IN (SELECT id FROM doctors WHERE user_id = auth.uid())
);

-- Doctors can view their own edit requests
CREATE POLICY "Doctors can view own edit requests"
ON public.consultation_edit_requests FOR SELECT
USING (
  doctor_id IN (SELECT id FROM doctors WHERE user_id = auth.uid())
);

-- Admins can view all edit requests
CREATE POLICY "Admins can view all edit requests"
ON public.consultation_edit_requests FOR SELECT
USING (has_role(auth.uid(), 'admin'));

-- Admins can update edit requests (approve/reject)
CREATE POLICY "Admins can update edit requests"
ON public.consultation_edit_requests FOR UPDATE
USING (has_role(auth.uid(), 'admin'));

-- Add lock_hours setting: appointments are locked X hours after completion
-- We'll use 24 hours as default, stored in the appointments completed_at timestamp
-- Add completed_at column to track exact completion time
ALTER TABLE public.appointments ADD COLUMN IF NOT EXISTS completed_at timestamptz;

-- Enable realtime for edit requests
ALTER PUBLICATION supabase_realtime ADD TABLE public.consultation_edit_requests;

-- ===== 20260301050142_535b5d57-2f5c-4c77-ad35-8aa289c354de.sql =====

-- Add is_government flag to hospitals
ALTER TABLE public.hospitals ADD COLUMN is_government boolean NOT NULL DEFAULT false;

-- ===== 20260301054235_6271eefc-7e73-42b4-9729-adb64fdfc837.sql =====

-- Add latitude/longitude to labs
ALTER TABLE public.labs ADD COLUMN IF NOT EXISTS latitude double precision;
ALTER TABLE public.labs ADD COLUMN IF NOT EXISTS longitude double precision;

-- Add latitude/longitude to pharmacies
ALTER TABLE public.pharmacies ADD COLUMN IF NOT EXISTS latitude double precision;
ALTER TABLE public.pharmacies ADD COLUMN IF NOT EXISTS longitude double precision;

-- ===== 20260301064025_d67d11ae-3c3c-4227-b8fa-2b37f51604fe.sql =====
-- Add admin_note column to doctors for revision/rejection notes
ALTER TABLE public.doctors ADD COLUMN IF NOT EXISTS admin_note text;

-- Add admin_note to hospitals, labs, pharmacies too for consistency
ALTER TABLE public.hospitals ADD COLUMN IF NOT EXISTS admin_note text;
ALTER TABLE public.labs ADD COLUMN IF NOT EXISTS admin_note text;
ALTER TABLE public.pharmacies ADD COLUMN IF NOT EXISTS admin_note text;
-- ===== 20260301071311_f237b5cb-a917-47b4-ac99-0d9b2ec0c94f.sql =====

-- Add detailed bed tracking columns to hospitals
ALTER TABLE public.hospitals 
ADD COLUMN IF NOT EXISTS total_beds integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS available_beds integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_icu_beds integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS available_icu_beds integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS emergency_contact text,
ADD COLUMN IF NOT EXISTS platform_commission_percent numeric DEFAULT 10;

-- Departments table
CREATE TABLE public.departments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.hospitals(id) ON DELETE CASCADE,
  name text NOT NULL,
  head_doctor_id uuid REFERENCES public.doctors(id) ON DELETE SET NULL,
  description text,
  is_active boolean DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Hospital admins can manage own departments" ON public.departments FOR ALL
  USING (hospital_id IN (SELECT id FROM hospitals WHERE user_id = auth.uid()))
  WITH CHECK (hospital_id IN (SELECT id FROM hospitals WHERE user_id = auth.uid()));
CREATE POLICY "Admins can manage all departments" ON public.departments FOR ALL
  USING (has_role(auth.uid(), 'admin')) WITH CHECK (has_role(auth.uid(), 'admin'));
CREATE POLICY "Departments viewable by everyone" ON public.departments FOR SELECT USING (true);

-- Operation theaters table
CREATE TABLE public.operation_theaters (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.hospitals(id) ON DELETE CASCADE,
  name text NOT NULL,
  department_id uuid REFERENCES public.departments(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'available',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.operation_theaters ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Hospital admins can manage own OTs" ON public.operation_theaters FOR ALL
  USING (hospital_id IN (SELECT id FROM hospitals WHERE user_id = auth.uid()))
  WITH CHECK (hospital_id IN (SELECT id FROM hospitals WHERE user_id = auth.uid()));
CREATE POLICY "Admins can manage all OTs" ON public.operation_theaters FOR ALL
  USING (has_role(auth.uid(), 'admin')) WITH CHECK (has_role(auth.uid(), 'admin'));
CREATE POLICY "OTs viewable by everyone" ON public.operation_theaters FOR SELECT USING (true);

-- Equipment table
CREATE TABLE public.hospital_equipment (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.hospitals(id) ON DELETE CASCADE,
  name text NOT NULL,
  department_id uuid REFERENCES public.departments(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'operational',
  maintenance_notes text,
  last_maintenance_date date,
  next_maintenance_date date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.hospital_equipment ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Hospital admins can manage own equipment" ON public.hospital_equipment FOR ALL
  USING (hospital_id IN (SELECT id FROM hospitals WHERE user_id = auth.uid()))
  WITH CHECK (hospital_id IN (SELECT id FROM hospitals WHERE user_id = auth.uid()));
CREATE POLICY "Admins can manage all equipment" ON public.hospital_equipment FOR ALL
  USING (has_role(auth.uid(), 'admin')) WITH CHECK (has_role(auth.uid(), 'admin'));

-- Hospital earnings table
CREATE TABLE public.hospital_earnings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.hospitals(id) ON DELETE CASCADE,
  appointment_id uuid REFERENCES public.appointments(id) ON DELETE SET NULL,
  amount numeric NOT NULL DEFAULT 0,
  platform_commission numeric NOT NULL DEFAULT 0,
  net_earning numeric NOT NULL DEFAULT 0,
  description text,
  type text NOT NULL DEFAULT 'appointment',
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.hospital_earnings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Hospital admins can view own earnings" ON public.hospital_earnings FOR SELECT
  USING (hospital_id IN (SELECT id FROM hospitals WHERE user_id = auth.uid()));
CREATE POLICY "Admins can manage all earnings" ON public.hospital_earnings FOR ALL
  USING (has_role(auth.uid(), 'admin')) WITH CHECK (has_role(auth.uid(), 'admin'));
CREATE POLICY "System can insert earnings" ON public.hospital_earnings FOR INSERT
  WITH CHECK (hospital_id IN (SELECT id FROM hospitals WHERE user_id = auth.uid()));

-- Add department_id to doctors for department association
ALTER TABLE public.doctors ADD COLUMN IF NOT EXISTS department_id uuid REFERENCES public.departments(id) ON DELETE SET NULL;

-- Add department to appointments
ALTER TABLE public.appointments ADD COLUMN IF NOT EXISTS department text;

-- Enable realtime for bed tracking
ALTER PUBLICATION supabase_realtime ADD TABLE public.departments;
ALTER PUBLICATION supabase_realtime ADD TABLE public.operation_theaters;

-- Triggers for updated_at
CREATE TRIGGER update_operation_theaters_updated_at BEFORE UPDATE ON public.operation_theaters
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_hospital_equipment_updated_at BEFORE UPDATE ON public.hospital_equipment
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ===== 20260301072941_7bb2c5b4-76d0-4dae-8255-5d77513ef737.sql =====

-- Hospital Ambulance Service Configuration
CREATE TABLE public.hospital_ambulance_config (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid REFERENCES public.hospitals(id) ON DELETE CASCADE NOT NULL UNIQUE,
  service_enabled boolean DEFAULT false,
  service_type text NOT NULL DEFAULT 'free', -- free, paid, conditional
  base_fare numeric DEFAULT 0,
  per_km_charge numeric DEFAULT 0,
  emergency_surcharge numeric DEFAULT 0,
  night_surcharge numeric DEFAULT 0,
  minimum_charge numeric DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_ambulance_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage all ambulance configs"
ON public.hospital_ambulance_config FOR ALL
USING (has_role(auth.uid(), 'admin'::app_role))
WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Hospital admins can manage own ambulance config"
ON public.hospital_ambulance_config FOR ALL
USING (hospital_id IN (SELECT id FROM hospitals WHERE user_id = auth.uid()))
WITH CHECK (hospital_id IN (SELECT id FROM hospitals WHERE user_id = auth.uid()));

CREATE TRIGGER update_hospital_ambulance_config_updated_at
BEFORE UPDATE ON public.hospital_ambulance_config
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Enhance ambulances table with hospital linkage
ALTER TABLE public.ambulances 
ADD COLUMN IF NOT EXISTS hospital_id uuid REFERENCES public.hospitals(id),
ADD COLUMN IF NOT EXISTS vehicle_type text DEFAULT 'BLS',
ADD COLUMN IF NOT EXISTS equipment_details text;

-- Allow hospital admins to manage their ambulances
CREATE POLICY "Hospital admins can manage own ambulances"
ON public.ambulances FOR ALL
USING (hospital_id IN (SELECT id FROM hospitals WHERE user_id = auth.uid()))
WITH CHECK (hospital_id IN (SELECT id FROM hospitals WHERE user_id = auth.uid()));

CREATE POLICY "Hospital admins can insert ambulances"
ON public.ambulances FOR INSERT
WITH CHECK (hospital_id IN (SELECT id FROM hospitals WHERE user_id = auth.uid()));

-- Ambulance Trips table
CREATE TABLE public.ambulance_trips (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid REFERENCES public.hospitals(id) ON DELETE CASCADE NOT NULL,
  ambulance_id uuid REFERENCES public.ambulances(id),
  emergency_request_id uuid REFERENCES public.emergency_requests(id),
  patient_id uuid NOT NULL,
  driver_name text,
  driver_phone text,
  status text NOT NULL DEFAULT 'assigned',
  distance_km numeric DEFAULT 0,
  base_fare numeric DEFAULT 0,
  distance_fare numeric DEFAULT 0,
  surcharge numeric DEFAULT 0,
  total_fare numeric DEFAULT 0,
  is_free boolean DEFAULT false,
  payment_method text DEFAULT 'cash',
  payment_status text DEFAULT 'pending',
  started_at timestamptz,
  reached_at timestamptz,
  completed_at timestamptz,
  response_time_minutes numeric,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.ambulance_trips ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage all ambulance trips"
ON public.ambulance_trips FOR ALL
USING (has_role(auth.uid(), 'admin'::app_role))
WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Hospital admins can manage own trips"
ON public.ambulance_trips FOR ALL
USING (hospital_id IN (SELECT id FROM hospitals WHERE user_id = auth.uid()))
WITH CHECK (hospital_id IN (SELECT id FROM hospitals WHERE user_id = auth.uid()));

CREATE POLICY "Patients can view own trips"
ON public.ambulance_trips FOR SELECT
USING (auth.uid() = patient_id);

CREATE TRIGGER update_ambulance_trips_updated_at
BEFORE UPDATE ON public.ambulance_trips
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ===== 20260301073317_c1ce2f7b-83f1-4fb9-8bf0-373d6bf73f8d.sql =====

-- Trigger: auto-decrease available_beds when emergency is resolved (patient admitted)
CREATE OR REPLACE FUNCTION public.sync_beds_on_emergency()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  amb_hospital_id uuid;
BEGIN
  -- When emergency status changes to 'resolved' (admitted), decrease available beds
  IF NEW.status = 'resolved' AND (OLD.status IS DISTINCT FROM 'resolved') THEN
    -- Find hospital via assigned ambulance
    IF NEW.assigned_ambulance_id IS NOT NULL THEN
      SELECT hospital_id INTO amb_hospital_id FROM ambulances WHERE id = NEW.assigned_ambulance_id;
    END IF;

    IF amb_hospital_id IS NOT NULL THEN
      UPDATE hospitals
      SET available_beds = GREATEST(available_beds - 1, 0)
      WHERE id = amb_hospital_id AND available_beds > 0;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_sync_beds_on_emergency
BEFORE UPDATE ON public.emergency_requests
FOR EACH ROW
EXECUTE FUNCTION public.sync_beds_on_emergency();

-- ===== 20260301081950_39ac7081-24c4-42c8-9500-b5d253578d34.sql =====

-- Add payment fields to appointments
ALTER TABLE public.appointments
ADD COLUMN IF NOT EXISTS payment_method text NOT NULL DEFAULT 'at_clinic',
ADD COLUMN IF NOT EXISTS payment_status text NOT NULL DEFAULT 'pending';

-- Auto-confirm appointment when payment is completed online
CREATE OR REPLACE FUNCTION public.auto_confirm_paid_appointment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  -- When payment_status changes to 'paid' and payment_method is 'online', auto-confirm
  IF NEW.payment_method = 'online' 
     AND NEW.payment_status = 'paid' 
     AND NEW.status = 'pending'
     AND (OLD.payment_status IS DISTINCT FROM 'paid') THEN
    NEW.status := 'confirmed';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_auto_confirm_paid_appointment
BEFORE UPDATE ON public.appointments
FOR EACH ROW
EXECUTE FUNCTION public.auto_confirm_paid_appointment();

-- Also auto-confirm on INSERT if already paid
CREATE OR REPLACE FUNCTION public.auto_confirm_paid_appointment_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF NEW.payment_method = 'online' AND NEW.payment_status = 'paid' AND NEW.status = 'pending' THEN
    NEW.status := 'confirmed';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_auto_confirm_paid_appointment_insert
BEFORE INSERT ON public.appointments
FOR EACH ROW
EXECUTE FUNCTION public.auto_confirm_paid_appointment_insert();

-- ===== 20260301084439_f10059c2-476d-461c-92dd-518cf7a58457.sql =====

-- Admin-configurable OTP channel settings (singleton row)
CREATE TABLE public.cancellation_otp_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email_enabled boolean NOT NULL DEFAULT true,
  sms_enabled boolean NOT NULL DEFAULT false,
  whatsapp_enabled boolean NOT NULL DEFAULT false,
  otp_required_for_confirmed boolean NOT NULL DEFAULT true,
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.cancellation_otp_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage OTP settings"
  ON public.cancellation_otp_settings FOR ALL
  USING (has_role(auth.uid(), 'admin'::app_role))
  WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Anyone can read OTP settings"
  ON public.cancellation_otp_settings FOR SELECT
  USING (true);

-- Insert default row
INSERT INTO public.cancellation_otp_settings (email_enabled, sms_enabled, whatsapp_enabled, otp_required_for_confirmed)
VALUES (true, false, false, true);

-- OTP codes table
CREATE TABLE public.cancellation_otps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  appointment_id uuid NOT NULL REFERENCES public.appointments(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  otp_code text NOT NULL,
  channels_used text[] NOT NULL DEFAULT '{}',
  verified boolean NOT NULL DEFAULT false,
  expires_at timestamp with time zone NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.cancellation_otps ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own OTPs"
  ON public.cancellation_otps FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "System can insert OTPs"
  ON public.cancellation_otps FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own OTPs"
  ON public.cancellation_otps FOR UPDATE
  USING (auth.uid() = user_id);

-- ===== 20260301123708_44bf32c1-e5fd-4347-829e-e9fe0ae455a8.sql =====

-- Create a master lab tests catalog that labs can reference
CREATE TABLE public.lab_tests (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'General',
  description TEXT,
  sample_type TEXT DEFAULT 'Blood',
  turnaround_time TEXT DEFAULT '24 hours',
  price NUMERIC NOT NULL DEFAULT 0,
  discount_percent NUMERIC DEFAULT 0,
  is_popular BOOLEAN DEFAULT false,
  requires_fasting BOOLEAN DEFAULT false,
  home_collection BOOLEAN DEFAULT true,
  lab_id UUID NOT NULL REFERENCES public.labs(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.lab_tests ENABLE ROW LEVEL SECURITY;

-- Everyone can view tests
CREATE POLICY "Lab tests viewable by everyone"
ON public.lab_tests FOR SELECT USING (true);

-- Lab admins can manage own tests
CREATE POLICY "Lab admins can manage own tests"
ON public.lab_tests FOR ALL
USING (lab_id IN (SELECT id FROM labs WHERE user_id = auth.uid()))
WITH CHECK (lab_id IN (SELECT id FROM labs WHERE user_id = auth.uid()));

-- Admins can manage all tests
CREATE POLICY "Admins can manage all lab tests"
ON public.lab_tests FOR ALL
USING (has_role(auth.uid(), 'admin'))
WITH CHECK (has_role(auth.uid(), 'admin'));

-- ===== 20260301131003_4a8439fa-4e2d-41cd-95db-0f6b9f87ebbf.sql =====

-- Add home collection fee to lab_tests
ALTER TABLE public.lab_tests ADD COLUMN home_collection_fee numeric DEFAULT 0;

-- ===== 20260301140938_aaf4065e-695c-40a2-b1fe-aa25cad50082.sql =====

-- Add license, GST, and additional document columns to all provider tables

-- Doctors
ALTER TABLE public.doctors ADD COLUMN IF NOT EXISTS license_url text;
ALTER TABLE public.doctors ADD COLUMN IF NOT EXISTS gst_url text;
ALTER TABLE public.doctors ADD COLUMN IF NOT EXISTS additional_docs_urls text[];

-- Hospitals
ALTER TABLE public.hospitals ADD COLUMN IF NOT EXISTS license_url text;
ALTER TABLE public.hospitals ADD COLUMN IF NOT EXISTS gst_url text;
ALTER TABLE public.hospitals ADD COLUMN IF NOT EXISTS additional_docs_urls text[];

-- Labs
ALTER TABLE public.labs ADD COLUMN IF NOT EXISTS license_url text;
ALTER TABLE public.labs ADD COLUMN IF NOT EXISTS gst_url text;
ALTER TABLE public.labs ADD COLUMN IF NOT EXISTS additional_docs_urls text[];

-- Pharmacies
ALTER TABLE public.pharmacies ADD COLUMN IF NOT EXISTS license_url text;
ALTER TABLE public.pharmacies ADD COLUMN IF NOT EXISTS gst_url text;
ALTER TABLE public.pharmacies ADD COLUMN IF NOT EXISTS additional_docs_urls text[];

-- Update certificates bucket RLS to allow all providers to upload (already exists but ensure it works)
-- Drop existing policies and recreate for broader provider access
DO $$
BEGIN
  -- Add INSERT policy for all authenticated users on certificates bucket
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'Providers can upload certificates' AND tablename = 'objects'
  ) THEN
    CREATE POLICY "Providers can upload certificates"
    ON storage.objects FOR INSERT
    WITH CHECK (
      bucket_id = 'certificates' AND auth.uid()::text = (storage.foldername(name))[1]
    );
  END IF;

  -- Add SELECT policy for own files
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'Providers can view own certificates' AND tablename = 'objects'
  ) THEN
    CREATE POLICY "Providers can view own certificates"
    ON storage.objects FOR SELECT
    USING (
      bucket_id = 'certificates' AND auth.uid()::text = (storage.foldername(name))[1]
    );
  END IF;
END $$;

-- ===== 20260301151940_a58d54df-a95e-4174-a1e5-f6e6928e640f.sql =====

-- Reviews table for rating providers
CREATE TABLE public.reviews (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  provider_id UUID NOT NULL,
  provider_type TEXT NOT NULL, -- 'doctor', 'hospital', 'lab', 'pharmacy'
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  appointment_id UUID REFERENCES public.appointments(id),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(user_id, appointment_id)
);

ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view all reviews" ON public.reviews FOR SELECT USING (true);
CREATE POLICY "Users can create own reviews" ON public.reviews FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own reviews" ON public.reviews FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own reviews" ON public.reviews FOR DELETE USING (auth.uid() = user_id);
CREATE POLICY "Admins can manage all reviews" ON public.reviews FOR ALL USING (has_role(auth.uid(), 'admin'::app_role)) WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

-- Account deletion requests table
CREATE TABLE public.account_deletion_requests (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  reason TEXT,
  status TEXT NOT NULL DEFAULT 'pending', -- pending, approved, rejected
  admin_notes TEXT,
  reviewed_by UUID,
  reviewed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

ALTER TABLE public.account_deletion_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own deletion requests" ON public.account_deletion_requests FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can create own deletion requests" ON public.account_deletion_requests FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Admins can manage all deletion requests" ON public.account_deletion_requests FOR ALL USING (has_role(auth.uid(), 'admin'::app_role)) WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

-- Refunds table for tracking refund status
CREATE TABLE public.refunds (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  appointment_id UUID REFERENCES public.appointments(id),
  order_id UUID REFERENCES public.orders(id),
  amount NUMERIC NOT NULL DEFAULT 0,
  reason TEXT,
  status TEXT NOT NULL DEFAULT 'requested', -- requested, processing, completed, rejected
  admin_notes TEXT,
  processed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

ALTER TABLE public.refunds ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own refunds" ON public.refunds FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can create own refunds" ON public.refunds FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Admins can manage all refunds" ON public.refunds FOR ALL USING (has_role(auth.uid(), 'admin'::app_role)) WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

-- Trigger for updated_at on reviews and refunds
CREATE TRIGGER update_reviews_updated_at BEFORE UPDATE ON public.reviews FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_refunds_updated_at BEFORE UPDATE ON public.refunds FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ===== 20260301154839_20b25c6e-fab2-4e72-a411-4c60d5bdebd4.sql =====

-- =============================================
-- 1. PLATFORM COMMISSION CONFIG
-- =============================================
CREATE TABLE public.platform_commission_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_type TEXT NOT NULL, -- 'doctor', 'hospital', 'pharmacy', 'lab'
  service_type TEXT NOT NULL DEFAULT 'appointment', -- 'appointment', 'order', 'ambulance', 'lab_test'
  commission_percent NUMERIC NOT NULL DEFAULT 10,
  flat_fee NUMERIC NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(provider_type, service_type)
);

ALTER TABLE public.platform_commission_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage commission config"
ON public.platform_commission_config FOR ALL
USING (public.has_role(auth.uid(), 'admin'))
WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Providers can view commission config"
ON public.platform_commission_config FOR SELECT
TO authenticated USING (true);

-- Seed default commission rates
INSERT INTO public.platform_commission_config (provider_type, service_type, commission_percent, description) VALUES
('doctor', 'appointment', 10, 'Doctor appointment commission'),
('hospital', 'appointment', 10, 'Hospital appointment commission'),
('hospital', 'ambulance', 5, 'Ambulance trip commission'),
('pharmacy', 'order', 8, 'Pharmacy order commission'),
('lab', 'lab_test', 10, 'Lab test commission');

-- =============================================
-- 2. PROVIDER EARNINGS (unified for doctor/pharmacy/lab)
-- =============================================
CREATE TABLE public.provider_earnings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_type TEXT NOT NULL, -- 'doctor', 'pharmacy', 'lab'
  provider_id UUID NOT NULL,
  reference_type TEXT NOT NULL, -- 'appointment', 'order', 'lab_test'
  reference_id UUID NOT NULL,
  gross_amount NUMERIC NOT NULL DEFAULT 0,
  commission_percent NUMERIC NOT NULL DEFAULT 0,
  commission_amount NUMERIC NOT NULL DEFAULT 0,
  net_amount NUMERIC NOT NULL DEFAULT 0,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(reference_type, reference_id)
);

ALTER TABLE public.provider_earnings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage all provider earnings"
ON public.provider_earnings FOR ALL
USING (public.has_role(auth.uid(), 'admin'))
WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Doctors can view own earnings"
ON public.provider_earnings FOR SELECT
USING (provider_type = 'doctor' AND provider_id IN (
  SELECT id FROM doctors WHERE user_id = auth.uid()
));

CREATE POLICY "Pharmacies can view own earnings"
ON public.provider_earnings FOR SELECT
USING (provider_type = 'pharmacy' AND provider_id IN (
  SELECT id FROM pharmacies WHERE user_id = auth.uid()
));

CREATE POLICY "Labs can view own earnings"
ON public.provider_earnings FOR SELECT
USING (provider_type = 'lab' AND provider_id IN (
  SELECT id FROM labs WHERE user_id = auth.uid()
));

-- =============================================
-- 3. PROVIDER WALLETS
-- =============================================
CREATE TABLE public.provider_wallets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_type TEXT NOT NULL,
  provider_id UUID NOT NULL,
  user_id UUID NOT NULL,
  total_earned NUMERIC NOT NULL DEFAULT 0,
  total_withdrawn NUMERIC NOT NULL DEFAULT 0,
  pending_withdrawal NUMERIC NOT NULL DEFAULT 0,
  available_balance NUMERIC NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(provider_type, provider_id)
);

ALTER TABLE public.provider_wallets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage all wallets"
ON public.provider_wallets FOR ALL
USING (public.has_role(auth.uid(), 'admin'))
WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Providers can view own wallet"
ON public.provider_wallets FOR SELECT
USING (user_id = auth.uid());

-- =============================================
-- 4. PAYOUT REQUESTS
-- =============================================
CREATE TABLE public.payout_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_type TEXT NOT NULL,
  provider_id UUID NOT NULL,
  user_id UUID NOT NULL,
  amount NUMERIC NOT NULL,
