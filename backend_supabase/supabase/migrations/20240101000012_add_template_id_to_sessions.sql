-- Add template_id column to sessions table for tracking template usage
-- This allows analytics to track which templates are most used

ALTER TABLE sessions
ADD COLUMN IF NOT EXISTS template_id UUID REFERENCES templates(id) ON DELETE SET NULL;

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_sessions_template_id ON sessions(template_id);

