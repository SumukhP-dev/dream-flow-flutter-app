-- Enhance family subscription features
-- Adds per-child usage tracking, family subscription management, and gift subscriptions

-- Add columns to subscriptions for family features
ALTER TABLE subscriptions
ADD COLUMN IF NOT EXISTS is_family_plan BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS max_family_members INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS gift_subscription BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS gifted_by_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS gift_recipient_email TEXT;

-- Create per_child_usage table for tracking usage per child in family plans
CREATE TABLE IF NOT EXISTS per_child_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
    child_profile_id UUID NOT NULL REFERENCES family_profiles(id) ON DELETE CASCADE,
    
    stories_generated_today INTEGER DEFAULT 0,
    stories_generated_this_week INTEGER DEFAULT 0,
    stories_generated_this_month INTEGER DEFAULT 0,
    
    last_story_date DATE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(subscription_id, child_profile_id)
);

-- Create gift_subscriptions table for gift subscription management
CREATE TABLE IF NOT EXISTS gift_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    gift_code TEXT UNIQUE NOT NULL,
    gifter_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    recipient_email TEXT NOT NULL,
    
    subscription_tier TEXT NOT NULL CHECK (subscription_tier IN ('premium', 'family')),
    duration_months INTEGER NOT NULL DEFAULT 12,
    
    redeemed BOOLEAN DEFAULT FALSE,
    redeemed_by_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    redeemed_at TIMESTAMPTZ,
    
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_per_child_usage_subscription_id ON per_child_usage(subscription_id);
CREATE INDEX IF NOT EXISTS idx_per_child_usage_child_profile_id ON per_child_usage(child_profile_id);
CREATE INDEX IF NOT EXISTS idx_gift_subscriptions_gift_code ON gift_subscriptions(gift_code);
CREATE INDEX IF NOT EXISTS idx_gift_subscriptions_gifter_user_id ON gift_subscriptions(gifter_user_id);
CREATE INDEX IF NOT EXISTS idx_gift_subscriptions_recipient_email ON gift_subscriptions(recipient_email);

-- Enable RLS
ALTER TABLE per_child_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE gift_subscriptions ENABLE ROW LEVEL SECURITY;

-- RLS Policies for per_child_usage
CREATE POLICY "Parents can view own child usage"
    ON per_child_usage FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM subscriptions s
            JOIN family_profiles fp ON fp.id = per_child_usage.child_profile_id
            WHERE s.id = per_child_usage.subscription_id
            AND fp.parent_user_id = auth.uid()
        )
    );

CREATE POLICY "Service role can manage child usage"
    ON per_child_usage FOR ALL
    USING (auth.jwt()->>'role' = 'service_role');

-- RLS Policies for gift_subscriptions
CREATE POLICY "Users can view own gift subscriptions"
    ON gift_subscriptions FOR SELECT
    USING (
        gifter_user_id = auth.uid()
        OR (redeemed_by_user_id = auth.uid())
        OR recipient_email = (SELECT email FROM auth.users WHERE id = auth.uid())
    );

CREATE POLICY "Service role can manage gift subscriptions"
    ON gift_subscriptions FOR ALL
    USING (auth.jwt()->>'role' = 'service_role');

-- Function to track per-child usage
CREATE OR REPLACE FUNCTION track_child_story_generation(
    p_subscription_id UUID,
    p_child_profile_id UUID
) RETURNS VOID AS $$
DECLARE
    v_today DATE := CURRENT_DATE;
    v_week_start DATE := DATE_TRUNC('week', CURRENT_DATE)::DATE;
    v_month_start DATE := DATE_TRUNC('month', CURRENT_DATE)::DATE;
BEGIN
    INSERT INTO per_child_usage (
        subscription_id,
        child_profile_id,
        stories_generated_today,
        stories_generated_this_week,
        stories_generated_this_month,
        last_story_date,
        updated_at
    )
    VALUES (
        p_subscription_id,
        p_child_profile_id,
        1,
        1,
        1,
        v_today,
        NOW()
    )
    ON CONFLICT (subscription_id, child_profile_id) DO UPDATE SET
        stories_generated_today = CASE
            WHEN per_child_usage.last_story_date = v_today
            THEN per_child_usage.stories_generated_today + 1
            ELSE 1
        END,
        stories_generated_this_week = CASE
            WHEN per_child_usage.last_story_date >= v_week_start
            THEN per_child_usage.stories_generated_this_week + 1
            ELSE 1
        END,
        stories_generated_this_month = CASE
            WHEN per_child_usage.last_story_date >= v_month_start
            THEN per_child_usage.stories_generated_this_month + 1
            ELSE 1
        END,
        last_story_date = v_today,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- Function to get family subscription summary
CREATE OR REPLACE FUNCTION get_family_subscription_summary(p_subscription_id UUID)
RETURNS TABLE (
    total_children INTEGER,
    total_stories_today INTEGER,
    total_stories_this_week INTEGER,
    total_stories_this_month INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(DISTINCT pc.child_profile_id)::INTEGER as total_children,
        COALESCE(SUM(pc.stories_generated_today), 0)::INTEGER as total_stories_today,
        COALESCE(SUM(pc.stories_generated_this_week), 0)::INTEGER as total_stories_this_week,
        COALESCE(SUM(pc.stories_generated_this_month), 0)::INTEGER as total_stories_this_month
    FROM per_child_usage pc
    WHERE pc.subscription_id = p_subscription_id;
END;
$$ LANGUAGE plpgsql STABLE;

