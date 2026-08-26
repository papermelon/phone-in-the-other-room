-- Additive schema-four contract. v1-v3 remain only for explicitly fenced legacy clients.
create table private.night_flock_v4_parties (id uuid primary key default gen_random_uuid(),host_user_id uuid not null references auth.users(id),name text not null check(char_length(name) between 1 and 48),normalized_name text not null,time_zone_identifier text not null check(char_length(time_zone_identifier) between 1 and 64),revision int not null default 1,deleted_at timestamptz,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table private.night_flock_v4_memberships (id uuid primary key default gen_random_uuid(),party_id uuid not null references private.night_flock_v4_parties(id),user_id uuid not null references auth.users(id),role text not null check(role in('host','member')),status text not null default 'active' check(status in('active','left','removed')),joined_at timestamptz not null default now(),left_at timestamptz,unique(party_id,user_id),check((status='active' and left_at is null) or (status<>'active' and left_at is not null)));
create unique index night_flock_v4_one_host on private.night_flock_v4_memberships(party_id) where role='host' and status='active';
create table private.night_flock_v4_rounds (id uuid primary key default gen_random_uuid(),party_id uuid not null references private.night_flock_v4_parties(id),round_number int not null check(round_number>0),time_zone_identifier text not null,starts_on date,ends_on date,status text not null default 'pending' check(status in('pending','active','completed','cancelled')),started_at timestamptz,completed_at timestamptz,created_at timestamptz not null default now(),unique(party_id,round_number),check(status<>'active' or(starts_on is not null and ends_on is not null and started_at is not null)),check(ends_on is null or ends_on=starts_on+6));
create unique index night_flock_v4_one_open_round on private.night_flock_v4_rounds(party_id) where status in('pending','active');
-- Plain invite text is never stored: the private envelope is decryptable only by Edge service code.
create table private.night_flock_v4_invites (id uuid primary key default gen_random_uuid(),party_id uuid not null references private.night_flock_v4_parties(id),lookup_digest bytea not null unique check(octet_length(lookup_digest)=32),ciphertext bytea not null,nonce bytea not null check(octet_length(nonce)=12),key_version smallint not null,created_by uuid not null references auth.users(id),created_at timestamptz not null default now(),expires_at timestamptz not null default now()+interval '100 years',revoked_at timestamptz);
create unique index night_flock_v4_one_active_invite on private.night_flock_v4_invites(party_id) where revoked_at is null;
create table private.night_flock_v4_profiles (user_id uuid primary key references auth.users(id),display_name text not null,normalized_display_name text not null,revision int not null default 0,skin_tone_id text not null check(skin_tone_id in('porcelain','warm','olive','brown','deep')),hair_style_id text not null check(hair_style_id in('cropped','waves','curls','coils','long')),shepherd_outfit_id text not null check(shepherd_outfit_id in('none','shepherd_moss_coat','shepherd_moon_coat','shepherd_field_overalls','shepherd_star_keeper_cloak')),shepherd_accessory_id text not null check(shepherd_accessory_id in('none','shepherd_wool_hat','shepherd_clover_headscarf','shepherd_moon_beanie')),ollie_ornament_id text not null check(ollie_ornament_id in('none','ollie_moss_bandana','ollie_moon_kerchief','ollie_brass_bell','ollie_clover_collar','ollie_sunrise_scarf','ollie_star_keeper_cape')),featured_sheep_definition_id text not null check(featured_sheep_definition_id in('none','mabel','pippin','bramble','clementine','oat','midnight','juniper','hazel','ramsey','luna','marigold','wisp')),pasture_theme_id text not null check(pasture_theme_id in('pasture_meadow','pasture_moonlit','pasture_sunrise')),created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table private.night_flock_v4_name_changes (id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id),changed_at timestamptz not null default now());
create table private.night_flock_v4_activity_ledger (id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id),source_event_id uuid not null,kind text not null check(kind in('windDown','phoneAway')),outcome text not null check(outcome in('completed','partlyCompleted')),started_at timestamptz not null,ended_at timestamptz not null,wind_down_minutes smallint not null check(wind_down_minutes between 0 and 180),phone_away_minutes smallint not null check(phone_away_minutes between 0 and 240),status_revision int not null check(status_revision>=0),received_at timestamptz not null default now(),unique(user_id,source_event_id,kind),check(ended_at>=started_at));
create table public.night_flock_v4_party_activities (id uuid primary key default gen_random_uuid(),party_id uuid not null references private.night_flock_v4_parties(id),round_id uuid not null references private.night_flock_v4_rounds(id),member_id uuid not null references private.night_flock_v4_memberships(id),ledger_id uuid not null references private.night_flock_v4_activity_ledger(id),kind text not null check(kind in('windDown','phoneAway')),outcome text not null check(outcome in('completed','partlyCompleted')),activity_day smallint not null check(activity_day between 1 and 7),wind_down_minutes smallint not null,phone_away_minutes smallint not null,revision int not null,observed_at timestamptz not null,unique(party_id,ledger_id));
create table public.night_flock_v4_statuses (party_id uuid not null references private.night_flock_v4_parties(id),round_id uuid not null references private.night_flock_v4_rounds(id),member_id uuid not null references private.night_flock_v4_memberships(id),revision int not null,observed_at timestamptz not null,expires_at timestamptz not null,status text not null check(status in('windDownStarting','phoneAwayActive','windDownCompleted','phoneAwayCompleted')),primary key(party_id,member_id),check(expires_at>observed_at));
create table public.night_flock_v4_reactions (id uuid primary key default gen_random_uuid(),party_activity_id uuid not null references public.night_flock_v4_party_activities(id),member_id uuid not null references private.night_flock_v4_memberships(id),reaction text not null check(reaction in('warmWave','moonGlow','pawPrint')),created_at timestamptz not null default now(),unique(party_activity_id,member_id,reaction));
create table private.night_flock_v4_live_reactions (
  id uuid primary key default gen_random_uuid(),
  party_id uuid not null references private.night_flock_v4_parties(id),
  round_id uuid not null references private.night_flock_v4_rounds(id),
  target_member_id uuid not null references private.night_flock_v4_memberships(id),
  reactor_member_id uuid not null references private.night_flock_v4_memberships(id),
  reaction text not null check(reaction in('warmWave','moonGlow','pawPrint')),
  activity_day smallint not null check(activity_day between 1 and 7),
  created_at timestamptz not null default now(),
  check(target_member_id<>reactor_member_id),
  unique(round_id,target_member_id,activity_day,reactor_member_id,reaction)
);
create table public.night_flock_v4_party_signals (
  party_id uuid primary key references private.night_flock_v4_parties(id),
  revision bigint not null check(revision>0),
  updated_at timestamptz not null
);
create table private.night_flock_v4_grants (id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id),party_id uuid,round_id uuid,ledger_id uuid not null references private.night_flock_v4_activity_ledger(id),reward_kind text not null default 'wool',wool_amount smallint not null default 1,acknowledged_at timestamptz,created_at timestamptz not null default now(),unique(user_id,party_id,ledger_id));
create table private.night_flock_v4_backfills (party_id uuid not null,round_id uuid not null,user_id uuid not null references auth.users(id),cursor text not null,completed_at timestamptz not null default now(),primary key(party_id,round_id,user_id));
create table private.night_flock_v4_audit (id bigint generated always as identity primary key,party_id uuid,actor_user_id uuid,action text not null,occurred_at timestamptz not null default now(),purge_after timestamptz not null default now()+interval '90 days');
create table private.night_flock_v4_idempotency (user_id uuid not null references auth.users(id),idempotency_key text not null check(idempotency_key~'^[0-9a-f]{64}$'),command_name text not null,payload_hash bytea not null,response jsonb not null,created_at timestamptz not null default now(),primary key(user_id,idempotency_key));

