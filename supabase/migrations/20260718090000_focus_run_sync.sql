create or replace function public.sync_focus_run(
  p_run_id uuid,
  p_installation_id uuid,
  p_planned_end_at timestamptz,
  p_observed_at timestamptz,
  p_status public.focus_run_cloud_status,
  p_run_revision bigint,
  p_app_version text,
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
  if p_run_revision < 1 then raise exception 'invalid revision'; end if;
  if length(p_idempotency_key) < 8 or length(p_idempotency_key) > 512 then
    raise exception 'invalid idempotency key';
  end if;
  if p_planned_end_at < now() - interval '36 hours'
     or p_planned_end_at > now() + interval '36 hours' then
    raise exception 'planned end outside accepted window';
  end if;

  insert into public.devices (id, user_id, app_version, last_seen_at)
  values (p_installation_id, caller, left(p_app_version, 64), p_observed_at)
  on conflict (id) do update set
    app_version = coalesce(excluded.app_version, public.devices.app_version),
    last_seen_at = greatest(public.devices.last_seen_at, excluded.last_seen_at),
    updated_at = now()
  where public.devices.user_id = caller;

  if not exists (select 1 from public.devices where id = p_installation_id and user_id = caller) then
    raise exception 'device belongs to another user' using errcode = '42501';
  end if;

  insert into public.focus_runs (id, user_id, device_id, planned_end_at, status, revision)
  values (p_run_id, caller, p_installation_id, p_planned_end_at, p_status, p_run_revision)
  on conflict (id) do update set
    planned_end_at = excluded.planned_end_at,
    status = excluded.status,
    revision = excluded.revision,
    updated_at = now()
  where public.focus_runs.user_id = caller
    and public.focus_runs.revision <= excluded.revision;

  if not exists (select 1 from public.focus_runs where id = p_run_id and user_id = caller) then
    raise exception 'run belongs to another user' using errcode = '42501';
  end if;
  return true;
end;
$$;

-- Update projects that already applied the initial migration. Fresh databases receive the
-- same limit from that migration directly.
do $$
declare
  function_oid regprocedure := 'public.register_live_activity(uuid,uuid,text,text,timestamptz,timestamptz,public.apns_environment,bigint,bigint,text)'::regprocedure;
  old_definition text;
  new_definition text;
begin
  select pg_get_functiondef(function_oid) into old_definition;
  if old_definition like '%interval ''36 hours''%' or old_definition like '%''36:00:00''::interval%' then
    return;
  end if;
  new_definition := replace(old_definition, '''08:00:00''::interval', '''36:00:00''::interval');
  new_definition := replace(new_definition, 'interval ''8 hours''', 'interval ''36 hours''');
  if new_definition = old_definition then
    raise exception 'register_live_activity planned-end limit was not found';
  end if;
  execute new_definition;
end;
$$;

revoke all on function public.sync_focus_run(uuid, uuid, timestamptz, timestamptz,
  public.focus_run_cloud_status, bigint, text, text) from public, anon;
grant execute on function public.sync_focus_run(uuid, uuid, timestamptz, timestamptz,
  public.focus_run_cloud_status, bigint, text, text) to authenticated;
