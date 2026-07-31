-- The phase-aware overload added six defaulted parameters to register_live_activity.
-- PostgreSQL then cannot resolve the ten-argument call inside that function because both
-- the original and extended signatures match. Keep the original name for older clients
-- and give the phase-aware RPC an explicit versioned name.
alter function public.register_live_activity(
  uuid,
  uuid,
  text,
  text,
  timestamptz,
  timestamptz,
  public.apns_environment,
  bigint,
  bigint,
  text,
  text,
  timestamptz,
  timestamptz,
  timestamptz,
  text,
  text
) rename to register_live_activity_v2;

revoke all on function public.register_live_activity_v2(
  uuid,
  uuid,
  text,
  text,
  timestamptz,
  timestamptz,
  public.apns_environment,
  bigint,
  bigint,
  text,
  text,
  timestamptz,
  timestamptz,
  timestamptz,
  text,
  text
) from public, anon;

grant execute on function public.register_live_activity_v2(
  uuid,
  uuid,
  text,
  text,
  timestamptz,
  timestamptz,
  public.apns_environment,
  bigint,
  bigint,
  text,
  text,
  timestamptz,
  timestamptz,
  timestamptz,
  text,
  text
) to authenticated;

-- Preserve the currently deployed Edge Function during rollout. Unlike the old extended
-- overload, this wrapper has no default arguments, so ten-argument calls resolve only to
-- the original v1 function and sixteen-argument calls resolve only to this wrapper.
create function public.register_live_activity(
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
  p_phase text,
  p_bedtime_at timestamptz,
  p_wake_at timestamptz,
  p_morning_quiet_ends_at timestamptz,
  p_evening_activity_title text,
  p_morning_activity_title text
)
returns table (accepted_generation bigint, scheduled_for timestamptz)
language sql
security invoker
set search_path = ''
as $$
  select *
  from public.register_live_activity_v2(
    p_run_id,
    p_installation_id,
    p_activity_id,
    p_push_token,
    p_planned_end_at,
    p_observed_at,
    p_environment,
    p_run_revision,
    p_client_token_generation,
    p_idempotency_key,
    p_phase,
    p_bedtime_at,
    p_wake_at,
    p_morning_quiet_ends_at,
    p_evening_activity_title,
    p_morning_activity_title
  )
$$;

revoke all on function public.register_live_activity(
  uuid,
  uuid,
  text,
  text,
  timestamptz,
  timestamptz,
  public.apns_environment,
  bigint,
  bigint,
  text,
  text,
  timestamptz,
  timestamptz,
  timestamptz,
  text,
  text
) from public, anon;

grant execute on function public.register_live_activity(
  uuid,
  uuid,
  text,
  text,
  timestamptz,
  timestamptz,
  public.apns_environment,
  bigint,
  bigint,
  text,
  text,
  timestamptz,
  timestamptz,
  timestamptz,
  text,
  text
) to authenticated;
