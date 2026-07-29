alter table public.live_activities
  add column if not exists phase text,
  add column if not exists bedtime_at timestamptz,
  add column if not exists wake_at timestamptz,
  add column if not exists morning_quiet_ends_at timestamptz,
  add column if not exists evening_activity_title text,
  add column if not exists morning_activity_title text;

alter table public.scheduled_events
  drop constraint if exists scheduled_events_event_kind_check;

alter table public.scheduled_events
  add constraint scheduled_events_event_kind_check
  check (event_kind in ('bedtime', 'wake', 'end'));

-- Keep the original ten-argument registration RPC backwards-compatible for older builds.
-- New clients use this overload to attach the phase dates needed for background updates.
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
  p_idempotency_key text,
  p_phase text default null,
  p_bedtime_at timestamptz default null,
  p_wake_at timestamptz default null,
  p_morning_quiet_ends_at timestamptz default null,
  p_evening_activity_title text default null,
  p_morning_activity_title text default null
)
returns table (accepted_generation bigint, scheduled_for timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  next_generation bigint;
begin
  perform public.register_live_activity(
    p_run_id,
    p_installation_id,
    p_activity_id,
    p_push_token,
    p_planned_end_at,
    p_observed_at,
    p_environment,
    p_run_revision,
    p_client_token_generation,
    p_idempotency_key
  );

  select token_generation into next_generation
  from public.live_activities
  where activity_id = p_activity_id;

  update public.live_activities
  set phase = left(p_phase, 32),
      bedtime_at = p_bedtime_at,
      wake_at = p_wake_at,
      morning_quiet_ends_at = p_morning_quiet_ends_at,
      evening_activity_title = left(p_evening_activity_title, 120),
      morning_activity_title = left(p_morning_activity_title, 120),
      updated_at = now()
  where activity_id = p_activity_id and token_generation = next_generation;

  update public.scheduled_events
  set status = 'cancelled', cancelled_at = now(), lease_id = null,
      lease_owner = null, lease_expires_at = null, updated_at = now()
  where activity_id = p_activity_id
    and generation = next_generation
    and event_kind in ('bedtime', 'wake')
    and status in ('pending', 'retry', 'leased');

  if p_bedtime_at is not null and p_bedtime_at > now() then
    insert into public.scheduled_events (
      activity_id, run_id, user_id, event_kind, generation, idempotency_key,
      due_at, next_attempt_at
    )
    select p_activity_id, p_run_id, user_id, 'bedtime', next_generation,
      p_idempotency_key || ':bedtime:' || next_generation,
      p_bedtime_at, p_bedtime_at
    from public.live_activities
    where activity_id = p_activity_id
    on conflict (activity_id, event_kind, generation) do update set
      due_at = excluded.due_at,
      next_attempt_at = excluded.next_attempt_at,
      status = case
        when public.scheduled_events.status in ('delivered', 'cancelled', 'failed')
          then public.scheduled_events.status
        else 'pending'::public.scheduled_event_status
      end,
      cancelled_at = null,
      lease_id = null,
      lease_owner = null,
      lease_expires_at = null,
      updated_at = now();
  end if;

  if p_wake_at is not null and p_wake_at > now() then
    insert into public.scheduled_events (
      activity_id, run_id, user_id, event_kind, generation, idempotency_key,
      due_at, next_attempt_at
    )
    select p_activity_id, p_run_id, user_id, 'wake', next_generation,
      p_idempotency_key || ':wake:' || next_generation,
      p_wake_at, p_wake_at
    from public.live_activities
    where activity_id = p_activity_id
    on conflict (activity_id, event_kind, generation) do update set
      due_at = excluded.due_at,
      next_attempt_at = excluded.next_attempt_at,
      status = case
        when public.scheduled_events.status in ('delivered', 'cancelled', 'failed')
          then public.scheduled_events.status
        else 'pending'::public.scheduled_event_status
      end,
      cancelled_at = null,
      lease_id = null,
      lease_owner = null,
      lease_expires_at = null,
      updated_at = now();
  end if;

  return query select next_generation, p_planned_end_at;
end;
$$;

create or replace function public.live_activity_event_payload(
  p_event_id uuid,
  p_lease_id uuid
)
returns table (
  event_kind text,
  planned_end_at timestamptz,
  bedtime_at timestamptz,
  wake_at timestamptz,
  morning_quiet_ends_at timestamptz,
  evening_activity_title text,
  morning_activity_title text
)
language sql
security definer
set search_path = ''
as $$
  select se.event_kind, la.planned_end_at, la.bedtime_at, la.wake_at,
    la.morning_quiet_ends_at, la.evening_activity_title, la.morning_activity_title
  from public.scheduled_events se
  join public.live_activities la on la.activity_id = se.activity_id
    and la.token_generation = se.generation
    and la.invalidated_at is null
  where se.id = p_event_id
    and se.lease_id = p_lease_id
    and se.status = 'leased'
$$;

revoke all on function public.register_live_activity(
  uuid, uuid, text, text, timestamptz, timestamptz, public.apns_environment,
  bigint, bigint, text, text, timestamptz, timestamptz, timestamptz, text, text
) from public, anon;
grant execute on function public.register_live_activity(
  uuid, uuid, text, text, timestamptz, timestamptz, public.apns_environment,
  bigint, bigint, text, text, timestamptz, timestamptz, timestamptz, text, text
) to authenticated;
revoke all on function public.live_activity_event_payload(uuid, uuid) from public, anon, authenticated;
grant execute on function public.live_activity_event_payload(uuid, uuid) to service_role;
