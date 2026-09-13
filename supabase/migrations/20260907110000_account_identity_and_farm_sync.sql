-- Account-owned Farm sync is deliberately additive.  Old clients retain the
-- Apple-only farm_save_v1 contract until an upgraded client records acceptance.
create table private.account_usernames (
  user_id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique,
  claimed_at timestamptz not null default now(),
  constraint account_usernames_normalized check (username ~ '^[a-z][a-z0-9_]{2,23}$')
);

create table private.account_sync_acceptances (
  user_id uuid primary key references auth.users(id) on delete cascade,
  accepted_at timestamptz not null default now(),
  contract_version integer not null default 1 check (contract_version = 1)
);

create table private.account_password_login_limits (
  scope text not null check (scope in ('ip', 'identifier')),
  key_digest text not null check (key_digest ~ '^[0-9a-f]{64}$'),
  window_started timestamptz not null,
  attempt_count integer not null check (attempt_count > 0),
  primary key (scope, key_digest)
);

alter table private.account_usernames enable row level security;
alter table private.account_sync_acceptances enable row level security;
alter table private.account_password_login_limits enable row level security;
revoke all on private.account_usernames, private.account_sync_acceptances,
  private.account_password_login_limits from public, anon, authenticated;

create function private.account_verified_farm_owner_v1(p_user uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from auth.users u
    where u.id = p_user
      and not coalesce(u.is_anonymous, true)
      and (u.email_confirmed_at is not null or exists (
        select 1 from auth.identities i where i.user_id = u.id and i.provider = 'apple'
      ))
  )
$$;
revoke all on function private.account_verified_farm_owner_v1(uuid) from public, anon, authenticated;

