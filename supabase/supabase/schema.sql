-- Khon Kaen Night — consolidated schema 0001–0006.
-- 0001–0006 are applied on the hosted project xhmlirjwkndvtvjgkwbe (as of 2026-11-23). Run once on a fresh project.

-- ═══════════════ 0001 core schema, booking engine, RLS ═══════════════
create extension if not exists btree_gist with schema extensions;
create extension if not exists pg_trgm with schema extensions;

create function public.set_updated_at() returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at := now(); return new; end $$;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text, phone text, avatar_url text,
  role text not null default 'customer' check (role in ('customer','venue_owner','venue_staff','admin')),
  preferred_language text not null default 'th' check (preferred_language in ('th','en')),
  account_status text not null default 'active' check (account_status in ('active','suspended')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table public.venues (
  id uuid primary key default gen_random_uuid(),
  name_th text, name_en text,
  slug text not null unique,
  description_th text, description_en text,
  category text not null check (category in ('pub','bar','nightclub','lounge','live_music','restaurant','entertainment')),
  address text, district text, province text not null default 'Khon Kaen',
  latitude double precision check (latitude between -90 and 90),
  longitude double precision check (longitude between -180 and 180),
  phone text, cover_image_url text,
  status text not null default 'pending_review' check (status in ('draft','pending_review','approved','rejected','suspended')),
  -- {"fri":[{"open":"18:00","close":"02:00"}], ...}; close <= open means after midnight. NULL = unknown.
  opening_hours jsonb,
  price_level smallint check (price_level between 1 and 4),
  facilities text[] not null default '{}',
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (coalesce(name_th,'') <> '' or coalesce(name_en,'') <> '')
);
create index venues_status_idx on public.venues(status);
create index venues_name_th_trgm on public.venues using gin (name_th gin_trgm_ops);
create index venues_name_en_trgm on public.venues using gin (name_en gin_trgm_ops);

create table public.venue_members (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('owner','manager','staff')),
  created_at timestamptz not null default now(),
  unique (venue_id, user_id)
);

create table public.floor_plans (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  name text not null,
  canvas_width numeric not null default 1000 check (canvas_width > 0),
  canvas_height numeric not null default 800 check (canvas_height > 0),
  background_image_url text,
  is_published boolean not null default false,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table public.venue_tables (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  floor_plan_id uuid references public.floor_plans(id) on delete set null,
  table_number text not null,
  name text,
  capacity smallint not null check (capacity > 0),
  table_type text not null default 'standard' check (table_type in ('standard','vip','sofa','private_room','outdoor')),
  position_x numeric not null default 0 check (position_x >= 0),
  position_y numeric not null default 0 check (position_y >= 0),
  width numeric not null default 80 check (width > 0),
  height numeric not null default 80 check (height > 0),
  rotation numeric not null default 0,
  shape text not null default 'rect' check (shape in ('rect','round','oval')),
  is_active boolean not null default true, -- deactivate, never delete: bookings keep history
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique (venue_id, table_number)
);

create table public.events (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  title_th text, title_en text, description_th text, description_en text,
  cover_image_url text,
  start_at timestamptz not null, end_at timestamptz,
  status text not null default 'draft' check (status in ('draft','published','cancelled','completed')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (coalesce(title_th,'') <> '' or coalesce(title_en,'') <> ''),
  check (end_at is null or end_at > start_at)
);

create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  booking_reference text not null unique,
  customer_id uuid not null references public.profiles(id) on delete restrict,
  venue_id uuid not null references public.venues(id) on delete restrict,
  table_id uuid not null references public.venue_tables(id) on delete restrict,
  booking_date date not null, -- Asia/Bangkok calendar date of starts_at
  starts_at timestamptz not null, ends_at timestamptz not null,
  guest_count smallint not null check (guest_count > 0),
  customer_name text not null, customer_phone text not null, customer_note text,
  status text not null default 'pending' check (status in ('pending','confirmed','rejected','cancelled','expired','completed')),
  venue_note text, rejection_reason text, hold_expires_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (ends_at > starts_at),
  -- Database is the final authority against double booking.
  constraint no_overlapping_active_bookings exclude using gist
    (table_id with =, tstzrange(starts_at, ends_at, '[)') with &&)
    where (status in ('pending','confirmed'))
);
create index bookings_customer_idx on public.bookings(customer_id, starts_at desc);
create index bookings_venue_idx on public.bookings(venue_id, status, starts_at);
create index bookings_pending_hold_idx on public.bookings(hold_expires_at) where status = 'pending';

create table public.booking_status_history (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  old_status text, new_status text not null,
  changed_by uuid references public.profiles(id) on delete set null,
  note text, created_at timestamptz not null default now()
);

-- title/body hold translation KEYS (e.g. notif.booking_confirmed.title); clients translate per preferred_language.
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null, body text not null, type text not null,
  related_booking_id uuid references public.bookings(id) on delete cascade,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
create index notifications_user_idx on public.notifications(user_id, created_at desc);

create table public.admin_audit_log (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid references public.profiles(id) on delete set null,
  action text not null, target_type text not null, target_id uuid,
  reason text, metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create table public.platform_settings (key text primary key, value jsonb not null);
insert into public.platform_settings values ('pending_hold_minutes', '15') on conflict do nothing;

do $$ declare t text; begin
  foreach t in array array['profiles','venues','floor_plans','venue_tables','events','bookings'] loop
    execute format('create trigger set_updated_at before update on public.%I for each row execute function public.set_updated_at()', t);
  end loop;
end $$;

-- Helpers
create function public.is_admin() returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles where id = (select auth.uid()) and role = 'admin' and account_status = 'active') $$;

create function public.is_venue_member(p_venue_id uuid, p_roles text[] default array['owner','manager','staff'])
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.venue_members
    where venue_id = p_venue_id and user_id = (select auth.uid()) and role = any(p_roles)) $$;

