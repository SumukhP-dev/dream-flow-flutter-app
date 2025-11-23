-- Create analytics views for monetization tracking
-- These views provide daily metrics: DAU, average story count, and persona mix

-- View: Daily Active Users (DAU)
-- Counts unique users who created at least one session per day
CREATE OR REPLACE VIEW analytics_daily_active_users AS
SELECT 
    DATE(created_at) AS date,
    COUNT(DISTINCT user_id) AS dau
FROM sessions
GROUP BY DATE(created_at)
ORDER BY date DESC;

-- View: Daily Story Count Statistics
-- Provides total stories, average stories per user, and other metrics per day
CREATE OR REPLACE VIEW analytics_daily_story_stats AS
SELECT 
    DATE(created_at) AS date,
    COUNT(*) AS total_stories,
    COUNT(DISTINCT user_id) AS active_users,
    CASE 
        WHEN COUNT(DISTINCT user_id) > 0 
        THEN ROUND(COUNT(*)::NUMERIC / COUNT(DISTINCT user_id), 2)
        ELSE 0 
    END AS avg_stories_per_user,
    COUNT(DISTINCT theme) AS unique_themes,
    AVG(target_length) AS avg_target_length,
    AVG(num_scenes) AS avg_num_scenes
FROM sessions
GROUP BY DATE(created_at)
ORDER BY date DESC;

-- View: User Persona Classification
-- Classifies users into personas based on profile and behavior patterns
-- Personas: 'mindful_professional', 'burned_out_parent', 'wellness_seeker', 'unknown'
CREATE OR REPLACE VIEW analytics_user_personas AS
WITH user_profile_data AS (
    SELECT 
        p.id AS user_id,
        p.mood,
        p.routine,
        p.preferences,
        p.calming_elements,
        COUNT(DISTINCT s.id) AS total_sessions,
        COUNT(DISTINCT DATE(s.created_at)) AS active_days,
        ARRAY_AGG(DISTINCT s.theme) AS themes_used,
        AVG(s.target_length) AS avg_story_length,
        MIN(s.created_at) AS first_session_date,
        MAX(s.created_at) AS last_session_date
    FROM profiles p
    LEFT JOIN sessions s ON p.id = s.user_id
    GROUP BY p.id, p.mood, p.routine, p.preferences, p.calming_elements
),
persona_classification AS (
    SELECT 
        user_id,
        mood,
        routine,
        preferences,
        total_sessions,
        active_days,
        themes_used,
        -- Classify persona based on profile data and behavior
        CASE
            -- Mindful Professional: high session count, professional routine keywords, calm themes
            WHEN (
                total_sessions >= 5 
                AND (
                    routine ILIKE '%work%' OR routine ILIKE '%professional%' OR routine ILIKE '%office%'
                    OR routine ILIKE '%screen%' OR routine ILIKE '%computer%'
                )
                AND (
                    mood ILIKE '%calm%' OR mood ILIKE '%focused%' OR mood ILIKE '%stressed%'
                )
            ) THEN 'mindful_professional'
            
            -- Burned Out Parent: mentions of kids, family, bedtime routines
            WHEN (
                routine ILIKE '%kid%' OR routine ILIKE '%child%' OR routine ILIKE '%bedtime%'
                OR routine ILIKE '%parent%' OR routine ILIKE '%family%'
                OR EXISTS (
                    SELECT 1 FROM unnest(preferences) AS pref 
                    WHERE pref ILIKE '%kid%' OR pref ILIKE '%child%' OR pref ILIKE '%family%'
                )
            ) THEN 'burned_out_parent'
            
            -- Wellness Seeker: ASMR, meditation, sensory elements, diverse calming elements
            WHEN (
                array_length(calming_elements, 1) > 2
                OR EXISTS (
                    SELECT 1 FROM unnest(preferences) AS pref 
                    WHERE pref ILIKE '%asmr%' OR pref ILIKE '%meditation%' 
                    OR pref ILIKE '%wellness%' OR pref ILIKE '%sensory%'
                )
                OR EXISTS (
                    SELECT 1 FROM unnest(calming_elements) AS elem 
                    WHERE elem ILIKE '%asmr%' OR elem ILIKE '%binaural%' 
                    OR elem ILIKE '%ambient%' OR elem ILIKE '%sensory%'
                )
            ) THEN 'wellness_seeker'
            
            -- Default to unknown if no clear classification
            ELSE 'unknown'
        END AS persona
    FROM user_profile_data
)
SELECT 
    user_id,
    persona,
    mood,
    routine,
    total_sessions,
    active_days,
    themes_used,
    first_session_date,
    last_session_date
