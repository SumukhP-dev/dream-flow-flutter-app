-- Migration: Add trial support to subscriptions
-- Description: Adds trial_ends_at and is_trial columns to support 7-day premium trials

-- Add trial columns to subscriptions table
ALTER TABLE subscriptions 
ADD COLUMN IF NOT EXISTS trial_ends_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS is_trial BOOLEAN DEFAULT FALSE;

-- Create index for trial queries
CREATE INDEX IF NOT EXISTS idx_subscriptions_trial_ends_at 
ON subscriptions(trial_ends_at) 
WHERE is_trial = TRUE AND status = 'active';

-- Update get_user_subscription_tier function to include trial logic
CREATE OR REPLACE FUNCTION get_user_subscription_tier(p_user_id UUID)
RETURNS TEXT AS $$
DECLARE
    v_tier TEXT;
    v_trial_ends_at TIMESTAMPTZ;
    v_is_trial BOOLEAN;
BEGIN
    SELECT tier, trial_ends_at, is_trial INTO v_tier, v_trial_ends_at, v_is_trial
    FROM subscriptions
    WHERE user_id = p_user_id
    AND status = 'active'
    AND current_period_end > NOW()
    ORDER BY created_at DESC
    LIMIT 1;
    
    -- If no subscription found, return 'free'
    IF v_tier IS NULL THEN
        RETURN 'free';
    END IF;
    
    -- If trial has expired, return 'free' (unless they have a paid subscription)
    IF v_is_trial = TRUE AND v_trial_ends_at IS NOT NULL AND v_trial_ends_at < NOW() THEN
        -- Check if there's a non-trial subscription
        SELECT tier INTO v_tier
        FROM subscriptions
        WHERE user_id = p_user_id
        AND status = 'active'
        AND is_trial = FALSE
        AND current_period_end > NOW()
        ORDER BY created_at DESC
        LIMIT 1;
        
        RETURN COALESCE(v_tier, 'free');
    END IF;
    
    RETURN COALESCE(v_tier, 'free');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Comment on columns
COMMENT ON COLUMN subscriptions.trial_ends_at IS 'Timestamp when the trial period ends. NULL if not a trial.';
COMMENT ON COLUMN subscriptions.is_trial IS 'Whether this subscription is a trial. Trials automatically convert to free tier when expired.';