create function public.venue_is_public(p_venue_id uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.venues where id = p_venue_id and status = 'approved') $$;

-- Is [p_start, p_end) inside one opening window? Handles windows that close after midnight. Asia/Bangkok time.
create function public.venue_is_open(p_hours jsonb, p_start timestamptz, p_end timestamptz)
returns boolean language plpgsql immutable set search_path = '' as $$
declare
  v_s timestamp := p_start at time zone 'Asia/Bangkok';
  v_e timestamp := p_end at time zone 'Asia/Bangkok';
  d date; k text; w jsonb; o timestamp; c timestamp;
begin
  if p_hours is null or p_hours = '{}'::jsonb then return true; end if; -- hours unknown: not enforced
  foreach d in array array[v_s::date - 1, v_s::date] loop
    k := (array['sun','mon','tue','wed','thu','fri','sat'])[extract(dow from d)::int + 1];
    for w in select value from jsonb_array_elements(coalesce(p_hours -> k, '[]'::jsonb)) loop
      o := d + (w ->> 'open')::time;
      c := d + (w ->> 'close')::time;
      if c <= o then c := c + interval '1 day'; end if;
      if v_s >= o and v_e <= c then return true; end if;
    end loop;
  end loop;
  return false;
end $$;

create function public.notify_venue_members(p_venue_id uuid, p_type text, p_booking_id uuid) returns void
language sql security definer set search_path = '' as $$
  insert into public.notifications(user_id, title, body, type, related_booking_id)
  select user_id, 'notif.' || p_type || '.title', 'notif.' || p_type || '.body', p_type, p_booking_id
  from public.venue_members where venue_id = p_venue_id $$;

create function public.expire_overdue_bookings() returns int language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  with u as (
    update public.bookings set status = 'expired'
    where status = 'pending' and hold_expires_at <= now() returning id)
  insert into public.booking_status_history(booking_id, old_status, new_status, note)
  select id, 'pending', 'expired', 'hold_expired' from u;
  get diagnostics n = row_count;
  return n;
end $$;

-- Triggers on signup / venue creation. Role is NEVER read from client metadata: every signup is a customer.
create function public.handle_new_user() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(id, full_name, preferred_language)
  values (new.id, new.raw_user_meta_data ->> 'full_name',
          case when new.raw_user_meta_data ->> 'preferred_language' = 'en' then 'en' else 'th' end);
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

create function public.add_venue_creator_as_owner() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.created_by is not null then
    insert into public.venue_members(venue_id, user_id, role) values (new.id, new.created_by, 'owner') on conflict do nothing;
  end if;
  return new;
end $$;
create trigger venue_creator_owner after insert on public.venues for each row execute function public.add_venue_creator_as_owner();

-- Booking RPCs
create function public.create_booking_request(
  p_table_id uuid, p_starts_at timestamptz, p_ends_at timestamptz, p_guest_count int,
  p_customer_name text, p_customer_phone text, p_customer_note text default null)
