-- Support chat media attachments (admin-controlled).
-- Users may attach images/PDFs in the support chat only when the
-- admin enables it in Admin > Settings > Support Chat
-- (app_config key 'support_chat': {media_enabled, media_per_ticket}).

ALTER TABLE public.support_messages
  ADD COLUMN IF NOT EXISTS attachment_url TEXT,
  ADD COLUMN IF NOT EXISTS attachment_name TEXT,
  ADD COLUMN IF NOT EXISTS attachment_type TEXT; -- 'image' | 'file'

-- Default: media OFF, limit 5 per ticket, until the admin enables it.
INSERT INTO public.app_config (key, value)
VALUES ('support_chat',
        '{"media_enabled": false, "media_per_ticket": 5}'::jsonb)
ON CONFLICT (key) DO NOTHING;
