-- Independent public projection. Deploying this migration does not activate it.
-- No party history, private intentions, Health or Farm payload enters these tables.
create table private.global_campfire_settings (id boolean primary key default true check(id), enabled boolean not null default false);
insert into private.global_campfire_settings(id) values(true);
create table private.global_campfire_profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 public_id uuid not null unique default gen_random_uuid(),
 name text not null, appearance jsonb not null,
 agreement_id uuid not null default gen_random_uuid(), revision integer not null default 1,
 enabled boolean not null default true, suspended boolean not null default false,
 accepted_at timestamptz not null default now()
);
create table private.global_campfire_sessions (
 user_id uuid not null references private.global_campfire_profiles(user_id) on delete cascade,
 source_id uuid not null, id uuid not null unique default gen_random_uuid(), agreement_id uuid not null,
 kind text not null check(kind in('windDown','phoneAway')),
 activity text check(activity in('phoneAway','reading','studying','making','chores','resting')),
 started_at timestamptz not null, expires_at timestamptz not null, ended boolean not null,
 primary key(user_id,source_id), check(expires_at>started_at and expires_at<=started_at+interval '24 hours'),
 check((kind='windDown' and activity is null) or (kind='phoneAway' and activity is not null))
);
create index global_campfire_session_current on private.global_campfire_sessions(expires_at,user_id,started_at desc);
create table private.global_campfire_encouragements (
 sender uuid not null references auth.users(id) on delete cascade,
 session_id uuid not null references private.global_campfire_sessions(id) on delete cascade,
 created_at timestamptz not null default now(), primary key(sender,session_id)
);
create table private.global_campfire_reports (
 id uuid primary key default gen_random_uuid(), reporter uuid not null references auth.users(id) on delete cascade,
 target uuid not null references auth.users(id) on delete cascade, snapshot jsonb not null,
 reason text not null check(reason='profile'), created_at timestamptz not null default now(),
 moderation_status text not null default 'open' check(moderation_status in('open','reviewed','removed'))
);
create table private.global_campfire_commands (
 user_id uuid not null references auth.users(id) on delete cascade, id text not null,
 request jsonb not null, result jsonb not null, created_at timestamptz not null default now(), primary key(user_id,id)
);
create table private.global_campfire_limits (
 user_id uuid not null references auth.users(id) on delete cascade, kind text not null,
 bucket timestamptz not null, count integer not null, primary key(user_id,kind,bucket)
);
do $$ declare t text; begin
 foreach t in array array['global_campfire_settings','global_campfire_profiles','global_campfire_sessions',
 'global_campfire_encouragements','global_campfire_reports','global_campfire_commands','global_campfire_limits'] loop
 execute format('alter table private.%I enable row level security',t);
 execute format('revoke all on private.%I from public,anon,authenticated,service_role',t);
 end loop;
end $$;

create function private.global_campfire_rate(u uuid,k text,lim integer,window_size text) returns void
language plpgsql security definer set search_path='' as $$
declare n integer; b timestamptz:=date_trunc(window_size,now());
begin
 insert into private.global_campfire_limits values(u,k,b,1)
 on conflict(user_id,kind,bucket) do update set count=private.global_campfire_limits.count+1 returning count into n;
 if n>lim then raise exception 'rate_limited'; end if;
end $$;

create function private.global_campfire_agreement(p private.global_campfire_profiles) returns jsonb
language sql stable set search_path='' as $$
 select case when p.user_id is null then null else jsonb_build_object('id',p.agreement_id,'version',1,
 'revision',p.revision,'enabled',p.enabled and not p.suspended,'acceptedAt',p.accepted_at) end;
$$;

create function private.global_campfire_visible(u uuid,g text) returns setof private.global_campfire_sessions
language sql stable security definer set search_path='' as $$
 with latest as (
 select distinct on(s.user_id) s.* from private.global_campfire_sessions s
 join private.global_campfire_profiles p on p.user_id=s.user_id and p.agreement_id=s.agreement_id and p.enabled and not p.suspended
 where s.started_at>now()-interval '24 hours' and s.started_at<=now()
 and not private.night_flock_users_blocked(u,s.user_id)
 order by s.user_id,s.started_at desc,s.ended desc,s.id
 ) select * from latest s where not s.ended and s.expires_at>now()
 and (g='all' or (g='windDown' and s.kind='windDown') or (g='phoneAway' and s.kind='phoneAway') or s.activity=g);
