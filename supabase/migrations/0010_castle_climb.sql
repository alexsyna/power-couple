-- Castle Climb: 2 to 6 couples ("rope teams") race up a mountain to a
-- castle. Every day each chosen activity gives a team 0-3 stars; the last
-- day counts double ("Final ascent"). Other teams' stars stay hidden in
-- the fog until reveal_at, enforced here, not just in the app.

create table public.challenges (
  id uuid primary key default gen_random_uuid(),
  invite_code text not null unique
    default upper(substr(encode(gen_random_bytes(4), 'hex'), 1, 6)),
  created_by uuid references auth.users on delete set null,
  created_at timestamptz not null default now(),
  activities text[] not null check (
    cardinality(activities) between 1 and 5
    and activities <@ array['chores', 'steps', 'sleep', 'bedtime', 'snap']
  ),
  days int not null check (days in (3, 7, 14, 30)),
  -- Day 1 in each team's own household calendar.
  starts_on date not null,
  -- When everyone's stars become visible (the day after the last day).
  reveal_at timestamptz not null,
  stakes text check (char_length(stakes) <= 80)
);

create table public.challenge_teams (
  challenge_id uuid not null references public.challenges on delete cascade,
  couple_id uuid not null references public.couples on delete cascade,
  -- "Alex & Sam", saved at joining: other teams can't read our profiles.
  name text not null check (char_length(name) between 1 and 60),
  banner text not null check (char_length(banner) between 1 and 8),
  joined_at timestamptz not null default now(),
  -- When the team last earned a star. Others see this, never the count.
  last_climb_at timestamptz,
  primary key (challenge_id, couple_id)
);

create index challenge_teams_couple_idx on public.challenge_teams (couple_id);

create table public.challenge_scores (
  challenge_id uuid not null,
  couple_id uuid not null,
  day date not null,
  activity text not null,
  stars int not null check (stars between 0 and 3),
  updated_at timestamptz not null default now(),
  primary key (challenge_id, couple_id, day, activity),
  foreign key (challenge_id, couple_id) references public.challenge_teams on delete cascade
);

-- ---------------------------------------------------------------- helpers

-- Is my household one of the teams?
create or replace function public.in_challenge(ch uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from challenge_teams t
    join couple_members m on m.couple_id = t.couple_id
    where t.challenge_id = ch and m.user_id = auth.uid()
  );
$$;

create or replace function public.my_couple()
returns uuid
language sql stable security definer set search_path = public
as $$
  select couple_id from couple_members where user_id = auth.uid() limit 1;
$$;

-- ---------------------------------------------------------------- RLS

alter table public.challenges enable row level security;
alter table public.challenge_teams enable row level security;
alter table public.challenge_scores enable row level security;

create policy "challenges: teams read" on public.challenges
  for select using (public.in_challenge(id));

create policy "teams: teams read" on public.challenge_teams
  for select using (public.in_challenge(challenge_id));

-- Own stars any time; everyone's once the fog lifts.
create policy "scores: own, or all after reveal" on public.challenge_scores
  for select using (
    public.is_member(couple_id)
    or (public.in_challenge(challenge_id)
        and exists (select 1 from challenges c where c.id = challenge_id and c.reveal_at <= now()))
  );

-- A team writes its own stars, for challenge days, until the reveal.
create policy "scores: write own before reveal" on public.challenge_scores
  for insert with check (
    public.is_member(couple_id)
    and exists (
      select 1 from challenges c
      where c.id = challenge_id and now() < c.reveal_at
        and day between c.starts_on and c.starts_on + (c.days - 1)
        and activity = any (c.activities)
    )
  );

create policy "scores: update own before reveal" on public.challenge_scores
  for update using (public.is_member(couple_id))
  with check (
    public.is_member(couple_id)
    and exists (select 1 from challenges c where c.id = challenge_id and now() < c.reveal_at)
  );

-- Earning a star lets the other teams see "they just climbed".
create or replace function public.challenge_climbed()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if new.stars > coalesce(case when tg_op = 'UPDATE' then old.stars end, 0) then
    update challenge_teams set last_climb_at = now()
    where challenge_id = new.challenge_id and couple_id = new.couple_id;
  end if;
  return new;
end;
$$;

create trigger challenge_scores_climbed
  after insert or update on public.challenge_scores
  for each row execute function public.challenge_climbed();

-- ---------------------------------------------------------------- RPCs

create or replace function public.create_challenge(
  p_activities text[], p_days int, p_starts_on date, p_reveal_at timestamptz,
  p_stakes text, p_team_name text, p_banner text)
returns public.challenges
language plpgsql security definer set search_path = public
as $$
declare
  c challenges;
  me uuid := public.my_couple();
begin
  if me is null then raise exception 'join a household first'; end if;
  insert into challenges (created_by, activities, days, starts_on, reveal_at, stakes)
    values (auth.uid(), p_activities, p_days, p_starts_on, p_reveal_at, nullif(trim(p_stakes), ''))
    returning * into c;
  insert into challenge_teams (challenge_id, couple_id, name, banner)
    values (c.id, me, p_team_name, p_banner);
  return c;
end;
$$;

-- What a code leads to, before joining (shown on the join screen).
create or replace function public.preview_challenge(p_code text)
returns table (id uuid, activities text[], days int, starts_on date, stakes text, teams bigint, already_in boolean)
language sql stable security definer set search_path = public
as $$
  select c.id, c.activities, c.days, c.starts_on, c.stakes,
         (select count(*) from challenge_teams t where t.challenge_id = c.id),
         exists (select 1 from challenge_teams t where t.challenge_id = c.id and t.couple_id = public.my_couple())
  from challenges c
  where c.invite_code = upper(trim(p_code));
$$;

create or replace function public.join_challenge(p_code text, p_team_name text, p_banner text)
returns public.challenges
language plpgsql security definer set search_path = public
as $$
declare
  c challenges;
  me uuid := public.my_couple();
begin
  if me is null then raise exception 'join a household first'; end if;
  select * into c from challenges where invite_code = upper(trim(p_code)) for update;
  if not found then raise exception 'challenge code not found'; end if;
  if exists (select 1 from challenge_teams where challenge_id = c.id and couple_id = me) then
    raise exception 'already in this climb';
  end if;
  -- Joining closes at the end of day 1 (a little slack for time zones).
  if now() > (c.starts_on + 1)::timestamptz + interval '14 hours' then
    raise exception 'this climb has already started';
  end if;
  if (select count(*) from challenge_teams where challenge_id = c.id) >= 6 then
    raise exception 'this climb is full';
  end if;
  insert into challenge_teams (challenge_id, couple_id, name, banner)
    values (c.id, me, p_team_name, p_banner);
  return c;
end;
$$;

revoke execute on function public.create_challenge(text[], int, date, timestamptz, text, text, text) from public, anon;
revoke execute on function public.preview_challenge(text) from public, anon;
revoke execute on function public.join_challenge(text, text, text) from public, anon;
grant execute on function public.create_challenge(text[], int, date, timestamptz, text, text, text) to authenticated;
grant execute on function public.preview_challenge(text) to authenticated;
grant execute on function public.join_challenge(text, text, text) to authenticated;
