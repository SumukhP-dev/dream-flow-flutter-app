-- Create subscriptions table for managing user subscription tiers
-- Supports Free, Premium, and Family tiers with usage tracking

CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    tier TEXT NOT NULL DEFAULT 'free' CHECK (tier IN ('free', 'premium', 'family')),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'cancelled', 'expired', 'past_due')),
    stripe_subscription_id TEXT UNIQUE,
    stripe_customer_id TEXT,
    revenuecat_user_id TEXT,
    revenuecat_entitlement_id TEXT,
    current_period_start TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    current_period_end TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '1 month'),
    cancel_at_period_end BOOLEAN DEFAULT FALSE,
    cancelled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id)
);

-- Create usage_tracking table for quota enforcement
CREATE TABLE IF NOT EXISTS usage_tracking (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    period_start TIMESTAMPTZ NOT NULL,
    period_end TIMESTAMPTZ NOT NULL,
    period_type TEXT NOT NULL CHECK (period_type IN ('daily', 'weekly', 'monthly')),
    story_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, period_start, period_type)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_tier ON subscriptions(tier);
CREATE INDEX IF NOT EXISTS idx_subscriptions_stripe_subscription_id ON subscriptions(stripe_subscription_id);
CREATE INDEX IF NOT EXISTS idx_usage_tracking_user_id ON usage_tracking(user_id);
CREATE INDEX IF NOT EXISTS idx_usage_tracking_period ON usage_tracking(period_start, period_end, period_type);

-- Enable RLS
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE usage_tracking ENABLE ROW LEVEL SECURITY;

-- RLS Policies for subscriptions
-- Users can only view their own subscription
CREATE POLICY "Users can view own subscription"
    ON subscriptions FOR SELECT
    USING (auth.uid() = user_id);

-- Service role can do everything (for backend operations)
CREATE POLICY "Service role can manage subscriptions"
    ON subscriptions FOR ALL
    USING (auth.jwt()->>'role' = 'service_role');

-- RLS Policies for usage_tracking
-- Users can only view their own usage
CREATE POLICY "Users can view own usage"
    ON usage_tracking FOR SELECT
    USING (auth.uid() = user_id);

-- Service role can do everything
CREATE POLICY "Service role can manage usage"
    ON usage_tracking FOR ALL
    USING (auth.jwt()->>'role' = 'service_role');

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_subscriptions_updated_at
    BEFORE UPDATE ON subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_usage_tracking_updated_at
    BEFORE UPDATE ON usage_tracking
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to get user's current subscription tier
CREATE OR REPLACE FUNCTION get_user_subscription_tier(p_user_id UUID)
RETURNS TEXT AS $$
DECLARE
    v_tier TEXT;
BEGIN
    SELECT tier INTO v_tier
    FROM subscriptions
    WHERE user_id = p_user_id
    AND status = 'active'
    AND current_period_end > NOW()
    ORDER BY created_at DESC
    LIMIT 1;
    
    RETURN COALESCE(v_tier, 'free');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user's story generation quota
CREATE OR REPLACE FUNCTION get_user_story_quota(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
    v_tier TEXT;
BEGIN
    v_tier := get_user_subscription_tier(p_user_id);
    
    CASE v_tier
        WHEN 'free' THEN RETURN 7;  -- 7 stories per week
        WHEN 'premium' THEN RETURN 999999;  -- Unlimited
        WHEN 'family' THEN RETURN 999999;  -- Unlimited
        ELSE RETURN 7;
    END CASE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user's current story count for the period
CREATE OR REPLACE FUNCTION get_user_story_count(p_user_id UUID, p_period_type TEXT DEFAULT 'weekly')
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
    v_period_start TIMESTAMPTZ;
    v_period_end TIMESTAMPTZ;
BEGIN
    -- Calculate period boundaries
    IF p_period_type = 'daily' THEN
        v_period_start := DATE_TRUNC('day', NOW());
        v_period_end := v_period_start + INTERVAL '1 day';
    ELSIF p_period_type = 'weekly' THEN
        v_period_start := DATE_TRUNC('week', NOW());
        v_period_end := v_period_start + INTERVAL '1 week';
    ELSIF p_period_type = 'monthly' THEN
        v_period_start := DATE_TRUNC('month', NOW());
        v_period_end := v_period_start + INTERVAL '1 month';
    END IF;
    
    SELECT COALESCE(story_count, 0) INTO v_count
    FROM usage_tracking
    WHERE user_id = p_user_id
    AND period_type = p_period_type
    AND period_start = v_period_start
    AND period_end = v_period_end;
    
    RETURN COALESCE(v_count, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to increment story count
CREATE OR REPLACE FUNCTION increment_story_count(p_user_id UUID, p_period_type TEXT DEFAULT 'weekly')
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
    v_period_start TIMESTAMPTZ;
    v_period_end TIMESTAMPTZ;
BEGIN
    -- Calculate period boundaries
    IF p_period_type = 'daily' THEN
        v_period_start := DATE_TRUNC('day', NOW());
        v_period_end := v_period_start + INTERVAL '1 day';
    ELSIF p_period_type = 'weekly' THEN
        v_period_start := DATE_TRUNC('week', NOW());
        v_period_end := v_period_start + INTERVAL '1 week';
    ELSIF p_period_type = 'monthly' THEN
        v_period_start := DATE_TRUNC('month', NOW());
        v_period_end := v_period_start + INTERVAL '1 month';
    END IF;
    
    INSERT INTO usage_tracking (user_id, period_start, period_end, period_type, story_count)
    VALUES (p_user_id, v_period_start, v_period_end, p_period_type, 1)
    ON CONFLICT (user_id, period_start, period_type)
    DO UPDATE SET
        story_count = usage_tracking.story_count + 1,
        updated_at = NOW();
    
    SELECT story_count INTO v_count
    FROM usage_tracking
    WHERE user_id = p_user_id
    AND period_start = v_period_start
    AND period_end = v_period_end
    AND period_type = p_period_type;
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

