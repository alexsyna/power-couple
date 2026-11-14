-- Daily stars: Apple Health numbers, Snap moments and Out together
-- sessions. The app turns these into 0-3 stars per activity per day.
-- Everything is readable by both partners of a household only.

-- Home location: time near home doesn't count as "out together".
alter table public.couples
  add column if not exists home_lat double precision,
  add column if not exists home_lng double precision;

-- ------------------------------------------------------------ health

-- One row per person per household-local day, written by their phone.
create table public.daily_metrics (
  user_id uuid not null references auth.users on delete cascade,
  couple_id uuid not null references public.couples on delete cascade,
  day date not null,
  steps int check (steps >= 0),
  sleep_minutes int check (sleep_minutes between 0 and 1440),
  updated_at timestamptz not null default now(),
  primary key (user_id, day)
);

create index daily_metrics_couple_idx on public.daily_metrics (couple_id, day);

alter table public.daily_metrics enable row level security;

create policy "metrics: members read" on public.daily_metrics
  for select using (public.is_member(couple_id));

create policy "metrics: write own" on public.daily_metrics
  for insert with check (user_id = auth.uid() and public.is_member(couple_id));

create policy "metrics: update own" on public.daily_metrics
  for update using (user_id = auth.uid())
  with check (user_id = auth.uid() and public.is_member(couple_id));

-- -------------------------------------------------------------- snaps

-- One photo per person per day. created_at is the server's clock, so a
-- phone can't fake how fast it answered the prompt.
create table public.snaps (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples on delete cascade,
  user_id uuid not null references auth.users on delete cascade,
  day date not null,
  path text not null,
  created_at timestamptz not null default now(),
  unique (user_id, day)
);

create index snaps_couple_idx on public.snaps (couple_id, day);

alter table public.snaps enable row level security;

create policy "snaps: members read" on public.snaps
  for select using (public.is_member(couple_id));

create policy "snaps: add own" on public.snaps
  for insert with check (
    user_id = auth.uid()
    and public.is_member(couple_id)
    and created_at between now() - interval '1 minute' and now() + interval '1 minute'
  );

insert into storage.buckets (id, name, public)
values ('snaps', 'snaps', false)
on conflict (id) do nothing;

-- Objects are stored as "<couple id>/<user id>/<day>.jpg".
create policy "snaps: read household" on storage.objects
  for select using (
    bucket_id = 'snaps' and public.is_member(((storage.foldername(name))[1])::uuid)
  );

create policy "snaps: upload own" on storage.objects
  for insert with check (
    bucket_id = 'snaps'
    and public.is_member(((storage.foldername(name))[1])::uuid)
    and (storage.foldername(name))[2] = auth.uid()::text
  );

-- ------------------------------------------------------- out together

create table public.together_sessions (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples on delete cascade,
  started_by uuid not null references auth.users on delete cascade,
  started_at timestamptz not null default now(),
  joined_by uuid references auth.users on delete set null,
  joined_at timestamptz,
  ended_at timestamptz,
  ended_by uuid references auth.users on delete set null
);

create index together_sessions_couple_idx on public.together_sessions (couple_id, started_at);

alter table public.together_sessions enable row level security;

create policy "together: members read" on public.together_sessions
  for select using (public.is_member(couple_id));

create policy "together: members start" on public.together_sessions
  for insert with check (
    started_by = auth.uid() and public.is_member(couple_id)
    and joined_by is null and ended_at is null
  );

-- Join (the partner) or end (either).
create policy "together: members update" on public.together_sessions
  for update using (public.is_member(couple_id))
  with check (public.is_member(couple_id) and (joined_by is null or joined_by <> started_by));

-- Positions are only recorded while a session runs.
create table public.together_pings (
  id bigint generated always as identity primary key,
  session_id uuid not null references public.together_sessions on delete cascade,
  user_id uuid not null references auth.users on delete cascade,
  at timestamptz not null default now(),
  lat double precision not null,
  lng double precision not null
);

create index together_pings_session_idx on public.together_pings (session_id, at);

alter table public.together_pings enable row level security;

create policy "pings: members read" on public.together_pings
  for select using (
    exists (select 1 from public.together_sessions s where s.id = session_id and public.is_member(s.couple_id))
  );

create policy "pings: add own while running" on public.together_pings
  for insert with check (
    user_id = auth.uid()
    and at between now() - interval '1 minute' and now() + interval '1 minute'
    and exists (
      select 1 from public.together_sessions s
      where s.id = session_id
        and public.is_member(s.couple_id)
        and s.ended_at is null
        and s.started_at > now() - interval '6 hours'
    )
  );

alter publication supabase_realtime add table public.daily_metrics;
alter publication supabase_realtime add table public.snaps;
alter publication supabase_realtime add table public.together_sessions;
