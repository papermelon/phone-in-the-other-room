-- Additive shared placements and explicit, owner-verified sheep visits.
-- Source only. Apply after the private Farm and v4 membership migrations.
create table private.shared_pasture_policy (
 id boolean primary key default true check(id), required_contributions int not null check(required_contributions between 1 and 100),
 starts_at timestamptz not null default now()
);
insert into private.shared_pasture_policy(required_contributions) values(12);
create table private.shared_pasture_visits (
 id uuid primary key default gen_random_uuid(), party_id uuid not null references private.night_flock_v4_parties(id) on delete cascade,
 member_id uuid not null references private.night_flock_v4_memberships(id) on delete cascade,
 member_epoch_id uuid not null references private.night_flock_v4_membership_epochs(id) on delete cascade,
 owner_id uuid not null references auth.users(id) on delete cascade, sheep_id uuid not null,
 definition_id text not null, display_name text not null check(char_length(display_name) between 1 and 24),
 consent_version int not null check(consent_version=1), sent_at timestamptz not null default now(), recalled_at timestamptz
);
create unique index shared_pasture_one_sheep_per_party on private.shared_pasture_visits(member_id) where recalled_at is null;
create unique index shared_pasture_one_party_per_sheep on private.shared_pasture_visits(owner_id,sheep_id) where recalled_at is null;
create table private.shared_pasture_layout (
 party_id uuid not null references private.night_flock_v4_parties(id) on delete cascade, entity_id text not null,
 revision int not null default 1, x double precision not null, y double precision not null,
 previous_positions jsonb not null default '[]', updated_at timestamptz not null default now(),
 primary key(party_id,entity_id), check(x between 0.08 and 0.92 and y between 0.43 and 0.89),
 check(not(x<0.28 and y>0.80)), check(jsonb_array_length(previous_positions)<=10)
);
create table private.shared_pasture_projects (
 party_id uuid primary key references private.night_flock_v4_parties(id) on delete cascade,
 required_contributions int not null, contributions int not null default 0, completed_at timestamptz
);
create table private.shared_pasture_contributions (
 party_id uuid not null references private.night_flock_v4_parties(id) on delete cascade,
 user_id uuid references auth.users(id) on delete set null, party_day date not null,
 grant_id uuid unique not null, primary key(party_id,grant_id), unique(party_id,user_id,party_day)
);
-- Retain accepted sheep-contribution identities for the account lifetime. The
-- general v4 retry ledger expires; replaying an old contribution must never
-- resurrect a sheep after its owner recalled it.
create table private.shared_pasture_command_receipts (
 user_id uuid not null references auth.users(id) on delete cascade,
 idempotency_key text not null, command jsonb not null, response jsonb not null,
 primary key(user_id,idempotency_key)
);
-- Tables are reachable only through authenticated, membership-checked RPCs.
do $$ declare t text; begin foreach t in array array['shared_pasture_policy','shared_pasture_visits','shared_pasture_layout','shared_pasture_projects','shared_pasture_contributions','shared_pasture_command_receipts'] loop
 execute format('alter table private.%I enable row level security',t);
 execute format('revoke all on private.%I from public,anon,authenticated,service_role',t);
end loop; end $$;