-- Account deletion must release every new Auth and party-graph reference. Reward rows
-- intentionally keep party_id/round_id as plain UUIDs, so another member's earned
-- grant survives when its host account and hosted party are removed.
do $$
declare foreign_key record;
begin
  for foreign_key in
    select
      constraint_row.conrelid::regclass as relation_name,
      constraint_row.conname as constraint_name,
      pg_get_constraintdef(constraint_row.oid) as definition
    from pg_constraint constraint_row
    join pg_class relation on relation.oid=constraint_row.conrelid
    join pg_class referenced on referenced.oid=constraint_row.confrelid
    where constraint_row.contype='f'
      and relation.relname like 'night_flock_v4_%'
      and (
        constraint_row.confrelid='auth.users'::regclass
        or referenced.relname like 'night_flock_v4_%'
      )
  loop
    execute format(
      'alter table %s drop constraint %I, add constraint %I %s on delete cascade',
      foreign_key.relation_name,
      foreign_key.constraint_name,
      foreign_key.constraint_name,
      foreign_key.definition
    );
  end loop;
end
$$;

create or replace function private.night_flock_v4_member(u uuid,p uuid) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from private.night_flock_v4_memberships where user_id=u and party_id=p and status='active')$$;
create or replace function private.night_flock_v4_status_member(
  u uuid,target_party_id uuid,target_member_id uuid
)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select exists (
    select 1
    from private.night_flock_v4_memberships reader
    join private.night_flock_v4_memberships target
      on target.party_id=reader.party_id
    where reader.party_id=target_party_id
      and reader.user_id=u
      and reader.status='active'
      and target.id=target_member_id
      and target.status='active'
      and not private.night_flock_users_blocked(reader.user_id,target.user_id)
  )
$$;
revoke all on function private.night_flock_v4_status_member(uuid,uuid,uuid)
from public,anon;
grant execute on function private.night_flock_v4_status_member(uuid,uuid,uuid)
to authenticated;

create or replace function private.night_flock_v4_reaction_member(
  u uuid,activity_id uuid,reactor_member_id uuid
)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select exists (
    select 1
    from public.night_flock_v4_party_activities activity
    join private.night_flock_v4_memberships reader
      on reader.party_id=activity.party_id
    join private.night_flock_v4_memberships activity_owner
      on activity_owner.id=activity.member_id
      and activity_owner.party_id=activity.party_id
    join private.night_flock_v4_memberships reactor
      on reactor.id=reactor_member_id
      and reactor.party_id=activity.party_id
    where activity.id = activity_id
      and reader.user_id=u
      and reader.status='active'
      and activity_owner.status='active'
      and reactor.status='active'
      and not private.night_flock_users_blocked(reader.user_id,activity_owner.user_id)
      and not private.night_flock_users_blocked(reader.user_id,reactor.user_id)
      and not private.night_flock_users_blocked(activity_owner.user_id,reactor.user_id)
  )
$$;
revoke all on function private.night_flock_v4_reaction_member(uuid,uuid,uuid)
from public,anon;
grant execute on function private.night_flock_v4_reaction_member(uuid,uuid,uuid)
to authenticated;
create or replace function private.night_flock_v4_signal_party(target_party_id uuid)
returns void
language sql
security definer
set search_path=''
as $$
  insert into public.night_flock_v4_party_signals(party_id,revision,updated_at)
  select target_party_id,1,clock_timestamp()
  where exists(
    select 1 from private.night_flock_v4_parties
    where id=target_party_id
  )
  on conflict(party_id) do update set
    revision=public.night_flock_v4_party_signals.revision+1,
    updated_at=clock_timestamp()
$$;
revoke all on function private.night_flock_v4_signal_party(uuid)
from public,anon,authenticated;

create or replace function private.night_flock_v4_signal_change()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare target_party_id uuid;
begin
  if tg_table_name='night_flock_v4_profiles' then
    for target_party_id in
      select membership.party_id
      from private.night_flock_v4_memberships membership
      where membership.user_id=coalesce(new.user_id,old.user_id)
        and membership.status='active'
    loop
      perform private.night_flock_v4_signal_party(target_party_id);
    end loop;
  elsif tg_table_name='night_flock_v4_parties' then
    perform private.night_flock_v4_signal_party(coalesce(new.id,old.id));
  else
    perform private.night_flock_v4_signal_party(coalesce(new.party_id,old.party_id));
  end if;
  return null;
end
$$;
revoke all on function private.night_flock_v4_signal_change()
from public,anon,authenticated;

create trigger night_flock_v4_parties_signal
after insert or update on private.night_flock_v4_parties
for each row execute function private.night_flock_v4_signal_change();
create trigger night_flock_v4_memberships_signal
after insert or update or delete on private.night_flock_v4_memberships
for each row execute function private.night_flock_v4_signal_change();
create trigger night_flock_v4_rounds_signal
after insert or update or delete on private.night_flock_v4_rounds
for each row execute function private.night_flock_v4_signal_change();
create trigger night_flock_v4_invites_signal
after insert or update or delete on private.night_flock_v4_invites
for each row execute function private.night_flock_v4_signal_change();
create trigger night_flock_v4_profiles_signal
after insert or update or delete on private.night_flock_v4_profiles
for each row execute function private.night_flock_v4_signal_change();
create trigger night_flock_v4_activities_signal
after insert or update or delete on public.night_flock_v4_party_activities
for each row execute function private.night_flock_v4_signal_change();
create trigger night_flock_v4_live_reactions_signal
after insert or update or delete on private.night_flock_v4_live_reactions
for each row execute function private.night_flock_v4_signal_change();

