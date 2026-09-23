-- Three curated appearance fields; no Farm document or ownership ledger is published.
alter table private.night_flock_v4_profiles
  add column shepherd_shirt_id text not null default 'none'
    check (shepherd_shirt_id in ('none','shepherd_berry_shirt','shepherd_dusk_shirt','shepherd_amber_shirt')),
  add column shepherd_outerwear_id text not null default 'none'
    check (shepherd_outerwear_id in ('none','shepherd_open_moss_coat')),
  add column ollie_coat_id text not null default 'classic'
    check (ollie_coat_id in ('classic','fuller'));

alter function private.night_flock_v4_profile_json(private.night_flock_v4_profiles)
  rename to night_flock_v4_profile_json_before_wardrobe;
create function private.night_flock_v4_profile_json(pr private.night_flock_v4_profiles)
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_set(private.night_flock_v4_profile_json_before_wardrobe(pr),
    '{presentation}',
    private.night_flock_v4_profile_json_before_wardrobe(pr)->'presentation'
      || jsonb_build_object('shepherdShirtID',pr.shepherd_shirt_id,
        'shepherdOuterwearID',pr.shepherd_outerwear_id,'ollieCoatID',pr.ollie_coat_id))
$$;

-- The older profile command still validates names and all existing fields.
-- Strip only the three newly validated keys before calling it.
alter function private.night_flock_v4_apply(uuid,jsonb)
  rename to night_flock_v4_apply_before_wardrobe;
