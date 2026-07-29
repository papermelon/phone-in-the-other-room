create extension if not exists pgcrypto with schema extensions;

create type public.apns_environment as enum ('sandbox', 'production');
create type public.focus_run_cloud_status as enum ('active', 'completed', 'ended_early', 'cancelled');
create type public.scheduled_event_status as enum ('pending', 'leased', 'retry', 'delivered', 'cancelled', 'failed');
create type public.live_activity_cancel_reason as enum ('completed', 'endedEarly', 'reset', 'replaced');

create table public.devices (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null default 'ios' check (platform in ('ios', 'android', 'web')),
  app_version text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  unique (id, user_id)
);

create table public.focus_runs (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id uuid not null,
  planned_end_at timestamptz not null,
  status public.focus_run_cloud_status not null default 'active',
  revision bigint not null default 1 check (revision > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (device_id, user_id) references public.devices(id, user_id) on delete cascade
);

create table public.live_activities (
  activity_id text primary key,
  run_id uuid not null references public.focus_runs(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  push_token text not null,
  token_digest text not null,
  token_generation bigint not null default 1 check (token_generation > 0),
  client_token_generation bigint check (client_token_generation is null or client_token_generation > 0),
  registration_idempotency_key text not null unique,
  cancellation_idempotency_key text unique,
  environment public.apns_environment not null,
  planned_end_at timestamptz not null,
  observed_at timestamptz not null,
  invalidated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.scheduled_events (
  id uuid primary key default gen_random_uuid(),
  activity_id text not null references public.live_activities(activity_id) on delete cascade,
  run_id uuid not null references public.focus_runs(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  event_kind text not null check (event_kind = 'end'),
  generation bigint not null check (generation > 0),
  idempotency_key text not null unique,
  due_at timestamptz not null,
  status public.scheduled_event_status not null default 'pending',
  attempt_count integer not null default 0 check (attempt_count >= 0),
  next_attempt_at timestamptz not null,
  lease_id uuid,
  lease_owner text,
  lease_expires_at timestamptz,
  last_apns_status integer,
  last_apns_reason text,
  delivered_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (activity_id, event_kind, generation)
);

create table public.delivery_attempts (
  id bigint generated always as identity primary key,
  event_id uuid not null references public.scheduled_events(id) on delete cascade,
  attempted_at timestamptz not null default now(),
  apns_status integer,
  apns_reason text,
  outcome text not null check (outcome in ('delivered', 'retry', 'terminal'))
);

create index devices_user_idx on public.devices (user_id, last_seen_at desc);
create index focus_runs_user_updated_idx on public.focus_runs (user_id, updated_at desc);
create index focus_runs_device_idx on public.focus_runs (device_id, updated_at desc);
create index live_activities_run_idx on public.live_activities (run_id);
create index live_activities_owner_idx on public.live_activities (user_id, updated_at desc);
create index scheduled_events_due_idx
  on public.scheduled_events (next_attempt_at, due_at)
  where status in ('pending', 'retry', 'leased');
create index delivery_attempts_event_idx on public.delivery_attempts (event_id, attempted_at desc);
create unique index scheduled_events_one_open_event_idx
  on public.scheduled_events (activity_id, event_kind)
  where status in ('pending', 'leased', 'retry');
create index scheduled_events_owner_status_idx on public.scheduled_events (user_id, status, updated_at desc);

alter table public.devices enable row level security;
alter table public.focus_runs enable row level security;
alter table public.live_activities enable row level security;
alter table public.scheduled_events enable row level security;
alter table public.delivery_attempts enable row level security;

create policy "users read their focus runs"
  on public.focus_runs for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "users read their devices"
  on public.devices for select to authenticated
  using ((select auth.uid()) = user_id);

-- Activity tokens, schedules, and delivery attempts deliberately have no client-facing
-- policies. Authenticated clients mutate them only through the constrained RPCs below.

revoke all on public.devices, public.focus_runs, public.live_activities, public.scheduled_events,
  public.delivery_attempts from anon, authenticated;
grant select on public.devices, public.focus_runs to authenticated;

create or replace function public.register_live_activity(
  p_run_id uuid,
  p_installation_id uuid,
  p_activity_id text,
  p_push_token text,
  p_planned_end_at timestamptz,
  p_observed_at timestamptz,
  p_environment public.apns_environment,
  p_run_revision bigint,
  p_client_token_generation bigint,
  p_idempotency_key text
)
returns table (accepted_generation bigint, scheduled_for timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
  existing public.live_activities%rowtype;
  next_generation bigint;
  digest text;
begin
  if caller is null then raise exception 'authentication required' using errcode = '28000'; end if;
  if p_run_revision < 1 or p_client_token_generation < 1 then raise exception 'invalid generation'; end if;
  if length(p_idempotency_key) < 8 or length(p_idempotency_key) > 512 then raise exception 'invalid idempotency key'; end if;
  if length(p_activity_id) < 1 or length(p_activity_id) > 256 then raise exception 'invalid activity id'; end if;
  if p_push_token !~ '^[0-9a-f]+$' or length(p_push_token) < 32 or length(p_push_token) > 512 then
    raise exception 'invalid push token';
  end if;
  if p_planned_end_at < now() - interval '5 minutes' or p_planned_end_at > now() + interval '36 hours' then
    raise exception 'planned end outside accepted window';
  end if;

  digest := encode(extensions.digest(p_push_token, 'sha256'), 'hex');

  insert into public.devices (id, user_id)
  values (p_installation_id, caller)
  on conflict (id) do update set last_seen_at = now(), updated_at = now()
    where public.devices.user_id = caller;
  if not exists (select 1 from public.devices where id = p_installation_id and user_id = caller) then
    raise exception 'device belongs to another user' using errcode = '42501';
  end if;

  insert into public.focus_runs (id, user_id, device_id, planned_end_at, revision)
  values (p_run_id, caller, p_installation_id, p_planned_end_at, p_run_revision)
  on conflict (id) do update
    set planned_end_at = excluded.planned_end_at,
        revision = greatest(public.focus_runs.revision, excluded.revision),
        updated_at = now()
    where public.focus_runs.user_id = caller;

  if not exists (select 1 from public.focus_runs where id = p_run_id and user_id = caller) then
    raise exception 'run belongs to another user' using errcode = '42501';
  end if;

  select * into existing from public.live_activities where activity_id = p_activity_id for update;
  if found and existing.user_id <> caller then
    raise exception 'activity belongs to another user' using errcode = '42501';
  end if;

  next_generation := case
    when not found then 1
    when existing.token_digest = digest
      and existing.planned_end_at = p_planned_end_at
      and existing.environment = p_environment
      and existing.invalidated_at is null then existing.token_generation
    else existing.token_generation + 1
  end;

  insert into public.live_activities (
    activity_id, run_id, user_id, push_token, token_digest, token_generation,
    client_token_generation, registration_idempotency_key,
    environment, planned_end_at, observed_at, invalidated_at
  ) values (
    p_activity_id, p_run_id, caller, p_push_token, digest, next_generation,
    p_client_token_generation, p_idempotency_key,
    p_environment, p_planned_end_at, p_observed_at, null
  )
  on conflict (activity_id) do update set
    run_id = excluded.run_id,
    push_token = excluded.push_token,
    token_digest = excluded.token_digest,
    token_generation = excluded.token_generation,
    client_token_generation = greatest(public.live_activities.client_token_generation, excluded.client_token_generation),
    registration_idempotency_key = excluded.registration_idempotency_key,
    environment = excluded.environment,
    planned_end_at = excluded.planned_end_at,
    observed_at = greatest(public.live_activities.observed_at, excluded.observed_at),
    invalidated_at = null,
    updated_at = now();

  update public.scheduled_events se set
    status = 'cancelled', cancelled_at = now(), lease_id = null, lease_owner = null,
    lease_expires_at = null, updated_at = now()
  where se.activity_id = p_activity_id
    and se.generation <> next_generation
    and se.status in ('pending', 'retry', 'leased');

  insert into public.scheduled_events (
    activity_id, run_id, user_id, event_kind, generation, idempotency_key, due_at, next_attempt_at
  ) values (
    p_activity_id, p_run_id, caller, 'end', next_generation,
    p_idempotency_key || ':end:' || next_generation, p_planned_end_at, p_planned_end_at
  )
  on conflict (activity_id, event_kind, generation) do update set
    due_at = excluded.due_at,
    next_attempt_at = excluded.next_attempt_at,
    status = case
      when public.scheduled_events.status in ('delivered', 'cancelled', 'failed')
        then public.scheduled_events.status
      else 'pending'::public.scheduled_event_status
    end,
    lease_id = null,
    lease_owner = null,
    lease_expires_at = null,
    updated_at = now();

  return query select next_generation, p_planned_end_at;
end;
$$;

create or replace function public.cancel_live_activity(
  p_run_id uuid,
  p_activity_id text,
  p_reason public.live_activity_cancel_reason,
  p_occurred_at timestamptz,
  p_run_revision bigint,
  p_idempotency_key text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare caller uuid := auth.uid();
begin
  if caller is null then raise exception 'authentication required' using errcode = '28000'; end if;
  if p_run_revision < 1 or length(p_idempotency_key) < 8 or length(p_idempotency_key) > 512 then
    raise exception 'invalid cancellation metadata';
  end if;
  if exists (select 1 from public.focus_runs where id = p_run_id and user_id <> caller) then
    raise exception 'run belongs to another user' using errcode = '42501';
  end if;
  if not exists (select 1 from public.focus_runs where id = p_run_id) then return true; end if;

  update public.live_activities set invalidated_at = coalesce(invalidated_at, p_occurred_at),
    cancellation_idempotency_key = coalesce(cancellation_idempotency_key, p_idempotency_key), updated_at = now()
  where activity_id = p_activity_id and run_id = p_run_id and user_id = caller;

  update public.scheduled_events set
    status = 'cancelled', cancelled_at = coalesce(cancelled_at, p_occurred_at),
    lease_id = null, lease_owner = null, lease_expires_at = null, updated_at = now()
  where activity_id = p_activity_id and run_id = p_run_id and user_id = caller
    and status in ('pending', 'retry', 'leased');

  update public.focus_runs set
    status = case p_reason when 'completed' then 'completed'::public.focus_run_cloud_status
      when 'endedEarly' then 'ended_early'::public.focus_run_cloud_status
      else 'cancelled'::public.focus_run_cloud_status end,
    revision = greatest(revision, p_run_revision), updated_at = now()
  where id = p_run_id and user_id = caller;
  return true;
end;
$$;

create or replace function public.claim_due_live_activity_events(
  p_worker_id text,
  p_limit integer default 50
)
returns table (
  event_id uuid, lease_id uuid, activity_id text, run_id uuid, generation bigint,
  push_token text, environment public.apns_environment, planned_end_at timestamptz,
  attempt_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() <> 'service_role' then raise exception 'service role required' using errcode = '42501'; end if;
  return query
  with candidates as (
    select se.id
    from public.scheduled_events se
    where se.due_at <= now()
      and se.next_attempt_at <= now()
      and (se.status in ('pending', 'retry') or (se.status = 'leased' and se.lease_expires_at < now()))
      and exists (
        select 1 from public.live_activities la
        where la.activity_id = se.activity_id
          and la.token_generation = se.generation
          and la.invalidated_at is null
      )
    order by se.next_attempt_at, se.created_at
    for update skip locked
    limit greatest(1, least(p_limit, 200))
  ), claimed as (
    update public.scheduled_events se set
      status = 'leased', lease_id = gen_random_uuid(), lease_owner = left(p_worker_id, 128),
      lease_expires_at = now() + interval '2 minutes',
      attempt_count = se.attempt_count + 1, updated_at = now()
    from candidates c
    where se.id = c.id
    returning se.*
  )
  select c.id, c.lease_id, c.activity_id, c.run_id, c.generation,
    la.push_token, la.environment, la.planned_end_at, c.attempt_count
  from claimed c
  join public.live_activities la on la.activity_id = c.activity_id
    and la.token_generation = c.generation and la.invalidated_at is null;
end;
$$;

create or replace function public.validate_live_activity_lease(p_event_id uuid, p_lease_id uuid)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select auth.role() = 'service_role' and exists (
    select 1
    from public.scheduled_events se
    join public.live_activities la on la.activity_id = se.activity_id
    where se.id = p_event_id
      and se.lease_id = p_lease_id
      and se.status = 'leased'
      and se.lease_expires_at > now()
      and la.token_generation = se.generation
      and la.invalidated_at is null
  );
$$;

create or replace function public.record_live_activity_delivery(
  p_event_id uuid, p_lease_id uuid, p_outcome text, p_apns_status integer,
  p_apns_reason text, p_retry_at timestamptz default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare changed integer;
begin
  if auth.role() <> 'service_role' then raise exception 'service role required' using errcode = '42501'; end if;
  if p_outcome not in ('delivered', 'retry', 'terminal') then raise exception 'invalid outcome'; end if;

  update public.scheduled_events set
    status = case p_outcome when 'delivered' then 'delivered'::public.scheduled_event_status
      when 'retry' then 'retry'::public.scheduled_event_status
      else 'failed'::public.scheduled_event_status end,
    next_attempt_at = case when p_outcome = 'retry' then coalesce(p_retry_at, now() + interval '1 minute') else next_attempt_at end,
    delivered_at = case when p_outcome = 'delivered' then now() else delivered_at end,
    last_apns_status = p_apns_status, last_apns_reason = left(p_apns_reason, 200),
    lease_id = null, lease_owner = null, lease_expires_at = null, updated_at = now()
  where id = p_event_id and lease_id = p_lease_id and status = 'leased';
  get diagnostics changed = row_count;
  if changed = 1 then
    insert into public.delivery_attempts (event_id, apns_status, apns_reason, outcome)
    values (p_event_id, p_apns_status, left(p_apns_reason, 200), p_outcome);
  end if;
  return changed = 1;
end;
$$;

revoke all on function public.register_live_activity(uuid, uuid, text, text, timestamptz, timestamptz, public.apns_environment, bigint, bigint, text) from public, anon;
grant execute on function public.register_live_activity(uuid, uuid, text, text, timestamptz, timestamptz, public.apns_environment, bigint, bigint, text) to authenticated;
revoke all on function public.cancel_live_activity(uuid, text, public.live_activity_cancel_reason, timestamptz, bigint, text) from public, anon;
grant execute on function public.cancel_live_activity(uuid, text, public.live_activity_cancel_reason, timestamptz, bigint, text) to authenticated;
revoke all on function public.claim_due_live_activity_events(text, integer) from public, anon, authenticated;
grant execute on function public.claim_due_live_activity_events(text, integer) to service_role;
revoke all on function public.validate_live_activity_lease(uuid, uuid) from public, anon, authenticated;
grant execute on function public.validate_live_activity_lease(uuid, uuid) to service_role;
revoke all on function public.record_live_activity_delivery(uuid, uuid, text, integer, text, timestamptz) from public, anon, authenticated;
grant execute on function public.record_live_activity_delivery(uuid, uuid, text, integer, text, timestamptz) to service_role;
