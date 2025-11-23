-- Create rituals table
-- Stores saved bedtime rituals/routines that users can reuse

CREATE TABLE IF NOT EXISTS rituals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  routine TEXT NOT NULL,
  is_default BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Enable Row Level Security
ALTER TABLE rituals ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can view their own rituals
CREATE POLICY "Users can view own rituals"
  ON rituals
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own rituals
CREATE POLICY "Users can insert own rituals"
  ON rituals
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own rituals
CREATE POLICY "Users can update own rituals"
  ON rituals
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Users can delete their own rituals
CREATE POLICY "Users can delete own rituals"
  ON rituals
  FOR DELETE
  USING (auth.uid() = user_id);

-- Indexes
CREATE INDEX IF NOT EXISTS rituals_user_id_idx ON rituals(user_id);
CREATE INDEX IF NOT EXISTS rituals_user_id_default_idx ON rituals(user_id, is_default) WHERE is_default = TRUE;
CREATE INDEX IF NOT EXISTS rituals_created_at_idx ON rituals(created_at);

-- Trigger to automatically update updated_at
CREATE TRIGGER update_rituals_updated_at
  BEFORE UPDATE ON rituals
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Constraint: Only one default ritual per user
CREATE UNIQUE INDEX IF NOT EXISTS rituals_user_default_unique 
  ON rituals(user_id) 
  WHERE is_default = TRUE;

