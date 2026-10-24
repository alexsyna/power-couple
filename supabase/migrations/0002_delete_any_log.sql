-- Either partner can delete any task log in their household, not just their
-- own. Deletion stays a soft flag (undone_at/undone_by) so the history can
-- still show who removed what.

create or replace function public.undo_log(log_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  update task_logs
     set undone_at = now(), undone_by = auth.uid()
   where id = log_id
     and undone_at is null
     and public.is_member(couple_id);
  if not found then raise exception 'cannot delete this log'; end if;
end;
$$;
