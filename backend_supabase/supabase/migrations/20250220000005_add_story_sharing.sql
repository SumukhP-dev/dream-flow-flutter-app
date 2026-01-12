-- Add story sharing fields to sessions table
-- Enables opt-in sharing of stories with moderation and safety features

-- Add sharing fields to sessions table
ALTER TABLE sessions
  ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT FALSE NOT NULL,
  ADD COLUMN IF NOT EXISTS is_approved BOOLEAN DEFAULT FALSE NOT NULL,
  ADD COLUMN IF NOT EXISTS shared_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS report_count INTEGER DEFAULT 0 NOT NULL,
  ADD COLUMN IF NOT EXISTS age_rating TEXT CHECK (age_rating IN ('all', '5+', '7+', '10+', '13+')) DEFAULT 'all';

-- Create story_reports table for reporting inappropriate content
CREATE TABLE IF NOT EXISTS story_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  reporter_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason TEXT NOT NULL CHECK (reason IN ('inappropriate', 'spam', 'harassment', 'copyright', 'other')),
  details TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'resolved', 'dismissed')),
  reviewed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Create story_likes table for engagement
CREATE TABLE IF NOT EXISTS story_likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(session_id, user_id) -- Prevent duplicate likes
);

-- Enable Row Level Security on new tables
ALTER TABLE story_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE story_likes ENABLE ROW LEVEL SECURITY;

-- RLS Policies for story_reports
-- Users can create reports
CREATE POLICY "Users can report stories"
  ON story_reports
  FOR INSERT
  WITH CHECK (auth.uid() = reporter_user_id);

-- Users can view their own reports
CREATE POLICY "Users can view own reports"
  ON story_reports
  FOR SELECT
  USING (auth.uid() = reporter_user_id);

-- Admins can view all reports (will be added via service role)
-- Regular users cannot update/delete reports

-- RLS Policies for story_likes
-- Users can like stories
CREATE POLICY "Users can like stories"
  ON story_likes
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can view likes on public stories
CREATE POLICY "Users can view likes on public stories"
  ON story_likes
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM sessions
      WHERE sessions.id = story_likes.session_id
      AND sessions.is_public = TRUE
      AND sessions.is_approved = TRUE
    )
  );

-- Users can unlike (delete their own likes)
CREATE POLICY "Users can delete own likes"
  ON story_likes
  FOR DELETE
  USING (auth.uid() = user_id);

-- Update RLS policies for sessions table
-- Add policy: Users can view public approved stories
CREATE POLICY "Users can view public approved stories"
  ON sessions
  FOR SELECT
  USING (
    is_public = TRUE
    AND is_approved = TRUE
    AND report_count < 5 -- Auto-hide if too many reports
  );

DROP POLICY IF EXISTS "Users can update own story sharing" ON sessions;

CREATE POLICY "Users can update own story sharing"
  ON sessions
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Guardrail trigger to prevent users from changing moderation-only fields
CREATE OR REPLACE FUNCTION enforce_story_sharing_guardrails()
RETURNS TRIGGER AS $$
DECLARE
  request_role text := current_setting('request.jwt.claim.role', true);
BEGIN
  -- Allow service role / internal operations
  IF request_role IS NULL OR request_role = 'service_role' THEN
    RETURN NEW;
  END IF;

  -- Block user attempts to edit moderation-managed columns
  IF NEW.is_approved IS DISTINCT FROM OLD.is_approved THEN
    RAISE EXCEPTION 'Only moderators can change is_approved';
  END IF;

  IF NEW.report_count IS DISTINCT FROM OLD.report_count THEN
    RAISE EXCEPTION 'Only the system can change report_count';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS enforce_story_sharing_guardrails ON sessions;

CREATE TRIGGER enforce_story_sharing_guardrails
  BEFORE UPDATE OF is_approved, report_count ON sessions
  FOR EACH ROW
  EXECUTE FUNCTION enforce_story_sharing_guardrails();

-- Indexes for performance
CREATE INDEX IF NOT EXISTS sessions_is_public_approved_idx 
  ON sessions(is_public, is_approved) 
  WHERE is_public = TRUE AND is_approved = TRUE;

CREATE INDEX IF NOT EXISTS sessions_age_rating_idx ON sessions(age_rating);

CREATE INDEX IF NOT EXISTS story_reports_session_id_idx ON story_reports(session_id);
CREATE INDEX IF NOT EXISTS story_reports_status_idx ON story_reports(status) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS story_reports_reporter_user_id_idx ON story_reports(reporter_user_id);

CREATE INDEX IF NOT EXISTS story_likes_session_id_idx ON story_likes(session_id);
CREATE INDEX IF NOT EXISTS story_likes_user_id_idx ON story_likes(user_id);
CREATE INDEX IF NOT EXISTS story_likes_session_user_idx ON story_likes(session_id, user_id);

-- Function to update report_count when a report is created
CREATE OR REPLACE FUNCTION update_session_report_count()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE sessions
  SET report_count = report_count + 1
  WHERE id = NEW.session_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update report_count
CREATE TRIGGER update_report_count_on_report
  AFTER INSERT ON story_reports
  FOR EACH ROW
  EXECUTE FUNCTION update_session_report_count();

-- Function to get like count for a session
CREATE OR REPLACE FUNCTION get_session_like_count(session_uuid UUID)
RETURNS INTEGER AS $$
BEGIN
  RETURN (SELECT COUNT(*) FROM story_likes WHERE session_id = session_uuid);
END;
$$ LANGUAGE plpgsql;