returns public.bookings language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_table public.venue_tables; v_venue public.venues; v_row public.bookings; v_hold int;
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
  if not exists (select 1 from public.profiles where id = v_uid and account_status = 'active') then
    raise exception 'account_inactive' using errcode = '42501'; end if;
  if p_starts_at is null or p_ends_at is null or p_ends_at <= p_starts_at
     or p_ends_at - p_starts_at > interval '12 hours' or p_starts_at <= now() then
    raise exception 'invalid_interval'; end if;
  if coalesce(trim(p_customer_name), '') = '' or coalesce(trim(p_customer_phone), '') = '' then
    raise exception 'invalid_contact'; end if;

  select * into v_table from public.venue_tables where id = p_table_id and is_active;
  if not found then raise exception 'table_not_found'; end if;
  select * into v_venue from public.venues where id = v_table.venue_id and status = 'approved';
  if not found then raise exception 'venue_not_available'; end if;
  if p_guest_count is null or p_guest_count < 1 or p_guest_count > v_table.capacity then
    raise exception 'guest_count_exceeds_capacity'; end if;
  if not public.venue_is_open(v_venue.opening_hours, p_starts_at, p_ends_at) then
    raise exception 'venue_closed'; end if;

  perform public.expire_overdue_bookings();
  select (value #>> '{}')::int into v_hold from public.platform_settings where key = 'pending_hold_minutes';
  v_hold := coalesce(v_hold, 15);

  begin
    insert into public.bookings(booking_reference, customer_id, venue_id, table_id, booking_date, starts_at, ends_at,
      guest_count, customer_name, customer_phone, customer_note, status, hold_expires_at)
    values ('KKN-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)), v_uid, v_venue.id, v_table.id,
      (p_starts_at at time zone 'Asia/Bangkok')::date, p_starts_at, p_ends_at, p_guest_count,
      trim(p_customer_name), trim(p_customer_phone), p_customer_note, 'pending', now() + make_interval(mins => v_hold))
    returning * into v_row;
  exception when exclusion_violation then
    raise exception 'table_unavailable' using errcode = '23P01';
  end;

  insert into public.booking_status_history(booking_id, old_status, new_status, changed_by)
  values (v_row.id, null, 'pending', v_uid);
  perform public.notify_venue_members(v_venue.id, 'booking_requested', v_row.id);
  return v_row;
end $$;

create function public.update_booking_status(
  p_booking_id uuid, p_new_status text, p_note text default null, p_rejection_reason text default null)
returns public.bookings language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid(); v_b public.bookings; v_old text; v_member boolean; v_admin boolean;
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
  select * into v_b from public.bookings where id = p_booking_id for update;
  if not found then raise exception 'booking_not_found'; end if;
  v_member := public.is_venue_member(v_b.venue_id);
  v_admin := public.is_admin();
  if not (v_member or v_admin) then raise exception 'forbidden' using errcode = '42501'; end if;
  if not ((v_b.status = 'pending' and p_new_status in ('confirmed','rejected'))
       or (v_b.status = 'confirmed' and p_new_status in ('completed','cancelled'))) then
    raise exception 'invalid_status_transition'; end if;
  if v_b.status = 'pending' and v_b.hold_expires_at <= now() then raise exception 'booking_expired'; end if;
  if p_new_status = 'rejected' and coalesce(trim(p_rejection_reason), '') = '' then
    raise exception 'rejection_reason_required'; end if;
  if v_admin and not v_member and coalesce(trim(p_note), '') = '' then raise exception 'admin_reason_required'; end if;

  v_old := v_b.status;
  update public.bookings set status = p_new_status, hold_expires_at = null,
    venue_note = coalesce(p_note, venue_note),
    rejection_reason = case when p_new_status = 'rejected' then trim(p_rejection_reason) else rejection_reason end
  where id = p_booking_id returning * into v_b;

  insert into public.booking_status_history(booking_id, old_status, new_status, changed_by, note)
  values (v_b.id, v_old, p_new_status, v_uid, p_note);
  if v_admin and not v_member then
    insert into public.admin_audit_log(admin_id, action, target_type, target_id, reason, metadata)
    values (v_uid, 'booking_status_change', 'booking', v_b.id, p_note, jsonb_build_object('from', v_old, 'to', p_new_status));
  end if;
  insert into public.notifications(user_id, title, body, type, related_booking_id)
  values (v_b.customer_id, 'notif.booking_' || p_new_status || '.title', 'notif.booking_' || p_new_status || '.body',
          'booking_' || p_new_status, v_b.id);
  return v_b;
end $$;

create function public.cancel_booking(p_booking_id uuid, p_reason text default null)
returns public.bookings language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_b public.bookings; v_old text;
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
  select * into v_b from public.bookings where id = p_booking_id and customer_id = v_uid for update;
  if not found then raise exception 'booking_not_found'; end if;
  if v_b.status not in ('pending','confirmed') then raise exception 'not_cancellable'; end if;
  if v_b.status = 'confirmed' and v_b.starts_at < now() + interval '2 hours' then
    raise exception 'cancellation_window_closed'; end if;
  v_old := v_b.status;
  update public.bookings set status = 'cancelled', hold_expires_at = null where id = p_booking_id returning * into v_b;
  insert into public.booking_status_history(booking_id, old_status, new_status, changed_by, note)
  values (v_b.id, v_old, 'cancelled', v_uid, p_reason);
  perform public.notify_venue_members(v_b.venue_id, 'booking_cancelled', v_b.id);
  return v_b;
end $$;

create function public.get_available_tables(p_venue_id uuid, p_starts_at timestamptz, p_ends_at timestamptz, p_guest_count int)
returns setof public.venue_tables language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
  if p_starts_at is null or p_ends_at is null or p_ends_at <= p_starts_at or p_guest_count is null or p_guest_count < 1 then
    raise exception 'invalid_interval'; end if;
  if not public.venue_is_public(p_venue_id) then raise exception 'venue_not_available'; end if;
  return query
    select t.* from public.venue_tables t
    where t.venue_id = p_venue_id and t.is_active and t.capacity >= p_guest_count
      and not exists (
        select 1 from public.bookings b
        where b.table_id = t.id
          and tstzrange(b.starts_at, b.ends_at, '[)') && tstzrange(p_starts_at, p_ends_at, '[)')
          and (b.status = 'confirmed' or (b.status = 'pending' and b.hold_expires_at > now())))
    order by t.table_number;
end $$;

create function public.admin_set_venue_status(p_venue_id uuid, p_status text, p_reason text default null)
returns public.venues language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_v public.venues; v_old text;
begin
  if not public.is_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  if p_status not in ('approved','rejected','suspended') then raise exception 'invalid_status_transition'; end if;
  if p_status in ('rejected','suspended') and coalesce(trim(p_reason), '') = '' then raise exception 'admin_reason_required'; end if;
  select status into v_old from public.venues where id = p_venue_id for update;
  if not found then raise exception 'venue_not_found'; end if;
  update public.venues set status = p_status where id = p_venue_id returning * into v_v;
  insert into public.admin_audit_log(admin_id, action, target_type, target_id, reason, metadata)
  values (v_uid, 'venue_' || p_status, 'venue', p_venue_id, p_reason, jsonb_build_object('from', v_old, 'to', p_status));
  if v_v.created_by is not null then
    insert into public.notifications(user_id, title, body, type)
    values (v_v.created_by, 'notif.venue_' || p_status || '.title', 'notif.venue_' || p_status || '.body', 'venue_' || p_status);
  end if;
  return v_v;
end $$;

-- Row Level Security
alter table public.profiles enable row level security;
alter table public.venues enable row level security;
alter table public.venue_members enable row level security;
alter table public.floor_plans enable row level security;
alter table public.venue_tables enable row level security;
alter table public.events enable row level security;
alter table public.bookings enable row level security;
alter table public.booking_status_history enable row level security;
alter table public.notifications enable row level security;
alter table public.admin_audit_log enable row level security;
alter table public.platform_settings enable row level security;

create policy profiles_select on public.profiles for select using (id = (select auth.uid()) or public.is_admin());
create policy profiles_update_own on public.profiles for update using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy venues_select on public.venues for select using (status = 'approved' or public.is_venue_member(id) or public.is_admin());
create policy venues_insert on public.venues for insert to authenticated
  with check (created_by = (select auth.uid()) and status in ('draft','pending_review'));
create policy venues_update on public.venues for update to authenticated
  using (public.is_venue_member(id, array['owner','manager'])) with check (public.is_venue_member(id, array['owner','manager']));

create policy members_select on public.venue_members for select to authenticated
  using (user_id = (select auth.uid()) or public.is_venue_member(venue_id, array['owner']) or public.is_admin());
create policy members_insert on public.venue_members for insert to authenticated
  with check (public.is_venue_member(venue_id, array['owner']) or public.is_admin());
create policy members_delete on public.venue_members for delete to authenticated
  using (public.is_venue_member(venue_id, array['owner']) or public.is_admin());

create policy plans_select on public.floor_plans for select
  using ((is_published and public.venue_is_public(venue_id)) or public.is_venue_member(venue_id) or public.is_admin());
create policy plans_write on public.floor_plans for all to authenticated
  using (public.is_venue_member(venue_id, array['owner','manager'])) with check (public.is_venue_member(venue_id, array['owner','manager']));

create policy tables_select_public on public.venue_tables for select
  using (is_active and public.venue_is_public(venue_id)
         and exists (select 1 from public.floor_plans f where f.id = floor_plan_id and f.is_published));
create policy tables_select_members on public.venue_tables for select to authenticated
  using (public.is_venue_member(venue_id) or public.is_admin());
create policy tables_write on public.venue_tables for all to authenticated
  using (public.is_venue_member(venue_id, array['owner','manager'])) with check (public.is_venue_member(venue_id, array['owner','manager']));

create policy events_select on public.events for select
  using ((status = 'published' and public.venue_is_public(venue_id)) or public.is_venue_member(venue_id) or public.is_admin());
create policy events_write on public.events for all to authenticated
  using (public.is_venue_member(venue_id, array['owner','manager'])) with check (public.is_venue_member(venue_id, array['owner','manager']));

-- Bookings: read-only from clients. All writes go through the RPCs above.
create policy bookings_select on public.bookings for select to authenticated
  using (customer_id = (select auth.uid()) or public.is_venue_member(venue_id) or public.is_admin());
create policy history_select on public.booking_status_history for select to authenticated
  using (exists (select 1 from public.bookings b where b.id = booking_id));
create policy notifications_select on public.notifications for select to authenticated using (user_id = (select auth.uid()));
create policy notifications_update on public.notifications for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy audit_select on public.admin_audit_log for select to authenticated using (public.is_admin());
-- platform_settings: no policies = no client access (RPCs read it as definer).

-- Privileges (least privilege; column grants block self-promotion and status edits)
revoke all on all tables in schema public from anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;

grant select on public.venues, public.events, public.floor_plans, public.venue_tables to anon;
grant select on public.profiles, public.venues, public.venue_members, public.floor_plans, public.venue_tables, public.events,
  public.bookings, public.booking_status_history, public.notifications, public.admin_audit_log to authenticated;
grant insert on public.venues to authenticated;
grant update (name_th, name_en, description_th, description_en, category, address, district, latitude, longitude,
  phone, cover_image_url, opening_hours, price_level, facilities) on public.venues to authenticated;
grant update (full_name, phone, avatar_url, preferred_language) on public.profiles to authenticated;
grant update (is_read) on public.notifications to authenticated;
grant insert, update, delete on public.floor_plans, public.venue_tables, public.events to authenticated;
grant insert, delete on public.venue_members to authenticated;

grant execute on function public.is_admin(), public.is_venue_member(uuid, text[]), public.venue_is_public(uuid) to anon, authenticated;
grant execute on function public.create_booking_request(uuid, timestamptz, timestamptz, int, text, text, text) to authenticated;
grant execute on function public.update_booking_status(uuid, text, text, text) to authenticated;
grant execute on function public.cancel_booking(uuid, text) to authenticated;
grant execute on function public.get_available_tables(uuid, timestamptz, timestamptz, int) to authenticated;
grant execute on function public.admin_set_venue_status(uuid, text, text) to authenticated;
grant execute on function public.expire_overdue_bookings() to service_role;

-- Scheduled expiry (every minute) via pg_cron where available
do $$ begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    perform cron.schedule('expire-overdue-bookings', '* * * * *', 'select public.expire_overdue_bookings()');
  end if;
end $$;

-- ═══════════════ 0002 review fixes ═══════════════
alter default privileges for role postgres in schema public revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema public revoke all on functions from anon, authenticated;

alter policy venues_select on public.venues
  using (status = 'approved' or created_by = (select auth.uid()) or public.is_venue_member(id) or public.is_admin());

create policy events_admin_write on public.events for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

alter table public.bookings add constraint pending_has_hold check (status <> 'pending' or hold_expires_at is not null);
alter table public.bookings add constraint rejected_has_reason check (status <> 'rejected' or coalesce(trim(rejection_reason), '') <> '');

create or replace function public.venue_is_open(p_hours jsonb, p_start timestamptz, p_end timestamptz)
returns boolean language plpgsql stable set search_path = '' as $$
declare
  v_s timestamp := p_start at time zone 'Asia/Bangkok';
  v_e timestamp := p_end at time zone 'Asia/Bangkok';
  d date; k text; w jsonb; o timestamp; c timestamp;
begin
  if p_hours is null or p_hours = '{}'::jsonb then return true; end if;
  foreach d in array array[v_s::date - 1, v_s::date] loop
    k := (array['sun','mon','tue','wed','thu','fri','sat'])[extract(dow from d)::int + 1];
    for w in select value from jsonb_array_elements(coalesce(p_hours -> k, '[]'::jsonb)) loop
      o := d + (w ->> 'open')::time;
      c := d + (w ->> 'close')::time;
      if c <= o then c := c + interval '1 day'; end if;
      if v_s >= o and v_e <= c then return true; end if;
    end loop;
  end loop;
  return false;
end $$;

create or replace function public.expire_overdue_bookings() returns int language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  with u as (
    update public.bookings set status = 'expired'
    where status = 'pending' and hold_expires_at <= now() returning id, customer_id),
  h as (
    insert into public.booking_status_history(booking_id, old_status, new_status, note)
    select id, 'pending', 'expired', 'hold_expired' from u returning 1),
  nt as (
    insert into public.notifications(user_id, title, body, type, related_booking_id)
    select customer_id, 'notif.booking_expired.title', 'notif.booking_expired.body', 'booking_expired', id from u returning 1)
  select count(*) into n from u;
  return n;
end $$;

create or replace function public.admin_set_venue_status(p_venue_id uuid, p_status text, p_reason text default null)
returns public.venues language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_v public.venues; v_old text;
begin
  if not public.is_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  if p_status not in ('approved','rejected','suspended') then raise exception 'invalid_status_transition'; end if;
  if p_status in ('rejected','suspended') and coalesce(trim(p_reason), '') = '' then raise exception 'admin_reason_required'; end if;
  select status into v_old from public.venues where id = p_venue_id for update;
  if not found then raise exception 'venue_not_found'; end if;
  update public.venues set status = p_status where id = p_venue_id returning * into v_v;
  if p_status = 'approved' and v_v.created_by is not null then
    update public.profiles set role = 'venue_owner' where id = v_v.created_by and role = 'customer';
  end if;
  insert into public.admin_audit_log(admin_id, action, target_type, target_id, reason, metadata)
  values (v_uid, 'venue_' || p_status, 'venue', p_venue_id, p_reason, jsonb_build_object('from', v_old, 'to', p_status));
  if v_v.created_by is not null then
    insert into public.notifications(user_id, title, body, type)
    values (v_v.created_by, 'notif.venue_' || p_status || '.title', 'notif.venue_' || p_status || '.body', 'venue_' || p_status);
  end if;
  return v_v;
end $$;

create function public.admin_set_account_status(p_user_id uuid, p_status text, p_reason text)
returns public.profiles language plpgsql security definer set search_path = '' as $$
declare v_p public.profiles; v_old text;
begin
  if not public.is_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  if p_status not in ('active','suspended') or p_user_id = auth.uid() then raise exception 'invalid_status_transition'; end if;
  if coalesce(trim(p_reason), '') = '' then raise exception 'admin_reason_required'; end if;
  select account_status into v_old from public.profiles where id = p_user_id for update;
  if not found then raise exception 'user_not_found'; end if;
  update public.profiles set account_status = p_status where id = p_user_id returning * into v_p;
  insert into public.admin_audit_log(admin_id, action, target_type, target_id, reason, metadata)
  values (auth.uid(), 'account_' || p_status, 'user', p_user_id, p_reason, jsonb_build_object('from', v_old, 'to', p_status));
  return v_p;
end $$;
revoke all on function public.admin_set_account_status(uuid, text, text) from public, anon;
grant execute on function public.admin_set_account_status(uuid, text, text) to authenticated;

do $$ begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='bookings') then
      alter publication supabase_realtime add table public.bookings;
    end if;
    if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='notifications') then
      alter publication supabase_realtime add table public.notifications;
    end if;
  end if;
