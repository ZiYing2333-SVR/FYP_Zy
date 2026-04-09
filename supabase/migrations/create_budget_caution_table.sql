-- Supabase SQL Migration: Create BudgetCaution Table
-- This table tracks dismissed budget alerts:
-- 1. Caution alerts (when budget usage >= 70%)
-- 2. Exceed alerts (when budget usage > 100%)

-- Create BudgetCaution table
CREATE TABLE IF NOT EXISTS public."BudgetCaution" (
  "cautionId" UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  "budgetId" character varying NOT NULL,
  "userId" character varying NOT NULL,
  
  -- Caution alert fields (70-99% usage)
  "dismissed" BOOLEAN DEFAULT false,
  "dismissedAt" TIMESTAMP WITH TIME ZONE,
  
  -- Exceed alert fields (>100% usage)
  "exceedDismissed" BOOLEAN DEFAULT false,
  "exceedDismissedAt" TIMESTAMP WITH TIME ZONE,
  
  "createdAt" TIMESTAMP WITH TIME ZONE DEFAULT now(),
  "updatedAt" TIMESTAMP WITH TIME ZONE DEFAULT now(),
  
  -- Foreign key constraints
  CONSTRAINT fk_budget_caution_budget FOREIGN KEY ("budgetId") REFERENCES public."Budget"("budgetId") ON DELETE CASCADE,
  CONSTRAINT fk_budget_caution_user FOREIGN KEY ("userId") REFERENCES public."User"("userId") ON DELETE CASCADE,
  
  -- Unique constraint to prevent duplicate records per budget
  CONSTRAINT unique_budget_caution UNIQUE("budgetId", "userId")
) TABLESPACE pg_default;

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_budget_caution_budget ON public."BudgetCaution"("budgetId");
CREATE INDEX IF NOT EXISTS idx_budget_caution_user ON public."BudgetCaution"("userId");
CREATE INDEX IF NOT EXISTS idx_budget_caution_dismissed ON public."BudgetCaution"("dismissed");
CREATE INDEX IF NOT EXISTS idx_budget_caution_exceed_dismissed ON public."BudgetCaution"("exceedDismissed");

-- Add comment to the table
COMMENT ON TABLE public."BudgetCaution" IS 'Tracks dismissed budget alerts: caution (70-99%) and exceed (>100%). Dismissals auto-reset when budget cycle renews or status changes.';

