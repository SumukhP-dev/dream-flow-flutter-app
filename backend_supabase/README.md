# Dream Flow Supabase Migrations

This directory contains SQL migrations for the Dream Flow application's Supabase database schema.

## Migration Files

### 1. `20240101000000_create_profiles.sql`
Creates the `profiles` table to store user profile data:
- **Primary Key**: `id` (UUID, references `auth.users`)
- **Fields**:
  - `mood` (TEXT) - Current emotional tone
  - `routine` (TEXT) - Bedtime routine/ritual
  - `preferences` (TEXT[]) - General likes and interests
  - `favorite_characters` (TEXT[]) - Favorite story characters
  - `calming_elements` (TEXT[]) - Calming anchors (sounds, locations, colors)
  - `created_at`, `updated_at` (TIMESTAMPTZ)
- **RLS Policies**: Users can only view/insert/update/delete their own profile
- **Indexes**: On `id` and `updated_at`

### 2. `20240101000001_create_rituals.sql`
Creates the `rituals` table to store saved bedtime rituals:
- **Primary Key**: `id` (UUID)
- **Fields**:
  - `user_id` (UUID, references `auth.users`)
  - `name` (TEXT) - Name of the ritual
  - `description` (TEXT) - Optional description
  - `routine` (TEXT) - The ritual/routine text
  - `is_default` (BOOLEAN) - Whether this is the user's default ritual
  - `created_at`, `updated_at` (TIMESTAMPTZ)
- **RLS Policies**: Users can only manage their own rituals
- **Indexes**: On `user_id`, `(user_id, is_default)`, and `created_at`
- **Constraint**: Only one default ritual per user (unique index)

### 3. `20240101000002_create_sessions.sql`
Creates the `sessions` table to store story generation sessions:
- **Primary Key**: `id` (UUID)
- **Fields**:
  - `user_id` (UUID, references `auth.users`)
  - `prompt` (TEXT) - Original user prompt
  - `theme` (TEXT) - Story theme
  - `story_text` (TEXT) - Generated story text
  - `target_length` (INTEGER) - Target word count (default: 400)
  - `num_scenes` (INTEGER) - Number of visual scenes (default: 4)
  - `voice` (TEXT) - Voice preset used
  - `created_at`, `updated_at` (TIMESTAMPTZ)
- **RLS Policies**: Users can only manage their own sessions
- **Indexes**: On `user_id`, `(user_id, created_at DESC)`, `created_at DESC`, and `theme`

### 4. `20240101000003_create_session_assets.sql`
Creates the `session_assets` table to store assets (audio, video, frames) for sessions:
- **Primary Key**: `id` (UUID)
- **Fields**:
  - `session_id` (UUID, references `sessions`)
  - `asset_type` (TEXT) - One of: 'audio', 'video', 'frame'
  - `asset_url` (TEXT) - URL to the asset
  - `display_order` (INTEGER) - Order for display (default: 0)
  - `created_at` (TIMESTAMPTZ)
- **RLS Policies**: Users can only view/manage assets for their own sessions
- **Indexes**: On `session_id`, `(session_id, asset_type)`, `(session_id, display_order)`, and `created_at`
- **Constraint**: `asset_type` must be one of: 'audio', 'video', 'frame'

### 5. `20240101000004_create_session_feedback.sql`
Creates the `session_feedback` table to store post-session feedback:
- **Primary Key**: `id` (UUID)
- **Fields**:
  - `session_id` (UUID, references `sessions`)
  - `user_id` (UUID, references `auth.users`)
  - `rating` (INTEGER) - Rating from 1 to 5
  - `mood_delta` (INTEGER) - Mood change from -5 to 5
  - `created_at`, `updated_at` (TIMESTAMPTZ)
- **RLS Policies**: Users can only manage their own feedback
- **Indexes**: On `session_id`, `user_id`, and `created_at DESC`
- **Constraint**: One feedback per session (unique on `session_id`)

### 6. `20240101000005_create_user_streaks.sql`
Creates the `user_streaks` table and scheduled job to compute user streaks:
- **Primary Key**: `user_id` (UUID, references `auth.users`)
- **Fields**:
  - `current_streak` (INTEGER) - Current consecutive days with sessions (default: 0)
  - `longest_streak` (INTEGER) - Longest streak ever achieved (default: 0)
  - `last_session_date` (DATE) - Date of most recent session
  - `streak_start_date` (DATE) - Date when current streak started
  - `computed_at`, `updated_at` (TIMESTAMPTZ) - Timestamps for tracking
