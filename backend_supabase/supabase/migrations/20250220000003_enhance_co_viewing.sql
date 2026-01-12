-- Enhance co-viewing features for parent-child bedtime stories
-- Adds synchronized playback, parent controls, and family story sharing

-- Add columns to family_sessions for enhanced co-viewing
ALTER TABLE family_sessions
ADD COLUMN IF NOT EXISTS parent_joined_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS synchronized_playback BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS parent_controls_enabled BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS interaction_prompts_enabled BOOLEAN DEFAULT FALSE;

-- Create parent_voice_recordings table for parent narration
CREATE TABLE IF NOT EXISTS parent_voice_recordings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    child_profile_id UUID REFERENCES family_profiles(id) ON DELETE SET NULL,
    
    recording_name TEXT NOT NULL,
    audio_url TEXT NOT NULL, -- URL to stored audio file
    duration_seconds INTEGER,
    language TEXT DEFAULT 'en',
    
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create family_story_library table for shared stories
CREATE TABLE IF NOT EXISTS family_story_library (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL, -- Can be parent_user_id or a family group ID
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    
    added_by_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    is_family_favorite BOOLEAN DEFAULT FALSE,
    shared_with_siblings BOOLEAN DEFAULT TRUE,
    
    added_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create sibling_story_references table for stories that reference siblings
CREATE TABLE IF NOT EXISTS sibling_story_references (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    child_profile_id UUID NOT NULL REFERENCES family_profiles(id) ON DELETE CASCADE,
    referenced_sibling_id UUID REFERENCES family_profiles(id) ON DELETE SET NULL,
    
    reference_type TEXT CHECK (reference_type IN ('character', 'mention', 'dedication')),
    reference_text TEXT,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_parent_voice_recordings_parent_user_id ON parent_voice_recordings(parent_user_id);
CREATE INDEX IF NOT EXISTS idx_parent_voice_recordings_child_profile_id ON parent_voice_recordings(child_profile_id);
CREATE INDEX IF NOT EXISTS idx_family_story_library_family_id ON family_story_library(family_id);
CREATE INDEX IF NOT EXISTS idx_family_story_library_session_id ON family_story_library(session_id);
CREATE INDEX IF NOT EXISTS idx_sibling_story_references_session_id ON sibling_story_references(session_id);
CREATE INDEX IF NOT EXISTS idx_sibling_story_references_child_profile_id ON sibling_story_references(child_profile_id);

-- Enable RLS
ALTER TABLE parent_voice_recordings ENABLE ROW LEVEL SECURITY;
ALTER TABLE family_story_library ENABLE ROW LEVEL SECURITY;
ALTER TABLE sibling_story_references ENABLE ROW LEVEL SECURITY;

-- RLS Policies for parent_voice_recordings
CREATE POLICY "Parents can manage own voice recordings"
    ON parent_voice_recordings FOR ALL
    USING (auth.uid() = parent_user_id);

CREATE POLICY "Service role can manage voice recordings"
    ON parent_voice_recordings FOR ALL
    USING (auth.jwt()->>'role' = 'service_role');

-- RLS Policies for family_story_library
CREATE POLICY "Family members can view family story library"
    ON family_story_library FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM family_profiles
            WHERE family_profiles.parent_user_id = family_story_library.family_id
            AND family_profiles.parent_user_id = auth.uid()
        )
        OR added_by_user_id = auth.uid()
    );

CREATE POLICY "Family members can add to library"
    ON family_story_library FOR INSERT
    WITH CHECK (added_by_user_id = auth.uid());

CREATE POLICY "Service role can manage family library"
    ON family_story_library FOR ALL
    USING (auth.jwt()->>'role' = 'service_role');

-- RLS Policies for sibling_story_references
CREATE POLICY "Parents can view sibling references"
    ON sibling_story_references FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM family_profiles
            WHERE family_profiles.id = sibling_story_references.child_profile_id
            AND family_profiles.parent_user_id = auth.uid()
        )
    );

CREATE POLICY "Service role can manage sibling references"
    ON sibling_story_references FOR ALL
    USING (auth.jwt()->>'role' = 'service_role');

-- Function to update updated_at timestamp
CREATE TRIGGER update_parent_voice_recordings_updated_at
    BEFORE UPDATE ON parent_voice_recordings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to get family story library for a child
CREATE OR REPLACE FUNCTION get_family_story_library(p_child_profile_id UUID)
RETURNS TABLE (
    session_id UUID,
    story_text TEXT,
    theme TEXT,
    added_at TIMESTAMPTZ,
    is_family_favorite BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        fsl.session_id,
        s.story_text,
        s.theme,
        fsl.added_at,
        fsl.is_family_favorite
    FROM family_story_library fsl
    JOIN sessions s ON s.id = fsl.session_id
    JOIN family_profiles fp ON fp.id = p_child_profile_id
    WHERE fsl.family_id = fp.parent_user_id
    OR (fsl.shared_with_siblings = TRUE AND EXISTS (
        SELECT 1 FROM family_profiles fp2
        WHERE fp2.parent_user_id = fp.parent_user_id
        AND fp2.id = p_child_profile_id
    ))
    ORDER BY fsl.added_at DESC;
END;
$$ LANGUAGE plpgsql STABLE;