$$;

create function public.global_campfire_state(p_user_id uuid,p_gathering text default 'all',p_cursor uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p private.global_campfire_profiles%rowtype; enabled boolean; rows jsonb:='[]'; total integer:=0; next_id uuid; mine uuid; encouragement integer:=0;
begin
 if not private.is_apple_linked_night_flock_user(p_user_id) then raise exception 'linked_account_required'; end if;
 if p_gathering not in('all','windDown','phoneAway','reading','studying','making','chores','resting') then raise exception 'invalid_gathering'; end if;
 perform private.global_campfire_rate(p_user_id,'read',90,'minute');
 select s.enabled into enabled from private.global_campfire_settings s where id;
 select * into p from private.global_campfire_profiles where user_id=p_user_id;
 if enabled then
 select count(*) into total from private.global_campfire_visible(p_user_id,p_gathering);
 with page as (
 select s.*,row_number() over(order by s.id) n from private.global_campfire_visible(p_user_id,p_gathering) s
 where p_cursor is null or s.id>p_cursor order by s.id limit 9
 ) select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'profileID',profile.public_id,'name',profile.name,'appearance',profile.appearance,
 'kind',s.kind,'activity',s.activity,'remaining',case when s.expires_at-now()<interval '30 minutes' then 'short'
 when s.expires_at-now()<interval '90 minutes' then 'hour' when s.expires_at-now()<interval '4 hours' then 'fewHours' else 'severalHours' end,
 'encouragedByMe',exists(select 1 from private.global_campfire_encouragements e where e.sender=p_user_id and e.session_id=s.id),
 'isMe',s.user_id=p_user_id) order by s.id) filter(where s.n<=8),'[]'),
 case when max(s.n)>8 then (array_agg(s.id order by s.id))[8] else null end
 into rows,next_id from page s join private.global_campfire_profiles profile on profile.user_id=s.user_id;
 select source_id into mine from private.global_campfire_visible(p_user_id,'all') where user_id=p_user_id;
 select count(*) into encouragement from private.global_campfire_encouragements e
 where e.session_id=(select s.id from private.global_campfire_sessions s where s.user_id=p_user_id
 and s.agreement_id=p.agreement_id order by s.started_at desc,s.ended desc,s.id limit 1)
 and not private.night_flock_users_blocked(p_user_id,e.sender);
 end if;
 return jsonb_build_object('version',1,'available',coalesce(enabled,false),'observedAt',now(),
 'agreement',private.global_campfire_agreement(p),'publicName',p.name,'appearance',p.appearance,
 'participants',rows,'approximateCount',ceil(total/10.0)::integer*10,'nextCursor',next_id,'ownSourceID',mine,'ownEncouragementCount',encouragement);
end $$;

