-- AUTOX schema: profiles, vehicles, maintenance, documents, alerts, AI chats.
-- Every table is protected by row level security so users only see their own data.

create extension if not exists pgcrypto;

-- ───────────────────────── helpers ─────────────────────────
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- ───────────────────────── profiles ─────────────────────────
create table public.profiles (
  id              uuid primary key references auth.users (id) on delete cascade,
  name            text not null default '',
  email           text,
  phone           text,
  email_reminders boolean not null default true,
  distance_unit   text not null default 'km' check (distance_unit in ('km', 'mi')),
  currency        text not null default 'USD' check (currency ~ '^[A-Z]{3}$'),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, name, email)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'name', ''), new.email);
  insert into public.notifications (user_id, kind, title, body, link)
  values (new.id, 'welcome', 'Welcome to AUTOX',
          'Add your first vehicle, then set up maintenance reminders and upload your documents.',
          '/vehicles/new');
  return new;
end $$;

create or replace function public.handle_user_email_change()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.profiles set email = new.email where id = new.id;
  return new;
end $$;

-- ───────────────────────── vehicles ─────────────────────────
create table public.vehicles (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null default auth.uid() references auth.users (id) on delete cascade,
  nickname           text check (char_length(nickname) <= 60),
  make               text not null check (char_length(make) between 1 and 60),
  model              text not null check (char_length(model) between 1 and 60),
  year               int  not null check (year between 1900 and 2100),
  trim               text check (char_length(trim) <= 60),
  color              text check (char_length(color) <= 40),
  vin                text check (char_length(vin) <= 32),
  plate              text check (char_length(plate) <= 20),
  fuel_type          text check (char_length(fuel_type) <= 30),
  mileage            int  not null default 0 check (mileage >= 0),
  mileage_updated_at timestamptz not null default now(),
  photo_path         text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
create index vehicles_user_idx on public.vehicles (user_id);
create trigger vehicles_touch before update on public.vehicles
  for each row execute function public.touch_updated_at();

-- ───────────────────────── maintenance ─────────────────────────
create table public.maintenance_tasks (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null default auth.uid() references auth.users (id) on delete cascade,
  vehicle_id            uuid not null references public.vehicles (id) on delete cascade,
  name                  text not null check (char_length(name) between 1 and 100),
  category              text not null default 'General',
  interval_days         int check (interval_days > 0),
  interval_mileage      int check (interval_mileage > 0),
  last_done_at          date,
  last_done_mileage     int check (last_done_mileage >= 0),
  next_due_at           date,
  next_due_mileage      int,
  remind_days_before    int not null default 7 check (remind_days_before between 0 and 365),
  remind_mileage_before int not null default 500 check (remind_mileage_before >= 0),
  notes                 text check (char_length(notes) <= 1000),
  last_notified_at      timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
create index maintenance_tasks_user_idx on public.maintenance_tasks (user_id);
create index maintenance_tasks_vehicle_idx on public.maintenance_tasks (vehicle_id);
create trigger maintenance_tasks_touch before update on public.maintenance_tasks
  for each row execute function public.touch_updated_at();

create table public.maintenance_logs (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users (id) on delete cascade,
  vehicle_id   uuid not null references public.vehicles (id) on delete cascade,
  task_id      uuid references public.maintenance_tasks (id) on delete set null,
  title        text not null check (char_length(title) between 1 and 120),
  performed_at date not null,
  mileage      int check (mileage >= 0),
  cost         numeric(12, 2) check (cost >= 0),
  shop         text check (char_length(shop) <= 100),
  notes        text check (char_length(notes) <= 1000),
  created_at   timestamptz not null default now()
);
create index maintenance_logs_user_idx on public.maintenance_logs (user_id, performed_at desc);
create index maintenance_logs_vehicle_idx on public.maintenance_logs (vehicle_id);

-- ───────────────────────── documents ─────────────────────────
create table public.documents (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null default auth.uid() references auth.users (id) on delete cascade,
  vehicle_id         uuid references public.vehicles (id) on delete set null,
  type               text not null default 'other' check (type in (
                       'drivers_license', 'insurance', 'registration', 'roadworthiness', 'inspection',
                       'emissions', 'permit', 'warranty', 'receipt', 'other')),
  title              text not null check (char_length(title) between 1 and 120),
  number             text check (char_length(number) <= 80),
  issuer             text check (char_length(issuer) <= 120),
  issued_at          date,
  expires_at         date,
  remind_days_before int not null default 30 check (remind_days_before between 0 and 730),
  file_path          text,
  file_name          text,
  file_type          text,
  file_size          int,
  notes              text check (char_length(notes) <= 2000),
  last_notified_at   timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  check (expires_at is null or issued_at is null or expires_at >= issued_at)
);
create index documents_user_idx on public.documents (user_id);
create index documents_expiry_idx on public.documents (expires_at);
create trigger documents_touch before update on public.documents
  for each row execute function public.touch_updated_at();

-- ───────────────────────── notifications ─────────────────────────
create table public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  kind       text not null,
  title      text not null,
  body       text not null,
  link       text,
  read_at    timestamptz,
  created_at timestamptz not null default now()
);
create index notifications_user_idx on public.notifications (user_id, created_at desc);

-- ───────────────────────── AI mechanic ─────────────────────────
create table public.diagnosis_chats (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
  vehicle_id uuid references public.vehicles (id) on delete set null,
  title      text not null default 'New diagnosis',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index diagnosis_chats_user_idx on public.diagnosis_chats (user_id, updated_at desc);

create table public.diagnosis_messages (
  id          uuid primary key default gen_random_uuid(),
  chat_id     uuid not null references public.diagnosis_chats (id) on delete cascade,
  user_id     uuid not null references auth.users (id) on delete cascade,
  role        text not null check (role in ('user', 'assistant')),
  content     text not null default '',
  attachments jsonb not null default '[]'::jsonb,
  created_at  timestamptz not null default now()
);
create index diagnosis_messages_chat_idx on public.diagnosis_messages (chat_id, created_at);
create index diagnosis_messages_user_idx on public.diagnosis_messages (user_id, created_at);

-- Auth triggers (created after notifications exists).
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();
create trigger on_auth_user_email_changed after update of email on auth.users
  for each row execute function public.handle_user_email_change();

-- ───────────────────────── row level security ─────────────────────────
alter table public.profiles           enable row level security;
alter table public.vehicles           enable row level security;
alter table public.maintenance_tasks  enable row level security;
alter table public.maintenance_logs   enable row level security;
alter table public.documents          enable row level security;
alter table public.notifications      enable row level security;
alter table public.diagnosis_chats    enable row level security;
alter table public.diagnosis_messages enable row level security;

create or replace function public.owns_vehicle(v uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.vehicles where id = v and user_id = (select auth.uid()));
$$;

create policy "profile: read own" on public.profiles for select using (id = (select auth.uid()));
create policy "profile: update own" on public.profiles for update using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy "vehicles: own" on public.vehicles for all
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy "tasks: own" on public.maintenance_tasks for all
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()) and public.owns_vehicle(vehicle_id));

