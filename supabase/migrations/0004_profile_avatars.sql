-- Profile avatars: an initial (default), a preset boy/girl avatar, or a photo.
-- Photos live in a private bucket, readable only by the owner and their
-- partner; the app shows them through short-lived signed URLs.

alter table public.profiles
  add column if not exists avatar_kind text not null default 'initial'
    check (avatar_kind in ('initial', 'boy', 'girl', 'photo')),
  add column if not exists avatar_path text;

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', false)
on conflict (id) do nothing;

-- Objects are stored as "<user id>/<file name>".
create policy "avatars: read self and partner" on storage.objects
  for select using (
    bucket_id = 'avatars'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.shares_couple_with(((storage.foldername(name))[1])::uuid)
    )
  );

create policy "avatars: upload own" on storage.objects
  for insert with check (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "avatars: update own" on storage.objects
  for update using (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "avatars: delete own" on storage.objects
  for delete using (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text
  );

-- So a partner's new name or avatar shows up live.
alter publication supabase_realtime add table public.profiles;
