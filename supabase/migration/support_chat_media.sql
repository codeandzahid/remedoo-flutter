-- Support chat media attachments (admin-controlled PER QUERY).
-- The admin enables uploads inside one specific chat
-- (Admin > Support > open a chat > details), not globally.

ALTER TABLE public.support_messages
  ADD COLUMN IF NOT EXISTS attachment_url TEXT,
  ADD COLUMN IF NOT EXISTS attachment_name TEXT,
  ADD COLUMN IF NOT EXISTS attachment_type TEXT; -- 'image' | 'file'

-- Per-query media permission + limit (default: off, 5 files).
ALTER TABLE public.support_tickets
  ADD COLUMN IF NOT EXISTS media_enabled BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS media_limit INT NOT NULL DEFAULT 5;