create or replace function private.night_flock_v4_user_cap() returns trigger language plpgsql security definer set search_path='' as $$declare n int;begin if new.status<>'active' then return new;end if;perform pg_advisory_xact_lock(hashtextextended(new.user_id::text,0));select count(*) into n from private.night_flock_v4_memberships where user_id=new.user_id and status='active' and id<>new.id;if n>=5 then raise exception 'max_parties';end if;return new;end$$;
create or replace function private.night_flock_v4_party_cap() returns trigger language plpgsql security definer set search_path='' as $$declare n int;begin if new.status<>'active' then return new;end if;perform pg_advisory_xact_lock(hashtextextended(new.party_id::text,0));select count(*) into n from private.night_flock_v4_memberships where party_id=new.party_id and status='active' and id<>new.id;if n>=8 then raise exception 'flock_full';end if;return new;end$$;
create trigger a_night_flock_v4_user_cap before insert or update of status,user_id on private.night_flock_v4_memberships for each row execute function private.night_flock_v4_user_cap();
create trigger b_night_flock_v4_party_cap before insert or update of status,party_id on private.night_flock_v4_memberships for each row execute function private.night_flock_v4_party_cap();

alter table public.night_flock_v4_party_activities enable row level security; alter table public.night_flock_v4_statuses enable row level security; alter table public.night_flock_v4_reactions enable row level security; alter table public.night_flock_v4_party_signals enable row level security;
revoke all on public.night_flock_v4_party_activities,public.night_flock_v4_statuses,public.night_flock_v4_reactions,public.night_flock_v4_party_signals from public,anon,authenticated;
create policy night_flock_v4_status_read on public.night_flock_v4_statuses for select using(private.night_flock_v4_status_member(auth.uid(),party_id,member_id));
create policy night_flock_v4_reaction_read on public.night_flock_v4_reactions for select using(private.night_flock_v4_reaction_member(auth.uid(),party_activity_id,member_id));
create policy night_flock_v4_signal_read on public.night_flock_v4_party_signals for select using(private.night_flock_v4_member(auth.uid(),party_id));
grant select on public.night_flock_v4_statuses,public.night_flock_v4_reactions,public.night_flock_v4_party_signals to authenticated;
do $$begin alter publication supabase_realtime add table public.night_flock_v4_statuses,public.night_flock_v4_reactions,public.night_flock_v4_party_signals;exception when duplicate_object then null;end$$;

