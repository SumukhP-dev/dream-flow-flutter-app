-- Enhanced Parental Controls for Kids Bedtime Stories
-- Adds bedtime schedules, screen time limits, content review, and usage tracking

-- Create parental_settings table for parent-specific controls
CREATE TABLE IF NOT EXISTS parental_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    child_profile_id UUID NOT NULL REFERENCES family_profiles(id) ON DELETE CASCADE,
    
    -- Bedtime schedule
    bedtime_hour INTEGER CHECK (bedtime_hour >= 0 AND bedtime_hour <= 23),
    bedtime_minute INTEGER CHECK (bedtime_minute >= 0 AND bedtime_minute <= 59),
    bedtime_enabled BOOLEAN DEFAULT FALSE,
    
    -- Screen time limits
    daily_screen_time_minutes INTEGER CHECK (daily_screen_time_minutes > 0),
    screen_time_enabled BOOLEAN DEFAULT FALSE,
    
    -- Content controls
    require_story_approval BOOLEAN DEFAULT FALSE,
    blocked_themes TEXT[] DEFAULT ARRAY[]::TEXT[],
    blocked_characters TEXT[] DEFAULT ARRAY[]::TEXT[],
    max_story_length_minutes INTEGER CHECK (max_story_length_minutes > 0),
    
    -- Emergency notifications
    emergency_notification_enabled BOOLEAN DEFAULT TRUE,
    emergency_contact_email TEXT,
    
    -- Usage tracking
    track_usage BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(parent_user_id, child_profile_id)
);

-- Create content_review_queue table for story approval
CREATE TABLE IF NOT EXISTS content_review_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    child_profile_id UUID NOT NULL REFERENCES family_profiles(id) ON DELETE CASCADE,
    parent_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    story_text TEXT NOT NULL,
    theme TEXT NOT NULL,
    content_rating TEXT CHECK (content_rating IN ('G', 'PG', 'PG-13', 'R')),
    suggested_age_min INTEGER,
    suggested_age_max INTEGER,
    
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'auto_approved')),
    rejection_reason TEXT,
    
    reviewed_at TIMESTAMPTZ,
    reviewed_by UUID REFERENCES auth.users(id),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create child_usage_reports table for parent visibility
CREATE TABLE IF NOT EXISTS child_usage_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    child_profile_id UUID NOT NULL REFERENCES family_profiles(id) ON DELETE CASCADE,
    parent_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    report_date DATE NOT NULL,
    
    -- Daily stats
    stories_viewed INTEGER DEFAULT 0,
    total_viewing_time_minutes INTEGER DEFAULT 0,
    favorite_themes TEXT[] DEFAULT ARRAY[]::TEXT[],
    favorite_characters TEXT[] DEFAULT ARRAY[]::TEXT[],
    
    -- Bedtime compliance
    bedtime_compliance BOOLEAN,
    stories_after_bedtime INTEGER DEFAULT 0,
    
    -- Screen time
    screen_time_used_minutes INTEGER DEFAULT 0,
    screen_time_limit_minutes INTEGER,
    screen_time_exceeded BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(child_profile_id, report_date)
);

-- Create bedtime_routines table for routine management
CREATE TABLE IF NOT EXISTS bedtime_routines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    child_profile_id UUID REFERENCES family_profiles(id) ON DELETE SET NULL,
    
    routine_name TEXT NOT NULL,
    routine_steps JSONB NOT NULL, -- Array of {step: string, order: int, duration_minutes: int}
    is_active BOOLEAN DEFAULT TRUE,
    is_family_routine BOOLEAN DEFAULT FALSE, -- If true, applies to all children
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_parental_settings_parent_user_id ON parental_settings(parent_user_id);
CREATE INDEX IF NOT EXISTS idx_parental_settings_child_profile_id ON parental_settings(child_profile_id);
CREATE INDEX IF NOT EXISTS idx_content_review_queue_parent_user_id ON content_review_queue(parent_user_id);
CREATE INDEX IF NOT EXISTS idx_content_review_queue_child_profile_id ON content_review_queue(child_profile_id);
CREATE INDEX IF NOT EXISTS idx_content_review_queue_status ON content_review_queue(status);
CREATE INDEX IF NOT EXISTS idx_content_review_queue_session_id ON content_review_queue(session_id);
CREATE INDEX IF NOT EXISTS idx_child_usage_reports_child_profile_id ON child_usage_reports(child_profile_id);
CREATE INDEX IF NOT EXISTS idx_child_usage_reports_parent_user_id ON child_usage_reports(parent_user_id);
CREATE INDEX IF NOT EXISTS idx_child_usage_reports_report_date ON child_usage_reports(report_date);
CREATE INDEX IF NOT EXISTS idx_bedtime_routines_parent_user_id ON bedtime_routines(parent_user_id);
CREATE INDEX IF NOT EXISTS idx_bedtime_routines_child_profile_id ON bedtime_routines(child_profile_id);

