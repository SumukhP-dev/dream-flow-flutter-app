-- Create batch_jobs table for Studio batch processing
-- Supports queuing multiple story generation requests

CREATE TABLE IF NOT EXISTS batch_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'cancelled')),
    email_notifications BOOLEAN NOT NULL DEFAULT TRUE,
    items JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_batch_jobs_user_id ON batch_jobs(user_id);
CREATE INDEX IF NOT EXISTS idx_batch_jobs_status ON batch_jobs(status);
CREATE INDEX IF NOT EXISTS idx_batch_jobs_created_at ON batch_jobs(created_at DESC);

-- Enable RLS
ALTER TABLE batch_jobs ENABLE ROW LEVEL SECURITY;

-- RLS Policies for batch_jobs
-- Users can only view/manage their own batch jobs
CREATE POLICY "Users can manage own batch jobs"
    ON batch_jobs FOR ALL
    USING (auth.uid() = user_id);

-- Service role can do everything
CREATE POLICY "Service role can manage batch jobs"
    ON batch_jobs FOR ALL
    USING (auth.jwt()->>'role' = 'service_role');

