-- Push notifications for Bond: when someone answers, their partner's phones
-- get "your turn" (partner hasn't answered yet) or "both answers are in"
-- (this answer completed the day). Sent by the bond-push Edge Function.

-- One row per phone that has notifications turned on. Turning them off in
-- Settings deletes the row. Only the Edge Function (service role) reads it.
create table public.device_tokens (
  token text primary key,
  user_id uuid not null references auth.users on delete cascade,
  platform text not null default 'ios',
  updated_at timestamptz not null default now()
);

alter table public.device_tokens enable row level security;
-- No policies: the app goes through the two functions below.

-- Register this phone for the signed-in user. A phone can only belong to
-- one account, so a token used by a previous account moves to this one.
create or replace function public.register_device(p_token text, p_platform text default 'ios')
returns void
language sql security definer set search_path = public
as $$
  insert into device_tokens (token, user_id, platform, updated_at)
  values (p_token, auth.uid(), p_platform, now())
  on conflict (token) do update
    set user_id = auth.uid(), platform = excluded.platform, updated_at = now();
$$;

create or replace function public.unregister_device(p_token text)
returns void
language sql security definer set search_path = public
as $$
  delete from device_tokens where token = p_token and user_id = auth.uid();
$$;

revoke all on function public.register_device(text, text) from public, anon;
revoke all on function public.unregister_device(text) from public, anon;
grant execute on function public.register_device(text, text) to authenticated;
grant execute on function public.unregister_device(text) to authenticated;

-- Set by the Edge Function when it has handled an answer, so a repeated call
-- never sends the same notification twice.
alter table public.question_answers add column if not exists notified_at timestamptz;

-- Call the Edge Function after each answer. It only receives the answer id
-- and reads everything else itself, so the call needs no secret.
create extension if not exists pg_net;

create or replace function public.bond_push()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  perform net.http_post(
    url := 'https://kywifzncslgmdjlyckhu.supabase.co/functions/v1/bond-push',
    body := jsonb_build_object('answer_id', new.id),
    headers := '{"Content-Type": "application/json"}'::jsonb
  );
  return new;
end;
$$;

create trigger question_answers_push
  after insert on public.question_answers
  for each row execute function public.bond_push();
