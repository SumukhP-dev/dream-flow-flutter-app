-- Create kid-friendly achievement system
-- Supports badges, milestones, and story collections for children

CREATE TABLE IF NOT EXISTS kid_achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    child_profile_id UUID NOT NULL REFERENCES family_profiles(id) ON DELETE CASCADE,
    
    achievement_type TEXT NOT NULL CHECK (achievement_type IN (
        'first_story', 'ten_stories', 'perfect_week', 'bedtime_streak_7',
        'bedtime_streak_30', 'bedtime_streak_100', 'favorite_character',
        'story_collector', 'routine_master', 'early_sleeper'
    )),
    
    achievement_name TEXT NOT NULL,
    achievement_description TEXT,
    badge_emoji TEXT NOT NULL, -- Emoji for the badge (⭐, 🎉, 🏆, etc.)
    unlocked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(child_profile_id, achievement_type)
);

-- Create story_collections table for kids to collect favorite stories
CREATE TABLE IF NOT EXISTS story_collections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    child_profile_id UUID NOT NULL REFERENCES family_profiles(id) ON DELETE CASCADE,
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    
    collection_name TEXT, -- Optional: kids can name their collections
    is_favorite BOOLEAN DEFAULT FALSE,
    added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(child_profile_id, session_id)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_kid_achievements_child_profile_id ON kid_achievements(child_profile_id);
CREATE INDEX IF NOT EXISTS idx_kid_achievements_type ON kid_achievements(achievement_type);
CREATE INDEX IF NOT EXISTS idx_story_collections_child_profile_id ON story_collections(child_profile_id);
CREATE INDEX IF NOT EXISTS idx_story_collections_session_id ON story_collections(session_id);

-- Enable RLS
ALTER TABLE kid_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE story_collections ENABLE ROW LEVEL SECURITY;

-- RLS Policies for kid_achievements
CREATE POLICY "Parents can view child achievements"
    ON kid_achievements FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM family_profiles
            WHERE family_profiles.id = kid_achievements.child_profile_id
            AND family_profiles.parent_user_id = auth.uid()
        )
    );

CREATE POLICY "Service role can manage achievements"
    ON kid_achievements FOR ALL
    USING (auth.jwt()->>'role' = 'service_role');

-- RLS Policies for story_collections
CREATE POLICY "Parents can view child story collections"
    ON story_collections FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM family_profiles
            WHERE family_profiles.id = story_collections.child_profile_id
            AND family_profiles.parent_user_id = auth.uid()
        )
    );

CREATE POLICY "Service role can manage story collections"
    ON story_collections FOR ALL
    USING (auth.jwt()->>'role' = 'service_role');

-- Function to check and unlock achievements
CREATE OR REPLACE FUNCTION check_and_unlock_achievements(
    p_child_profile_id UUID,
    p_achievement_type TEXT
) RETURNS BOOLEAN AS $$
DECLARE
    v_already_unlocked BOOLEAN;
BEGIN
    -- Check if achievement already unlocked
    SELECT EXISTS (
        SELECT 1 FROM kid_achievements
        WHERE child_profile_id = p_child_profile_id
        AND achievement_type = p_achievement_type
    ) INTO v_already_unlocked;
    
    IF v_already_unlocked THEN
        RETURN FALSE;
    END IF;
    
    -- Unlock achievement based on type
    INSERT INTO kid_achievements (child_profile_id, achievement_type, achievement_name, achievement_description, badge_emoji)
    VALUES (
        p_child_profile_id,
        p_achievement_type,
        CASE p_achievement_type
            WHEN 'first_story' THEN 'First Story!'
            WHEN 'ten_stories' THEN 'Story Explorer'
            WHEN 'perfect_week' THEN 'Perfect Week'
            WHEN 'bedtime_streak_7' THEN '7 Day Streak'
            WHEN 'bedtime_streak_30' THEN '30 Day Champion'
            WHEN 'bedtime_streak_100' THEN '100 Day Master'
            WHEN 'favorite_character' THEN 'Character Friend'
            WHEN 'story_collector' THEN 'Story Collector'
            WHEN 'routine_master' THEN 'Routine Master'
            WHEN 'early_sleeper' THEN 'Early Sleeper'
            ELSE 'Achievement Unlocked!'
        END,
        CASE p_achievement_type
            WHEN 'first_story' THEN 'You watched your first bedtime story!'
            WHEN 'ten_stories' THEN 'You watched 10 stories!'
            WHEN 'perfect_week' THEN 'You completed your bedtime routine every day this week!'
            WHEN 'bedtime_streak_7' THEN '7 days in a row! Keep it up!'
            WHEN 'bedtime_streak_30' THEN '30 days of bedtime stories! Amazing!'
            WHEN 'bedtime_streak_100' THEN '100 days! You are a bedtime story master!'
            WHEN 'favorite_character' THEN 'You found your favorite character!'
            WHEN 'story_collector' THEN 'You collected 20 favorite stories!'
            WHEN 'routine_master' THEN 'You completed your bedtime routine 50 times!'
            WHEN 'early_sleeper' THEN 'You went to bed on time 10 nights in a row!'
            ELSE 'Great job!'
        END,
        CASE p_achievement_type
            WHEN 'first_story' THEN '⭐'
            WHEN 'ten_stories' THEN '🌟'
            WHEN 'perfect_week' THEN '🎉'
            WHEN 'bedtime_streak_7' THEN '🔥'
            WHEN 'bedtime_streak_30' THEN '🏆'
            WHEN 'bedtime_streak_100' THEN '👑'
            WHEN 'favorite_character' THEN '🎭'
            WHEN 'story_collector' THEN '📚'
            WHEN 'routine_master' THEN '✨'
            WHEN 'early_sleeper' THEN '🌙'
            ELSE '⭐'
        END
    );
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;










































