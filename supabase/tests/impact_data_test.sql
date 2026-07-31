begin;

insert into auth.users (id, instance_id, aud, role, created_at, updated_at)
values
  (
    '10000000-0000-0000-0000-000000000011',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    now(),
    now()
  ),
  (
    '10000000-0000-0000-0000-000000000012',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    now(),
    now()
  );

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000011',
  true
);
select set_config('request.jwt.claim.role', 'authenticated', true);

insert into public.impact_nights (
  id, schema_version, relative_night, planned_quiet_minutes, quiet_minutes,
  completed_ritual, start_method, shield_evidence, sleep_minutes,
  core_sleep_minutes, deep_sleep_minutes, rem_sleep_minutes, restfulness, app_version
) values (
  '40000000-0000-0000-0000-000000000011',
  1,
  -1,
  60,
  45,
  true,
  'nfcTag',
  'observed',
  430,
  240,
  70,
  90,
  'rested',
  '1.0'
);

do $$
begin
  if not exists (
    select 1 from public.impact_nights
    where id = '40000000-0000-0000-0000-000000000011'
      and user_id = '10000000-0000-0000-0000-000000000011'
      and relative_night = -1
  ) then
    raise exception 'impact row did not inherit the authenticated owner';
  end if;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000012',
  true
);

do $$
declare
  deleted_count integer;
begin
  if exists (
    select 1 from public.impact_nights
    where id = '40000000-0000-0000-0000-000000000011'
  ) then
    raise exception 'RLS exposed another user''s impact row';
  end if;

  select public.delete_my_impact_data() into deleted_count;
  if deleted_count <> 0 then
    raise exception 'deletion removed another user''s impact row';
  end if;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000011',
  true
);

do $$
declare
  deleted_count integer;
begin
  select public.delete_my_impact_data() into deleted_count;
  if deleted_count <> 1 then
    raise exception 'owner deletion did not remove exactly one row';
  end if;

  if exists (
    select 1 from public.impact_nights
    where id = '40000000-0000-0000-0000-000000000011'
  ) then
    raise exception 'impact row remained after owner deletion';
  end if;
end;
$$;

rollback;