-- Enable RLS
ALTER TABLE parental_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_review_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE child_usage_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE bedtime_routines ENABLE ROW LEVEL SECURITY;

-- RLS Policies for parental_settings
CREATE POLICY "Parents can manage own parental settings"
    ON parental_settings FOR ALL
    USING (auth.uid() = parent_user_id);

CREATE POLICY "Service role can manage parental settings"
    ON parental_settings FOR ALL
    USING (auth.jwt()->>'role' = 'service_role');

-- RLS Policies for content_review_queue
CREATE POLICY "Parents can view own review queue"
    ON content_review_queue FOR SELECT
    USING (auth.uid() = parent_user_id);

CREATE POLICY "Parents can update own review queue"
    ON content_review_queue FOR UPDATE
    USING (auth.uid() = parent_user_id);

CREATE POLICY "Service role can manage review queue"
    ON content_review_queue FOR ALL
    USING (auth.jwt()->>'role' = 'service_role');

-- RLS Policies for child_usage_reports
CREATE POLICY "Parents can view own child usage reports"
    ON child_usage_reports FOR SELECT
    USING (auth.uid() = parent_user_id);

CREATE POLICY "Service role can manage usage reports"
    ON child_usage_reports FOR ALL
    USING (auth.jwt()->>'role' = 'service_role');

-- RLS Policies for bedtime_routines
CREATE POLICY "Parents can manage own bedtime routines"
    ON bedtime_routines FOR ALL
    USING (auth.uid() = parent_user_id);

CREATE POLICY "Service role can manage bedtime routines"
    ON bedtime_routines FOR ALL
    USING (auth.jwt()->>'role' = 'service_role');

-- Function to update updated_at timestamp
CREATE TRIGGER update_parental_settings_updated_at
    BEFORE UPDATE ON parental_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_content_review_queue_updated_at
    BEFORE UPDATE ON content_review_queue
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_child_usage_reports_updated_at
    BEFORE UPDATE ON child_usage_reports
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_bedtime_routines_updated_at
    BEFORE UPDATE ON bedtime_routines
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to check if story needs approval
CREATE OR REPLACE FUNCTION needs_story_approval(
    p_child_profile_id UUID,
    p_session_id UUID
) RETURNS BOOLEAN AS $$
DECLARE
    v_require_approval BOOLEAN;
BEGIN
    SELECT require_story_approval INTO v_require_approval
    FROM parental_settings
    WHERE child_profile_id = p_child_profile_id
    LIMIT 1;
    
    RETURN COALESCE(v_require_approval, FALSE);
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to check bedtime compliance
CREATE OR REPLACE FUNCTION is_within_bedtime(
    p_child_profile_id UUID,
    p_check_time TIMESTAMPTZ DEFAULT NOW()
) RETURNS BOOLEAN AS $$
DECLARE
    v_bedtime_enabled BOOLEAN;
    v_bedtime_hour INTEGER;
    v_bedtime_minute INTEGER;
    v_check_hour INTEGER;
    v_check_minute INTEGER;
BEGIN
    SELECT bedtime_enabled, bedtime_hour, bedtime_minute
    INTO v_bedtime_enabled, v_bedtime_hour, v_bedtime_minute
    FROM parental_settings
    WHERE child_profile_id = p_child_profile_id
    LIMIT 1;
    
    IF NOT COALESCE(v_bedtime_enabled, FALSE) THEN
        RETURN TRUE; -- No bedtime restriction
    END IF;
    
    v_check_hour := EXTRACT(HOUR FROM p_check_time)::INTEGER;
    v_check_minute := EXTRACT(MINUTE FROM p_check_time)::INTEGER;
    
    -- Check if current time is before bedtime
    IF v_check_hour < v_bedtime_hour OR 
       (v_check_hour = v_bedtime_hour AND v_check_minute < v_bedtime_minute) THEN
        RETURN TRUE;
    END IF;
    
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to check screen time limits
CREATE OR REPLACE FUNCTION check_screen_time_limit(
    p_child_profile_id UUID,
    p_check_date DATE DEFAULT CURRENT_DATE
) RETURNS BOOLEAN AS $$
DECLARE
    v_screen_time_enabled BOOLEAN;
    v_daily_limit INTEGER;
    v_used_minutes INTEGER;
BEGIN
    SELECT screen_time_enabled, daily_screen_time_minutes
    INTO v_screen_time_enabled, v_daily_limit
    FROM parental_settings
    WHERE child_profile_id = p_child_profile_id
    LIMIT 1;
    
    IF NOT COALESCE(v_screen_time_enabled, FALSE) THEN
        RETURN TRUE; -- No screen time restriction
    END IF;
    
    SELECT COALESCE(screen_time_used_minutes, 0) INTO v_used_minutes
    FROM child_usage_reports
    WHERE child_profile_id = p_child_profile_id
    AND report_date = p_check_date
    LIMIT 1;
    
    RETURN v_used_minutes < v_daily_limit;
END;
$$ LANGUAGE plpgsql STABLE;










