FROM persona_classification
ORDER BY total_sessions DESC;

-- View: Daily Persona Mix
-- Aggregates persona distribution per day
CREATE OR REPLACE VIEW analytics_daily_persona_mix AS
WITH daily_persona_counts AS (
    SELECT 
        DATE(s.created_at) AS date,
        COALESCE(ap.persona, 'unknown') AS persona,
        COUNT(DISTINCT s.user_id) AS user_count,
        COUNT(*) AS story_count
    FROM sessions s
    LEFT JOIN analytics_user_personas ap ON s.user_id = ap.user_id
    GROUP BY DATE(s.created_at), ap.persona
),
daily_totals AS (
    SELECT 
        date,
        SUM(user_count) AS total_users
    FROM daily_persona_counts
    GROUP BY date
)
SELECT 
    dpc.date,
    dpc.persona,
    dpc.user_count,
    dpc.story_count,
    ROUND(
        CASE 
            WHEN dt.total_users > 0 
            THEN (dpc.user_count::NUMERIC / dt.total_users * 100)
            ELSE 0 
        END, 
        2
    ) AS user_percentage
FROM daily_persona_counts dpc
JOIN daily_totals dt ON dpc.date = dt.date
ORDER BY dpc.date DESC, dpc.user_count DESC;

-- View: Comprehensive Daily Analytics
-- Combines all metrics into a single view for easy export
CREATE OR REPLACE VIEW analytics_daily_comprehensive AS
WITH all_dates AS (
    SELECT DISTINCT DATE(created_at) AS date FROM sessions
),
daily_metrics AS (
    SELECT 
        ad.date,
        COALESCE(dau.dau, 0) AS daily_active_users,
        COALESCE(ds.total_stories, 0) AS total_stories,
        COALESCE(ds.avg_stories_per_user, 0) AS avg_stories_per_user,
        COALESCE(ds.active_users, 0) AS active_users,
        COALESCE(ds.unique_themes, 0) AS unique_themes,
        COALESCE(ds.avg_target_length, 0) AS avg_target_length,
        COALESCE(ds.avg_num_scenes, 0) AS avg_num_scenes
    FROM all_dates ad
    LEFT JOIN analytics_daily_active_users dau ON ad.date = dau.date
    LEFT JOIN analytics_daily_story_stats ds ON ad.date = ds.date
),
persona_aggregated AS (
    SELECT 
        date,
        jsonb_object_agg(
            persona, 
            jsonb_build_object(
                'user_count', user_count,
                'story_count', story_count,
                'user_percentage', user_percentage
            )
        ) AS persona_mix
    FROM analytics_daily_persona_mix
    GROUP BY date
)
SELECT 
    dm.date,
    dm.daily_active_users,
    dm.total_stories,
    dm.avg_stories_per_user,
    dm.active_users,
    dm.unique_themes,
    dm.avg_target_length,
    dm.avg_num_scenes,
    COALESCE(pa.persona_mix, '{}'::jsonb) AS persona_mix
FROM daily_metrics dm
LEFT JOIN persona_aggregated pa ON dm.date = pa.date
ORDER BY dm.date DESC;

-- Grant permissions for service role (bypasses RLS)
-- These views are read-only and safe for analytics
GRANT SELECT ON analytics_daily_active_users TO service_role;
GRANT SELECT ON analytics_daily_story_stats TO service_role;
GRANT SELECT ON analytics_user_personas TO service_role;
GRANT SELECT ON analytics_daily_persona_mix TO service_role;
GRANT SELECT ON analytics_daily_comprehensive TO service_role;

-- Create indexes to optimize view performance
CREATE INDEX IF NOT EXISTS sessions_created_at_date_idx 
    ON sessions(DATE(created_at));
CREATE INDEX IF NOT EXISTS sessions_user_id_created_at_idx 
    ON sessions(user_id, created_at DESC);