create or replace function private.night_flock_v4_legacy_fence(u uuid) returns void language plpgsql security definer set search_path='' as $$begin if exists(select 1 from private.night_flock_v4_memberships where user_id=u and status='active') then raise exception 'client_upgrade_required';end if;end$$;
alter function public.night_flock_state(uuid) rename to night_flock_state_v3_legacy; create function public.night_flock_state(u uuid) returns jsonb language plpgsql security definer set search_path='' as $$begin perform private.night_flock_v4_legacy_fence(u);return public.night_flock_state_v3_legacy(u);end$$;
alter function public.night_flock_commitment_state(uuid) rename to night_flock_commitment_state_v3_legacy; create function public.night_flock_commitment_state(u uuid) returns jsonb language plpgsql security definer set search_path='' as $$begin perform private.night_flock_v4_legacy_fence(u);return public.night_flock_commitment_state_v3_legacy(u);end$$;
alter function public.night_flock_social_state(uuid) rename to night_flock_social_state_v3_legacy; create function public.night_flock_social_state(u uuid) returns jsonb language plpgsql security definer set search_path='' as $$begin perform private.night_flock_v4_legacy_fence(u);return public.night_flock_social_state_v3_legacy(u);end$$;
alter function public.night_flock_command(uuid,jsonb) rename to night_flock_command_v3_legacy; create function public.night_flock_command(u uuid,c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$begin perform private.night_flock_v4_legacy_fence(u);return public.night_flock_command_v3_legacy(u,c);end$$;
alter function public.night_flock_commitment_command(uuid,jsonb) rename to night_flock_commitment_command_v3_legacy; create function public.night_flock_commitment_command(u uuid,c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$begin perform private.night_flock_v4_legacy_fence(u);return public.night_flock_commitment_command_v3_legacy(u,c);end$$;
alter function public.night_flock_social_command(uuid,jsonb) rename to night_flock_social_command_v3_legacy; create function public.night_flock_social_command(u uuid,c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$begin perform private.night_flock_v4_legacy_fence(u);return public.night_flock_social_command_v3_legacy(u,c);end$$;

create or replace function private.night_flock_v4_profile_json(pr private.night_flock_v4_profiles) returns jsonb language sql stable security definer set search_path='' as $$select jsonb_build_object('displayName',pr.display_name,'revision',pr.revision,'hasEstablishedDisplayName',true,'presentation',jsonb_build_object('skinToneID',pr.skin_tone_id,'hairStyleID',pr.hair_style_id,'shepherdOutfitID',pr.shepherd_outfit_id,'shepherdAccessoryID',pr.shepherd_accessory_id,'ollieOrnamentID',pr.ollie_ornament_id,'featuredSheepDefinitionID',pr.featured_sheep_definition_id,'pastureThemeID',pr.pasture_theme_id))$$;
create or replace function private.night_flock_v4_summary(pid uuid,u uuid) returns jsonb language sql stable security definer set search_path='' as $$select jsonb_build_object('partyID',p.id,'name',p.name,'memberCount',(select count(*) from private.night_flock_v4_memberships x where x.party_id=p.id and x.status='active'),'myRole',m.role,'revision',p.revision,'currentRound',(select jsonb_build_object('roundID',r.id,'number',r.round_number,'timeZoneIdentifier',r.time_zone_identifier,'startsOn',coalesce(r.starts_on,current_date),'status',r.status) from private.night_flock_v4_rounds r where r.party_id=p.id and r.status in('active','pending') order by case r.status when 'active' then 0 else 1 end limit 1)) from private.night_flock_v4_parties p join private.night_flock_v4_memberships m on m.party_id=p.id and m.user_id=u and m.status='active' where p.id=pid and p.deleted_at is null$$;

create or replace function private.night_flock_v4_apply(u uuid,c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare cmd text:=c->>'command';p private.night_flock_v4_parties%rowtype;m private.night_flock_v4_memberships%rowtype;target private.night_flock_v4_memberships%rowtype;r private.night_flock_v4_rounds%rowtype;i private.night_flock_v4_invites%rowtype;pr private.night_flock_v4_profiles%rowtype;l private.night_flock_v4_activity_ledger%rowtype;a public.night_flock_v4_party_activities%rowtype;shared_party record;n int;name text;obs timestamptz;out jsonb:=jsonb_build_object('accepted',true);begin
if u is null or not private.is_apple_linked_night_flock_user(u) then raise exception 'Apple-linked account required';end if;
if cmd='createParty' then name:=btrim(c->>'name');if char_length(name) not between 1 and 48 then raise exception 'Invalid party name';end if;insert into private.night_flock_v4_parties(host_user_id,name,normalized_name,time_zone_identifier) values(u,name,lower(name),c->>'timeZoneIdentifier') returning * into p;insert into private.night_flock_v4_memberships(party_id,user_id,role) values(p.id,u,'host');insert into private.night_flock_v4_rounds(party_id,round_number,time_zone_identifier) values(p.id,1,p.time_zone_identifier);return out;end if;
if cmd in('previewInvite','redeemInvite') then select * into i from private.night_flock_v4_invites where lookup_digest=extensions.digest(c->>'inviteCode','sha256') and revoked_at is null and expires_at>now() for update;if i.id is null then raise exception 'invite_unavailable';end if;select * into p from private.night_flock_v4_parties where id=i.party_id and deleted_at is null for update;if p.id is null then raise exception 'invite_unavailable';end if;select count(*) into n from private.night_flock_v4_memberships where party_id=p.id and status='active';if cmd='previewInvite' then return out||jsonb_build_object('invitePreview',jsonb_build_object('partyID',p.id,'name',p.name,'memberCount',n,'capacity',8));end if;select * into m from private.night_flock_v4_memberships where party_id=p.id and user_id=u for update;if m.id is not null and m.status='active' then return out;end if;if exists(select 1 from private.night_flock_v4_memberships x where x.party_id=p.id and x.status='active' and private.night_flock_users_blocked(u,x.user_id)) then raise exception 'blocked_membership';end if;insert into private.night_flock_v4_memberships(party_id,user_id,role,status,joined_at,left_at) values(p.id,u,'member','active',now(),null) on conflict(party_id,user_id) do update set status='active',joined_at=excluded.joined_at,left_at=null;update private.night_flock_v4_parties set revision=revision+1,updated_at=now() where id=p.id;return out;end if;
if cmd='updatePublicProfile' then select * into pr from private.night_flock_v4_profiles where user_id=u for update;name:=btrim(c->>'displayName');if char_length(name) not between 2 and 24 or name~'[[:cntrl:]]' then raise exception 'Invalid displayName';end if;if pr.user_id is not null and pr.revision<>(c->>'expectedRevision')::int then raise exception 'stale_revision';end if;if pr.user_id is null then if c->>'nameSelectionKind' not in('initial','migration') then raise exception 'Invalid nameSelectionKind';end if;insert into private.night_flock_v4_profiles(user_id,display_name,normalized_display_name,revision,skin_tone_id,hair_style_id,shepherd_outfit_id,shepherd_accessory_id,ollie_ornament_id,featured_sheep_definition_id,pasture_theme_id) values(u,name,lower(name),1,c->>'skinToneID',c->>'hairStyleID',c->>'shepherdOutfitID',c->>'shepherdAccessoryID',c->>'ollieOrnamentID',c->>'featuredSheepDefinitionID',c->>'pastureThemeID') returning * into pr;elsif pr.display_name=name and pr.skin_tone_id=c->>'skinToneID' and pr.hair_style_id=c->>'hairStyleID' and pr.shepherd_outfit_id=c->>'shepherdOutfitID' and pr.shepherd_accessory_id=c->>'shepherdAccessoryID' and pr.ollie_ornament_id=c->>'ollieOrnamentID' and pr.featured_sheep_definition_id=c->>'featuredSheepDefinitionID' and pr.pasture_theme_id=c->>'pastureThemeID' then null;else if pr.display_name<>name then if c->>'nameSelectionKind'<>'change' then raise exception 'Invalid nameSelectionKind';end if;select count(*) into n from private.night_flock_v4_name_changes where user_id=u and changed_at>now()-interval '14 days';if n>=2 then raise exception 'name_change_limit';end if;insert into private.night_flock_v4_name_changes(user_id) values(u);end if;update private.night_flock_v4_profiles set display_name=name,normalized_display_name=lower(name),revision=revision+1,skin_tone_id=c->>'skinToneID',hair_style_id=c->>'hairStyleID',shepherd_outfit_id=c->>'shepherdOutfitID',shepherd_accessory_id=c->>'shepherdAccessoryID',ollie_ornament_id=c->>'ollieOrnamentID',featured_sheep_definition_id=c->>'featuredSheepDefinitionID',pasture_theme_id=c->>'pastureThemeID',updated_at=now() where user_id=u returning * into pr;end if;return out||jsonb_build_object('profile',private.night_flock_v4_profile_json(pr));end if;
if cmd='publishActivity' then
  insert into private.night_flock_v4_activity_ledger(
    user_id,source_event_id,kind,outcome,started_at,ended_at,
    wind_down_minutes,phone_away_minutes,status_revision
  ) values (
    u,(c->>'sourceEventID')::uuid,c->>'kind',coalesce(c->>'outcome','completed'),
    (c->>'startedAt')::timestamptz,(c->>'endedAt')::timestamptz,
    (c->>'windDownMinutes')::smallint,(c->>'phoneAwayMinutes')::smallint,
    (c->>'statusRevision')::int
  ) on conflict(user_id,source_event_id,kind) do update set
    outcome=excluded.outcome,
    started_at=excluded.started_at,
    ended_at=excluded.ended_at,
    wind_down_minutes=excluded.wind_down_minutes,
    phone_away_minutes=excluded.phone_away_minutes,
    status_revision=excluded.status_revision
  where excluded.status_revision>private.night_flock_v4_activity_ledger.status_revision
     or (
       excluded.status_revision=private.night_flock_v4_activity_ledger.status_revision
       and excluded.ended_at>=private.night_flock_v4_activity_ledger.ended_at
     );

  select * into l
  from private.night_flock_v4_activity_ledger
  where user_id=u
    and source_event_id=(c->>'sourceEventID')::uuid
    and kind=c->>'kind';

  for m in
    select * from private.night_flock_v4_memberships
    where user_id=u and status='active'
  loop
    select * into r
    from private.night_flock_v4_rounds
    where party_id=m.party_id
      and status='active'
      and l.ended_at>=(starts_on::timestamp at time zone time_zone_identifier)
      and l.ended_at<((ends_on+1)::timestamp at time zone time_zone_identifier);

    if r.id is not null then
      insert into public.night_flock_v4_party_activities(
        party_id,round_id,member_id,ledger_id,kind,outcome,activity_day,
        wind_down_minutes,phone_away_minutes,revision,observed_at
      ) values (
        m.party_id,r.id,m.id,l.id,l.kind,l.outcome,
        ((l.ended_at at time zone r.time_zone_identifier)::date-r.starts_on+1),
        l.wind_down_minutes,l.phone_away_minutes,l.status_revision,l.ended_at
      ) on conflict(party_id,ledger_id) do update set
        outcome=excluded.outcome,
        wind_down_minutes=excluded.wind_down_minutes,
        phone_away_minutes=excluded.phone_away_minutes,
        revision=excluded.revision,
        observed_at=excluded.observed_at
      where excluded.revision>public.night_flock_v4_party_activities.revision
         or (
           excluded.revision=public.night_flock_v4_party_activities.revision
           and excluded.observed_at>=public.night_flock_v4_party_activities.observed_at
         );

      if l.outcome='completed' then
        insert into private.night_flock_v4_grants(user_id,party_id,round_id,ledger_id)
        values(u,m.party_id,r.id,l.id)
        on conflict do nothing;

        insert into public.night_flock_v4_statuses(
          party_id,round_id,member_id,revision,observed_at,expires_at,status
        ) values (
          m.party_id,r.id,m.id,l.status_revision,l.ended_at,
          l.ended_at+interval '12 hours',
          case when l.kind='windDown' then 'windDownCompleted' else 'phoneAwayCompleted' end
        ) on conflict(party_id,member_id) do update set
          round_id=excluded.round_id,
          revision=excluded.revision,
          observed_at=excluded.observed_at,
          expires_at=excluded.expires_at,
          status=excluded.status
        where excluded.observed_at>public.night_flock_v4_statuses.observed_at
           or (
             excluded.observed_at=public.night_flock_v4_statuses.observed_at
             and excluded.revision>=public.night_flock_v4_statuses.revision
           );
      end if;
    end if;
  end loop;
  return out;
end if;
if cmd='publishStatus' then
  obs:=(c->>'observedAt')::timestamptz;
  for m in
    select * from private.night_flock_v4_memberships
    where user_id=u and status='active'
  loop
    select * into r
    from private.night_flock_v4_rounds
    where party_id=m.party_id
      and status='active'
      and obs>=(starts_on::timestamp at time zone time_zone_identifier)
      and obs<((ends_on+1)::timestamp at time zone time_zone_identifier);

    if r.id is not null then
      insert into public.night_flock_v4_statuses(
        party_id,round_id,member_id,revision,observed_at,expires_at,status
      ) values (
        m.party_id,r.id,m.id,(c->>'revision')::int,obs,
        obs+case
          when c->>'status' in('windDownCompleted','phoneAwayCompleted')
          then interval '12 hours'
          else interval '30 minutes'
        end,
        c->>'status'
      ) on conflict(party_id,member_id) do update set
        round_id=excluded.round_id,
        revision=excluded.revision,
        observed_at=excluded.observed_at,
        expires_at=excluded.expires_at,
        status=excluded.status
      where excluded.observed_at>public.night_flock_v4_statuses.observed_at
         or (
           excluded.observed_at=public.night_flock_v4_statuses.observed_at
           and excluded.revision>=public.night_flock_v4_statuses.revision
         );
    end if;
  end loop;
  return out;
end if;
if cmd='acknowledgeGrant' then
  update private.night_flock_v4_grants
  set acknowledged_at=coalesce(acknowledged_at,now())
  where id=(c->>'grantID')::uuid
    and user_id=u;
  if not found then
    raise exception 'invite_unavailable';
  end if;
  return out;
end if;
if cmd='deleteAccount' then
  for p in
    select * from private.night_flock_v4_parties
    where host_user_id=u and deleted_at is null
    for update
  loop
    update private.night_flock_v4_parties
    set deleted_at=now(),revision=revision+1,updated_at=now()
    where id=p.id;
    update private.night_flock_v4_invites
    set revoked_at=coalesce(revoked_at,now())
    where party_id=p.id;
    update private.night_flock_v4_rounds
    set status='cancelled',completed_at=coalesce(completed_at,now())
    where party_id=p.id and status in('pending','active');
    update private.night_flock_v4_memberships
    set status='removed',left_at=now()
    where party_id=p.id and status='active';
    insert into private.night_flock_v4_audit(party_id,actor_user_id,action)
    values(p.id,u,'accountDeleted');
  end loop;

  for m in
    select * from private.night_flock_v4_memberships
    where user_id=u and status='active'
    for update
  loop
    update private.night_flock_v4_memberships
    set status='left',left_at=now()
    where id=m.id;
    update private.night_flock_v4_parties
    set revision=revision+1,updated_at=now()
    where id=m.party_id;
  end loop;
  return out||jsonb_build_object('deleteAccount',true);
end if;
select * into p from private.night_flock_v4_parties where id=(c->>'partyID')::uuid and deleted_at is null for update;if p.id is null then raise exception 'current_membership_required';end if;select * into m from private.night_flock_v4_memberships where party_id=p.id and user_id=u and status='active' for update;if m.id is null then raise exception 'current_membership_required';end if;
if cmd='renameParty' then if m.role<>'host' then raise exception 'host_permission_required';end if;update private.night_flock_v4_parties set name=btrim(c->>'name'),normalized_name=lower(btrim(c->>'name')),revision=revision+1,updated_at=now() where id=p.id;
elsif cmd='startRound' then if m.role<>'host' then raise exception 'host_permission_required';end if;update private.night_flock_v4_rounds set status='completed',completed_at=now() where party_id=p.id and status='active' and ends_on<(now() at time zone time_zone_identifier)::date;if exists(select 1 from private.night_flock_v4_rounds where party_id=p.id and status='active') then raise exception 'lobby_started';end if;select count(*) into n from private.night_flock_v4_memberships where party_id=p.id and status='active';if n<2 then raise exception 'invite_member_constraint';end if;select * into r from private.night_flock_v4_rounds where party_id=p.id and status='pending' for update;if r.id is null then insert into private.night_flock_v4_rounds(party_id,round_number,time_zone_identifier) values(p.id,(select coalesce(max(round_number),0)+1 from private.night_flock_v4_rounds where party_id=p.id),c->>'timeZoneIdentifier') returning * into r;end if;update private.night_flock_v4_rounds set status='active',time_zone_identifier=c->>'timeZoneIdentifier',starts_on=(now() at time zone(c->>'timeZoneIdentifier'))::date,ends_on=(now() at time zone(c->>'timeZoneIdentifier'))::date+6,started_at=now() where id=r.id;update private.night_flock_v4_parties set time_zone_identifier=c->>'timeZoneIdentifier',revision=revision+1,updated_at=now() where id=p.id;
elsif cmd in('createInvite','replaceInvite') then if m.role<>'host' then raise exception 'host_permission_required';end if;if cmd='replaceInvite' then update private.night_flock_v4_invites set revoked_at=now() where id=(c->>'expectedInviteID')::uuid and party_id=p.id and revoked_at is null;if not found then raise exception 'stale_revision';end if;elsif exists(select 1 from private.night_flock_v4_invites where party_id=p.id and revoked_at is null and expires_at>now()) then raise exception 'active_invite_exists';end if;insert into private.night_flock_v4_invites(party_id,lookup_digest,ciphertext,nonce,key_version,created_by) values(p.id,decode(c->>'inviteDigest','hex'),decode(c->>'inviteCiphertext','base64'),decode(c->>'inviteNonce','base64'),(c->>'inviteKeyVersion')::smallint,u) returning * into i;return out||jsonb_build_object('inviteID',i.id,'inviteEnvelope',jsonb_build_object('inviteCiphertext',encode(i.ciphertext,'base64'),'inviteNonce',encode(i.nonce,'base64'),'inviteKeyVersion',i.key_version));
elsif cmd='retrieveInvite' then select * into i from private.night_flock_v4_invites where party_id=p.id and revoked_at is null and expires_at>now();if i.id is null then raise exception 'invite_unavailable';end if;return out||jsonb_build_object('inviteID',i.id,'inviteEnvelope',jsonb_build_object('inviteCiphertext',encode(i.ciphertext,'base64'),'inviteNonce',encode(i.nonce,'base64'),'inviteKeyVersion',i.key_version));
elsif cmd='revokeInvite' then if m.role<>'host' then raise exception 'host_permission_required';end if;update private.night_flock_v4_invites set revoked_at=coalesce(revoked_at,now()) where id=(c->>'inviteID')::uuid and party_id=p.id;if not found then raise exception 'invite_unavailable';end if;
elsif cmd='leaveParty' then if m.role='host' then raise exception 'host_cannot_leave';end if;update private.night_flock_v4_memberships set status='left',left_at=now() where id=m.id;update private.night_flock_v4_parties set revision=revision+1 where id=p.id;
elsif cmd='deleteParty' then if m.role<>'host' then raise exception 'host_permission_required';end if;update private.night_flock_v4_parties set deleted_at=now(),revision=revision+1 where id=p.id;update private.night_flock_v4_invites set revoked_at=coalesce(revoked_at,now()) where party_id=p.id;update private.night_flock_v4_rounds set status='cancelled',completed_at=coalesce(completed_at,now()) where party_id=p.id and status in('pending','active');update private.night_flock_v4_memberships set status='removed',left_at=now() where party_id=p.id and status='active';insert into private.night_flock_v4_audit(party_id,actor_user_id,action) values(p.id,u,'deleted');
elsif cmd='completeBackfill' then select * into r from private.night_flock_v4_rounds where id=(c->>'roundID')::uuid and party_id=p.id and status in('active','completed');if r.id is null then raise exception 'invite_unavailable';end if;insert into private.night_flock_v4_backfills(party_id,round_id,user_id,cursor) values(p.id,r.id,u,c->>'cursor') on conflict(party_id,round_id,user_id) do update set cursor=excluded.cursor,completed_at=now();
elsif cmd='react' then
  select activity.* into a
  from public.night_flock_v4_party_activities activity
  join private.night_flock_v4_memberships activity_member
    on activity_member.id=activity.member_id
  where activity.id=(c->>'activityID')::uuid
    and activity.party_id=p.id
    and activity_member.status='active'
    and not private.night_flock_users_blocked(u,activity_member.user_id);
  if a.id is null then
    raise exception 'invite_unavailable';
  end if;
  insert into public.night_flock_v4_reactions(party_activity_id,member_id,reaction)
  values(a.id,m.id,c->>'cheer')
  on conflict do nothing;
elsif cmd='cheerMember' then
  select * into target
  from private.night_flock_v4_memberships
  where id=(c->>'memberID')::uuid
    and party_id=p.id
    and status='active';
  if target.id is null or target.user_id=u then
    raise exception 'Invalid cheer target';
  end if;
  select * into r
  from private.night_flock_v4_rounds
  where party_id=p.id and status='active';
  if r.id is null or not exists(
    select 1 from public.night_flock_v4_statuses status_row
    where status_row.party_id=p.id
      and status_row.round_id=r.id
      and status_row.member_id=target.id
      and status_row.expires_at>now()
      and status_row.status in('windDownStarting','phoneAwayActive')
  ) then
    raise exception 'Invalid cheer target';
  end if;
  insert into private.night_flock_v4_live_reactions(
    party_id,round_id,target_member_id,reactor_member_id,reaction,activity_day
  ) values (
    p.id,r.id,target.id,m.id,c->>'cheer',
    ((now() at time zone r.time_zone_identifier)::date-r.starts_on+1)
  ) on conflict(round_id,target_member_id,activity_day,reactor_member_id,reaction)
  do nothing;
elsif cmd='reportMember' then
  select * into target
  from private.night_flock_v4_memberships
  where id=(c->>'memberID')::uuid and party_id=p.id and status='active';
  if target.id is null or target.user_id=u then
    raise exception 'Invalid report target';
  end if;
  if c->>'reason' not in(
    'unwantedContact','harmfulConduct','impersonation','otherSafetyConcern'
  ) then
    raise exception 'Invalid report reason';
  end if;
  insert into public.night_flock_reports(
    reporter_user_id,reported_user_id,flock_id,reason,idempotency_key
  ) values (
    u,target.user_id,null,c->>'reason',
    coalesce(
      c->>'idempotencyKey',
      encode(extensions.digest(u::text||target.user_id::text||(c->>'reason'),'sha256'),'hex')
    )
  ) on conflict(idempotency_key) do nothing;
elsif cmd='blockMember' then
  select * into target
  from private.night_flock_v4_memberships
  where id=(c->>'memberID')::uuid and party_id=p.id and status='active';
  if target.id is null or target.user_id=u then
    raise exception 'Invalid block target';
  end if;
  insert into public.night_flock_blocks(blocker_user_id,blocked_user_id)
  values(u,target.user_id)
  on conflict do nothing;

  for shared_party in
    select mine.id as my_member_id,mine.role as my_role,
           theirs.id as target_member_id,mine.party_id
    from private.night_flock_v4_memberships mine
    join private.night_flock_v4_memberships theirs
      on theirs.party_id=mine.party_id
    where mine.user_id=u
      and theirs.user_id=target.user_id
      and mine.status='active'
      and theirs.status='active'
    for update of mine,theirs
  loop
    if shared_party.my_role='host' then
      update private.night_flock_v4_memberships
      set status='removed',left_at=now()
      where id=shared_party.target_member_id;
    else
      update private.night_flock_v4_memberships
      set status='left',left_at=now()
      where id=shared_party.my_member_id;
    end if;
    update private.night_flock_v4_parties
    set revision=revision+1,updated_at=now()
    where id=shared_party.party_id;
  end loop;
else raise exception 'Unsupported schema-four command';end if;return out;end$$;

create or replace function public.night_flock_v4_command(p_user_id uuid,p_command jsonb) returns jsonb language plpgsql security definer set search_path='' as $$declare u alias for $1;c alias for $2;k text:=lower(c->>'idempotencyKey');h bytea:=extensions.digest((c-'inviteDigest'-'inviteCiphertext'-'inviteNonce'-'inviteKeyVersion')::text,'sha256');saved private.night_flock_v4_idempotency%rowtype;out jsonb;begin
-- Edge validation requires the key. This branch is retained solely for the direct
-- service-role SQL harness; it is not reachable from the public HTTP contract.
if k is null then return private.night_flock_v4_apply(u,c);end if;
if k!~'^[0-9a-f]{64}$' then raise exception 'Invalid idempotencyKey';end if;perform pg_advisory_xact_lock(hashtextextended(u::text,0));select * into saved from private.night_flock_v4_idempotency where user_id=u and idempotency_key=k;if saved.user_id is not null then if saved.payload_hash<>h then raise exception 'idempotency_key_reused';end if;return saved.response;end if;out:=private.night_flock_v4_apply(u,c);insert into private.night_flock_v4_idempotency(user_id,idempotency_key,command_name,payload_hash,response) values(u,k,c->>'command',h,out);return out;end$$;

create or replace function public.night_flock_v4_state(
  u uuid,scope text default 'list',pid uuid default null,cursor text default null
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  summaries jsonb;
  pr private.night_flock_v4_profiles%rowtype;
  grants jsonb;
  my_member uuid;
  inv jsonb;
begin
  if u is null or not private.is_apple_linked_night_flock_user(u) then
    raise exception 'Apple-linked account required';
  end if;
  if scope not in('list','party') then
    raise exception 'Invalid scope';
  end if;
  if scope='party' and(pid is null or not private.night_flock_v4_member(u,pid)) then
    raise exception 'current_membership_required';
  end if;

  select coalesce(
    jsonb_agg(private.night_flock_v4_summary(p.id,u) order by p.updated_at desc),
    '[]'::jsonb
  ) into summaries
  from private.night_flock_v4_parties p
  join private.night_flock_v4_memberships m
    on m.party_id=p.id and m.user_id=u and m.status='active'
  where p.deleted_at is null and(scope='list' or p.id=pid);

  select * into pr from private.night_flock_v4_profiles where user_id=u;
  select coalesce(
    jsonb_agg(jsonb_build_object(
      'grantID',id,'partyID',party_id,'roundID',round_id,'kind',reward_kind,
      'woolAmount',wool_amount,'issuedAt',created_at,'acknowledgedAt',acknowledged_at
    )),
    '[]'::jsonb
  ) into grants
  from private.night_flock_v4_grants where user_id=u;

  if scope='list' then
    return jsonb_build_object(
      'parties',summaries,
      'profile',case
        when pr.user_id is null then null
        else private.night_flock_v4_profile_json(pr)
      end,
      'grantInbox',grants
    );
  end if;

  select id into my_member
  from private.night_flock_v4_memberships
  where party_id=pid and user_id=u and status='active';

  select jsonb_build_object(
    'inviteID',id,'partyID',party_id,'createdAt',created_at,
    'expiresAt',expires_at,'status','active'
  ) into inv
  from private.night_flock_v4_invites
  where party_id=pid and revoked_at is null and expires_at>now();

  return jsonb_build_object('party',jsonb_build_object(
    'summary',summaries->0,
    'myMemberID',my_member,
    'memberships',coalesce((
      select jsonb_agg(jsonb_build_object(
        'memberID',m.id,
        'profile',coalesce(
          private.night_flock_v4_profile_json(px),
          jsonb_build_object(
            'displayName','Shepherd','revision',0,
            'hasEstablishedDisplayName',false,
            'presentation',jsonb_build_object(
              'skinToneID','warm','hairStyleID','waves',
              'shepherdOutfitID','none','shepherdAccessoryID','none',
              'ollieOrnamentID','none','featuredSheepDefinitionID','none',
              'pastureThemeID','pasture_meadow'
            )
          )
        ),
        'role',m.role,
        'joinedAt',m.joined_at,
        'capabilities',jsonb_build_object(
          'canRenameParty',m.role='host',
          'canStartRound',m.role='host',
          'canManageInvites',m.role='host',
          'canDeleteParty',m.role='host',
          'canLeaveParty',m.role<>'host'
        )
      ) order by m.joined_at)
      from private.night_flock_v4_memberships m
      left join private.night_flock_v4_profiles px on px.user_id=m.user_id
      where m.party_id=pid
        and m.status='active'
        and not private.night_flock_users_blocked(u,m.user_id)
    ),'[]'::jsonb),
    'invitation',inv,
    'activities',coalesce((
      select jsonb_agg(jsonb_build_object(
        'activityID',a.id,'partyID',a.party_id,'roundID',a.round_id,
        'memberID',a.member_id,'day',a.activity_day,'kind',a.kind,
        'status',a.outcome,
        'roundedMinutes',greatest(0,least(
          case when a.kind='windDown' then 180 else 240 end,
          (round((case
            when a.kind='windDown' then a.wind_down_minutes
            else a.phone_away_minutes
          end)::numeric/5)*5)::integer
        )),
        'occurredAt',a.observed_at
      ) order by a.observed_at)
      from public.night_flock_v4_party_activities a
      join private.night_flock_v4_memberships activity_member
        on activity_member.id=a.member_id
      where a.party_id=pid
        and activity_member.status='active'
        and not private.night_flock_users_blocked(u,activity_member.user_id)
    ),'[]'::jsonb),
    'cursor',cursor,
    'liveStatuses',coalesce((
      select jsonb_agg(jsonb_build_object(
        'partyID',status_row.party_id,'roundID',status_row.round_id,
        'memberID',status_row.member_id,'status',status_row.status,
        'revision',status_row.revision,'observedAt',status_row.observed_at,
        'expiresAt',status_row.expires_at
      ))
      from public.night_flock_v4_statuses status_row
      join private.night_flock_v4_memberships status_member
        on status_member.id=status_row.member_id
      where status_row.party_id=pid
        and status_row.expires_at>now()
        and status_member.status='active'
        and not private.night_flock_users_blocked(u,status_member.user_id)
    ),'[]'::jsonb),
    'cheers',coalesce((
      select jsonb_agg(jsonb_build_object(
        'activityID',a.id,'cheer',reaction_group.reaction,
        'count',reaction_group.reaction_count,'sentByMe',reaction_group.sent_by_me
      ))
      from public.night_flock_v4_party_activities a
      join private.night_flock_v4_memberships activity_member
        on activity_member.id=a.member_id
      cross join lateral(
        select reaction_row.reaction,count(*)::int reaction_count,
               bool_or(reaction_row.member_id=my_member) sent_by_me
        from public.night_flock_v4_reactions reaction_row
        join private.night_flock_v4_memberships reactor
          on reactor.id=reaction_row.member_id
        where reaction_row.party_activity_id=a.id
          and reactor.status='active'
          and not private.night_flock_users_blocked(u,reactor.user_id)
        group by reaction_row.reaction
      )reaction_group
      where a.party_id=pid
        and activity_member.status='active'
        and not private.night_flock_users_blocked(u,activity_member.user_id)
    ),'[]'::jsonb),
    'liveCheers',coalesce((
      select jsonb_agg(jsonb_build_object(
        'memberID',reaction_group.target_member_id,
        'cheer',reaction_group.reaction,
        'count',reaction_group.reaction_count,
        'sentByMe',reaction_group.sent_by_me
      ))
      from (
        select live_reaction.target_member_id,live_reaction.reaction,
               count(*)::int reaction_count,
               bool_or(live_reaction.reactor_member_id=my_member) sent_by_me
        from private.night_flock_v4_live_reactions live_reaction
        join private.night_flock_v4_memberships target_member
          on target_member.id=live_reaction.target_member_id
        join private.night_flock_v4_memberships reactor
          on reactor.id=live_reaction.reactor_member_id
        where live_reaction.party_id=pid
          and target_member.status='active'
          and reactor.status='active'
          and not private.night_flock_users_blocked(u,target_member.user_id)
          and not private.night_flock_users_blocked(u,reactor.user_id)
        group by live_reaction.target_member_id,live_reaction.reaction
      )reaction_group
    ),'[]'::jsonb),
    'grantInbox',grants
  ));
end
$$;
revoke all on function public.night_flock_v4_command(uuid,jsonb),public.night_flock_v4_state(uuid,text,uuid,text) from public,anon,authenticated;grant execute on function public.night_flock_v4_command(uuid,jsonb),public.night_flock_v4_state(uuid,text,uuid,text) to service_role;
-- PostgREST resolves RPC arguments by name. Keep the implementation under a
-- private-by-name public function and expose the established Edge signature.
alter function public.night_flock_v4_state(uuid,text,uuid,text) rename to night_flock_v4_state_internal;
create function public.night_flock_v4_state(p_user_id uuid,p_scope text default 'list',p_party_id uuid default null,p_cursor text default null) returns jsonb language sql security definer set search_path='' as $$select public.night_flock_v4_state_internal(p_user_id,p_scope,p_party_id,p_cursor)$$;
alter function public.night_flock_state(uuid) rename to night_flock_state_v4_fenced_internal;
create function public.night_flock_state(p_user_id uuid) returns jsonb language sql security definer set search_path='' as $$select public.night_flock_state_v4_fenced_internal(p_user_id)$$;
alter function public.night_flock_commitment_state(uuid) rename to night_flock_commitment_state_v4_fenced_internal;
create function public.night_flock_commitment_state(p_user_id uuid) returns jsonb language sql security definer set search_path='' as $$select public.night_flock_commitment_state_v4_fenced_internal(p_user_id)$$;
alter function public.night_flock_social_state(uuid) rename to night_flock_social_state_v4_fenced_internal;
create function public.night_flock_social_state(p_user_id uuid) returns jsonb language sql security definer set search_path='' as $$select public.night_flock_social_state_v4_fenced_internal(p_user_id)$$;
alter function public.night_flock_command(uuid,jsonb) rename to night_flock_command_v4_fenced_internal;
create function public.night_flock_command(p_user_id uuid,p_command jsonb) returns jsonb language sql security definer set search_path='' as $$select public.night_flock_command_v4_fenced_internal(p_user_id,p_command)$$;
alter function public.night_flock_commitment_command(uuid,jsonb) rename to night_flock_commitment_command_v4_fenced_internal;
create function public.night_flock_commitment_command(p_user_id uuid,p_command jsonb) returns jsonb language sql security definer set search_path='' as $$select public.night_flock_commitment_command_v4_fenced_internal(p_user_id,p_command)$$;
alter function public.night_flock_social_command(uuid,jsonb) rename to night_flock_social_command_v4_fenced_internal;
create function public.night_flock_social_command(p_user_id uuid,p_command jsonb) returns jsonb language sql security definer set search_path='' as $$select public.night_flock_social_command_v4_fenced_internal(p_user_id,p_command)$$;
revoke all on function public.night_flock_v4_state_internal(uuid,text,uuid,text),public.night_flock_state_v4_fenced_internal(uuid),public.night_flock_commitment_state_v4_fenced_internal(uuid),public.night_flock_social_state_v4_fenced_internal(uuid),public.night_flock_command_v4_fenced_internal(uuid,jsonb),public.night_flock_commitment_command_v4_fenced_internal(uuid,jsonb),public.night_flock_social_command_v4_fenced_internal(uuid,jsonb) from public,anon,authenticated,service_role;
revoke all on function public.night_flock_v4_state(uuid,text,uuid,text),public.night_flock_state(uuid),public.night_flock_commitment_state(uuid),public.night_flock_social_state(uuid),public.night_flock_command(uuid,jsonb),public.night_flock_commitment_command(uuid,jsonb),public.night_flock_social_command(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.night_flock_v4_state(uuid,text,uuid,text),public.night_flock_state(uuid),public.night_flock_commitment_state(uuid),public.night_flock_social_state(uuid),public.night_flock_command(uuid,jsonb),public.night_flock_commitment_command(uuid,jsonb),public.night_flock_social_command(uuid,jsonb) to service_role;
