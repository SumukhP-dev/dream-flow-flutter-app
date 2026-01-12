-- Update get_user_story_quota function to return unlimited for free tier
-- Free tier now has unlimited stories with ads, paid tiers have unlimited without ads

CREATE OR REPLACE FUNCTION get_user_story_quota(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
    v_tier TEXT;
BEGIN
    v_tier := get_user_subscription_tier(p_user_id);
    
    CASE v_tier
        WHEN 'free' THEN RETURN 999999;  -- Unlimited (with ads)
        WHEN 'premium' THEN RETURN 999999;  -- Unlimited (no ads)
        WHEN 'family' THEN RETURN 999999;  -- Unlimited (no ads)
        ELSE RETURN 999999;  -- Default to unlimited
    END CASE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

