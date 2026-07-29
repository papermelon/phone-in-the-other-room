begin;

do $$
declare
  user_a uuid := '10000000-0000-0000-0000-000000000001';
  user_b uuid := '10000000-0000-0000-0000-000000000002';
  device_a uuid := '20000000-0000-0000-0000-000000000001';
  run_a uuid := '30000000-0000-0000-0000-000000000001';
  first_generation bigint;
  repeated_generation bigint;
  rotated_generation bigint;
  open_jobs integer;
  claimed_jobs integer;
begin
  insert into auth.users (id, instance_id, aud, role, created_at, updated_at)
  values
    (user_a, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', now(), now()),
    (user_b, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', now(), now());

  perform set_config('request.jwt.claim.sub', user_a::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  select accepted_generation into first_generation from public.register_live_activity(
    run_a, device_a, 'activity-a', repeat('a', 64), now() + interval '5 minutes', now(),
    'sandbox', 1, 1, 'registration-activity-a-generation-1'
  );
  if first_generation <> 1 then raise exception 'first registration must use generation 1'; end if;

  select accepted_generation into repeated_generation from public.register_live_activity(
    run_a, device_a, 'activity-a', repeat('a', 64), now() + interval '5 minutes', now(),
    'sandbox', 1, 1, 'registration-activity-a-generation-1'
  );
  if repeated_generation <> first_generation then raise exception 'repeated registration is not idempotent'; end if;

  select count(*) into open_jobs from public.scheduled_events
  where activity_id = 'activity-a' and status in ('pending', 'retry', 'leased');
  if open_jobs <> 1 then raise exception 'expected exactly one open schedule'; end if;

  select accepted_generation into rotated_generation from public.register_live_activity(
    run_a, device_a, 'activity-a', repeat('b', 64), now() + interval '5 minutes', now(),
    'sandbox', 1, 2, 'registration-activity-a-generation-2'
  );
  if rotated_generation <> 2 then raise exception 'token rotation did not increment generation'; end if;

  perform set_config('request.jwt.claim.sub', user_b::text, true);
  begin
    perform public.register_live_activity(
      run_a, '20000000-0000-0000-0000-000000000002', 'activity-a', repeat('c', 64),
      now() + interval '5 minutes', now(), 'sandbox', 1, 1,
      'registration-forbidden-owner-change'
    );
    raise exception 'ownership isolation failed';
  exception when insufficient_privilege then
    null;
  end;

  perform set_config('request.jwt.claim.sub', user_a::text, true);
  update public.scheduled_events set due_at = now() - interval '1 second', next_attempt_at = now() - interval '1 second'
  where activity_id = 'activity-a' and status = 'pending';
  perform set_config('request.jwt.claim.role', 'service_role', true);
  select count(*) into claimed_jobs
  from public.claim_due_live_activity_events('sql-verification-worker', 10);
  if claimed_jobs <> 1 then raise exception 'worker did not claim exactly one due job'; end if;
  if not exists (
    select 1 from public.scheduled_events
    where activity_id = 'activity-a' and status = 'leased'
      and lease_owner = 'sql-verification-worker' and lease_expires_at > now()
  ) then raise exception 'worker lease metadata is incomplete'; end if;
end;
$$;

rollback;
