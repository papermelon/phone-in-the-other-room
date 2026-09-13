-- Private account backups are independent of Slumber Party membership/consent.
-- No client-supplied user ID is accepted. Deleted generations fence old devices.
create extension if not exists pg_cron with schema pg_catalog;
create table private.farm_save_heads (
  user_id uuid primary key references auth.users(id) on delete cascade,
  generation uuid not null default gen_random_uuid(),
  revision uuid,
  last_delete_operation uuid,
  last_delete_digest text,
  updated_at timestamptz not null default now()
);
create table private.farm_save_revisions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  generation uuid not null,
  lineage_id uuid not null,
  payload jsonb not null,
  digest text not null,
  conflict boolean not null default false,
  created_at timestamptz not null default now()
);
create index farm_save_revisions_owner on private.farm_save_revisions(user_id, created_at desc);
create table private.farm_save_operations (
  user_id uuid not null references auth.users(id) on delete cascade,
  operation_id uuid not null,
  request_digest text not null,
  result jsonb not null,
  primary key(user_id, operation_id)
);
alter table private.farm_save_heads enable row level security;
alter table private.farm_save_revisions enable row level security;
alter table private.farm_save_operations enable row level security;
revoke all on private.farm_save_heads, private.farm_save_revisions,
  private.farm_save_operations from public, anon, authenticated;

create function private.farm_save_revision(p_user uuid, p_revision uuid)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object('id', id, 'payload', payload, 'digest', digest,
    'createdAt', created_at, 'conflict', conflict)
  from private.farm_save_revisions where user_id = p_user and id = p_revision
$$;
revoke all on function private.farm_save_revision(uuid,uuid) from public, anon, authenticated;

