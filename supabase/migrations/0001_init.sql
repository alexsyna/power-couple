-- Power Couple: initial schema.
--
-- The database stores facts only: who is in which couple and which tasks were
-- logged (append-only, undo is a soft flag). Points, boss outcomes, quests,
-- streaks and summaries are derived on the client by the shared scoring engine
-- (lib/domain), so past weeks can be recalculated after backdating or undo
-- without any server-side state to keep in sync.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------- tables

create table public.profiles (
  id uuid primary key references auth.users on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 40),
  created_at timestamptz not null default now()
);

create table public.couples (
  id uuid primary key default gen_random_uuid(),
  timezone text not null,
  has_kids boolean not null default false,
  has_pets boolean not null default false,
  invite_code text not null unique
    default upper(substr(encode(gen_random_bytes(5), 'hex'), 1, 8)),
  created_by uuid references auth.users on delete set null,
  created_at timestamptz not null default now()
);

create table public.couple_members (
  couple_id uuid not null references public.couples on delete cascade,
  user_id uuid not null references auth.users on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (couple_id, user_id),
  unique (user_id) -- a user belongs to at most one couple
);

create table public.task_logs (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples on delete cascade,
  task_id text not null,
  custom_name text check (custom_name is null or char_length(custom_name) between 1 and 60),
  -- Nullable so a deleted account leaves its history as "former partner".
  logged_by uuid references auth.users on delete set null,
  -- Partner who shared the task: points split, team gets full value.
  shared_with uuid references auth.users on delete set null,
  done_at timestamptz not null,
  created_at timestamptz not null default now(),
  undone_at timestamptz,
  undone_by uuid references auth.users on delete set null,
  check (task_id <> 'other' or custom_name is not null),
  check (done_at <= created_at + interval '5 minutes')
);

create index task_logs_couple_done_idx on public.task_logs (couple_id, done_at);

-- ---------------------------------------------------------------- helpers

create or replace function public.is_member(c uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from couple_members where couple_id = c and user_id = auth.uid()
  );
$$;

create or replace function public.shares_couple_with(other uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1
    from couple_members a
    join couple_members b on a.couple_id = b.couple_id
    where a.user_id = auth.uid() and b.user_id = other
  );
$$;

-- ---------------------------------------------------------------- RLS

alter table public.profiles enable row level security;
alter table public.couples enable row level security;
alter table public.couple_members enable row level security;
alter table public.task_logs enable row level security;

create policy "profiles: read self and partner" on public.profiles
  for select using (id = auth.uid() or public.shares_couple_with(id));
create policy "profiles: insert self" on public.profiles
  for insert with check (id = auth.uid());
create policy "profiles: update self" on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

create policy "couples: members read" on public.couples
  for select using (public.is_member(id));
create policy "couples: members update" on public.couples
  for update using (public.is_member(id)) with check (public.is_member(id));

create policy "members: members read" on public.couple_members
  for select using (public.is_member(couple_id));

create policy "logs: members read" on public.task_logs
  for select using (public.is_member(couple_id));
create policy "logs: members insert own" on public.task_logs
  for insert with check (
    public.is_member(couple_id)
    and logged_by = auth.uid()
    and undone_at is null
    and (shared_with is null
         or (shared_with <> auth.uid() and public.shares_couple_with(shared_with)))
  );
-- No update/delete policies: undo goes through undo_log() below.

-- ---------------------------------------------------------------- RPCs

create or replace function public.create_couple(tz text, kids boolean, pets boolean)
returns public.couples
language plpgsql security definer set search_path = public
as $$
declare
  c couples;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if exists (select 1 from couple_members where user_id = auth.uid()) then
    raise exception 'already in a household';
  end if;
  insert into couples (timezone, has_kids, has_pets, created_by)
    values (tz, kids, pets, auth.uid())
    returning * into c;
  insert into couple_members (couple_id, user_id) values (c.id, auth.uid());
  return c;
end;
$$;

create or replace function public.join_couple(code text)
returns public.couples
language plpgsql security definer set search_path = public
as $$
declare
  c couples;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if exists (select 1 from couple_members where user_id = auth.uid()) then
    raise exception 'already in a household';
  end if;
  select * into c from couples where invite_code = upper(trim(code)) for update;
  if not found then raise exception 'invite code not found'; end if;
  if (select count(*) from couple_members where couple_id = c.id) >= 2 then
    raise exception 'household is full';
  end if;
  insert into couple_members (couple_id, user_id) values (c.id, auth.uid());
  return c;
end;
$$;

-- Leaving keeps your past logs in the household history.
create or replace function public.leave_couple()
returns void
language sql security definer set search_path = public
as $$
  delete from couple_members where user_id = auth.uid();
$$;

-- Only the person who logged a task can undo it, in any week.
create or replace function public.undo_log(log_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  update task_logs
     set undone_at = now(), undone_by = auth.uid()
   where id = log_id
     and logged_by = auth.uid()
     and undone_at is null
     and public.is_member(couple_id);
  if not found then raise exception 'cannot undo this log'; end if;
end;
$$;

-- ---------------------------------------------------------------- realtime

alter publication supabase_realtime add table public.task_logs;
alter publication supabase_realtime add table public.couple_members;
alter publication supabase_realtime add table public.couples;
