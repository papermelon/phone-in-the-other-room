-- Global visibility now shares the character identity and an explicit display profile.
-- Existing version-1 receipts remain alias-only until the person saves the new choice.
alter table private.global_campfire_profiles add column consent_version integer not null default 1 check(consent_version in(1,2)),
 add column profile jsonb, add column profile_source_id uuid, add column profile_captured_at timestamptz;
create or replace function private.global_campfire_agreement(p private.global_campfire_profiles) returns jsonb
language sql stable set search_path='' as $$
 select case when p.user_id is null then null else jsonb_build_object('id',p.agreement_id,'version',p.consent_version,
 'revision',p.revision,'enabled',p.enabled and not p.suspended,'acceptedAt',p.accepted_at) end;
$$;

create function private.campfire_string_list(v jsonb, maximum integer default 5000) returns boolean
language sql immutable set search_path='' as $$
 select case when jsonb_typeof(v)='array' then jsonb_array_length(v)<=maximum and not exists(
 select 1 from jsonb_array_elements(v) x where jsonb_typeof(x)<>'string' or char_length(x#>>'{}')>2048) else false end;
$$;
create function private.valid_campfire_profile(p jsonb) returns boolean
language plpgsql immutable set search_path='' as $$
declare k text; s jsonb; a jsonb;
begin
 if jsonb_typeof(p) is distinct from 'object' or octet_length(p::text)>1000000 or
 exists(select 1 from jsonb_object_keys(p) x(key) where x.key not in('session','tasks','routines','intention','history','partyNames','inventory','sheep','appearance','decorations','collectibles','ollieAccessory','barnCapacityLevel')) then return false; end if;
 foreach k in array array['session','tasks','routines','history','partyNames','inventory'] loop
 if not coalesce(private.campfire_string_list(p->k),false) then return false; end if;
 end loop;
 if jsonb_typeof(p->'intention') is distinct from 'string' or char_length(p->>'intention')>2048
 or jsonb_typeof(p->'ollieAccessory') is distinct from 'string' or char_length(p->>'ollieAccessory')>100
 or coalesce(p->>'barnCapacityLevel','') !~ '^[0-9]{1,3}$' or (p->>'barnCapacityLevel')::int>100 then return false; end if;
 a:=p->'appearance';
 if jsonb_typeof(a) is distinct from 'object' or exists(select 1 from jsonb_object_keys(a) x(key) where x.key not in('skinToneID','hairStyleID','shepherdOutfitID','shepherdAccessoryID','headShapeID'))
 or coalesce(a->>'skinToneID','') not in('porcelain','warm','olive','brown','deep')
 or coalesce(a->>'hairStyleID','') not in('cropped','waves','curls','coils','long')
 or coalesce(a->>'shepherdOutfitID','') not in('none','shepherd_moss_coat','shepherd_moon_coat','shepherd_field_overalls','shepherd_star_keeper_cloak')
 or coalesce(a->>'shepherdAccessoryID','') not in('none','shepherd_wool_hat','shepherd_clover_headscarf','shepherd_moon_beanie')
 or (a->>'headShapeID' is not null and a->>'headShapeID' not in('pear','round','boxy','triangular')) then return false; end if;
 foreach k in array array['decorations','collectibles'] loop
 if jsonb_typeof(p->k) is distinct from 'object' then return false; end if;
 if exists(select 1 from jsonb_each(p->k) x where jsonb_typeof(x.value)<>'string' or (x.value#>>'{}') !~ '^[a-z0-9_]{1,100}$'
 or (k='decorations' and x.key not in('leftMeadow','rightMeadow','centerHorizon','leftFence','waterEdge','barnCorner'))
 or (k='collectibles' and x.key not in('left','centerLeft','centerRight','right'))) then return false; end if;
 end loop;
 if jsonb_typeof(p->'sheep') is distinct from 'array' or jsonb_array_length(p->'sheep')>5000 then return false; end if;
 for s in select * from jsonb_array_elements(p->'sheep') loop
 if jsonb_typeof(s) is distinct from 'object' or exists(select 1 from jsonb_object_keys(s) x(key) where x.key not in('id','definitionID','name','status','cosmetics'))
 or coalesce(s->>'id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
 or coalesce(s->>'definitionID','') !~ '^[a-z0-9_]{1,100}$' or jsonb_typeof(s->'name') is distinct from 'string' or char_length(s->>'name')>100
 or coalesce(s->>'status','') not in('active','pending','sold') or not coalesce(private.campfire_string_list(s->'cosmetics',20),false) then return false; end if;
 end loop;
 return true;
exception when others then return false;
end $$;
revoke all on function private.campfire_string_list(jsonb,integer),private.valid_campfire_profile(jsonb) from public,anon,authenticated,service_role;

-- Stable numbered channels share the meadow's eight seats. Ended/expired sessions free their seat.
alter table private.global_campfire_sessions add column channel_id integer not null default 1 check(channel_id between 1 and 1000000);
with ranked as (select id, ((row_number() over(order by started_at,id)-1)/8+1)::integer channel from private.global_campfire_sessions)
update private.global_campfire_sessions s set channel_id=r.channel from ranked r where r.id=s.id;
create index global_campfire_channel on private.global_campfire_sessions(channel_id,expires_at);
create function private.global_campfire_channels() returns table(id integer,count integer)
language sql stable set search_path='' as $$
 -- Reserve seats for the permitted clock-skew window too, so near-future starts cannot overfill a channel.
 with latest as (
 select distinct on(s.user_id) s.* from private.global_campfire_sessions s
 join private.global_campfire_profiles p on p.user_id=s.user_id and p.agreement_id=s.agreement_id and p.enabled and not p.suspended
 where s.started_at>now()-interval '24 hours'
 order by s.user_id,s.started_at desc,s.ended desc,s.id
 ), seats as (
 select user_id,channel_id from latest where not ended and expires_at>now()
 union select user_id,channel_id from private.global_campfire_visible(null,'all')
 ), occupied as (select channel_id id,count(*)::integer count from seats group by channel_id),
 empty as (select min(n)::integer id from generate_series(1,(select count(*)::integer+1 from occupied)) n where not exists(select 1 from occupied o where o.id=n))
 select * from occupied union all select id,0 from empty order by id;
$$;
revoke all on function private.global_campfire_channels() from public,anon,authenticated,service_role;
-- The optional fourth argument preserves old paginated reads; current clients always request a channel.
drop function public.global_campfire_state(uuid,text,uuid);
create function public.global_campfire_state(p_user_id uuid,p_gathering text default 'all',p_cursor uuid default null,p_channel integer default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p private.global_campfire_profiles%rowtype; enabled boolean; rows jsonb:='[]'; total integer:=0; next_id uuid; mine uuid; encouragement integer:=0; channel integer; own_channel integer; channels jsonb:='[]';
begin
 if not private.is_apple_linked_night_flock_user(p_user_id) then raise exception 'linked_account_required'; end if;
 if p_channel is not null and p_channel not between 0 and 1000000 then raise exception 'invalid_channel'; end if;
 if p_gathering not in('all','windDown','phoneAway','reading','studying','making','chores','resting') then raise exception 'invalid_gathering'; end if;
 perform private.global_campfire_rate(p_user_id,'read',90,'minute');
 select s.enabled into enabled from private.global_campfire_settings s where id;
 select * into p from private.global_campfire_profiles where user_id=p_user_id;
 if enabled then
 select channel_id into own_channel from private.global_campfire_visible(p_user_id,'all') where user_id=p_user_id;
 select jsonb_agg(jsonb_build_object('id',c.id,'count',c.count) order by c.id) into channels from private.global_campfire_channels() c;
 channel:=case when p_channel=0 then coalesce(own_channel,1) else p_channel end;
 if channel is not null and not exists(select 1 from private.global_campfire_channels() c where c.id=channel) then
 channel:=coalesce(own_channel,1);
 end if;
 select count(*) into total from private.global_campfire_visible(p_user_id,p_gathering);
 with page as (
 select s.*,row_number() over(order by s.id) n from private.global_campfire_visible(p_user_id,p_gathering) s
 where (channel is null or s.channel_id=channel) and (p_cursor is null or s.id>p_cursor) order by s.id limit 9
 ) select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object('id',s.id,'profileID',profile.public_id,'name',case when profile.consent_version=2 then (select display_name from private.night_flock_v4_profiles where user_id=profile.user_id) else profile.name end,'appearance',profile.appearance,
 'kind',s.kind,'activity',s.activity,'remaining',case when s.expires_at-now()<interval '30 minutes' then 'short'
 when s.expires_at-now()<interval '90 minutes' then 'hour' when s.expires_at-now()<interval '4 hours' then 'fewHours' else 'severalHours' end,
 'encouragedByMe',exists(select 1 from private.global_campfire_encouragements e where e.sender=p_user_id and e.session_id=s.id),
 'isMe',s.user_id=p_user_id,
 'startedAt',case when profile.consent_version=2 then s.started_at end,'expiresAt',case when profile.consent_version=2 then s.expires_at end,
 'hasProfile',profile.consent_version=2 and profile.profile_source_id=s.source_id and profile.profile is not null,
 'thought',case when profile.consent_version=2 and profile.profile_source_id=s.source_id then coalesce(profile.profile#>>'{tasks,0}',profile.profile#>>'{routines,0}') end)) order by s.id) filter(where s.n<=8),'[]'),
 case when max(s.n)>8 then (array_agg(s.id order by s.id))[8] else null end
 into rows,next_id from page s join private.global_campfire_profiles profile on profile.user_id=s.user_id;
 select source_id into mine from private.global_campfire_visible(p_user_id,'all') where user_id=p_user_id;
 select count(*) into encouragement from private.global_campfire_encouragements e
 where e.session_id=(select s.id from private.global_campfire_sessions s where s.user_id=p_user_id
 and s.agreement_id=p.agreement_id order by s.started_at desc,s.ended desc,s.id limit 1)
 and not private.night_flock_users_blocked(p_user_id,e.sender);
 end if;
 return jsonb_build_object('profileVersion',2,'version',1,'available',coalesce(enabled,false),'observedAt',now(),
 'channels',case when p_channel is not null then channels end,'channelID',channel,'ownChannelID',own_channel,
 'agreement',private.global_campfire_agreement(p),'publicName',p.name,'appearance',p.appearance,
 'participants',rows,'approximateCount',ceil(total/10.0)::integer*10,'nextCursor',next_id,'ownSourceID',mine,'ownEncouragementCount',encouragement);
end $$;
revoke all on function public.global_campfire_state(uuid,text,uuid,integer) from public,anon,authenticated;
grant execute on function public.global_campfire_state(uuid,text,uuid,integer) to service_role;

create or replace function public.global_campfire_command(p_user_id uuid,p_command jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c jsonb:=p_command; cmd text:=c->>'command'; p private.global_campfire_profiles%rowtype;
 previous private.global_campfire_commands%rowtype; target private.global_campfire_profiles%rowtype;
 s private.global_campfire_sessions%rowtype; result jsonb; allowed text[]; start_time timestamptz; expiry timestamptz; terminal boolean; channel integer;
begin
 if not private.is_apple_linked_night_flock_user(p_user_id) then raise exception 'linked_account_required'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_user_id::text,1612));
 if coalesce(c->>'id','') !~ '^[0-9a-fA-F-]{36,64}$' then raise exception 'invalid_command_id'; end if;
 allowed:=case cmd
 when 'agreement' then array['id','command','expectedRevision','consentVersion','enabled','publicName','appearance']
 when 'profile' then array['id','command','agreementID','sourceID','profile','capturedAt']
 when 'publish' then array['id','command','agreementID','sourceID','kind','activity','startedAt','expiresAt','ended','channelID']
 when 'channel' then array['id','command','agreementID','sourceID','channelID']
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
 if coalesce(c->>'consentVersion','') not in('1','2') or jsonb_typeof(c->'enabled') is distinct from 'boolean' or coalesce(c->>'expectedRevision','') !~ '^[0-9]{1,9}$' then raise exception 'invalid_agreement'; end if;
 if c->>'enabled'='true' then
 if p.suspended then raise exception 'profile_unavailable'; end if;
 if coalesce(p.revision,0)<>(c->>'expectedRevision')::integer then
 result:=jsonb_build_object('accepted',true,'conflict',true,'agreement',private.global_campfire_agreement(p));
 else
 if (c->>'consentVersion'='1' and coalesce(c->>'publicName','') not in('Fern','Willow','Clover','River','Sage','Maple','Robin','Wren','Hazel','Rowan','Juniper','Aspen'))
 or (c->>'consentVersion'='2' and not exists(select 1 from private.night_flock_v4_profiles where user_id=p_user_id and display_name=c->>'publicName'))
 or jsonb_typeof(c->'appearance') is distinct from 'object'
 or exists(select 1 from jsonb_object_keys(c->'appearance') k where k not in('skinToneID','hairStyleID','shepherdOutfitID','shepherdAccessoryID','headShapeID'))
 or (c#>>'{appearance,headShapeID}' is not null and c#>>'{appearance,headShapeID}' not in('pear','round','boxy','triangular'))
 or coalesce(c#>>'{appearance,skinToneID}','') not in('porcelain','warm','olive','brown','deep')
 or coalesce(c#>>'{appearance,hairStyleID}','') not in('cropped','waves','curls','coils','long')
 or coalesce(c#>>'{appearance,shepherdOutfitID}','') not in('none','shepherd_moss_coat','shepherd_moon_coat','shepherd_field_overalls','shepherd_star_keeper_cloak')
 or coalesce(c#>>'{appearance,shepherdAccessoryID}','') not in('none','shepherd_wool_hat','shepherd_clover_headscarf','shepherd_moon_beanie') then raise exception 'invalid_public_profile'; end if;
 insert into private.global_campfire_profiles(user_id,name,appearance,consent_version) values(p_user_id,c->>'publicName',c->'appearance',(c->>'consentVersion')::int)
 on conflict(user_id) do update set name=excluded.name,appearance=excluded.appearance,consent_version=excluded.consent_version,profile=null,profile_captured_at=null,
 agreement_id=gen_random_uuid(),revision=private.global_campfire_profiles.revision+1,enabled=true,accepted_at=now() returning * into p;
 delete from private.global_campfire_sessions where user_id=p_user_id;
 end if;
 else
 if c ? 'publicName' or c ? 'appearance' then raise exception 'invalid_withdrawal'; end if;
 -- An explicit withdrawal fences every earlier acceptance, even when its
 -- response was lost. Retrying the same command never advances it twice.
 insert into private.global_campfire_profiles(user_id,name,appearance,enabled)
 values(p_user_id,'Fern','{"skinToneID":"warm","hairStyleID":"waves","shepherdOutfitID":"none","shepherdAccessoryID":"none"}',false)
 on conflict(user_id) do update set enabled=false,profile=null,profile_captured_at=null,revision=private.global_campfire_profiles.revision+1,agreement_id=gen_random_uuid(),accepted_at=now()
 returning * into p;
 delete from private.global_campfire_sessions where user_id=p_user_id;
 end if;
 result:=coalesce(result,jsonb_build_object('accepted',true,'conflict',false,'agreement',private.global_campfire_agreement(p)));
 elsif cmd='profile' then
 if p.user_id is null or not p.enabled or p.suspended or p.consent_version<>2 or p.agreement_id is distinct from (c->>'agreementID')::uuid then raise exception 'agreement_required'; end if;
 if c->>'sourceID' is null or not private.valid_campfire_profile(c->'profile') or (c->>'capturedAt')::timestamptz>now()+interval '5 minutes'
 or (c->>'capturedAt')::timestamptz<p.accepted_at or c->>'capturedAt' is null then raise exception 'invalid_profile'; end if;
 update private.global_campfire_profiles set profile=c->'profile',profile_source_id=(c->>'sourceID')::uuid,profile_captured_at=(c->>'capturedAt')::timestamptz,
 appearance=c#>'{profile,appearance}' where user_id=p_user_id and (profile_captured_at is null or profile_captured_at<=(c->>'capturedAt')::timestamptz);
 result:=jsonb_build_object('accepted',true);
 elsif cmd='channel' then
 -- ponytail: one short allocation lock; use channel-row locks if admission contention becomes measurable.
 perform pg_advisory_xact_lock(1613,8);
 if coalesce(c->>'channelID','') !~ '^[0-9]{1,7}$' then raise exception 'invalid_channel'; end if;
 channel:=(c->>'channelID')::integer;
 if not exists(select 1 from private.global_campfire_channels() where id=channel) then raise exception 'invalid_channel'; end if;
 select * into s from private.global_campfire_visible(p_user_id,'all') where user_id=p_user_id and source_id=(c->>'sourceID')::uuid and agreement_id=(c->>'agreementID')::uuid;
 if s.id is null then raise exception 'session_unavailable'; end if;
 if channel<>s.channel_id and (select count from private.global_campfire_channels() where id=channel)>=8 then
 result:=jsonb_build_object('accepted',false,'retryable',false,'channelFull',true);
 else
 update private.global_campfire_sessions set channel_id=channel where id=s.id;
 result:=jsonb_build_object('accepted',true,'channelID',channel);
 end if;
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
 perform pg_advisory_xact_lock(1613,8);
 if c ? 'channelID' and coalesce(c->>'channelID','') !~ '^[0-9]{1,7}$' then raise exception 'invalid_channel'; end if;
 if coalesce((c->>'channelID')::integer,0) not between 0 and 1000000 then raise exception 'invalid_channel'; end if;
 channel:=s.channel_id;
 if channel is null then
 channel:=coalesce((c->>'channelID')::integer,0);
 if not exists(select 1 from private.global_campfire_channels() where id=channel and count<8) then
 select id into channel from private.global_campfire_channels() where count<8 order by id limit 1;
 end if;
 end if;
 insert into private.global_campfire_sessions(user_id,source_id,agreement_id,kind,activity,started_at,expires_at,ended,channel_id)
 values(p_user_id,(c->>'sourceID')::uuid,p.agreement_id,c->>'kind',c->>'activity',start_time,expiry,terminal,channel)
 on conflict(user_id,source_id) do update set ended=private.global_campfire_sessions.ended or excluded.ended;
 result:=jsonb_build_object('accepted',true,'channelID',channel);
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
 values(p_user_id,target.user_id,jsonb_build_object('publicID',target.public_id,'name',target.name,'appearance',target.appearance,'profile',target.profile),'profile');
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

-- Detail reads use current presence and block fences, including when opened from a party.
create function public.global_campfire_detail(p_user_id uuid,p_participant_id uuid default null,p_member_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare snapshot jsonb; target_user uuid;
begin
 if not private.is_apple_linked_night_flock_user(p_user_id) then raise exception 'linked_account_required'; end if;
 if (p_participant_id is null)=(p_member_id is null) then raise exception 'invalid_target'; end if;
 perform private.global_campfire_rate(p_user_id,'read',90,'minute');
 if (select enabled from private.global_campfire_settings where id) then
 if p_member_id is not null then
 select m.user_id into target_user from private.night_flock_v4_memberships m
 join private.night_flock_v4_memberships viewer on viewer.party_id=m.party_id and viewer.user_id=p_user_id and viewer.status='active'
 join private.night_flock_v4_parties party on party.id=m.party_id and party.deleted_at is null
 where m.id=p_member_id and m.status='active';
 end if;
 select p.profile into snapshot from private.global_campfire_visible(p_user_id,'all') s
 join private.global_campfire_profiles p on p.user_id=s.user_id and p.consent_version=2 and p.profile_source_id=s.source_id
 where (p_participant_id is not null and s.id=p_participant_id) or (target_user is not null and s.user_id=target_user);
 end if;
 return jsonb_build_object('accepted',true,'profile',snapshot,'observedAt',now());
end $$;
revoke all on function public.global_campfire_detail(uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function public.global_campfire_detail(uuid,uuid,uuid) to service_role;
