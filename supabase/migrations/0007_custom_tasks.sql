-- Custom tasks: a household can add its own tasks to any category (except
-- "Other"), worth 10 to 50 points in steps of 5. Either partner can add or
-- delete them. Deleting is soft, so logs already made keep their points.
-- Logs refer to them as task_id 'custom_<id>'.

create table public.household_tasks (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 40),
  category text not null check (category in (
    'shopping', 'cooking', 'kitchen', 'laundry', 'cleaning', 'bathroom', 'tidying',
    'maintenance', 'planning', 'supplies', 'childcare', 'pets')),
  points int not null check (points between 10 and 50 and points % 5 = 0),
  created_by uuid references auth.users on delete set null,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  deleted_by uuid references auth.users on delete set null
);

create index household_tasks_couple_idx on public.household_tasks (couple_id);

alter table public.household_tasks enable row level security;

create policy "household tasks: members read" on public.household_tasks
  for select using (public.is_member(couple_id));

create policy "household tasks: members create" on public.household_tasks
  for insert with check (
    public.is_member(couple_id)
    and created_by = auth.uid()
    and deleted_at is null
  );

-- Members can (soft) delete; moving a task to another household is not allowed.
create policy "household tasks: members update" on public.household_tasks
  for update using (public.is_member(couple_id))
  with check (public.is_member(couple_id));

alter publication supabase_realtime add table public.household_tasks;
