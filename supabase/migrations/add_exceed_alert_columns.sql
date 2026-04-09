-- Supabase SQL Migration: Add Exceed Alert Columns to BudgetCaution
-- This migration adds support for tracking exceed alerts (>100% budget usage)

-- Add new columns for exceed alerts if they don't already exist
ALTER TABLE IF EXISTS public."BudgetCaution"
ADD COLUMN IF NOT EXISTS "exceedDismissed" BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS "exceedDismissedAt" TIMESTAMP WITH TIME ZONE;

-- Create index for exceed dismissal lookups
CREATE INDEX IF NOT EXISTS idx_budget_caution_exceed_dismissed ON public."BudgetCaution"("exceedDismissed");

-- Update table comment
COMMENT ON COLUMN public."BudgetCaution"."exceedDismissed" IS 'Whether the exceed alert (>100% usage) has been dismissed';
COMMENT ON COLUMN public."BudgetCaution"."exceedDismissedAt" IS 'When the exceed alert was dismissed';
