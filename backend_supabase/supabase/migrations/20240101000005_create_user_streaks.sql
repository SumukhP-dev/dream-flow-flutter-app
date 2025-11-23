-- Create user_streaks table
-- Stores computed streak information for users based on their session activity

CREATE TABLE IF NOT EXISTS user_streaks (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  current_streak INTEGER DEFAULT 0 NOT NULL,
  longest_streak INTEGER DEFAULT 0 NOT NULL,
  last_session_date DATE,
  streak_start_date DATE,
  computed_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Enable Row Level Security
ALTER TABLE user_streaks ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can view their own streaks
CREATE POLICY "Users can view own streaks"
  ON user_streaks
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users cannot insert/update/delete their own streaks (only system can)
-- This ensures streaks are only computed by the scheduled job

-- Indexes
CREATE INDEX IF NOT EXISTS user_streaks_user_id_idx ON user_streaks(user_id);
CREATE INDEX IF NOT EXISTS user_streaks_last_session_date_idx ON user_streaks(last_session_date);
CREATE INDEX IF NOT EXISTS user_streaks_computed_at_idx ON user_streaks(computed_at);

-- Function to recompute streaks for all users
-- This function calculates streaks based on consecutive days with at least one session
CREATE OR REPLACE FUNCTION recompute_user_streaks()
RETURNS TABLE (
  user_id UUID,
  current_streak INTEGER,
  longest_streak INTEGER,
  last_session_date DATE,
  streak_start_date DATE
) AS $$
DECLARE
  user_record RECORD;
  session_dates DATE[];
  current_streak_count INTEGER;
  longest_streak_count INTEGER;
  last_date DATE;
  streak_start DATE;
  today_date DATE;
  check_date DATE;
  i INTEGER;
  temp_streak INTEGER;
  temp_start DATE;
BEGIN
  today_date := CURRENT_DATE;

  -- Loop through all users who have sessions
  FOR user_record IN
    SELECT DISTINCT s.user_id
    FROM sessions s
    ORDER BY s.user_id
  LOOP
    -- Get all unique session dates for this user, ordered by date descending
    SELECT ARRAY_AGG(DISTINCT DATE(s.created_at) ORDER BY DATE(s.created_at) DESC)
    INTO session_dates
    FROM sessions s
    WHERE s.user_id = user_record.user_id;

    -- If no sessions, skip
    IF session_dates IS NULL OR array_length(session_dates, 1) IS NULL THEN
      CONTINUE;
    END IF;

    last_date := session_dates[1]; -- Most recent session date

    -- Calculate current streak: count backwards from today or yesterday
    -- A streak is active if the user had a session today or yesterday
    current_streak_count := 0;
    streak_start := NULL;
    
    -- Check if most recent session was today or yesterday (streak is still active)
    IF last_date >= today_date - INTERVAL '1 day' THEN
      -- Streak is potentially active, count backwards from today
      check_date := today_date;
      
      -- Count consecutive days backwards from today
      WHILE check_date >= last_date LOOP
        -- Check if this date has a session
        IF EXISTS (
          SELECT 1 FROM unnest(session_dates) AS d 
          WHERE d = check_date
        ) THEN
          IF current_streak_count = 0 THEN
            streak_start := check_date;
          END IF;
          current_streak_count := current_streak_count + 1;
          check_date := check_date - INTERVAL '1 day';
        ELSE
          -- Gap found, streak broken
          EXIT;
        END IF;
      END LOOP;
    ELSE
      -- Most recent session was more than 1 day ago, streak is broken
      current_streak_count := 0;
      streak_start := NULL;
    END IF;

    -- Calculate longest streak: find the longest consecutive sequence in all dates
    -- Get dates sorted in ascending order for this calculation
    SELECT ARRAY_AGG(DISTINCT DATE(s.created_at) ORDER BY DATE(s.created_at) ASC)
    INTO session_dates
    FROM sessions s
    WHERE s.user_id = user_record.user_id;

    longest_streak_count := 0;
    IF array_length(session_dates, 1) > 0 THEN
      temp_streak := 1;
      temp_start := session_dates[1];

      FOR i IN 2..array_length(session_dates, 1) LOOP
        IF session_dates[i] = session_dates[i-1] + INTERVAL '1 day' THEN
          -- Consecutive day
          temp_streak := temp_streak + 1;
        ELSE
          -- Streak broken, check if this was the longest
          IF temp_streak > longest_streak_count THEN
            longest_streak_count := temp_streak;
          END IF;
          -- Start new streak
          temp_streak := 1;
          temp_start := session_dates[i];
        END IF;
      END LOOP;

      -- Final check for longest streak
      IF temp_streak > longest_streak_count THEN
        longest_streak_count := temp_streak;
      END IF;
    END IF;

    -- Upsert the streak data
    INSERT INTO user_streaks (
      user_id,
      current_streak,
      longest_streak,
      last_session_date,
      streak_start_date,
      computed_at,
      updated_at
    )
    VALUES (
      user_record.user_id,
      current_streak_count,
      longest_streak_count,
      last_date,
      streak_start,
      NOW(),
      NOW()
    )
    ON CONFLICT (user_id) DO UPDATE SET
      current_streak = EXCLUDED.current_streak,
      longest_streak = GREATEST(user_streaks.longest_streak, EXCLUDED.longest_streak),
      last_session_date = EXCLUDED.last_session_date,
      streak_start_date = EXCLUDED.streak_start_date,
      computed_at = EXCLUDED.computed_at,
      updated_at = EXCLUDED.updated_at;

    -- Return the computed values
    user_id := user_record.user_id;
    current_streak := current_streak_count;
    longest_streak := longest_streak_count;
    last_session_date := last_date;
    streak_start_date := streak_start;
    
    RETURN NEXT;
  END LOOP;

  -- Also handle users with no sessions - set their streaks to 0
  FOR user_record IN
    SELECT u.id as user_id
    FROM auth.users u
    WHERE NOT EXISTS (
      SELECT 1 FROM sessions s WHERE s.user_id = u.id
    )
    AND NOT EXISTS (
      SELECT 1 FROM user_streaks us WHERE us.user_id = u.id
    )
  LOOP
    INSERT INTO user_streaks (
      user_id,
      current_streak,
      longest_streak,
      last_session_date,
      streak_start_date,
      computed_at,
      updated_at
    )
    VALUES (
      user_record.user_id,
      0,
      0,
      NULL,
      NULL,
      NOW(),
      NOW()
    )
    ON CONFLICT (user_id) DO UPDATE SET
      current_streak = 0,
      last_session_date = NULL,
      streak_start_date = NULL,
      computed_at = NOW(),
      updated_at = NOW();
  END LOOP;

  RETURN;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users (for manual invocation if needed)
GRANT EXECUTE ON FUNCTION recompute_user_streaks() TO authenticated;
GRANT EXECUTE ON FUNCTION recompute_user_streaks() TO service_role;

-- Enable pg_cron extension if not already enabled
-- Note: This requires superuser privileges, so it may need to be run separately
-- or enabled via Supabase dashboard (Database > Extensions > pg_cron)
-- If pg_cron is not available, you can manually run: SELECT recompute_user_streaks();
DO $$
BEGIN
  -- Try to enable pg_cron extension
  CREATE EXTENSION IF NOT EXISTS pg_cron;
  
  -- Schedule the streak recomputation to run nightly at 2:00 AM UTC
  -- Only schedule if the job doesn't already exist
  IF NOT EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'nightly-recompute-streaks'
  ) THEN
    PERFORM cron.schedule(
      'nightly-recompute-streaks',
      '0 2 * * *', -- Every day at 2:00 AM UTC
      $$SELECT recompute_user_streaks();$$
    );
  END IF;
