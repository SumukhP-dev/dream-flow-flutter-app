-- Create assets table for Studio Website
-- Stores custom assets uploaded by users (video, audio, images)

CREATE TABLE IF NOT EXISTS assets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('video', 'audio', 'image')),
  url TEXT NOT NULL,
  thumbnail_url TEXT,
  name TEXT NOT NULL,
  size INTEGER NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Enable Row Level Security
ALTER TABLE assets ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can view their own assets
CREATE POLICY "Users can view own assets"
  ON assets
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own assets
CREATE POLICY "Users can insert own assets"
  ON assets
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own assets
CREATE POLICY "Users can update own assets"
  ON assets
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Users can delete their own assets
CREATE POLICY "Users can delete own assets"
  ON assets
  FOR DELETE
  USING (auth.uid() = user_id);

-- Indexes
CREATE INDEX IF NOT EXISTS assets_user_id_idx ON assets(user_id);
CREATE INDEX IF NOT EXISTS assets_type_idx ON assets(type);