end $$;

-- ═══════════════ 0003 storage ═══════════════
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('venue-images','venue-images', true, 5242880, array['image/jpeg','image/png','image/webp']),
  ('venue-covers','venue-covers', true, 5242880, array['image/jpeg','image/png','image/webp']),
  ('event-images','event-images', true, 5242880, array['image/jpeg','image/png','image/webp']),
  ('floor-plans','floor-plans',   true, 5242880, array['image/jpeg','image/png','image/webp']),
  ('avatars','avatars',           true, 2097152, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create function public.try_uuid(p text) returns uuid language plpgsql immutable set search_path = '' as $$
begin return p::uuid; exception when others then return null; end $$;
revoke all on function public.try_uuid(text) from public;
grant execute on function public.try_uuid(text) to anon, authenticated;

create policy "assets public read" on storage.objects for select
  using (bucket_id in ('venue-images','venue-covers','event-images','floor-plans','avatars'));

create policy "venue assets insert" on storage.objects for insert to authenticated
  with check (bucket_id in ('venue-images','venue-covers','event-images','floor-plans')
    and public.is_venue_member(public.try_uuid((storage.foldername(name))[1]), array['owner','manager']));
create policy "venue assets update" on storage.objects for update to authenticated
  using (bucket_id in ('venue-images','venue-covers','event-images','floor-plans')
    and public.is_venue_member(public.try_uuid((storage.foldername(name))[1]), array['owner','manager']))
  with check (bucket_id in ('venue-images','venue-covers','event-images','floor-plans')
    and public.is_venue_member(public.try_uuid((storage.foldername(name))[1]), array['owner','manager']));
create policy "venue assets delete" on storage.objects for delete to authenticated
  using (bucket_id in ('venue-images','venue-covers','event-images','floor-plans')
    and public.is_venue_member(public.try_uuid((storage.foldername(name))[1]), array['owner','manager']));

create policy "avatars insert own" on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "avatars update own" on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "avatars delete own" on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- ═══════════════ 0004 favorites, reviews, LINE id ═══════════════
alter table public.venues add column if not exists line_id text;

create table public.favorites (
  user_id uuid not null references public.profiles(id) on delete cascade,
  venue_id uuid not null references public.venues(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, venue_id)
);
alter table public.favorites enable row level security;
create policy favorites_own on public.favorites for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
grant select, insert, delete on public.favorites to authenticated;

create table public.venue_reviews (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  body text,
  created_at timestamptz not null default now(),
  unique (venue_id, user_id)
);
alter table public.venue_reviews enable row level security;
create policy reviews_select on public.venue_reviews for select
  using (public.venue_is_public(venue_id) or public.is_venue_member(venue_id) or public.is_admin());
create policy reviews_insert on public.venue_reviews for insert to authenticated
  with check (user_id = (select auth.uid()) and public.venue_is_public(venue_id));
grant select on public.venue_reviews to anon, authenticated;
grant insert on public.venue_reviews to authenticated;

-- ═══════════════ 0005 14-day venue trial ═══════════════
alter table public.venues
  add column plan text not null default 'trial' check (plan in ('trial', 'active', 'expired')),
  add column trial_started_at timestamptz,
  add column trial_ends_at timestamptz;

create function public.apply_venue_trial()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'approved'
     and new.trial_started_at is null
     and new.plan is distinct from 'active'
     and (tg_op = 'INSERT' or old.status is distinct from 'approved') then
    new.plan := 'trial';
    new.trial_started_at := now();
    new.trial_ends_at := now() + interval '14 days';
  end if;
  if new.plan = 'trial' and new.trial_ends_at is not null and new.trial_ends_at <= now() then
    new.plan := 'expired';
  end if;
  return new;
end;
$$;

create trigger venues_apply_trial
  before insert or update on public.venues
  for each row execute function public.apply_venue_trial();

update public.venues
set trial_started_at = coalesce(trial_started_at, now()),
    trial_ends_at = coalesce(trial_ends_at, now() + interval '14 days'),
    plan = 'trial'
where status = 'approved' and plan = 'trial' and trial_started_at is null;

create function public.block_booking_when_trial_expired()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_plan text;
  v_ends timestamptz;
begin
  select plan, trial_ends_at into v_plan, v_ends
  from public.venues where id = new.venue_id;
  if v_plan = 'trial' and v_ends is not null and v_ends <= now() then
    update public.venues set plan = 'expired' where id = new.venue_id and plan = 'trial';
    v_plan := 'expired';
  end if;
  if v_plan = 'expired' then
    raise exception 'trial_expired';
  end if;
  return new;
end;
$$;

create trigger bookings_block_expired_trial
  before insert on public.bookings
  for each row execute function public.block_booking_when_trial_expired();

create function public.admin_extend_venue_trial(p_venue_id uuid, p_days int default 14)
returns public.venues
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.venues;
begin
  if not public.is_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  if p_days is null or p_days < 1 or p_days > 365 then raise exception 'invalid_interval'; end if;
  update public.venues
  set plan = 'trial',
      trial_started_at = coalesce(trial_started_at, now()),
      trial_ends_at = greatest(coalesce(trial_ends_at, now()), now()) + make_interval(days => p_days)
  where id = p_venue_id
  returning * into v;
  if not found then raise exception 'venue_not_found'; end if;
  insert into public.admin_audit_log (admin_id, action, target_type, target_id, metadata)
  values (auth.uid(), 'venue_trial_extended', 'venue', p_venue_id, jsonb_build_object('days', p_days, 'trial_ends_at', v.trial_ends_at));
  return v;
end;
$$;

create function public.admin_end_venue_trial(p_venue_id uuid)
returns public.venues
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.venues;
begin
  if not public.is_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  update public.venues
  set plan = 'expired',
      trial_ends_at = least(coalesce(trial_ends_at, now()), now())
  where id = p_venue_id
  returning * into v;
  if not found then raise exception 'venue_not_found'; end if;
  insert into public.admin_audit_log (admin_id, action, target_type, target_id, metadata)
  values (auth.uid(), 'venue_trial_ended', 'venue', p_venue_id, '{}'::jsonb);
  return v;
end;
$$;

revoke all on function public.admin_extend_venue_trial(uuid, int) from public, anon;
revoke all on function public.admin_end_venue_trial(uuid) from public, anon;
grant execute on function public.admin_extend_venue_trial(uuid, int) to authenticated;
grant execute on function public.admin_end_venue_trial(uuid) to authenticated;

-- ═══════════════ 0006 chat thread ownership + RLS, realtime, 60-minute hold ═══════════════
create table if not exists public.venue_messages (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  customer_id uuid not null references auth.users(id) on delete cascade,
  sender_role text not null check (sender_role in ('customer','venue')),
  body text not null,
  created_at timestamptz not null default now()
);

alter table public.venue_messages add column if not exists customer_id uuid references auth.users(id) on delete cascade;

update public.venue_messages
set customer_id = user_id
where sender_role = 'customer' and customer_id is null;

update public.venue_messages m
set customer_id = (
  select c.customer_id from public.venue_messages c
  where c.venue_id = m.venue_id and c.sender_role = 'customer' and c.customer_id is not null and c.created_at <= m.created_at
  order by c.created_at desc limit 1)
where m.sender_role = 'venue' and m.customer_id is null;

alter table public.venue_messages alter column customer_id set not null;

alter table public.venue_messages drop constraint if exists venue_messages_body_len;
alter table public.venue_messages add constraint venue_messages_body_len check (length(btrim(body)) between 1 and 2000);
alter table public.venue_messages drop constraint if exists venue_messages_thread_owner;
alter table public.venue_messages add constraint venue_messages_thread_owner check (sender_role <> 'customer' or customer_id = user_id);

create or replace function public.venue_messages_set_thread_owner() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.sender_role = 'customer' and new.customer_id is null then new.customer_id := new.user_id; end if;
  return new;
end $$;
drop trigger if exists venue_messages_thread_owner_trg on public.venue_messages;
create trigger venue_messages_thread_owner_trg before insert on public.venue_messages
  for each row execute function public.venue_messages_set_thread_owner();

create index if not exists venue_messages_thread_idx on public.venue_messages (venue_id, customer_id, created_at);
create index if not exists venue_messages_customer_idx on public.venue_messages (customer_id, created_at);

alter table public.venue_messages enable row level security;
drop policy if exists "Insert own messages" on public.venue_messages;
drop policy if exists "Read venue chat thread" on public.venue_messages;
drop policy if exists venue_messages_select on public.venue_messages;
drop policy if exists venue_messages_insert_customer on public.venue_messages;
drop policy if exists venue_messages_insert_staff on public.venue_messages;
drop function if exists public.has_chatted_venue(uuid);

create policy venue_messages_select on public.venue_messages for select to authenticated
  using (customer_id = (select auth.uid()) or public.is_venue_member(venue_id) or public.is_admin());
create policy venue_messages_insert_customer on public.venue_messages for insert to authenticated
  with check (sender_role = 'customer' and user_id = (select auth.uid()) and customer_id = (select auth.uid())
              and public.venue_is_public(venue_id));
create policy venue_messages_insert_staff on public.venue_messages for insert to authenticated
  with check (sender_role = 'venue' and user_id = (select auth.uid()) and public.is_venue_member(venue_id));

revoke all on public.venue_messages from anon, authenticated;
grant select, insert on public.venue_messages to authenticated;

do $$
declare t text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach t in array array['bookings','notifications','venue_messages'] loop
      if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
        execute format('alter publication supabase_realtime add table public.%I', t);
      end if;
    end loop;
  end if;
end $$;

insert into public.platform_settings (key, value) values ('pending_hold_minutes', '60')
on conflict (key) do update set value = excluded.value;