EXCEPTION
  WHEN insufficient_privilege THEN
    -- pg_cron requires superuser, log a notice
    RAISE NOTICE 'pg_cron extension requires superuser privileges. Please enable it via Supabase dashboard and run: SELECT cron.schedule(''nightly-recompute-streaks'', ''0 2 * * *'', $$SELECT recompute_user_streaks();$$);';
  WHEN OTHERS THEN
    -- Other errors, log but don't fail
    RAISE NOTICE 'Could not set up pg_cron schedule. Error: %', SQLERRM;
END $$;

-- Alternative: If you prefer to use an Edge Function instead, uncomment and modify:
-- SELECT cron.schedule(
--   'nightly-recompute-streaks',
--   '0 2 * * *',
--   $$
--   SELECT
--     net.http_post(
--       url := 'https://<project_ref>.functions.supabase.co/recompute-streaks',
--       headers := jsonb_build_object(
--         'Content-Type', 'application/json',
--         'Authorization', 'Bearer YOUR_ANON_KEY'
--       ),
--       body := jsonb_build_object('trigger', 'cron')
--     ) as request_id;
--   $$
-- );

-- Trigger to automatically update updated_at
CREATE TRIGGER update_user_streaks_updated_at
  BEFORE UPDATE ON user_streaks
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

