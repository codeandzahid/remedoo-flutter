-- Theme packs: admin-controlled availability of the 6 app themes.
-- The app fetches enabled packs at boot; users pick from those in
-- Settings > Appearance. Sky Pulse is the primary theme and cannot be disabled.

CREATE TABLE IF NOT EXISTS public.theme_packs (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT true,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

ALTER TABLE public.theme_packs ENABLE ROW LEVEL SECURITY;

-- Everyone (including guests/anon) can read theme availability.
DROP POLICY IF EXISTS "Anyone can view theme packs" ON public.theme_packs;
CREATE POLICY "Anyone can view theme packs"
  ON public.theme_packs FOR SELECT
  USING (true);

-- Only admins can change theme availability.
DROP POLICY IF EXISTS "Admins can manage theme packs" ON public.theme_packs;
CREATE POLICY "Admins can manage theme packs"
  ON public.theme_packs FOR ALL
  USING (public.has_role(auth.uid(), 'admin'))
  WITH CHECK (public.has_role(auth.uid(), 'admin'));

-- Seed the 6 themes (Sky Pulse first, marked primary).
INSERT INTO public.theme_packs (id, name, enabled, is_primary, sort_order)
VALUES
  ('sky_pulse', 'Sky Pulse', true, true, 1),
  ('ocean_sand', 'Ocean Sand', true, false, 2),
  ('lavender_mist', 'Lavender Mist', true, false, 3),
  ('blush_rose', 'Blush Rose', true, false, 4),
  ('honey_glow', 'Honey Glow', true, false, 5),
  ('emerald_heal', 'Emerald Heal', true, false, 6)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  is_primary = EXCLUDED.is_primary,
  sort_order = EXCLUDED.sort_order;

-- Guard: the primary theme can never be disabled.
CREATE OR REPLACE FUNCTION public.prevent_primary_theme_disable()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_primary AND NEW.enabled = false THEN
    RAISE EXCEPTION 'The primary theme cannot be disabled';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prevent_primary_theme_disable ON public.theme_packs;
CREATE TRIGGER trg_prevent_primary_theme_disable
  BEFORE UPDATE ON public.theme_packs
  FOR EACH ROW EXECUTE FUNCTION public.prevent_primary_theme_disable();

-- Per-user theme choice, synced across web + app via Realtime.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS theme_pack TEXT NOT NULL DEFAULT 'sky_pulse';
