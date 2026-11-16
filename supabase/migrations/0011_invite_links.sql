-- Invite links: powercouple.mindblo.app/c/<climb code> and /h/<household code>.

-- What a link leads to, for the landing page (works signed out: the code
-- itself is the secret). Returns null for unknown codes.
create or replace function public.invite_info(p_code text)
returns json
language plpgsql stable security definer set search_path = public
as $$
declare
  code text := upper(trim(p_code));
  c challenges;
  h couples;
begin
  select * into c from challenges where invite_code = code;
  if found then
    return json_build_object(
      'kind', 'climb',
      'teams', (select coalesce(json_agg(t.name order by t.joined_at), '[]'::json)
                from challenge_teams t where t.challenge_id = c.id),
      'days', c.days,
      'activities', c.activities,
      'stakes', c.stakes,
      'starts_on', c.starts_on,
      'open', now() <= (c.starts_on + 1)::timestamptz + interval '14 hours'
              and (select count(*) from challenge_teams t where t.challenge_id = c.id) < 6
    );
  end if;
  select * into h from couples where invite_code = code;
  if found then
    return json_build_object(
      'kind', 'household',
      'inviter', (select p.display_name from couple_members m join profiles p on p.id = m.user_id
                  where m.couple_id = h.id order by m.joined_at limit 1),
      'full', (select count(*) from couple_members m where m.couple_id = h.id) >= 2
    );
  end if;
  return null;
end;
$$;

revoke execute on function public.invite_info(text) from public;
grant execute on function public.invite_info(text) to anon, authenticated;

-- A rope team's name follows its household: "Maria" becomes
-- "Maria & Nikos" when Nikos joins, and follows name changes.
create or replace function public.refresh_team_names(c uuid)
returns void
language sql security definer set search_path = public
as $$
  update challenge_teams t
  set name = coalesce((
    select string_agg(p.display_name, ' & ' order by m.joined_at)
    from couple_members m join profiles p on p.id = m.user_id
    where m.couple_id = c
  ), t.name)
  where t.couple_id = c;
$$;

revoke execute on function public.refresh_team_names(uuid) from public, anon, authenticated;

create or replace function public.team_names_on_member()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  perform refresh_team_names(coalesce(new.couple_id, old.couple_id));
  return coalesce(new, old);
end;
$$;

create trigger couple_members_team_names
  after insert or delete on public.couple_members
  for each row execute function public.team_names_on_member();

create or replace function public.team_names_on_profile()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if new.display_name is distinct from old.display_name then
    perform refresh_team_names(m.couple_id) from couple_members m where m.user_id = new.id;
  end if;
  return new;
end;
$$;

create trigger profiles_team_names
  after update of display_name on public.profiles
  for each row execute function public.team_names_on_profile();
