-- Database migrations for gamification, character customization, and social features
-- Run these migrations in Supabase SQL editor

-- Extend kid_achievements table if it doesn't have these columns
ALTER TABLE kid_achievements
ADD COLUMN IF NOT EXISTS achievement_type TEXT NOT NULL DEFAULT 'first_story',
ADD COLUMN IF NOT EXISTS is_new BOOLEAN DEFAULT true;

-- Create reading_progress table
CREATE TABLE IF NOT EXISTS reading_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  child_profile_id UUID REFERENCES family_profiles(id) ON DELETE CASCADE,
  stories_completed INTEGER DEFAULT 0,
  minutes_listened INTEGER DEFAULT 0,
  themes_explored TEXT[] DEFAULT ARRAY[]::TEXT[],
  vocabulary_words_learned INTEGER DEFAULT 0,
  questions_answered_correctly INTEGER DEFAULT 0,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(child_profile_id)
);

-- Enhance user_streaks table if needed
CREATE TABLE IF NOT EXISTS user_streaks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  current_streak INTEGER DEFAULT 0,
  longest_streak INTEGER DEFAULT 0,
  last_activity_date DATE,
  calendar JSONB DEFAULT '{}'::JSONB,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id)
);

-- Create user_avatars table
CREATE TABLE IF NOT EXISTS user_avatars (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  child_profile_id UUID REFERENCES family_profiles(id) ON DELETE CASCADE,
  avatar_data JSONB NOT NULL,
  name TEXT NOT NULL DEFAULT 'My Avatar',
  is_default BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create character_library table
CREATE TABLE IF NOT EXISTS character_library (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  character_id TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  emoji TEXT,
  unlock_condition TEXT, -- e.g., 'achievement:streak_30'
  is_default BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert default characters
INSERT INTO character_library (character_id, name, emoji, is_default) VALUES
  ('default', 'Default Character', '😊', true),
  ('adventurer', 'Adventurer', '🧙', true),
  ('princess', 'Princess', '👸', true),
  ('knight', 'Knight', '🛡️', false)
ON CONFLICT (character_id) DO NOTHING;

-- Create family_libraries table
CREATE TABLE IF NOT EXISTS family_libraries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL, -- Can be derived from parent_user_id
  story_id UUID REFERENCES sessions(id) ON DELETE CASCADE,
  shared_by UUID NOT NULL, -- user_id of parent who shared
  shared_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(family_id, story_id)
);

-- Create collaboration_sessions table
CREATE TABLE IF NOT EXISTS collaboration_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID REFERENCES sessions(id) ON DELETE CASCADE,
  parent_id UUID NOT NULL,
  child_id UUID REFERENCES family_profiles(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'pending', -- 'pending', 'in_progress', 'completed'
  parent_contribution TEXT,
  child_contribution TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create comprehension_questions table
CREATE TABLE IF NOT EXISTS comprehension_questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  story_id UUID REFERENCES sessions(id) ON DELETE CASCADE,
  question TEXT NOT NULL,
  options JSONB NOT NULL, -- Array of answer options
  correct_answer INTEGER NOT NULL, -- Index of correct answer
  question_type TEXT DEFAULT 'multiple_choice',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create vocabulary_highlights table
CREATE TABLE IF NOT EXISTS vocabulary_highlights (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  story_id UUID REFERENCES sessions(id) ON DELETE CASCADE,
  word TEXT NOT NULL,
  definition TEXT NOT NULL,
  age_level TEXT, -- '5-7', '8-10', '11-13'
  context_sentence TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create learning_progress table
CREATE TABLE IF NOT EXISTS learning_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  child_profile_id UUID REFERENCES family_profiles(id) ON DELETE CASCADE,
  metrics JSONB DEFAULT '{}'::JSONB, -- Flexible metrics storage
  reading_level TEXT,
  words_read INTEGER DEFAULT 0,
  new_vocabulary_count INTEGER DEFAULT 0,
  comprehension_score DECIMAL(5,2),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(child_profile_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_reading_progress_child ON reading_progress(child_profile_id);
CREATE INDEX IF NOT EXISTS idx_user_streaks_user ON user_streaks(user_id);
CREATE INDEX IF NOT EXISTS idx_user_avatars_user ON user_avatars(user_id);
CREATE INDEX IF NOT EXISTS idx_user_avatars_child ON user_avatars(child_profile_id);
CREATE INDEX IF NOT EXISTS idx_family_libraries_family ON family_libraries(family_id);
CREATE INDEX IF NOT EXISTS idx_collaboration_sessions_child ON collaboration_sessions(child_id);
CREATE INDEX IF NOT EXISTS idx_comprehension_questions_story ON comprehension_questions(story_id);
CREATE INDEX IF NOT EXISTS idx_vocabulary_highlights_story ON vocabulary_highlights(story_id);
CREATE INDEX IF NOT EXISTS idx_learning_progress_child ON learning_progress(child_profile_id);