create function public.farm_save_v1(c jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  u uuid := auth.uid(); h private.farm_save_heads%rowtype;
  op private.farm_save_operations%rowtype;
  action text := c->>'action'; operation uuid; request_hash text;
  payload jsonb := c->'payload'; r uuid; result jsonb; conflicted boolean;
begin
  if u is null or not exists (
    select 1 from auth.users a join auth.identities i on i.user_id=a.id
    where a.id=u and not coalesce(a.is_anonymous,true) and i.provider='apple'
  ) then raise exception 'farm_apple_account_required' using errcode='42501'; end if;
  if jsonb_typeof(c)<>'object' or action is null or action not in ('lookup','put','select','delete')
    or c - array['action','generation','baseRevision','operationID','payload','revisionID'] <> '{}'::jsonb
  then raise exception 'farm_invalid_request'; end if;

  insert into private.farm_save_heads(user_id) values(u) on conflict do nothing;
  select * into h from private.farm_save_heads where user_id=u for update;
  if action='lookup' then
    return jsonb_build_object('capability','farm_save_v1','generation',h.generation,
      'head',private.farm_save_revision(u,h.revision),
      'revisions',coalesce((select jsonb_agg(jsonb_build_object('id',id,'createdAt',created_at,
        'conflict',conflict,'lineageID',lineage_id) order by created_at desc,id)
        from private.farm_save_revisions where user_id=u),'[]'::jsonb));
  end if;

  operation := (c->>'operationID')::uuid;
  if operation is null then raise exception 'farm_operation_required'; end if;
  request_hash := encode(extensions.digest(convert_to(c::text,'UTF8'),'sha256'),'hex');
  -- The deletion receipt lives outside the cleared generation, so its retry
  -- cannot delete a newly enrolled backup or resurrect an older operation.
  if action='delete' and operation=h.last_delete_operation then
    if request_hash is distinct from h.last_delete_digest then raise exception 'farm_operation_reused'; end if;
    return jsonb_build_object('status','deleted','generation',h.generation);
  end if;
  if (c->>'generation')::uuid is distinct from h.generation then
    raise exception 'farm_generation_changed';
  end if;
  select * into op from private.farm_save_operations where user_id=u and operation_id=operation;
  if found then
    if op.request_digest<>request_hash then raise exception 'farm_operation_reused'; end if;
    return op.result;
  end if;

  if action='delete' then
    if (c->>'baseRevision')::uuid is distinct from h.revision then raise exception 'farm_head_changed'; end if;
    delete from private.farm_save_revisions where user_id=u;
    delete from private.farm_save_operations where user_id=u;
    update private.farm_save_heads set generation=gen_random_uuid(), revision=null,
      last_delete_operation=operation,last_delete_digest=request_hash,updated_at=now() where user_id=u returning * into h;
    return jsonb_build_object('status','deleted','generation',h.generation);
  end if;

  if action='put' then
    if payload is null or jsonb_typeof(payload)<>'object'
      or octet_length(convert_to(payload::text,'UTF8'))>2097152
      or not payload ?& array['schemaVersion','economyVersion','lineageID','farm','search','welcome',
        'socialRewards','sunrise','completedWindDownCount','keepsakes','deliveredWindDownRunIDs','deliveredEffectIDs']
      or payload - array['schemaVersion','economyVersion','lineageID','farm','search','welcome',
        'socialRewards','sunrise','completedWindDownCount','keepsakes','deliveredWindDownRunIDs',
        'deliveredEffectIDs','pasture','appearance'] <> '{}'::jsonb
      or payload->>'schemaVersion'<>'1' or payload->>'economyVersion'<>'1'
      or jsonb_typeof(payload->'farm')<>'object'
      or jsonb_typeof(payload->'search')<>'object'
      or jsonb_typeof(payload->'welcome')<>'object'
      or jsonb_typeof(payload->'socialRewards')<>'object'
      or jsonb_typeof(payload->'sunrise')<>'object'
      or jsonb_typeof(payload->'keepsakes')<>'array'
      or jsonb_typeof(payload->'deliveredWindDownRunIDs')<>'array'
      or jsonb_typeof(payload->'deliveredEffectIDs')<>'array'
      or jsonb_typeof(payload->'completedWindDownCount')<>'number'
      or (payload->>'completedWindDownCount')::numeric<0
      or payload#>>'{farm,cumulativeCredit,migrationCompleted}' is distinct from 'true'
    then raise exception 'farm_invalid_payload'; end if;
    conflicted := (c->>'baseRevision')::uuid is distinct from h.revision;
    -- Refuse excess branches without discarding any saved progress. The local
    -- pending operation remains retryable after the player resolves a branch.
    if conflicted and (select count(*) from private.farm_save_revisions where user_id=u and conflict)>=20
      then raise exception 'farm_resolve_conflicts_first'; end if;
    insert into private.farm_save_revisions(user_id,generation,lineage_id,payload,digest,conflict)
      values(u,h.generation,(payload->>'lineageID')::uuid,payload,
        encode(extensions.digest(convert_to(payload::text,'UTF8'),'sha256'),'hex'),conflicted)
      returning id into r;
    if not conflicted then
      update private.farm_save_heads set revision=r,updated_at=now() where user_id=u;
    end if;
    result := jsonb_build_object('status',case when conflicted then 'conflict' else 'saved' end,
      'generation',h.generation,'revision',private.farm_save_revision(u,r));
  else
    if (c->>'baseRevision')::uuid is distinct from h.revision then raise exception 'farm_head_changed'; end if;
    r := (c->>'revisionID')::uuid;
    if not exists(select 1 from private.farm_save_revisions where user_id=u and id=r and generation=h.generation)
      then raise exception 'farm_revision_unavailable'; end if;
    update private.farm_save_heads set revision=r,updated_at=now() where user_id=u;
    -- Explicit selection resolves the current branch decision. Other copies
    -- remain in revision history under the documented retention policy.
    update private.farm_save_revisions set conflict=false where user_id=u;
    result := jsonb_build_object('status','saved','generation',h.generation,
      'revision',private.farm_save_revision(u,r));
  end if;
  result := jsonb_set(result,'{revision}',(result->'revision')-'payload');
  insert into private.farm_save_operations values(u,operation,request_hash,result);
  -- Keep the current head, unresolved branches, every copy from 30 days, and
  -- at least the ten most recent resolved copies. Operation receipts retain
  -- only IDs/status, never duplicate the payload after retention expires.
  delete from private.farm_save_revisions x where x.user_id=u and not x.conflict
    and x.created_at<now()-interval '30 days'
    and x.id is distinct from (select revision from private.farm_save_heads where user_id=u)
    and x.id not in (select id from private.farm_save_revisions where user_id=u and not conflict
      order by created_at desc,id limit 10);
  return result;
end
$$;
revoke all on function public.farm_save_v1(jsonb) from public, anon;
grant execute on function public.farm_save_v1(jsonb) to authenticated;

create function private.prune_farm_save_revisions()
returns void language plpgsql security definer set search_path = '' as $$
declare h private.farm_save_heads%rowtype;
begin
  -- Share the per-account lock with uploads and branch selection. A copy
  -- being selected as the new head cannot be removed by concurrent pruning.
  for h in select * from private.farm_save_heads for update skip locked loop
    delete from private.farm_save_revisions x where x.user_id=h.user_id and not x.conflict
      and x.created_at<now()-interval '30 days' and x.id is distinct from h.revision
      and x.id not in (select id from private.farm_save_revisions
        where user_id=h.user_id and not conflict order by created_at desc,id limit 10);
  end loop;
end $$;
revoke all on function private.prune_farm_save_revisions() from public, anon, authenticated;
select cron.schedule('farm-save-retention', '0 3 * * *', 'select private.prune_farm_save_revisions()');