-- Inspect only the caller's current private saved Farm. Nothing from the private
-- payload is returned by the social projection except this explicitly chosen look.
create function private.shared_pasture_owned_sheep(u uuid,s uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select animal from private.farm_save_heads h join private.farm_save_revisions r on r.id=h.revision and r.user_id=h.user_id
 cross join lateral jsonb_array_elements(coalesce(r.payload#>'{farm,sheep}','[]')) animal
 where h.user_id=u and lower(animal->>'id')=s::text and animal->>'status'='active' limit 1
$$;
create function private.shared_pasture_prune() returns trigger
language plpgsql security definer set search_path='' as $$
declare affected_party uuid; owner uuid:=coalesce(new.user_id,old.user_id);
begin
 -- Use the same head → party → visit lock order as contribution commands.
 for affected_party in select distinct party_id from private.shared_pasture_visits where owner_id=owner and recalled_at is null order by party_id loop
 perform 1 from private.night_flock_v4_parties where id=affected_party for update;
 update private.shared_pasture_visits v set recalled_at=now() where v.party_id=affected_party and v.owner_id=owner and v.recalled_at is null
 and private.shared_pasture_owned_sheep(v.owner_id,v.sheep_id) is null;
 if found then perform private.night_flock_v4_signal_party(affected_party); end if;
 end loop;
 return coalesce(new,old);
end $$;
create trigger shared_pasture_farm_removed after update of revision or delete on private.farm_save_heads
for each row execute function private.shared_pasture_prune();
create function private.shared_pasture_epoch_ended() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.ended_at is not null then
 update private.shared_pasture_visits set recalled_at=coalesce(recalled_at,now()) where member_epoch_id=new.id;
 end if; return new;
end $$;
create trigger shared_pasture_membership_ended after update of ended_at on private.night_flock_v4_membership_epochs
for each row execute function private.shared_pasture_epoch_ended();

create function private.shared_pasture_visible_visits(u uuid,p uuid)
returns setof private.shared_pasture_visits language sql stable security definer set search_path='' as $$
 select v.* from private.shared_pasture_visits v
 join private.night_flock_v4_memberships m on m.id=v.member_id and m.status='active'
 join private.night_flock_v4_membership_epochs e on e.id=v.member_epoch_id and e.ended_at is null
 where v.party_id=p and v.recalled_at is null and not private.night_flock_users_blocked(u,v.owner_id)
 and private.shared_pasture_owned_sheep(v.owner_id,v.sheep_id) is not null
$$;

create function private.shared_pasture_entities(u uuid,p uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 with members as (
 select m.id,e.id epoch_id,row_number() over(order by m.joined_at,m.id)-1 n,count(*) over() total
 from private.night_flock_v4_memberships m join private.night_flock_v4_membership_epochs e on e.membership_id=m.id and e.ended_at is null
 where m.party_id=p and m.status='active' and not private.night_flock_users_blocked(u,m.user_id)
 ), anchors as (
 select *,case when total>4 then (array[0.16,0.34,0.42,0.57,0.75,0.85,0.63,0.23])[(n%8+1)::int]
 when total>2 then (array[0.22,0.66,0.26,0.70])[(n%4+1)::int]
 else (array[0.36,0.67,0.67,0.32])[(n%4+1)::int] end x,
 case when total>4 then (array[0.65,0.78,0.49,0.66,0.50,0.79,0.87,0.46])[(n%8+1)::int]
 when total>2 then (array[0.54,0.57,0.88,0.88])[(n%4+1)::int]
 else (array[0.65,0.76,0.49,0.87])[(n%4+1)::int] end y from members
 ), entities as (
 select 'member-'||epoch_id::text entity_id,'shepherd' kind,id ref,x,y from anchors
 union all
 select 'visitor-'||v.id::text,'sheep',v.id,least(0.92,a.x+case when a.total>4 then 0.075 when a.total>2 then 0.18 else 0.14 end),least(0.89,a.y+0.04)
 from private.shared_pasture_visible_visits(u,p) v join anchors a on a.id=v.member_id
 union all select 'lantern-'||p::text,'lantern',p,0.32,0.60 from private.shared_pasture_projects where party_id=p and completed_at is not null
 ) select coalesce(jsonb_agg(jsonb_build_object('id',e.entity_id,'kind',e.kind,'referenceID',e.ref,
 'revision',coalesce(l.revision,0),'x',coalesce(l.x,e.x),'y',coalesce(l.y,case when e.x<0.28 then least(e.y,0.80) else e.y end)) order by e.entity_id),'[]')
 from entities e left join private.shared_pasture_layout l on l.party_id=p and l.entity_id=e.entity_id
$$;

-- Reward settlement is driven by existing grants, never by opening or playing.
create function private.shared_pasture_credit_grant() returns trigger
language plpgsql security definer set search_path='' as $$
declare l private.night_flock_v4_activity_ledger%rowtype; p private.night_flock_v4_parties%rowtype; policy private.shared_pasture_policy%rowtype; added int;
begin
 select * into l from private.night_flock_v4_activity_ledger where id=new.ledger_id;
 select * into p from private.night_flock_v4_parties where id=new.party_id and deleted_at is null for update;
 select * into policy from private.shared_pasture_policy;
 if p.id is null or l.outcome<>'completed' or l.ended_at<policy.starts_at or not exists(
 select 1 from private.night_flock_v4_membership_epochs e where e.party_id=p.id and e.user_id=new.user_id
 and e.ended_at is null and l.ended_at>=e.joined_at) then return new; end if;
 insert into private.shared_pasture_projects(party_id,required_contributions) values(p.id,policy.required_contributions) on conflict do nothing;
 insert into private.shared_pasture_contributions(party_id,user_id,party_day,grant_id)
 values(p.id,new.user_id,(l.ended_at at time zone p.time_zone_identifier)::date,new.id) on conflict do nothing;
 get diagnostics added=row_count;
 if added=1 then
 update private.shared_pasture_projects set contributions=contributions+1,
 completed_at=case when contributions+1>=required_contributions then coalesce(completed_at,now()) else completed_at end where party_id=p.id;
 perform private.night_flock_v4_signal_party(p.id);
 end if; return new;
end $$;
create trigger shared_pasture_grant after insert on private.night_flock_v4_grants
for each row execute function private.shared_pasture_credit_grant();

alter function private.night_flock_v4_apply(uuid,jsonb) rename to night_flock_v4_apply_before_pasture;
create function private.night_flock_v4_apply(u uuid,c jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p uuid:=(c->>'partyID')::uuid; cmd text:=c->>'command'; m private.night_flock_v4_memberships%rowtype;
 epoch uuid; animal jsonb; v private.shared_pasture_visits%rowtype; ent jsonb; current_layout private.shared_pasture_layout%rowtype;
 px double precision; py double precision; expected int; saved private.shared_pasture_command_receipts%rowtype; answer jsonb;
begin
 if cmd not in('movePastureEntity','contributePastureSheep','recallPastureSheep') then return private.night_flock_v4_apply_before_pasture(u,c); end if;
 if not private.is_apple_linked_night_flock_user(u) then raise exception 'linked_account_required'; end if;
 if c->>'sceneRevision' is distinct from '1' then raise exception 'unsupported_schema'; end if;
 -- Match the private save lock before party mutation; inspect canonical ownership.
 if cmd='contributePastureSheep' then perform 1 from private.farm_save_heads where user_id=u for update; end if;
 perform 1 from private.night_flock_v4_parties where id=p and deleted_at is null for update;
 if not found then raise exception 'invite_unavailable'; end if;
 select * into m from private.night_flock_v4_memberships where party_id=p and user_id=u and status='active';
 select id into epoch from private.night_flock_v4_membership_epochs where membership_id=m.id and ended_at is null;
 if epoch is null or epoch is distinct from (c->>'memberEpochID')::uuid then raise exception 'invite_unavailable'; end if;
 if exists(select 1 from private.night_flock_v4_memberships other where other.party_id=p and other.status='active'
 and private.night_flock_users_blocked(u,other.user_id)) then raise exception 'invite_unavailable'; end if;
 if c->>'idempotencyKey' is not null then
 select * into saved from private.shared_pasture_command_receipts where user_id=u and idempotency_key=c->>'idempotencyKey';
 if found then
 if saved.command<>c then raise exception 'Invalid idempotency reuse'; end if;
 return saved.response;
 end if;
 end if;
 if cmd='contributePastureSheep' then
 if c->>'consentVersion' is distinct from '1' then raise exception 'agreement_required'; end if;
 animal:=private.shared_pasture_owned_sheep(u,(c->>'sheepID')::uuid);
 if animal is null then raise exception 'pasture_sheep_not_owned'; end if;
 -- Public look is bounded by the existing catalogue allowlist, not caller text.
 if coalesce(animal->>'definitionID','') not in ('mabel','pippin','bramble','clementine','oat','midnight','juniper','hazel','ramsey','luna','marigold','wisp') or char_length(trim(animal->>'displayName')) not between 1 and 24
 or animal->>'displayName' ~ '[[:cntrl:]]' then raise exception 'Invalid sheep appearance'; end if;
 if exists(select 1 from private.shared_pasture_visits where owner_id=u and sheep_id=(c->>'sheepID')::uuid and recalled_at is null and party_id<>p)
 then raise exception 'pasture_sheep_already_visiting'; end if;
 update private.shared_pasture_visits set recalled_at=now() where member_id=m.id and recalled_at is null;
 insert into private.shared_pasture_visits(party_id,member_id,member_epoch_id,owner_id,sheep_id,definition_id,display_name,consent_version)
 values(p,m.id,epoch,u,(c->>'sheepID')::uuid,animal->>'definitionID',trim(animal->>'displayName'),1);
 elsif cmd='recallPastureSheep' then
 select * into v from private.shared_pasture_visits where id=(c->>'visitID')::uuid and party_id=p and owner_id=u and member_epoch_id=epoch for update;
 if v.id is null then raise exception 'invite_unavailable'; end if;
 update private.shared_pasture_visits set recalled_at=coalesce(recalled_at,now()) where id=v.id;
 else
 if (select count(*) from private.night_flock_v4_idempotency where user_id=u and command_name='movePastureEntity' and created_at>now()-interval '1 minute')>=40 then raise exception 'rate_limited'; end if;
 select item into ent from jsonb_array_elements(private.shared_pasture_entities(u,p)) item where item->>'id'=c->>'entityID';
 if ent is null then raise exception 'invite_unavailable'; end if;
 expected:=(c->>'expectedRevision')::int; px:=(c->>'x')::double precision; py:=(c->>'y')::double precision;
 if expected is null or expected<0 or px is null or py is null or not(px between 0.08 and 0.92 and py between 0.43 and 0.89) or (px<0.28 and py>0.80) then raise exception 'Invalid pasture anchor'; end if;
 if expected<>(ent->>'revision')::int then
 answer:=jsonb_build_object('accepted',true,'conflict',true);
 return answer; end if;
 select * into current_layout from private.shared_pasture_layout where party_id=p and entity_id=c->>'entityID' for update;
 insert into private.shared_pasture_layout(party_id,entity_id,revision,x,y,previous_positions)
 values(p,c->>'entityID',expected+1,px,py,jsonb_build_array(jsonb_build_object('x',ent->'x','y',ent->'y')))
 on conflict(party_id,entity_id) do update set revision=excluded.revision,x=excluded.x,y=excluded.y,updated_at=now(),
 previous_positions=(select jsonb_agg(value) from (select value from jsonb_array_elements(excluded.previous_positions||current_layout.previous_positions) with ordinality q(value,n) order by n limit 10) recent);
 end if;
 perform private.night_flock_v4_signal_party(p);
 answer:=jsonb_build_object('accepted',true,'conflict',false);
 if cmd='contributePastureSheep' and c->>'idempotencyKey' is not null then insert into private.shared_pasture_command_receipts values(u,c->>'idempotencyKey',c,answer) on conflict do nothing; end if;
 return answer;
end $$;

alter function public.night_flock_v4_state(uuid,text,uuid,text) rename to night_flock_v4_state_before_pasture;
create function public.night_flock_v4_state(p_user_id uuid,p_scope text default 'list',p_party_id uuid default null,p_cursor text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb; epoch uuid; visits jsonb; lantern jsonb;
begin
 result:=public.night_flock_v4_state_before_pasture(p_user_id,p_scope,p_party_id,p_cursor);
 if p_scope<>'party' or result->'party' is null then return result; end if;
 select e.id into epoch from private.night_flock_v4_membership_epochs e join private.night_flock_v4_memberships m on m.id=e.membership_id
 where e.party_id=p_party_id and e.user_id=p_user_id and e.ended_at is null and m.status='active';
 if epoch is null then return result; end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',v.id,'memberID',v.member_id,'sheepDefinitionID',v.definition_id,
 'sheepDisplayName',v.display_name,'sentAt',v.sent_at,'ownedSheepID',case when v.owner_id=p_user_id then v.sheep_id end)),'[]')
 into visits from private.shared_pasture_visible_visits(p_user_id,p_party_id) v;
 select jsonb_build_object('contributions',coalesce(pr.contributions,0),'requiredContributions',coalesce(pr.required_contributions,policy.required_contributions),
 'completedAt',pr.completed_at) into lantern from private.shared_pasture_policy policy left join private.shared_pasture_projects pr on pr.party_id=p_party_id;
 return jsonb_set(result,'{party,pasture}',jsonb_build_object('version',1,'sceneRevision',1,'memberEpochID',epoch,
 'entities',private.shared_pasture_entities(p_user_id,p_party_id),'visits',visits,'lantern',lantern));
end $$;
revoke all on function private.shared_pasture_owned_sheep(uuid,uuid),private.shared_pasture_prune(),private.shared_pasture_epoch_ended(),
 private.shared_pasture_visible_visits(uuid,uuid),private.shared_pasture_entities(uuid,uuid),private.shared_pasture_credit_grant(),
 private.night_flock_v4_apply_before_pasture(uuid,jsonb),private.night_flock_v4_apply(uuid,jsonb),public.night_flock_v4_state_before_pasture(uuid,text,uuid,text)
 from public,anon,authenticated,service_role;
revoke all on function public.night_flock_v4_state(uuid,text,uuid,text) from public,anon,authenticated;
grant execute on function public.night_flock_v4_state(uuid,text,uuid,text) to service_role;
