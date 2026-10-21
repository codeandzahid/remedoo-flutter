-- Audit-76 Batch 8 (Admin gap 28): approval decisions left no
-- audit trail — the applications table recorded WHEN a decision
-- happened (decided_at) but not WHO made it. Adds the reviewer
-- column; the app stamps it on every approve/reject and falls
-- back gracefully until this runs.

ALTER TABLE public.provider_applications
  ADD COLUMN IF NOT EXISTS decided_by UUID;
