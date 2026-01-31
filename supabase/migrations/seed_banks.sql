-- Supabase SQL Migration: Create and Seed Bank Table
-- Run this in your Supabase SQL Editor

-- Create Bank table
CREATE TABLE IF NOT EXISTS public."Bank" (
  "bankId" character varying NOT NULL,
  "bankName" character varying NOT NULL,
  "bankType" character varying NULL DEFAULT 'Local',
  "bankIcon" character varying NULL,
  constraint "Bank_pkey" primary key ("bankId")
) TABLESPACE pg_default;

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_bank_type ON public."Bank" ("bankType");
CREATE INDEX IF NOT EXISTS idx_bank_name ON public."Bank" ("bankName");

-- Seed Local Banks
INSERT INTO public."Bank" ("bankId", "bankName", "bankType", "bankIcon") VALUES
  ('LOCAL_AFFIN', 'Affin Bank', 'Local', 'AFFINBANK.png'),
  ('LOCAL_ALLIANCE', 'Alliance Bank', 'Local', 'ALLIANCEBANK.png'),
  ('LOCAL_AM', 'AM Bank', 'Local', 'AMBANK.png'),
  ('LOCAL_CIMB', 'CIMB Bank', 'Local', 'CIMBBANK.png'),
  ('LOCAL_HLB', 'Hong Leong Bank', 'Local', 'HONGLEONGBANK.png'),
  ('LOCAL_MAYBANK', 'Maybank', 'Local', 'MAYBANK.png'),
  ('LOCAL_PUBLICBANK', 'Public Bank', 'Local', 'PUBLICBANK.png'),
  ('LOCAL_RHB', 'RHB', 'Local', 'RHB.png')
ON CONFLICT DO NOTHING;

-- Seed Islamic Banks
INSERT INTO public."Bank" ("bankId", "bankName", "bankType", "bankIcon") VALUES
  ('ISLAMIC_AFFIN', 'Affin Islamic Bank', 'Islamic', 'AffinIslamicBank.png'),
  ('ISLAMIC_ALLIANCE', 'Alliance Islamic Bank', 'Islamic', 'AllianceIslamicBank.png'),
  ('ISLAMIC_AMBANK', 'AmBank Islamic', 'Islamic', 'AmBankIslamic.png'),
  ('ISLAMIC_BANKISLAM', 'Bank Islam', 'Islamic', 'bankIslam.png'),
  ('ISLAMIC_MUAMALAT', 'Bank Muamalat', 'Islamic', 'BankMuamalat.png'),
  ('ISLAMIC_CIMB', 'CIMB Islamic', 'Islamic', 'CIMBIslamic.png'),
  ('ISLAMIC_HLB', 'Hong Leong Islamic', 'Islamic', 'HongLeongIslamic.jpg'),
  ('ISLAMIC_MAYBANK', 'Maybank Islamic', 'Islamic', 'MaybankIslamic.png'),
  ('ISLAMIC_PUBLICBANK', 'Public Islamic Bank', 'Islamic', 'PublicIslamicBank.png'),
  ('ISLAMIC_RHB', 'RHB Islamic Bank', 'Islamic', 'RHBIslamicBank.jpg')
ON CONFLICT DO NOTHING;

-- Seed Foreign Banks
INSERT INTO public."Bank" ("bankId", "bankName", "bankType", "bankIcon") VALUES
  ('FOREIGN_ABC', 'Agricultural Bank of China', 'Foreign', 'AgriculturalBankofChina.png'),
  ('FOREIGN_BOA_MY', 'Bank of America Malaysia', 'Foreign', 'BankofAmericaMalaysia.png'),
  ('FOREIGN_BOC', 'Bank of China', 'Foreign', 'BankofChina.png'),
  ('FOREIGN_BOCM', 'Bank of Communication', 'Foreign', 'BankOfCommunication.png'),
  ('FOREIGN_BARCLAYS', 'Barclays Bank', 'Foreign', 'BarclaysBank.png'),
  ('FOREIGN_BNPPARIBAS', 'BNP Paribas Malaysia', 'Foreign', 'BNPParibasMalaysia.png'),
  ('FOREIGN_BNYMELLON', 'BNY Mellon', 'Foreign', 'BNYMellon.png'),
  ('FOREIGN_CCB', 'CCB Bank', 'Foreign', 'CCBBank.png'),
  ('FOREIGN_CITIBANK', 'Citibank', 'Foreign', 'Citibank.png'),
  ('FOREIGN_COMMERZBANK', 'Commerzbank', 'Foreign', 'Commerzbank.png'),
  ('FOREIGN_CREDITAGRICOLE', 'Credit Agricole', 'Foreign', 'CreditAgricole.png'),
  ('FOREIGN_DBS', 'DBS Bank', 'Foreign', 'DBSBank.png'),
  ('FOREIGN_DEUTSCHEBANK', 'Deutsche Bank', 'Foreign', 'DeutscheBank.png'),
  ('FOREIGN_DBJAPAN', 'Development Bank of Japan', 'Foreign', 'DevelopmentBankofJapan.png'),
  ('FOREIGN_GOLDMANSACHS', 'Goldman Sachs', 'Foreign', 'GoldmanSachs.png'),
  ('FOREIGN_HSBC', 'HSBC Bank', 'Foreign', 'HSBCBank.png'),
  ('FOREIGN_ICBC', 'ICBC Bank', 'Foreign', 'ICBCBank.png'),
  ('FOREIGN_JPMORGAN', 'J.P. Morgan Chase Bank', 'Foreign', 'J.P.MorganChaseBank.png'),
  ('FOREIGN_LLOYDS', 'Lloyds Bank', 'Foreign', 'LloydsBank.png'),
  ('FOREIGN_MIZUHO', 'Mizuho Bank', 'Foreign', 'MizuhoBank.png'),
  ('FOREIGN_MORGANSTANLEY', 'Morgan Stanley', 'Foreign', 'MorganStanley.png'),
  ('FOREIGN_MUFG', 'MUFG Bank', 'Foreign', 'MUFGBank.png'),
  ('FOREIGN_NATWEST', 'NatWest Group', 'Foreign', 'NatWestGroup.png'),
  ('FOREIGN_OCBC', 'Oversea Chinese Banking Corporation', 'Foreign', 'OverseaChineseBankingCorporation.webp'),
  ('FOREIGN_PNC', 'PNC Bank', 'Foreign', 'PNCBank.png'),
  ('FOREIGN_SOCIETEGENERALE', 'Societe Generale', 'Foreign', 'SociétéGénérale.png'),
  ('FOREIGN_STANDARDCHARTERED', 'Standard Chartered Bank', 'Foreign', 'StandardCharteredBank.png'),
  ('FOREIGN_SUMITOMOMITSUI', 'Sumitomo Mitsui Banking Corporation Malaysia', 'Foreign', 'SumitomoMitsuiBankingCorporationMalaysia.png'),
  ('FOREIGN_USBANK', 'U.S. Bank', 'Foreign', 'U.S.Bank.png'),
  ('FOREIGN_UBS', 'UBS', 'Foreign', 'UBS.png'),
  ('FOREIGN_UOB', 'United Overseas Bank', 'Foreign', 'UnitedOverseasBank.png'),
  ('FOREIGN_WELLSFARGO', 'Wells Fargo', 'Foreign', 'WellsFargo.png')
ON CONFLICT DO NOTHING;
