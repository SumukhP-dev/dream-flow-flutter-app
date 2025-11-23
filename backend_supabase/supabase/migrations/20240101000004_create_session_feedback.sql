-- Create session_feedback table
-- Stores post-session feedback including rating and mood delta

CREATE TABLE IF NOT EXISTS session_feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  mood_delta INTEGER NOT NULL CHECK (mood_delta >= -5 AND mood_delta <= 5),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  -- Ensure one feedback per session
  UNIQUE(session_id)
);

-- Enable Row Level Security
ALTER TABLE session_feedback ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can view their own feedback
CREATE POLICY "Users can view own feedback"
  ON session_feedback
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own feedback
CREATE POLICY "Users can insert own feedback"
  ON session_feedback
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own feedback
CREATE POLICY "Users can update own feedback"
  ON session_feedback
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Users can delete their own feedback
CREATE POLICY "Users can delete own feedback"
  ON session_feedback
  FOR DELETE
  USING (auth.uid() = user_id);

-- Indexes
CREATE INDEX IF NOT EXISTS session_feedback_session_id_idx ON session_feedback(session_id);
CREATE INDEX IF NOT EXISTS session_feedback_user_id_idx ON session_feedback(user_id);
CREATE INDEX IF NOT EXISTS session_feedback_created_at_idx ON session_feedback(created_at DESC);

-- Trigger to automatically update updated_at
CREATE TRIGGER update_session_feedback_updated_at
  BEFORE UPDATE ON session_feedback
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

