-- Bond: a daily question for each partner. Answers are hidden from the
-- partner until both have answered that day. Each revealed day raises the
-- couple's bond level, which adds bonus damage to the weekly boss.
-- Question packs beyond "light" are unlocked per household (fake payment).

alter table public.couples
  add column if not exists unlocked_packs text[] not null default '{light}',
  -- Bumped on every answer so the partner's app gets a realtime ping even
  -- though it can't see the answer row itself yet.
  add column if not exists last_answer_at timestamptz;

create table public.question_answers (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples on delete cascade,
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  day date not null,
  question_id text not null,
  answer text not null check (char_length(answer) between 1 and 500),
  created_at timestamptz not null default now(),
  unique (user_id, day)
);

create index question_answers_couple_day_idx on public.question_answers (couple_id, day);

-- Whether the caller has answered on this day (bypasses RLS to avoid the
-- policy querying its own table).
create or replace function public.answered_on(c uuid, d date)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from question_answers
    where couple_id = c and day = d and user_id = auth.uid()
  );
$$;

alter table public.question_answers enable row level security;

create policy "answers: own, or partner's once I've answered that day" on public.question_answers
  for select using (
    user_id = auth.uid()
    or (public.is_member(couple_id) and public.answered_on(couple_id, day))
  );

create policy "answers: insert own" on public.question_answers
  for insert with check (user_id = auth.uid() and public.is_member(couple_id));
-- No update/delete: answers are final.

-- Who answered when (no content), for the "partner answered" badge and the
-- bond level.
create or replace function public.answer_log()
returns table (user_id uuid, day date, created_at timestamptz)
language sql stable security definer set search_path = public
as $$
  select a.user_id, a.day, a.created_at
  from question_answers a
  join couple_members m on m.couple_id = a.couple_id and m.user_id = auth.uid();
$$;

create or replace function public.touch_couple_answer()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  update couples set last_answer_at = now() where id = new.couple_id;
  return new;
end;
$$;

create trigger question_answers_touch
  after insert on public.question_answers
  for each row execute function public.touch_couple_answer();
