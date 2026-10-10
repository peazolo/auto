-- Keep the RLS helper out of the exposed API schema, and index the remaining foreign keys.
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create or replace function private.owns_vehicle(v uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.vehicles where id = v and user_id = (select auth.uid()));
$$;
revoke execute on function private.owns_vehicle(uuid) from public, anon;
grant execute on function private.owns_vehicle(uuid) to authenticated;

alter policy "tasks: own" on public.maintenance_tasks
  with check (user_id = (select auth.uid()) and private.owns_vehicle(vehicle_id));
alter policy "logs: own" on public.maintenance_logs
  with check (user_id = (select auth.uid()) and private.owns_vehicle(vehicle_id));
alter policy "documents: own" on public.documents
  with check (user_id = (select auth.uid()) and (vehicle_id is null or private.owns_vehicle(vehicle_id)));

-- The old public helper is no longer used by any policy; nobody may call it.
revoke execute on function public.owns_vehicle(uuid) from public, anon, authenticated;

create index diagnosis_chats_vehicle_idx on public.diagnosis_chats (vehicle_id);
create index documents_vehicle_idx on public.documents (vehicle_id);
create index maintenance_logs_task_idx on public.maintenance_logs (task_id);