create policy "logs: own" on public.maintenance_logs for all
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()) and public.owns_vehicle(vehicle_id));

create policy "documents: own" on public.documents for all
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()) and (vehicle_id is null or public.owns_vehicle(vehicle_id)));

create policy "notifications: read own" on public.notifications for select using (user_id = (select auth.uid()));
create policy "notifications: update own" on public.notifications for update using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "notifications: delete own" on public.notifications for delete using (user_id = (select auth.uid()));

create policy "chats: read own" on public.diagnosis_chats for select using (user_id = (select auth.uid()));
create policy "chats: delete own" on public.diagnosis_chats for delete using (user_id = (select auth.uid()));
create policy "messages: read own" on public.diagnosis_messages for select using (user_id = (select auth.uid()));
-- Chats and messages are written only by the `diagnose` edge function (service role).

-- ───────────────────────── RPC: complete a maintenance task ─────────────────────────
-- Logs the service, reschedules the task and bumps the odometer in one transaction.
create or replace function public.complete_maintenance_task(
  p_task_id uuid,
  p_performed_at date,
  p_mileage int default null,
  p_cost numeric default null,
  p_shop text default null,
  p_notes text default null
) returns void language plpgsql security invoker set search_path = '' as $$
declare
  t public.maintenance_tasks;
  v public.vehicles;
  m int;
begin
  select * into t from public.maintenance_tasks where id = p_task_id and user_id = auth.uid();
  if not found then raise exception 'Reminder not found'; end if;
  select * into v from public.vehicles where id = t.vehicle_id;
  m := coalesce(p_mileage, v.mileage);

  insert into public.maintenance_logs (user_id, vehicle_id, task_id, title, performed_at, mileage, cost, shop, notes)
  values (t.user_id, t.vehicle_id, t.id, t.name, p_performed_at, m, p_cost, nullif(p_shop, ''), nullif(p_notes, ''));

  update public.maintenance_tasks set
    last_done_at      = p_performed_at,
    last_done_mileage = m,
    next_due_at       = case when t.interval_days is not null then p_performed_at + t.interval_days else null end,
    next_due_mileage  = case when t.interval_mileage is not null then m + t.interval_mileage else null end,
    last_notified_at  = null
  where id = t.id;

  if m > v.mileage then
    update public.vehicles set mileage = m, mileage_updated_at = now() where id = v.id;
  end if;
end $$;

grant execute on function public.complete_maintenance_task(uuid, date, int, numeric, text, text) to authenticated;

-- ───────────────────────── storage ─────────────────────────
-- Private bucket. Files live under "<user id>/..." and only their owner can touch them.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('files', 'files', false, 26214400,
        array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif', 'image/gif', 'application/pdf'])
on conflict (id) do nothing;

create policy "files: owner read" on storage.objects for select to authenticated
  using (bucket_id = 'files' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "files: owner insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'files' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "files: owner update" on storage.objects for update to authenticated
  using (bucket_id = 'files' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "files: owner delete" on storage.objects for delete to authenticated
  using (bucket_id = 'files' and (storage.foldername(name))[1] = (select auth.uid())::text);
