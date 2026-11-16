-- Out together is gone: drop its sessions, location pings and the home
-- location. Bedtime sync replaces it: each phone saves when that night's
-- main sleep started (estimated from Apple Health).

drop table if exists public.together_pings;
drop table if exists public.together_sessions;

alter table public.couples
  drop column if exists home_lat,
  drop column if exists home_lng;

alter table public.daily_metrics
  add column if not exists bed_at timestamptz;
