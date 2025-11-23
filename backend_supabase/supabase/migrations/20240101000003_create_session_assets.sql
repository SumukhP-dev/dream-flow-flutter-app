-- Create session_assets table
-- Stores audio, video, and frame assets associated with sessions

CREATE TABLE IF NOT EXISTS session_assets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  asset_type TEXT NOT NULL CHECK (asset_type IN ('audio', 'video', 'frame')),
  asset_url TEXT NOT NULL,
  display_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Enable Row Level Security
ALTER TABLE session_assets ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can view assets for their own sessions
CREATE POLICY "Users can view own session assets"
  ON session_assets
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM sessions
      WHERE sessions.id = session_assets.session_id
      AND sessions.user_id = auth.uid()
    )
  );

-- Users can insert assets for their own sessions
CREATE POLICY "Users can insert own session assets"
  ON session_assets
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM sessions
      WHERE sessions.id = session_assets.session_id
      AND sessions.user_id = auth.uid()
    )
  );

-- Users can update assets for their own sessions
CREATE POLICY "Users can update own session assets"
  ON session_assets
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM sessions
      WHERE sessions.id = session_assets.session_id
      AND sessions.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM sessions
      WHERE sessions.id = session_assets.session_id
      AND sessions.user_id = auth.uid()
    )
  );

-- Users can delete assets for their own sessions
CREATE POLICY "Users can delete own session assets"
  ON session_assets
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM sessions
      WHERE sessions.id = session_assets.session_id
      AND sessions.user_id = auth.uid()
    )
  );

-- Indexes
CREATE INDEX IF NOT EXISTS session_assets_session_id_idx ON session_assets(session_id);
CREATE INDEX IF NOT EXISTS session_assets_session_id_type_idx ON session_assets(session_id, asset_type);
CREATE INDEX IF NOT EXISTS session_assets_session_id_order_idx ON session_assets(session_id, display_order);
CREATE INDEX IF NOT EXISTS session_assets_created_at_idx ON session_assets(created_at);

