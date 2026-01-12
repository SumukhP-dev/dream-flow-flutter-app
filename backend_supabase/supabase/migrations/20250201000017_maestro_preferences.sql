-- Maestro Mode preferences stored alongside existing notification settings.

alter table if exists public.notification_preferences
    add column if not exists maestro_nudges_enabled boolean not null default false;

alter table if exists public.notification_preferences
    add column if not exists maestro_digest_time time;

create index if not exists idx_notification_preferences_maestro_opt_in
    on public.notification_preferences (maestro_nudges_enabled);

