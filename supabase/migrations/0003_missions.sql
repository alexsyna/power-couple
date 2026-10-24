-- Missions: shared to-dos with a due date. Either partner can create, edit,
-- pick up, complete or delete them. They earn no points and don't affect the
-- boss, quests or streaks; completed missions show in the activity feed.

create table public.missions (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples on delete cascade,
  title text not null check (char_length(title) between 1 and 80),
  due_on date not null,
  created_by uuid references auth.users on delete set null,
  created_at timestamptz not null default now(),
  -- Partner who picked it up, if any.
  assignee uuid references auth.users on delete set null,
  completed_at timestamptz,
  completed_by uuid references auth.users on delete set null,
  -- Soft delete, like task logs.
  deleted_at timestamptz,
  deleted_by uuid references auth.users on delete set null
);

create index missions_couple_idx on public.missions (couple_id, due_on);

alter table public.missions enable row level security;

create policy "missions: members read" on public.missions
  for select using (public.is_member(couple_id));

create policy "missions: members create" on public.missions
  for insert with check (
    public.is_member(couple_id)
    and created_by = auth.uid()
    and completed_at is null
    and deleted_at is null
    and (assignee is null or assignee = auth.uid() or public.shares_couple_with(assignee))
  );

-- Members can edit, pick up, complete and (soft) delete any mission in their
-- household. Moving a mission to another household is not allowed.
create policy "missions: members update" on public.missions
  for update using (public.is_member(couple_id))
  with check (
    public.is_member(couple_id)
    and (assignee is null or assignee = auth.uid() or public.shares_couple_with(assignee))
  );

alter publication supabase_realtime add table public.missions;
