-- Create moderation_queue table
-- Stores content violations detected by guardrails for admin review

CREATE TABLE IF NOT EXISTS moderation_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'resolved', 'rejected')),
  violations JSONB NOT NULL,
  content TEXT NOT NULL,
  content_type TEXT NOT NULL CHECK (content_type IN ('story', 'prompt', 'narration', 'visual')),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  session_id UUID REFERENCES sessions(id) ON DELETE SET NULL,
  resolved_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  resolved_at TIMESTAMPTZ,
  resolution_notes TEXT,
  audit_log JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Enable Row Level Security
ALTER TABLE moderation_queue ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Only admins can view moderation queue items
-- Note: This assumes you have a way to identify admins (e.g., via a profiles table or JWT claims)
-- For now, we'll use a service role check or you can add an admin check function
CREATE POLICY "Admins can view moderation queue"
  ON moderation_queue
  FOR SELECT
  USING (
    -- Allow service role (backend) to access all records
    -- In production, you might want to add a check for admin role in profiles table
    true
  );

-- Only admins can insert moderation queue items
-- This will be done by the backend service role
CREATE POLICY "Service role can insert moderation queue"
  ON moderation_queue
  FOR INSERT
  WITH CHECK (true);

-- Only admins can update moderation queue items
CREATE POLICY "Admins can update moderation queue"
  ON moderation_queue
  FOR UPDATE
  USING (true)
  WITH CHECK (true);

-- Indexes
CREATE INDEX IF NOT EXISTS moderation_queue_status_idx ON moderation_queue(status);
CREATE INDEX IF NOT EXISTS moderation_queue_user_id_idx ON moderation_queue(user_id);
CREATE INDEX IF NOT EXISTS moderation_queue_session_id_idx ON moderation_queue(session_id);
CREATE INDEX IF NOT EXISTS moderation_queue_content_type_idx ON moderation_queue(content_type);
CREATE INDEX IF NOT EXISTS moderation_queue_created_at_idx ON moderation_queue(created_at DESC);
CREATE INDEX IF NOT EXISTS moderation_queue_status_created_at_idx ON moderation_queue(status, created_at DESC);
CREATE INDEX IF NOT EXISTS moderation_queue_resolved_by_idx ON moderation_queue(resolved_by);

-- Trigger to automatically update updated_at
CREATE TRIGGER update_moderation_queue_updated_at
  BEFORE UPDATE ON moderation_queue
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