create function public.global_campfire_command(p_user_id uuid,p_command jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c jsonb:=p_command; cmd text:=c->>'command'; p private.global_campfire_profiles%rowtype;
 previous private.global_campfire_commands%rowtype; target private.global_campfire_profiles%rowtype;
 s private.global_campfire_sessions%rowtype; result jsonb; allowed text[]; start_time timestamptz; expiry timestamptz; terminal boolean;
begin
 if not private.is_apple_linked_night_flock_user(p_user_id) then raise exception 'linked_account_required'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_user_id::text,1612));
 if coalesce(c->>'id','') !~ '^[0-9a-fA-F-]{36,64}$' then raise exception 'invalid_command_id'; end if;
 allowed:=case cmd
 when 'agreement' then array['id','command','expectedRevision','consentVersion','enabled','publicName','appearance']
 when 'publish' then array['id','command','agreementID','sourceID','kind','activity','startedAt','expiresAt','ended']
 when 'encourage' then array['id','command','targetID'] when 'block' then array['id','command','targetID']
 when 'report' then array['id','command','targetID','reason'] else null end;
 if allowed is null or exists(select 1 from jsonb_object_keys(c) k where not k=any(allowed)) then raise exception 'invalid_fields'; end if;
 select * into previous from private.global_campfire_commands where user_id=p_user_id and id=c->>'id';
 if found then
 if previous.request<>c then raise exception 'idempotency_conflict'; end if;
 return previous.result;
 end if;
 perform private.global_campfire_rate(p_user_id,'write',30,'minute');
 if not (select enabled from private.global_campfire_settings where id)
 and not (cmd in('block','report') or (cmd='agreement' and c->>'enabled'='false')) then raise exception 'capability_unavailable'; end if;
 select * into p from private.global_campfire_profiles where user_id=p_user_id for update;
 if cmd='agreement' then
 if c->>'consentVersion' is distinct from '1' or jsonb_typeof(c->'enabled') is distinct from 'boolean' or coalesce(c->>'expectedRevision','') !~ '^[0-9]{1,9}$' then raise exception 'invalid_agreement'; end if;
 if c->>'enabled'='true' then
 if p.suspended then raise exception 'profile_unavailable'; end if;
 if coalesce(p.revision,0)<>(c->>'expectedRevision')::integer then
 result:=jsonb_build_object('accepted',true,'conflict',true,'agreement',private.global_campfire_agreement(p));
 else
 if c->>'publicName' is null or c->>'publicName' not in('Fern','Willow','Clover','River','Sage','Maple','Robin','Wren','Hazel','Rowan','Juniper','Aspen')
 or jsonb_typeof(c->'appearance') is distinct from 'object'
 or (select count(*) from jsonb_object_keys(c->'appearance'))<>4
 or coalesce(c#>>'{appearance,skinToneID}','') not in('porcelain','warm','olive','brown','deep')
 or coalesce(c#>>'{appearance,hairStyleID}','') not in('cropped','waves','curls','coils','long')
 or coalesce(c#>>'{appearance,shepherdOutfitID}','') not in('none','shepherd_moss_coat','shepherd_moon_coat','shepherd_field_overalls','shepherd_star_keeper_cloak')
 or coalesce(c#>>'{appearance,shepherdAccessoryID}','') not in('none','shepherd_wool_hat','shepherd_clover_headscarf','shepherd_moon_beanie') then raise exception 'invalid_public_profile'; end if;
 insert into private.global_campfire_profiles(user_id,name,appearance) values(p_user_id,c->>'publicName',c->'appearance')
 on conflict(user_id) do update set name=excluded.name,appearance=excluded.appearance,
 agreement_id=gen_random_uuid(),revision=private.global_campfire_profiles.revision+1,enabled=true,accepted_at=now() returning * into p;
 delete from private.global_campfire_sessions where user_id=p_user_id;
 end if;
 else
 if c ? 'publicName' or c ? 'appearance' then raise exception 'invalid_withdrawal'; end if;
 -- An explicit withdrawal fences every earlier acceptance, even when its
 -- response was lost. Retrying the same command never advances it twice.
 insert into private.global_campfire_profiles(user_id,name,appearance,enabled)
 values(p_user_id,'Fern','{"skinToneID":"warm","hairStyleID":"waves","shepherdOutfitID":"none","shepherdAccessoryID":"none"}',false)
 on conflict(user_id) do update set enabled=false,revision=private.global_campfire_profiles.revision+1,agreement_id=gen_random_uuid(),accepted_at=now()
 returning * into p;
 delete from private.global_campfire_sessions where user_id=p_user_id;
 end if;
 result:=coalesce(result,jsonb_build_object('accepted',true,'conflict',false,'agreement',private.global_campfire_agreement(p)));
 elsif cmd='publish' then
 if p.user_id is null or not p.enabled or p.suspended or p.agreement_id is distinct from (c->>'agreementID')::uuid then raise exception 'agreement_required'; end if;
 start_time:=(c->>'startedAt')::timestamptz; expiry:=(c->>'expiresAt')::timestamptz;
 if jsonb_typeof(c->'ended') is distinct from 'boolean' then raise exception 'invalid_session'; end if;
 terminal:=(c->>'ended')::boolean;
 if start_time is null or expiry is null or not isfinite(start_time) or not isfinite(expiry)
 or start_time<p.accepted_at or start_time<now()-interval '7 days' or start_time>now()+interval '5 minutes'
 or expiry<=start_time or expiry>start_time+interval '24 hours'
 or coalesce(c->>'kind','') not in('windDown','phoneAway') or c->>'sourceID' is null
 or (c->>'kind'='windDown' and c->>'activity' is not null)
 or (c->>'kind'='phoneAway' and coalesce(c->>'activity','') not in('phoneAway','reading','studying','making','chores','resting')) then raise exception 'invalid_session'; end if;
 select * into s from private.global_campfire_sessions where user_id=p_user_id and source_id=(c->>'sourceID')::uuid;
 if found and (s.agreement_id<>p.agreement_id or s.started_at<>start_time or s.expires_at<>expiry or s.kind<>c->>'kind' or s.activity is distinct from c->>'activity') then raise exception 'immutable_session'; end if;
 insert into private.global_campfire_sessions(user_id,source_id,agreement_id,kind,activity,started_at,expires_at,ended)
 values(p_user_id,(c->>'sourceID')::uuid,p.agreement_id,c->>'kind',c->>'activity',start_time,expiry,terminal)
 on conflict(user_id,source_id) do update set ended=private.global_campfire_sessions.ended or excluded.ended;
 result:=jsonb_build_object('accepted',true);
 else
 if cmd='encourage' then
 select * into s from private.global_campfire_visible(p_user_id,'all') where id=(c->>'targetID')::uuid;
 if s.id is null or s.user_id=p_user_id then raise exception 'session_unavailable'; end if;
 insert into private.global_campfire_encouragements(sender,session_id) values(p_user_id,s.id) on conflict do nothing;
 else
 select * into target from private.global_campfire_profiles where public_id=(c->>'targetID')::uuid;
 if target.user_id is null or target.user_id=p_user_id then raise exception 'profile_unavailable'; end if;
 if cmd='block' then
 insert into public.night_flock_blocks(blocker_user_id,blocked_user_id) values(p_user_id,target.user_id) on conflict do nothing;
 else
 if c->>'reason' is distinct from 'profile' then raise exception 'invalid_report'; end if;
 perform private.global_campfire_rate(p_user_id,'report',5,'day');
 insert into private.global_campfire_reports(reporter,target,snapshot,reason)
 values(p_user_id,target.user_id,jsonb_build_object('publicID',target.public_id,'name',target.name,'appearance',target.appearance),'profile');
 end if;
 end if;
 result:=jsonb_build_object('accepted',true);
 end if;
 insert into private.global_campfire_commands(user_id,id,request,result) values(p_user_id,c->>'id',c,result);
 delete from private.global_campfire_commands where user_id=p_user_id and created_at<now()-interval '8 days';
 delete from private.global_campfire_sessions where user_id=p_user_id and started_at<now()-interval '8 days';
 delete from private.global_campfire_limits where user_id=p_user_id and bucket<now()-interval '2 days';
 return result;
end $$;

revoke all on function private.global_campfire_rate(uuid,text,integer,text),
 private.global_campfire_agreement(private.global_campfire_profiles),private.global_campfire_visible(uuid,text) from public,anon,authenticated,service_role;
revoke all on function public.global_campfire_state(uuid,text,uuid),public.global_campfire_command(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.global_campfire_state(uuid,text,uuid),public.global_campfire_command(uuid,jsonb) to service_role;

-- Physical deletion is separate from expiry in the public projection. Keep
-- replay tombstones longer than the seven-day write admission window.
create function private.prune_global_campfire() returns void language sql security definer set search_path='' as $$
 delete from private.global_campfire_sessions where started_at<now()-interval '8 days';
 delete from private.global_campfire_commands where created_at<now()-interval '8 days';
 delete from private.global_campfire_limits where bucket<now()-interval '2 days';
 delete from private.global_campfire_reports where created_at<now()-interval '90 days';
$$;
revoke all on function private.prune_global_campfire() from public,anon,authenticated,service_role;
select cron.schedule('global-campfire-retention','35 3 * * *','select private.prune_global_campfire()');
