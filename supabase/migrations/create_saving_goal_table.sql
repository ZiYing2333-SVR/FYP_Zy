-- Create SavingGoal table for cycle-based automatic deductions
CREATE TABLE IF NOT EXISTS public."SavingGoal" (
  "goalId" character varying NOT NULL,
  "name" character varying NOT NULL,
  "type" character varying NULL,
  "targetAmount" double precision NOT NULL,
  "currentAmount" double precision NOT NULL DEFAULT 0,
  "startDate" date NULL,
  "endDate" date NULL,
  "description" text NULL,
  "status" character varying NULL DEFAULT 'active',
  "cycleStatus" boolean NULL DEFAULT false,
  "cycleFrequency" text NULL,
  "icon" character varying NULL,
  "sourceAcountId" character varying NULL,
  "destAccountId" character varying NOT NULL,
  "linkedAccountId" character varying NOT NULL,
  "userId" character varying NOT NULL,
  "createdAt" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT "SavingGoal_pkey" PRIMARY KEY ("goalId"),
  CONSTRAINT "SavingGoal_destAccountId_fkey" FOREIGN KEY ("destAccountId") 
    REFERENCES "Account" ("accountId") ON UPDATE CASCADE ON DELETE SET NULL,
  CONSTRAINT "SavingGoal_linkedAccountId_fkey" FOREIGN KEY ("linkedAccountId") 
    REFERENCES "Account" ("accountId") ON UPDATE CASCADE ON DELETE SET NULL,
  CONSTRAINT "SavingGoal_sourceAcountId_fkey" FOREIGN KEY ("sourceAcountId") 
    REFERENCES "Account" ("accountId") ON UPDATE CASCADE ON DELETE SET NULL,
  CONSTRAINT "SavingGoal_userId_fkey" FOREIGN KEY ("userId") 
    REFERENCES "User" ("userId") ON UPDATE CASCADE ON DELETE CASCADE
) TABLESPACE pg_default;

-- Create index for querying active cycle-based goals
CREATE INDEX IF NOT EXISTS "idx_saving_goal_user_cycle" 
ON public."SavingGoal"("userId", "cycleStatus", "status");

-- Add column to Transfer table if not exists to track auto-deduction source
ALTER TABLE public."Transfer" 
ADD COLUMN IF NOT EXISTS "savingGoalId" character varying,
ADD COLUMN IF NOT EXISTS "isAutoDeduction" boolean DEFAULT false;

-- Add foreign key for savingGoalId if not exists
ALTER TABLE public."Transfer"
ADD CONSTRAINT "Transfer_savingGoalId_fkey" FOREIGN KEY ("savingGoalId")
REFERENCES "SavingGoal" ("goalId") ON UPDATE CASCADE ON DELETE SET NULL;

-- Enable RLS for SavingGoal table
ALTER TABLE public."SavingGoal" ENABLE ROW LEVEL SECURITY;

-- Create RLS policy for users to view their own saving goals
CREATE POLICY "Users can view own saving goals"
ON public."SavingGoal"
FOR SELECT
TO authenticated
USING ("userId" = auth.uid()::text);

-- Create RLS policy for users to insert their own saving goals
CREATE POLICY "Users can insert own saving goals"
ON public."SavingGoal"
FOR INSERT
TO authenticated
WITH CHECK ("userId" = auth.uid()::text);

-- Create RLS policy for users to update their own saving goals
CREATE POLICY "Users can update own saving goals"
ON public."SavingGoal"
FOR UPDATE
TO authenticated
USING ("userId" = auth.uid()::text);
