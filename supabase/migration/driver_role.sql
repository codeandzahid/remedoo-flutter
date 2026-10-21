-- Form-pages audit Panelist 9 / M19: the driver dashboard
-- existed but no account could ever hold a driver role — the
-- app_role enum had no 'driver' value, so PartnerRootGate could
-- never route one. Follows the provider_roles.sql pattern.
-- delivery_drivers / delivery_orders tables and their driver
-- RLS policies already exist (schema_part_04).
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'driver' AND enumtypid = 'public.app_role'::regtype) THEN
    ALTER TYPE public.app_role ADD VALUE 'driver';
  END IF;
END
$$;
