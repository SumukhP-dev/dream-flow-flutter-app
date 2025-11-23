-- Create family_profiles table for child profiles with age-appropriate content filters
-- Supports family mode with co-view functionality for parent-child bedtime stories

CREATE TABLE IF NOT EXISTS family_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    child_name TEXT NOT NULL,
    age INTEGER NOT NULL CHECK (age >= 0 AND age <= 18),
    favorite_characters TEXT[] DEFAULT ARRAY[]::TEXT[],
    preferred_themes TEXT[] DEFAULT ARRAY[]::TEXT[],
    content_filter_level TEXT NOT NULL DEFAULT 'standard' CHECK (content_filter_level IN ('strict', 'standard', 'relaxed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create family_sessions table to track co-view sessions
CREATE TABLE IF NOT EXISTS family_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    parent_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    child_profile_id UUID REFERENCES family_profiles(id) ON DELETE SET NULL,
    co_view_mode BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_family_profiles_parent_user_id ON family_profiles(parent_user_id);
CREATE INDEX IF NOT EXISTS idx_family_profiles_age ON family_profiles(age);
CREATE INDEX IF NOT EXISTS idx_family_sessions_session_id ON family_sessions(session_id);
CREATE INDEX IF NOT EXISTS idx_family_sessions_parent_user_id ON family_sessions(parent_user_id);
CREATE INDEX IF NOT EXISTS idx_family_sessions_child_profile_id ON family_sessions(child_profile_id);

-- Enable RLS
ALTER TABLE family_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE family_sessions ENABLE ROW LEVEL SECURITY;

-- RLS Policies for family_profiles
-- Users can only view/manage their own family profiles
CREATE POLICY "Users can manage own family profiles"
    ON family_profiles FOR ALL
    USING (auth.uid() = parent_user_id);

-- Service role can do everything
CREATE POLICY "Service role can manage family profiles"
    ON family_profiles FOR ALL
    USING (auth.jwt()->>'role' = 'service_role');

-- RLS Policies for family_sessions
-- Users can only view their own family sessions
CREATE POLICY "Users can view own family sessions"
    ON family_sessions FOR SELECT
    USING (auth.uid() = parent_user_id);

-- Service role can do everything
CREATE POLICY "Service role can manage family sessions"
    ON family_sessions FOR ALL
    USING (auth.jwt()->>'role' = 'service_role');

-- Function to update updated_at timestamp
CREATE TRIGGER update_family_profiles_updated_at
    BEFORE UPDATE ON family_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to get content filter level based on age
CREATE OR REPLACE FUNCTION get_content_filter_level(p_age INTEGER)
RETURNS TEXT AS $$
BEGIN
    CASE
        WHEN p_age < 5 THEN RETURN 'strict';
        WHEN p_age < 10 THEN RETURN 'standard';
        ELSE RETURN 'relaxed';
    END CASE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