- **RLS Policies**: Users can only view their own streaks (system-managed)
- **Indexes**: On `user_id`, `last_session_date`, and `computed_at`
- **Functions**:
  - `recompute_user_streaks()` - Calculates streaks for all users based on session activity
- **Scheduled Job**: Automatically runs nightly at 2:00 AM UTC via `pg_cron`

### 7. `20240101000006_create_analytics_views.sql`
Creates analytics views for monetization tracking:
- **Views Created**:
  - `analytics_daily_active_users` - Daily Active Users (DAU) count per day
  - `analytics_daily_story_stats` - Daily story statistics (total stories, avg per user, themes, etc.)
  - `analytics_user_personas` - User persona classification based on profile and behavior
  - `analytics_daily_persona_mix` - Daily persona distribution
  - `analytics_daily_comprehensive` - Combined daily metrics with persona mix
- **Persona Types**:
  - `mindful_professional` - High session count, professional routine keywords
  - `burned_out_parent` - Mentions of kids, family, bedtime routines
  - `wellness_seeker` - ASMR, meditation, sensory elements, diverse calming elements
  - `unknown` - Default classification when no clear pattern matches
- **Permissions**: Views are read-only and accessible via service_role
- **Indexes**: Optimized indexes on `sessions.created_at` for view performance

## Row Level Security (RLS)

All tables have RLS enabled with policies that ensure:
- Users can only access their own data
- Foreign key relationships are respected in RLS policies
- Session assets inherit permissions from their parent session

## Usage

### Applying Migrations

If using Supabase CLI:

```bash
supabase migration up
```

Or apply manually in the Supabase Dashboard:
1. Go to SQL Editor
2. Run each migration file in order (by timestamp)

### Migration Order

Migrations should be applied in this order:
1. `create_profiles.sql` (no dependencies)
2. `create_rituals.sql` (depends on auth.users)
3. `create_sessions.sql` (depends on auth.users)
4. `create_session_assets.sql` (depends on sessions)
5. `create_session_feedback.sql` (depends on sessions and auth.users)
6. `create_user_streaks.sql` (depends on sessions and auth.users)
7. `create_analytics_views.sql` (depends on sessions and profiles)

## Database Schema Relationships

```
auth.users
  ├── profiles (1:1)
  ├── rituals (1:many)
  ├── sessions (1:many)
  │     ├── session_assets (1:many)
  │     └── session_feedback (1:1)
  └── user_streaks (1:1)
```

## Streak System

The streak system automatically tracks user engagement by calculating consecutive days with at least one session.

### How Streaks Work

- **Current Streak**: Counts consecutive days with sessions, starting from today or yesterday
- **Longest Streak**: Tracks the longest consecutive day streak ever achieved
- **Streak Calculation**: A streak is active if the user had a session today or yesterday. If the last session was more than 1 day ago, the streak is broken.

### Scheduled Recomputation

The `recompute_user_streaks()` function runs automatically every night at 2:00 AM UTC via `pg_cron`. 

**Setting up pg_cron**:
1. Enable the `pg_cron` extension in Supabase Dashboard (Database > Extensions)
2. The migration will automatically schedule the job, or you can manually run:
   ```sql
   SELECT cron.schedule(
     'nightly-recompute-streaks',
     '0 2 * * *',
     $$SELECT recompute_user_streaks();$$
   );
   ```

**Manual Execution**:
You can manually recompute streaks at any time:
```sql
SELECT recompute_user_streaks();
```

**Viewing Scheduled Jobs**:
```sql
SELECT * FROM cron.job WHERE jobname = 'nightly-recompute-streaks';
```

## Notes

- All tables use UUID primary keys
- Foreign keys use `ON DELETE CASCADE` to maintain referential integrity
- The `update_updated_at_column()` function is created in the profiles migration and reused in others
- Timestamps use `TIMESTAMPTZ` for timezone-aware storage
- The `user_streaks` table is system-managed and users cannot directly insert/update/delete their streaks

