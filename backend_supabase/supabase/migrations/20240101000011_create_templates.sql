-- Create templates table for Studio template management
-- Supports saving and reusing story generation templates

CREATE TABLE IF NOT EXISTS templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    prompt TEXT NOT NULL,
    theme TEXT NOT NULL,
    target_length INTEGER NOT NULL DEFAULT 400,
    num_scenes INTEGER NOT NULL DEFAULT 4,
    voice TEXT,
    mode TEXT NOT NULL DEFAULT 'bedtime_story' CHECK (mode IN ('bedtime_story', 'asmr', 'mindfulness', 'branded_wellness')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_templates_user_id ON templates(user_id);
CREATE INDEX IF NOT EXISTS idx_templates_created_at ON templates(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_templates_mode ON templates(mode);

-- Enable RLS
ALTER TABLE templates ENABLE ROW LEVEL SECURITY;

-- RLS Policies for templates
-- Users can only view/manage their own templates
CREATE POLICY "Users can manage own templates"
    ON templates FOR ALL
    USING (auth.uid() = user_id);

-- Service role can do everything
CREATE POLICY "Service role can manage templates"
    ON templates FOR ALL
    USING (auth.jwt()->>'role' = 'service_role');

