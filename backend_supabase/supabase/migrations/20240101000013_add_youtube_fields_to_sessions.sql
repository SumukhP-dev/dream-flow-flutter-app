-- Add YouTube-related fields to sessions table
-- Enables tracking of featured stories and YouTube upload status

ALTER TABLE sessions
  ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT FALSE NOT NULL,
  ADD COLUMN IF NOT EXISTS youtube_video_id TEXT,
  ADD COLUMN IF NOT EXISTS youtube_status TEXT CHECK (youtube_status IN ('pending', 'uploaded', 'failed')) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS youtube_published_at TIMESTAMPTZ;

-- Create index for featured stories query
CREATE INDEX IF NOT EXISTS sessions_is_featured_idx ON sessions(is_featured) WHERE is_featured = TRUE;

-- Create index for YouTube status queries
CREATE INDEX IF NOT EXISTS sessions_youtube_status_idx ON sessions(youtube_status) WHERE youtube_status IS NOT NULL;

-- Create index for featured stories pending YouTube upload
CREATE INDEX IF NOT EXISTS sessions_featured_pending_youtube_idx 
  ON sessions(is_featured, youtube_status) 
  WHERE is_featured = TRUE AND youtube_status IS NULL;

-- Note: RLS policies for updating sessions are already defined in create_sessions.sql
-- Admin checks are performed at the application level via get_admin_user_id dependency
-- The service-role key is used for admin operations, bypassing RLS

