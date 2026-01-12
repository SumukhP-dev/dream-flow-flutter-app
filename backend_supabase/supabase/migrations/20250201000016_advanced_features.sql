-- Advanced feature tables for Maestro insights, reflections, moodboards, travel, and smart scenes.

-- Session contexts capture lighting / diffuser readings per session
create table if not exists public.session_contexts (
    id uuid primary key default gen_random_uuid(),
    session_id uuid references public.sessions(id) on delete cascade,
    user_id uuid references public.profiles(id) on delete set null,
    lighting_score numeric,
    scent_score numeric,
    note text,
    metadata jsonb default '{}'::jsonb,
    created_at timestamptz not null default timezone('utc', now())
);
create index if not exists idx_session_contexts_session_id on public.session_contexts(session_id);

-- Maestro nightly summaries + audit log
create table if not exists public.maestro_insight_summaries (
    id uuid primary key,
    user_id uuid references public.profiles(id) on delete cascade,
    nightly_tip jsonb not null,
    streaks jsonb not null,
    environment jsonb not null,
    quick_actions jsonb not null,
    streak_days integer not null default 0,
    computed_at timestamptz not null default timezone('utc', now())
);
create index if not exists idx_maestro_insights_user_id on public.maestro_insight_summaries(user_id);

create table if not exists public.maestro_coach_activity (
    id uuid primary key,
    user_id uuid references public.profiles(id) on delete set null,
    action_id text not null,
    slider_value numeric,
    created_at timestamptz not null default timezone('utc', now())
);
create index if not exists idx_maestro_activity_user_id on public.maestro_coach_activity(user_id);

-- Narrative reflections + derived topics
create table if not exists public.story_reflections (
    id uuid primary key,
    user_id uuid references public.profiles(id) on delete set null,
    session_id uuid references public.sessions(id) on delete set null,
    child_profile_id uuid references public.family_profiles(id) on delete set null,
    mood text not null,
    note text,
    transcript text,
    audio_url text,
    sentiment numeric,
    tags text[] default '{}'::text[],
    created_at timestamptz not null default timezone('utc', now())
);
create index if not exists idx_story_reflections_user_id on public.story_reflections(user_id);

create table if not exists public.reflection_topics (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references public.profiles(id) on delete cascade,
    label text not null,
    mentions integer not null default 0,
    week_start date not null default current_date,
    created_at timestamptz not null default timezone('utc', now())
);
create index if not exists idx_reflection_topics_user_week on public.reflection_topics(user_id, week_start);

-- Travel intelligence
create table if not exists public.travel_itineraries (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references public.profiles(id) on delete cascade,
    start_date date not null,
    end_date date not null,
    timezone_offset integer default 0,
    location text,
    location_type text,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);
create index if not exists idx_travel_itineraries_user_dates on public.travel_itineraries(user_id, start_date);

-- Moodboard cache
create table if not exists public.moodboard_loops (
    session_id uuid primary key references public.sessions(id) on delete cascade,
    preview_url text not null,
    frames text[] not null,
    requires_moderation boolean not null default false,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

-- Smart scene presets + activity log
create table if not exists public.smart_scene_presets (
    id text primary key,
    user_id uuid references public.profiles(id) on delete set null,
    name text not null,
    description text,
    actions jsonb not null default '[]'::jsonb,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.smart_scene_activity (
    id uuid primary key,
    scene_id text not null,
    user_id uuid references public.profiles(id) on delete set null,
    trigger_source text not null default 'app',
    created_at timestamptz not null default timezone('utc', now())
);
create index if not exists idx_smart_scene_activity_user_id on public.smart_scene_activity(user_id);

