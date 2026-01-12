-- Create stories table for Studio Website
-- Stores stories created in the Studio with rich editing capabilities
-- Separate from sessions table which is for the main app

CREATE TABLE IF NOT EXISTS stories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  theme TEXT NOT NULL,
  parameters JSONB DEFAULT '{}'::jsonb,
  video_url TEXT,
  audio_url TEXT,
  is_featured BOOLEAN DEFAULT FALSE,
  youtube_video_id TEXT,
  youtube_status TEXT CHECK (youtube_status IN ('pending', 'uploaded', 'failed')),
  youtube_published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Enable Row Level Security
ALTER TABLE stories ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can view their own stories
CREATE POLICY "Users can view own stories"
  ON stories
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own stories
CREATE POLICY "Users can insert own stories"
  ON stories
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own stories
CREATE POLICY "Users can update own stories"
  ON stories
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Users can delete their own stories
CREATE POLICY "Users can delete own stories"
  ON stories
  FOR DELETE
  USING (auth.uid() = user_id);

-- Indexes
CREATE INDEX IF NOT EXISTS stories_user_id_idx ON stories(user_id);
CREATE INDEX IF NOT EXISTS stories_created_at_idx ON stories(created_at DESC);
CREATE INDEX IF NOT EXISTS stories_theme_idx ON stories(theme);
CREATE INDEX IF NOT EXISTS stories_user_id_created_at_idx ON stories(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS stories_user_id_theme_idx ON stories(user_id, theme);
CREATE INDEX IF NOT EXISTS stories_is_featured_idx ON stories(is_featured);
CREATE INDEX IF NOT EXISTS stories_youtube_status_idx ON stories(youtube_status);
CREATE INDEX IF NOT EXISTS stories_is_featured_youtube_status_idx ON stories(is_featured, youtube_status);

-- Trigger to automatically update updated_at
CREATE TRIGGER update_stories_updated_at
  BEFORE UPDATE ON stories
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