create function private.night_flock_v4_apply(u uuid,c jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb; old_revision int; pr private.night_flock_v4_profiles%rowtype;
begin
  if c->>'command'<>'updatePublicProfile' or not (c ?| array['shepherdShirtID','shepherdOuterwearID','ollieCoatID']) then
    return private.night_flock_v4_apply_before_wardrobe(u,c);
  end if;
  if not (c ?& array['shepherdShirtID','shepherdOuterwearID','ollieCoatID'])
    or c->>'shepherdShirtID' not in ('none','shepherd_berry_shirt','shepherd_dusk_shirt','shepherd_amber_shirt')
    or c->>'shepherdOuterwearID' not in ('none','shepherd_open_moss_coat')
    or c->>'ollieCoatID' not in ('classic','fuller') then
    raise exception 'invalid_public_wardrobe';
  end if;
  select revision into old_revision from private.night_flock_v4_profiles where user_id=u for update;
  result:=private.night_flock_v4_apply_before_wardrobe(u,c-'shepherdShirtID'-'shepherdOuterwearID'-'ollieCoatID');
  select * into pr from private.night_flock_v4_profiles where user_id=u for update;
  if pr.shepherd_shirt_id is distinct from c->>'shepherdShirtID'
    or pr.shepherd_outerwear_id is distinct from c->>'shepherdOuterwearID'
    or pr.ollie_coat_id is distinct from c->>'ollieCoatID' then
    update private.night_flock_v4_profiles set
      shepherd_shirt_id=c->>'shepherdShirtID',
      shepherd_outerwear_id=c->>'shepherdOuterwearID',
      ollie_coat_id=c->>'ollieCoatID',
      revision=revision+case when revision=coalesce(old_revision,0) then 1 else 0 end,
      updated_at=now() where user_id=u returning * into pr;
  end if;
  return (result-'profile')||jsonb_build_object('profile',private.night_flock_v4_profile_json(pr));
end $$;

alter function public.night_flock_v4_state(uuid,text,uuid,text)
  rename to night_flock_v4_state_before_wardrobe;
create function public.night_flock_v4_state(p_user_id uuid,p_scope text default 'list',
  p_party_id uuid default null,p_cursor text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare snapshot jsonb;
begin
  snapshot:=public.night_flock_v4_state_before_wardrobe(p_user_id,p_scope,p_party_id,p_cursor);
  if p_scope='list' then return snapshot||jsonb_build_object('profileWardrobeVersion',1); end if;
  return snapshot;
end $$;

-- Global profiles are JSON projections. Keep the existing consent, name,
-- idempotency and session checks in the established command.
create table private.global_campfire_wardrobe_commands (
  user_id uuid not null references auth.users(id) on delete cascade,
  id text not null,
  extras jsonb not null,
  primary key(user_id,id)
);
alter table private.global_campfire_wardrobe_commands enable row level security;
revoke all on private.global_campfire_wardrobe_commands from public,anon,authenticated,service_role;

alter function public.global_campfire_command(uuid,jsonb)
  rename to global_campfire_command_before_wardrobe;
create function public.global_campfire_command(p_user_id uuid,p_command jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare c jsonb:=p_command; a jsonb; extras jsonb; result jsonb;
begin
  if c->>'command' not in ('agreement','profile') then
    return public.global_campfire_command_before_wardrobe(p_user_id,c);
  end if;
  -- The stripped legacy command cannot distinguish two wardrobe payloads with
  -- the same ID. Hold its account lock while checking the extra fields too.
  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text,1612));
  if c->>'command'='agreement' then a:=c->'appearance';
  else a:=c#>'{profile,appearance}'; end if;
  if a is null or not (a ?| array['shepherdShirtID','shepherdOuterwearID','ollieCoatID']) then
    return public.global_campfire_command_before_wardrobe(p_user_id,c);
  end if;
  if not (a ?& array['shepherdShirtID','shepherdOuterwearID','ollieCoatID'])
    or a->>'shepherdShirtID' not in ('none','shepherd_berry_shirt','shepherd_dusk_shirt','shepherd_amber_shirt')
    or a->>'shepherdOuterwearID' not in ('none','shepherd_open_moss_coat')
    or a->>'ollieCoatID' not in ('classic','fuller') then raise exception 'invalid_public_wardrobe'; end if;
  extras:=jsonb_build_object('shepherdShirtID',a->>'shepherdShirtID',
    'shepherdOuterwearID',a->>'shepherdOuterwearID','ollieCoatID',a->>'ollieCoatID');
  if exists(select 1 from private.global_campfire_wardrobe_commands w
    where w.user_id=p_user_id and w.id=c->>'id' and w.extras is distinct from
      jsonb_build_object('shepherdShirtID',a->>'shepherdShirtID',
        'shepherdOuterwearID',a->>'shepherdOuterwearID','ollieCoatID',a->>'ollieCoatID')) then
    raise exception 'idempotency_conflict';
  end if;
  insert into private.global_campfire_wardrobe_commands(user_id,id,extras)
    values(p_user_id,c->>'id',extras) on conflict do nothing;
  if c->>'command'='agreement' then
    result:=public.global_campfire_command_before_wardrobe(p_user_id,
      jsonb_set(c,'{appearance}',a-'shepherdShirtID'-'shepherdOuterwearID'-'ollieCoatID'));
    if result->>'accepted'='true' and result->>'conflict'='false' then
      update private.global_campfire_profiles set appearance=appearance||extras
      where user_id=p_user_id and agreement_id=(result#>>'{agreement,id}')::uuid and enabled;
    end if;
  else
    result:=public.global_campfire_command_before_wardrobe(p_user_id,
      jsonb_set(c,'{profile,appearance}',a-'shepherdShirtID'-'shepherdOuterwearID'-'ollieCoatID'));
    if result->>'accepted'='true' then
      update private.global_campfire_profiles set
        appearance=appearance||extras,
        profile=jsonb_set(profile,'{appearance}',profile->'appearance'||extras)
      where user_id=p_user_id and enabled and agreement_id=(c->>'agreementID')::uuid
        and profile_source_id=(c->>'sourceID')::uuid
        and profile_captured_at=(c->>'capturedAt')::timestamptz;
    end if;
  end if;
  return result;
end $$;

alter function public.global_campfire_state(uuid,text,uuid,integer)
  rename to global_campfire_state_before_wardrobe;
create function public.global_campfire_state(p_user_id uuid,p_gathering text default 'all',
  p_cursor uuid default null,p_channel integer default null)
returns jsonb language sql security definer set search_path='' as $$
  select public.global_campfire_state_before_wardrobe(p_user_id,p_gathering,p_cursor,p_channel)
    || jsonb_build_object('appearanceVersion',1)
$$;

revoke all on function private.night_flock_v4_profile_json_before_wardrobe(private.night_flock_v4_profiles),
  private.night_flock_v4_profile_json(private.night_flock_v4_profiles),
  private.night_flock_v4_apply_before_wardrobe(uuid,jsonb),private.night_flock_v4_apply(uuid,jsonb),
  public.night_flock_v4_state_before_wardrobe(uuid,text,uuid,text),
  public.global_campfire_command_before_wardrobe(uuid,jsonb),
  public.global_campfire_state_before_wardrobe(uuid,text,uuid,integer)
  from public,anon,authenticated,service_role;
revoke all on function public.night_flock_v4_state(uuid,text,uuid,text),
  public.global_campfire_command(uuid,jsonb),public.global_campfire_state(uuid,text,uuid,integer)
  from public,anon,authenticated;
grant execute on function public.night_flock_v4_state(uuid,text,uuid,text),
  public.global_campfire_command(uuid,jsonb),public.global_campfire_state(uuid,text,uuid,integer)
  to service_role;
