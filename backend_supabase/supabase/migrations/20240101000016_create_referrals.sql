-- Migration: Create referrals table for referral program
-- Description: Tracks referrals between users for viral growth

CREATE TABLE IF NOT EXISTS referrals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    referrer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    referee_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    referral_code TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'expired')),
    referrer_reward_given BOOLEAN DEFAULT FALSE,
    referee_trial_given BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    UNIQUE(referee_id)  -- Each user can only be referred once
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_referrals_referrer_id ON referrals(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referee_id ON referrals(referee_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referral_code ON referrals(referral_code);
CREATE INDEX IF NOT EXISTS idx_referrals_status ON referrals(status);

-- Enable RLS
ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can view their own referrals (as referrer or referee)
CREATE POLICY "Users can view own referrals"
    ON referrals FOR SELECT
    USING (
        auth.uid() = referrer_id OR 
        auth.uid() = referee_id
    );

-- Service role can do everything
CREATE POLICY "Service role can manage referrals"
    ON referrals FOR ALL
    USING (true)
    WITH CHECK (true);

-- Add referral_code column to profiles table (for storing user's referral code)
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS referral_code TEXT UNIQUE;

-- Generate referral codes for existing users (optional, can be done via application)
-- CREATE OR REPLACE FUNCTION generate_referral_code() RETURNS TEXT AS $$
-- BEGIN
--     RETURN upper(substring(md5(random()::text || clock_timestamp()::text) from 1 for 8));
-- END;
-- $$ LANGUAGE plpgsql;

-- Create index on profiles.referral_code
CREATE INDEX IF NOT EXISTS idx_profiles_referral_code ON profiles(referral_code);

COMMENT ON TABLE referrals IS 'Tracks referral relationships between users';
COMMENT ON COLUMN referrals.referrer_id IS 'User who made the referral';
COMMENT ON COLUMN referrals.referee_id IS 'User who was referred';
COMMENT ON COLUMN referrals.referral_code IS 'Unique referral code used';
COMMENT ON COLUMN referrals.status IS 'Status: pending (referee signed up), completed (referee converted to paid), expired';
COMMENT ON COLUMN referrals.referrer_reward_given IS 'Whether referrer has received their 1 week Premium reward';
COMMENT ON COLUMN referrals.referee_trial_given IS 'Whether referee has received their 7-day Premium trial';