-- Keep the established Night Flock predicate name so every versioned social
-- command receives the same provider-neutral identity policy without changing
-- its public RPC contract.  The original Apple-only behavior is superseded by
-- ADR-0023 for verified password accounts.
create or replace function private.is_apple_linked_night_flock_user(p_user_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.account_verified_farm_owner_v1(p_user_id)
$$;
revoke all on function private.is_apple_linked_night_flock_user(uuid) from public, anon, authenticated;

create function private.account_username_normalize_v1(p_username text)
returns text language plpgsql immutable set search_path = '' as $$
declare normalized text := lower(btrim(p_username));
begin
  if normalized !~ '^[a-z][a-z0-9_]{2,23}$' then
    raise exception 'account_username_invalid';
  end if;
  if normalized = any (array['admin','administrator','api','apple','auth','countingsheep',
    'help','ollie','root','support','system','team']) then
    raise exception 'account_username_reserved';
  end if;
  return normalized;
end $$;
revoke all on function private.account_username_normalize_v1(text) from public, anon, authenticated;

create function public.account_username_v1(p_action text, p_username text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); normalized text; existing text;
begin
  if u is null or not private.account_verified_farm_owner_v1(u) then
    raise exception 'account_verified_identity_required' using errcode = '42501';
  end if;
  if p_action = 'get' then
    if p_username is not null then raise exception 'account_username_invalid_request'; end if;
    select username into existing from private.account_usernames where user_id = u;
    return jsonb_build_object('capability','account_username_v1','username',existing);
  end if;
  if p_action <> 'claim' or p_username is null then
    raise exception 'account_username_invalid_request';
  end if;
  normalized := private.account_username_normalize_v1(p_username);
  select username into existing from private.account_usernames where user_id = u for update;
  if existing is not null then
    if existing = normalized then
      return jsonb_build_object('capability','account_username_v1','status','claimed','username',existing);
    end if;
    raise exception 'account_username_already_claimed';
  end if;
  begin
    insert into private.account_usernames(user_id, username) values (u, normalized);
  exception when unique_violation then
    raise exception 'account_username_unavailable' using errcode = '23505';
  end;
  return jsonb_build_object('capability','account_username_v1','status','claimed','username',normalized);
end $$;
revoke all on function public.account_username_v1(text,text) from public, anon;
grant execute on function public.account_username_v1(text,text) to authenticated;

-- This RPC is executable only by the Edge Function's service-role client.  It
-- keeps the email lookup inside the server boundary and is never a public API.
create function public.account_username_login_email_v1(p_username text)
returns text language plpgsql stable security definer set search_path = '' as $$
declare normalized text;
begin
  if auth.role() <> 'service_role' then raise exception 'service_role_required' using errcode = '42501'; end if;
  normalized := private.account_username_normalize_v1(p_username);
  return (
    select u.email from private.account_usernames n join auth.users u on u.id = n.user_id
    where n.username = normalized and u.email_confirmed_at is not null and not coalesce(u.is_anonymous, true)
  );
end $$;
revoke all on function public.account_username_login_email_v1(text) from public, anon, authenticated;
grant execute on function public.account_username_login_email_v1(text) to service_role;

create function public.account_password_login_rate_limit_v1(
  p_ip_digest text, p_identifier_digest text, p_ip_limit integer,
  p_identifier_limit integer, p_window_seconds integer
)
returns boolean language plpgsql security definer set search_path = '' as $$
declare now_at timestamptz := clock_timestamp(); ip_count integer; identifier_count integer;
begin
  if auth.role() <> 'service_role' then raise exception 'service_role_required' using errcode = '42501'; end if;
  if p_ip_digest !~ '^[0-9a-f]{64}$' or p_identifier_digest !~ '^[0-9a-f]{64}$'
    or p_ip_limit not between 1 and 1000 or p_identifier_limit not between 1 and 1000
    or p_window_seconds not between 60 and 3600 then raise exception 'account_rate_limit_invalid'; end if;
  insert into private.account_password_login_limits(scope,key_digest,window_started,attempt_count)
    values ('ip',p_ip_digest,now_at,1)
  on conflict (scope,key_digest) do update set
    window_started = case when private.account_password_login_limits.window_started <= now_at - make_interval(secs => p_window_seconds)
      then excluded.window_started else private.account_password_login_limits.window_started end,
    attempt_count = case when private.account_password_login_limits.window_started <= now_at - make_interval(secs => p_window_seconds)
      then 1 else private.account_password_login_limits.attempt_count + 1 end
  returning attempt_count into ip_count;
  insert into private.account_password_login_limits(scope,key_digest,window_started,attempt_count)
    values ('identifier',p_identifier_digest,now_at,1)
  on conflict (scope,key_digest) do update set
    window_started = case when private.account_password_login_limits.window_started <= now_at - make_interval(secs => p_window_seconds)
      then excluded.window_started else private.account_password_login_limits.window_started end,
    attempt_count = case when private.account_password_login_limits.window_started <= now_at - make_interval(secs => p_window_seconds)
      then 1 else private.account_password_login_limits.attempt_count + 1 end
  returning attempt_count into identifier_count;
  return ip_count <= p_ip_limit and identifier_count <= p_identifier_limit;
end $$;
revoke all on function public.account_password_login_rate_limit_v1(text,text,integer,integer,integer) from public, anon, authenticated;
grant execute on function public.account_password_login_rate_limit_v1(text,text,integer,integer,integer) to service_role;

create function private.farm_account_sync_apply_v1(p_user uuid, c jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare h private.farm_save_heads%rowtype; op private.farm_save_operations%rowtype;
  action text := c->>'action'; operation uuid; request_hash text; payload jsonb := c->'payload';
  r uuid; result jsonb; conflicted boolean;
begin
  if jsonb_typeof(c) <> 'object' or action is null or action not in ('lookup','put','select','delete')
    or c - array['action','generation','baseRevision','operationID','payload','revisionID'] <> '{}'::jsonb
  then raise exception 'farm_invalid_request'; end if;
  insert into private.farm_save_heads(user_id) values(p_user) on conflict do nothing;
  select * into h from private.farm_save_heads where user_id=p_user for update;
  if action='lookup' then
    return jsonb_build_object('generation',h.generation,'head',private.farm_save_revision(p_user,h.revision),
      'revisions',coalesce((select jsonb_agg(jsonb_build_object('id',id,'createdAt',created_at,
        'conflict',conflict,'lineageID',lineage_id) order by created_at desc,id)
        from private.farm_save_revisions where user_id=p_user),'[]'::jsonb));
  end if;
  operation := (c->>'operationID')::uuid;
  if operation is null then raise exception 'farm_operation_required'; end if;
  request_hash := encode(extensions.digest(convert_to(c::text,'UTF8'),'sha256'),'hex');
  if action='delete' and operation=h.last_delete_operation then
    if request_hash is distinct from h.last_delete_digest then raise exception 'farm_operation_reused'; end if;
    return jsonb_build_object('status','deleted','generation',h.generation);
  end if;
  if (c->>'generation')::uuid is distinct from h.generation then raise exception 'farm_generation_changed'; end if;
  select * into op from private.farm_save_operations where user_id=p_user and operation_id=operation;
  if found then
    if op.request_digest <> request_hash then raise exception 'farm_operation_reused'; end if;
    return op.result;
  end if;
  if action='delete' then
    if (c->>'baseRevision')::uuid is distinct from h.revision then raise exception 'farm_head_changed'; end if;
    delete from private.farm_save_revisions where user_id=p_user;
    delete from private.farm_save_operations where user_id=p_user;
    update private.farm_save_heads set generation=gen_random_uuid(),revision=null,last_delete_operation=operation,
      last_delete_digest=request_hash,updated_at=now() where user_id=p_user returning * into h;
    return jsonb_build_object('status','deleted','generation',h.generation);
  end if;
  if action='put' then
    if payload is null or jsonb_typeof(payload)<>'object' or octet_length(convert_to(payload::text,'UTF8'))>2097152
      or not payload ?& array['schemaVersion','economyVersion','lineageID','farm','search','welcome','socialRewards',
        'sunrise','completedWindDownCount','keepsakes','deliveredWindDownRunIDs','deliveredEffectIDs']
      or payload - array['schemaVersion','economyVersion','lineageID','farm','search','welcome','socialRewards',
        'sunrise','completedWindDownCount','keepsakes','deliveredWindDownRunIDs','deliveredEffectIDs','pasture','appearance'] <> '{}'::jsonb
      or payload->>'schemaVersion'<>'1' or payload->>'economyVersion'<>'1'
      or jsonb_typeof(payload->'farm')<>'object' or jsonb_typeof(payload->'search')<>'object'
      or jsonb_typeof(payload->'welcome')<>'object' or jsonb_typeof(payload->'socialRewards')<>'object'
      or jsonb_typeof(payload->'sunrise')<>'object' or jsonb_typeof(payload->'keepsakes')<>'array'
      or jsonb_typeof(payload->'deliveredWindDownRunIDs')<>'array' or jsonb_typeof(payload->'deliveredEffectIDs')<>'array'
      or jsonb_typeof(payload->'completedWindDownCount')<>'number' or (payload->>'completedWindDownCount')::numeric<0
      or payload#>>'{farm,cumulativeCredit,migrationCompleted}' is distinct from 'true'
    then raise exception 'farm_invalid_payload'; end if;
    conflicted := (c->>'baseRevision')::uuid is distinct from h.revision;
    if conflicted and (select count(*) from private.farm_save_revisions where user_id=p_user and conflict)>=20
      then raise exception 'farm_resolve_conflicts_first'; end if;
    insert into private.farm_save_revisions(user_id,generation,lineage_id,payload,digest,conflict)
      values(p_user,h.generation,(payload->>'lineageID')::uuid,payload,
        encode(extensions.digest(convert_to(payload::text,'UTF8'),'sha256'),'hex'),conflicted) returning id into r;
    if not conflicted then update private.farm_save_heads set revision=r,updated_at=now() where user_id=p_user; end if;
    result := jsonb_build_object('status',case when conflicted then 'conflict' else 'saved' end,
      'generation',h.generation,'revision',private.farm_save_revision(p_user,r));
  else
    if (c->>'baseRevision')::uuid is distinct from h.revision then raise exception 'farm_head_changed'; end if;
    r := (c->>'revisionID')::uuid;
    if not exists(select 1 from private.farm_save_revisions where user_id=p_user and id=r and generation=h.generation)
      then raise exception 'farm_revision_unavailable'; end if;
    update private.farm_save_heads set revision=r,updated_at=now() where user_id=p_user;
    update private.farm_save_revisions set conflict=false where user_id=p_user;
    result := jsonb_build_object('status','saved','generation',h.generation,'revision',private.farm_save_revision(p_user,r));
  end if;
  result := jsonb_set(result,'{revision}',(result->'revision')-'payload');
  insert into private.farm_save_operations values(p_user,operation,request_hash,result);
  delete from private.farm_save_revisions x where x.user_id=p_user and not x.conflict and x.created_at<now()-interval '30 days'
    and x.id is distinct from (select revision from private.farm_save_heads where user_id=p_user)
    and x.id not in (select id from private.farm_save_revisions where user_id=p_user and not conflict order by created_at desc,id limit 10);
  return result;
end $$;
revoke all on function private.farm_account_sync_apply_v1(uuid,jsonb) from public, anon, authenticated;

create function public.farm_account_sync_v1(c jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); action text := c->>'action'; result jsonb;
begin
  if u is null or not private.account_verified_farm_owner_v1(u) then
    raise exception 'farm_verified_account_required' using errcode='42501';
  end if;
  if jsonb_typeof(c) <> 'object' or action is null then raise exception 'farm_invalid_request'; end if;
  if action='status' and c - array['action'] <> '{}'::jsonb then raise exception 'farm_invalid_request'; end if;
  if action='status' then return jsonb_build_object('capability','farm_account_sync_v1','accepted',exists(select 1 from private.account_sync_acceptances where user_id=u)); end if;
  if action='accept' then
    if c - array['action'] <> '{}'::jsonb then raise exception 'farm_invalid_request'; end if;
    insert into private.account_sync_acceptances(user_id) values(u) on conflict do nothing;
    result := private.farm_account_sync_apply_v1(u,'{"action":"lookup"}'::jsonb);
    return jsonb_build_object('capability','farm_account_sync_v1','status','accepted','accepted',true,'generation',result->'generation','head',result->'head','revisions',result->'revisions');
  end if;
  if not exists(select 1 from private.account_sync_acceptances where user_id=u) then raise exception 'farm_account_sync_acceptance_required' using errcode='42501'; end if;
  result := private.farm_account_sync_apply_v1(u,c);
  return jsonb_set(result,'{capability}','"farm_account_sync_v1"'::jsonb);
end $$;
revoke all on function public.farm_account_sync_v1(jsonb) from public, anon;
grant execute on function public.farm_account_sync_v1(jsonb) to authenticated;

create function public.farm_account_sync_revision_v1(c jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); current_state jsonb; revision jsonb;
begin
  if u is null or not private.account_verified_farm_owner_v1(u) or not exists(select 1 from private.account_sync_acceptances where user_id=u)
  then raise exception 'farm_account_sync_acceptance_required' using errcode='42501'; end if;
  if jsonb_typeof(c)<>'object' or c - array['action','revisionID'] <> '{}'::jsonb or c->>'action' is distinct from 'read' or c->>'revisionID' is null
  then raise exception 'farm_invalid_request'; end if;
  current_state := private.farm_account_sync_apply_v1(u,'{"action":"lookup"}'::jsonb);
  revision := private.farm_save_revision(u,(c->>'revisionID')::uuid);
  if revision is null then raise exception 'farm_revision_unavailable'; end if;
  return jsonb_build_object('capability','farm_account_sync_v1','accepted',true,'generation',current_state->'generation',
    'head',revision,'currentRevisionID',current_state#>'{head,id}','revisions','[]'::jsonb);
end $$;
revoke all on function public.farm_account_sync_revision_v1(jsonb) from public, anon;
grant execute on function public.farm_account_sync_revision_v1(jsonb) to authenticated;

create function private.prune_account_password_login_limits()
returns void language sql security definer set search_path = '' as $$
  delete from private.account_password_login_limits where window_started < now() - interval '2 days'
$$;
revoke all on function private.prune_account_password_login_limits() from public, anon, authenticated;
select cron.schedule('account-password-login-rate-limit-prune', '15 3 * * *', 'select private.prune_account_password_login_limits()');
