-- Membership sharing is deliberately separate from the round/reward ledger.  The
-- existing v4 tables remain the only source of round grants and late-join backfill.
create table private.night_flock_v4_membership_epochs (
  id uuid primary key default gen_random_uuid(),
  membership_id uuid not null references private.night_flock_v4_memberships(id) on delete cascade,
  party_id uuid not null references private.night_flock_v4_parties(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null,
  ended_at timestamptz,
  created_at timestamptz not null default now()
);
create unique index night_flock_v4_one_current_membership_epoch
  on private.night_flock_v4_membership_epochs(membership_id) where ended_at is null;

insert into private.night_flock_v4_membership_epochs(membership_id,party_id,user_id,joined_at,ended_at)
select id,party_id,user_id,joined_at,case when status='active' then null else left_at end
from private.night_flock_v4_memberships;

create or replace function private.night_flock_v4_membership_epoch_sync()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.status='active' and (tg_op='INSERT' or old.status<>'active' or new.joined_at is distinct from old.joined_at) then
    update private.night_flock_v4_membership_epochs
    set ended_at=coalesce(ended_at,new.joined_at)
    where membership_id=new.id and ended_at is null;
    insert into private.night_flock_v4_membership_epochs(membership_id,party_id,user_id,joined_at)
    values(new.id,new.party_id,new.user_id,new.joined_at);
  elsif tg_op='UPDATE' and old.status='active' and new.status<>'active' then
    update private.night_flock_v4_membership_epochs
    set ended_at=coalesce(new.left_at,now())
    where membership_id=new.id and ended_at is null;
  end if;
  return null;
end
$$;
create trigger z_night_flock_v4_membership_epochs
after insert or update of status,joined_at on private.night_flock_v4_memberships
for each row execute function private.night_flock_v4_membership_epoch_sync();

create table private.night_flock_v4_membership_stream_sources (
  party_id uuid not null references private.night_flock_v4_parties(id) on delete cascade,
  member_epoch_id uuid not null references private.night_flock_v4_membership_epochs(id) on delete cascade,
  source_event_id uuid not null,
  terminal_revision int not null check(terminal_revision>=0),
  terminal_observed_at timestamptz not null,
  purge_after timestamptz not null,
  primary key(party_id,member_epoch_id,source_event_id)
);
create table private.night_flock_v4_membership_stream_activities (
  id uuid primary key default gen_random_uuid(),
  party_id uuid not null references private.night_flock_v4_parties(id) on delete cascade,
  member_id uuid not null references private.night_flock_v4_memberships(id) on delete cascade,
  member_epoch_id uuid not null references private.night_flock_v4_membership_epochs(id) on delete cascade,
  source_event_id uuid not null,
  round_id uuid references private.night_flock_v4_rounds(id) on delete set null,
  activity_day smallint check(activity_day between 1 and 7),
  kind text not null check(kind in('windDown','phoneAway')),
  outcome text not null check(outcome in('completed','partlyCompleted')),
  wind_down_minutes smallint not null check(wind_down_minutes between 0 and 180),
  phone_away_minutes smallint not null check(phone_away_minutes between 0 and 240),
  revision int not null check(revision>=0),
  occurred_at timestamptz not null,
  created_at timestamptz not null default now(),
  unique(party_id,member_epoch_id,source_event_id)
);
create index night_flock_v4_membership_stream_recent
  on private.night_flock_v4_membership_stream_activities(party_id,occurred_at desc);
create table private.night_flock_v4_membership_stream_statuses (
  id uuid primary key default gen_random_uuid(),
  party_id uuid not null references private.night_flock_v4_parties(id) on delete cascade,
  member_id uuid not null references private.night_flock_v4_memberships(id) on delete cascade,
  member_epoch_id uuid not null references private.night_flock_v4_membership_epochs(id) on delete cascade,
  source_event_id uuid not null,
  round_id uuid references private.night_flock_v4_rounds(id) on delete set null,
  status text not null check(status in('windDownStarting','phoneAwayActive')),
  revision int not null check(revision>=0),
  observed_at timestamptz not null,
  expires_at timestamptz not null check(expires_at>observed_at),
  terminal_at timestamptz,
  created_at timestamptz not null default now(),
  unique(party_id,member_epoch_id,source_event_id)
);
create index night_flock_v4_membership_stream_live
  on private.night_flock_v4_membership_stream_statuses(party_id,expires_at);
create table private.night_flock_v4_membership_stream_reactions (
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null references private.night_flock_v4_membership_stream_activities(id) on delete cascade,
  reactor_member_id uuid not null references private.night_flock_v4_memberships(id) on delete cascade,
  reactor_epoch_id uuid not null references private.night_flock_v4_membership_epochs(id) on delete cascade,
  reaction text not null check(reaction in('warmWave','moonGlow','pawPrint')),
  created_at timestamptz not null default now(),
  unique(activity_id,reactor_epoch_id,reaction)
);
create table private.night_flock_v4_membership_stream_live_reactions (
  id uuid primary key default gen_random_uuid(),
  status_id uuid not null references private.night_flock_v4_membership_stream_statuses(id) on delete cascade,
  target_member_id uuid not null references private.night_flock_v4_memberships(id) on delete cascade,
  target_epoch_id uuid not null references private.night_flock_v4_membership_epochs(id) on delete cascade,
  reactor_member_id uuid not null references private.night_flock_v4_memberships(id) on delete cascade,
  reactor_epoch_id uuid not null references private.night_flock_v4_membership_epochs(id) on delete cascade,
  reaction text not null check(reaction in('warmWave','moonGlow','pawPrint')),
  created_at timestamptz not null default now(),
  check(target_member_id<>reactor_member_id),
  unique(status_id,reactor_epoch_id,reaction)
);

-- All stream mutations advance the existing realtime-safe party signal; stream rows
-- themselves stay private so no raw source identity is exposed through Realtime.
create or replace function private.night_flock_v4_membership_stream_signal_change()
returns trigger language plpgsql security definer set search_path='' as $$
declare target_party_id uuid;
begin
  if tg_table_name='night_flock_v4_membership_stream_reactions' then
    select party_id into target_party_id from private.night_flock_v4_membership_stream_activities where id=coalesce(new.activity_id,old.activity_id);
  elsif tg_table_name='night_flock_v4_membership_stream_live_reactions' then
    select party_id into target_party_id from private.night_flock_v4_membership_stream_statuses where id=coalesce(new.status_id,old.status_id);
  else
    target_party_id:=coalesce(new.party_id,old.party_id);
  end if;
  if target_party_id is not null then perform private.night_flock_v4_signal_party(target_party_id); end if;
  return null;
end
$$;
create trigger night_flock_v4_membership_stream_activities_signal
after insert or update or delete on private.night_flock_v4_membership_stream_activities
for each row execute function private.night_flock_v4_membership_stream_signal_change();
create trigger night_flock_v4_membership_stream_statuses_signal
after insert or update or delete on private.night_flock_v4_membership_stream_statuses
for each row execute function private.night_flock_v4_membership_stream_signal_change();
create trigger night_flock_v4_membership_stream_reactions_signal
after insert or update or delete on private.night_flock_v4_membership_stream_reactions
for each row execute function private.night_flock_v4_membership_stream_signal_change();
create trigger night_flock_v4_membership_stream_live_reactions_signal
after insert or update or delete on private.night_flock_v4_membership_stream_live_reactions
for each row execute function private.night_flock_v4_membership_stream_signal_change();

alter function private.night_flock_v4_apply(uuid,jsonb) rename to night_flock_v4_apply_round_legacy;
-- Scoped source records freeze their factual round boundary.  An unscoped legacy
-- backfill still works for old clients, except it cannot turn a known no-round
-- membership-stream source into a later grant for that party.
create or replace function private.night_flock_v4_apply_activity_with_round_fence(u uuid,c jsonb,strict_round boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare l private.night_flock_v4_activity_ledger%rowtype; m private.night_flock_v4_memberships%rowtype; r private.night_flock_v4_rounds%rowtype;
begin
  insert into private.night_flock_v4_activity_ledger(user_id,source_event_id,kind,outcome,started_at,ended_at,wind_down_minutes,phone_away_minutes,status_revision)
  values(u,(c->>'sourceEventID')::uuid,c->>'kind',coalesce(c->>'outcome','completed'),(c->>'startedAt')::timestamptz,(c->>'endedAt')::timestamptz,(c->>'windDownMinutes')::smallint,(c->>'phoneAwayMinutes')::smallint,(c->>'statusRevision')::int)
  on conflict(user_id,source_event_id,kind) do update set outcome=excluded.outcome,started_at=excluded.started_at,ended_at=excluded.ended_at,wind_down_minutes=excluded.wind_down_minutes,phone_away_minutes=excluded.phone_away_minutes,status_revision=excluded.status_revision
  where excluded.status_revision>private.night_flock_v4_activity_ledger.status_revision or (excluded.status_revision=private.night_flock_v4_activity_ledger.status_revision and excluded.ended_at>=private.night_flock_v4_activity_ledger.ended_at);
  select * into l from private.night_flock_v4_activity_ledger where user_id=u and source_event_id=(c->>'sourceEventID')::uuid and kind=c->>'kind';
  if strict_round and (l.ended_at<now()-interval '90 days' or l.ended_at>now()+interval '5 minutes') then return jsonb_build_object('accepted',true); end if;
  for m in select * from private.night_flock_v4_memberships where user_id=u and status='active' loop
    if exists(select 1 from private.night_flock_v4_membership_stream_activities known where known.party_id=m.party_id and known.source_event_id=l.source_event_id and known.round_id is null) then continue; end if;
    select * into r from private.night_flock_v4_rounds where party_id=m.party_id and status='active' and l.ended_at>=(starts_on::timestamp at time zone time_zone_identifier) and l.ended_at<((ends_on+1)::timestamp at time zone time_zone_identifier) and (not strict_round or started_at<=l.ended_at) order by started_at desc nulls last limit 1;
    if r.id is null then continue; end if;
    insert into public.night_flock_v4_party_activities(party_id,round_id,member_id,ledger_id,kind,outcome,activity_day,wind_down_minutes,phone_away_minutes,revision,observed_at)
    values(m.party_id,r.id,m.id,l.id,l.kind,l.outcome,((l.ended_at at time zone r.time_zone_identifier)::date-r.starts_on+1),l.wind_down_minutes,l.phone_away_minutes,l.status_revision,l.ended_at)
    on conflict(party_id,ledger_id) do update set outcome=excluded.outcome,wind_down_minutes=excluded.wind_down_minutes,phone_away_minutes=excluded.phone_away_minutes,revision=excluded.revision,observed_at=excluded.observed_at
    where excluded.revision>public.night_flock_v4_party_activities.revision or (excluded.revision=public.night_flock_v4_party_activities.revision and excluded.observed_at>=public.night_flock_v4_party_activities.observed_at);
    if l.outcome='completed' then
      insert into private.night_flock_v4_grants(user_id,party_id,round_id,ledger_id) values(u,m.party_id,r.id,l.id) on conflict do nothing;
      insert into public.night_flock_v4_statuses(party_id,round_id,member_id,revision,observed_at,expires_at,status)
      values(m.party_id,r.id,m.id,l.status_revision,l.ended_at,l.ended_at+interval '12 hours',case when l.kind='windDown' then 'windDownCompleted' else 'phoneAwayCompleted' end)
      on conflict(party_id,member_id) do update set round_id=excluded.round_id,revision=excluded.revision,observed_at=excluded.observed_at,expires_at=excluded.expires_at,status=excluded.status
      where excluded.observed_at>public.night_flock_v4_statuses.observed_at or (excluded.observed_at=public.night_flock_v4_statuses.observed_at and excluded.revision>=public.night_flock_v4_statuses.revision);
    end if;
  end loop;
  return jsonb_build_object('accepted',true);
end
$$;
create or replace function private.night_flock_v4_apply_status_with_round_fence(u uuid,c jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare m private.night_flock_v4_memberships%rowtype; r private.night_flock_v4_rounds%rowtype; obs timestamptz:=(c->>'observedAt')::timestamptz;
begin
  for m in select * from private.night_flock_v4_memberships where user_id=u and status='active' loop
    select * into r from private.night_flock_v4_rounds where party_id=m.party_id and status='active' and started_at<=obs and obs>=(starts_on::timestamp at time zone time_zone_identifier) and obs<((ends_on+1)::timestamp at time zone time_zone_identifier) order by started_at desc nulls last limit 1;
    if r.id is null then continue; end if;
    insert into public.night_flock_v4_statuses(party_id,round_id,member_id,revision,observed_at,expires_at,status)
    values(m.party_id,r.id,m.id,(c->>'revision')::int,obs,obs+case when c->>'status' in('windDownCompleted','phoneAwayCompleted') then interval '12 hours' else interval '30 minutes' end,c->>'status')
    on conflict(party_id,member_id) do update set round_id=excluded.round_id,revision=excluded.revision,observed_at=excluded.observed_at,expires_at=excluded.expires_at,status=excluded.status
    where excluded.observed_at>public.night_flock_v4_statuses.observed_at or (excluded.observed_at=public.night_flock_v4_statuses.observed_at and excluded.revision>=public.night_flock_v4_statuses.revision);
  end loop;
  return jsonb_build_object('accepted',true);
end
$$;
create or replace function private.night_flock_v4_apply(u uuid,c jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  cmd text:=c->>'command'; out jsonb; l private.night_flock_v4_activity_ledger%rowtype;
  m private.night_flock_v4_memberships%rowtype; e private.night_flock_v4_membership_epochs%rowtype;
  p private.night_flock_v4_parties%rowtype; r private.night_flock_v4_rounds%rowtype;
  activity private.night_flock_v4_membership_stream_activities%rowtype;
  live_status private.night_flock_v4_membership_stream_statuses%rowtype;
  target private.night_flock_v4_memberships%rowtype; reactor_epoch uuid; obs timestamptz;
begin
  if c ? 'sharingScope' and c->>'sharingScope'<>'membership' then raise exception 'Invalid sharingScope'; end if;
  if u is null or not private.is_apple_linked_night_flock_user(u) then raise exception 'Apple-linked account required'; end if;
  if c->>'sharingScope'='membership' and cmd='publishActivity' and ((c->>'endedAt')::timestamptz<now()-interval '90 days' or (c->>'endedAt')::timestamptz>now()+interval '5 minutes') then raise exception 'membership_activity_outside_window'; end if;
  if c->>'sharingScope'='membership' and cmd='publishStatus' and ((c->>'observedAt')::timestamptz<now()-interval '90 days' or (c->>'observedAt')::timestamptz>now()+interval '5 minutes') then raise exception 'membership_status_outside_window'; end if;

  if cmd='react' and c->>'sharingScope'='membership' then
    select * into p from private.night_flock_v4_parties where id=(c->>'partyID')::uuid and deleted_at is null for update;
    select * into m from private.night_flock_v4_memberships where party_id=p.id and user_id=u and status='active' for update;
    select id into reactor_epoch from private.night_flock_v4_membership_epochs where membership_id=m.id and ended_at is null;
    select a.* into activity from private.night_flock_v4_membership_stream_activities a
    join private.night_flock_v4_memberships owner on owner.id=a.member_id and owner.status='active'
    join private.night_flock_v4_membership_epochs owner_epoch on owner_epoch.id=a.member_epoch_id and owner_epoch.ended_at is null
    where a.id=(c->>'activityID')::uuid and a.party_id=p.id and not private.night_flock_users_blocked(u,owner.user_id);
    if p.id is null or m.id is null or reactor_epoch is null or activity.id is null then raise exception 'invite_unavailable'; end if;
    insert into private.night_flock_v4_membership_stream_reactions(activity_id,reactor_member_id,reactor_epoch_id,reaction)
    values(activity.id,m.id,reactor_epoch,c->>'cheer') on conflict do nothing;
    return jsonb_build_object('accepted',true);
  end if;

  if cmd='cheerMember' and c ? 'statusID' then
    select * into p from private.night_flock_v4_parties where id=(c->>'partyID')::uuid and deleted_at is null for update;
    select * into m from private.night_flock_v4_memberships where party_id=p.id and user_id=u and status='active' for update;
    select id into reactor_epoch from private.night_flock_v4_membership_epochs where membership_id=m.id and ended_at is null;
    select s.* into live_status from private.night_flock_v4_membership_stream_statuses s
    join private.night_flock_v4_memberships owner on owner.id=s.member_id and owner.status='active'
    join private.night_flock_v4_membership_epochs owner_epoch on owner_epoch.id=s.member_epoch_id and owner_epoch.ended_at is null
    where s.id=(c->>'statusID')::uuid and s.party_id=p.id and s.member_id=(c->>'memberID')::uuid
      and s.terminal_at is null and s.expires_at>now() and not private.night_flock_users_blocked(u,owner.user_id);
    if p.id is null or m.id is null or reactor_epoch is null or live_status.id is null or live_status.member_id=m.id then raise exception 'Invalid cheer target'; end if;
    insert into private.night_flock_v4_membership_stream_live_reactions(status_id,target_member_id,target_epoch_id,reactor_member_id,reactor_epoch_id,reaction)
    values(live_status.id,live_status.member_id,live_status.member_epoch_id,m.id,reactor_epoch,c->>'cheer') on conflict do nothing;
    return jsonb_build_object('accepted',true);
  end if;

  if cmd='publishActivity' then
    out:=private.night_flock_v4_apply_activity_with_round_fence(u,c,coalesce(c->>'sharingScope'='membership',false));
  elsif cmd='publishStatus' and c->>'sharingScope'='membership' then
    out:=private.night_flock_v4_apply_status_with_round_fence(u,c);
  else
    out:=private.night_flock_v4_apply_round_legacy(u,c-'sharingScope');
  end if;
  if cmd not in('publishActivity','publishStatus') or c->>'sharingScope' is distinct from 'membership' then return out; end if;

  if cmd='publishActivity' then
    select * into l from private.night_flock_v4_activity_ledger
    where user_id=u and source_event_id=(c->>'sourceEventID')::uuid and kind=c->>'kind';
    if l.id is null or l.ended_at<now()-interval '90 days' or l.ended_at>now()+interval '5 minutes' then return out; end if;
    for m in select membership.* from private.night_flock_v4_memberships membership join private.night_flock_v4_parties party on party.id=membership.party_id and party.deleted_at is null where membership.user_id=u and membership.status='active' order by membership.party_id loop
      select * into e from private.night_flock_v4_membership_epochs where membership_id=m.id and ended_at is null;
      if e.id is null or l.ended_at<e.joined_at then continue; end if;
      perform pg_advisory_xact_lock(hashtextextended(m.party_id::text||e.id::text,0));
      select * into r from private.night_flock_v4_rounds where party_id=m.party_id and started_at<=l.ended_at and l.ended_at>=(starts_on::timestamp at time zone time_zone_identifier) and l.ended_at<((ends_on+1)::timestamp at time zone time_zone_identifier) and (status='active' or completed_at>=l.ended_at) order by started_at desc limit 1;
      insert into private.night_flock_v4_membership_stream_activities(party_id,member_id,member_epoch_id,source_event_id,round_id,activity_day,kind,outcome,wind_down_minutes,phone_away_minutes,revision,occurred_at)
      values(m.party_id,m.id,e.id,l.source_event_id,r.id,case when r.id is null then null else ((l.ended_at at time zone r.time_zone_identifier)::date-r.starts_on+1)::smallint end,l.kind,l.outcome,l.wind_down_minutes,l.phone_away_minutes,l.status_revision,l.ended_at)
      on conflict(party_id,member_epoch_id,source_event_id) do update set outcome=excluded.outcome,wind_down_minutes=excluded.wind_down_minutes,phone_away_minutes=excluded.phone_away_minutes,revision=excluded.revision,occurred_at=excluded.occurred_at
      where excluded.revision>private.night_flock_v4_membership_stream_activities.revision or (excluded.revision=private.night_flock_v4_membership_stream_activities.revision and excluded.occurred_at>=private.night_flock_v4_membership_stream_activities.occurred_at);
      insert into private.night_flock_v4_membership_stream_sources(party_id,member_epoch_id,source_event_id,terminal_revision,terminal_observed_at,purge_after)
      values(m.party_id,e.id,l.source_event_id,l.status_revision,l.ended_at,l.ended_at+interval '90 days')
      on conflict(party_id,member_epoch_id,source_event_id) do update set terminal_revision=excluded.terminal_revision,terminal_observed_at=excluded.terminal_observed_at,purge_after=greatest(private.night_flock_v4_membership_stream_sources.purge_after,excluded.purge_after)
      where excluded.terminal_revision>private.night_flock_v4_membership_stream_sources.terminal_revision or (excluded.terminal_revision=private.night_flock_v4_membership_stream_sources.terminal_revision and excluded.terminal_observed_at>=private.night_flock_v4_membership_stream_sources.terminal_observed_at);
      update private.night_flock_v4_membership_stream_statuses set terminal_at=coalesce(terminal_at,now()) where party_id=m.party_id and member_epoch_id=e.id and source_event_id=l.source_event_id;
    end loop;
    return out;
  end if;

  obs:=(c->>'observedAt')::timestamptz;
  if obs<now()-interval '90 days' or obs>now()+interval '5 minutes' then return out; end if;
  for m in select membership.* from private.night_flock_v4_memberships membership join private.night_flock_v4_parties party on party.id=membership.party_id and party.deleted_at is null where membership.user_id=u and membership.status='active' order by membership.party_id loop
    select * into e from private.night_flock_v4_membership_epochs where membership_id=m.id and ended_at is null;
    if e.id is null or obs<e.joined_at then continue; end if;
    perform pg_advisory_xact_lock(hashtextextended(m.party_id::text||e.id::text,0));
    if c->>'status' in('windDownCompleted','phoneAwayCompleted') then
      insert into private.night_flock_v4_membership_stream_sources(party_id,member_epoch_id,source_event_id,terminal_revision,terminal_observed_at,purge_after)
      values(m.party_id,e.id,(c->>'sourceEventID')::uuid,(c->>'revision')::int,obs,obs+interval '90 days')
      on conflict(party_id,member_epoch_id,source_event_id) do update set terminal_revision=excluded.terminal_revision,terminal_observed_at=excluded.terminal_observed_at,purge_after=greatest(private.night_flock_v4_membership_stream_sources.purge_after,excluded.purge_after)
      where excluded.terminal_revision>private.night_flock_v4_membership_stream_sources.terminal_revision or (excluded.terminal_revision=private.night_flock_v4_membership_stream_sources.terminal_revision and excluded.terminal_observed_at>=private.night_flock_v4_membership_stream_sources.terminal_observed_at);
      update private.night_flock_v4_membership_stream_statuses set terminal_at=coalesce(terminal_at,now()) where party_id=m.party_id and member_epoch_id=e.id and source_event_id=(c->>'sourceEventID')::uuid;
    elsif not exists(select 1 from private.night_flock_v4_membership_stream_sources where party_id=m.party_id and member_epoch_id=e.id and source_event_id=(c->>'sourceEventID')::uuid) then
      if exists(select 1 from private.night_flock_v4_membership_stream_statuses current_status where current_status.party_id=m.party_id and current_status.member_epoch_id=e.id and current_status.source_event_id<>(c->>'sourceEventID')::uuid and (current_status.observed_at>obs or (current_status.observed_at=obs and current_status.revision>=(c->>'revision')::int))) then continue; end if;
      select * into r from private.night_flock_v4_rounds where party_id=m.party_id and started_at<=obs and obs>=(starts_on::timestamp at time zone time_zone_identifier) and obs<((ends_on+1)::timestamp at time zone time_zone_identifier) and (status='active' or completed_at>=obs) order by started_at desc limit 1;
      update private.night_flock_v4_membership_stream_statuses set terminal_at=coalesce(terminal_at,now()) where party_id=m.party_id and member_epoch_id=e.id and source_event_id<>(c->>'sourceEventID')::uuid;
      insert into private.night_flock_v4_membership_stream_statuses(party_id,member_id,member_epoch_id,source_event_id,round_id,status,revision,observed_at,expires_at)
      values(m.party_id,m.id,e.id,(c->>'sourceEventID')::uuid,r.id,c->>'status',(c->>'revision')::int,obs,obs+interval '30 minutes')
      on conflict(party_id,member_epoch_id,source_event_id) do update set round_id=excluded.round_id,status=excluded.status,revision=excluded.revision,observed_at=excluded.observed_at,expires_at=excluded.expires_at
      where excluded.revision>private.night_flock_v4_membership_stream_statuses.revision or (excluded.revision=private.night_flock_v4_membership_stream_statuses.revision and excluded.observed_at>=private.night_flock_v4_membership_stream_statuses.observed_at);
    end if;
  end loop;
  return out;
end
$$;

alter function public.night_flock_v4_state(uuid,text,uuid,text) rename to night_flock_v4_state_membership_legacy;
create or replace function public.night_flock_v4_state(p_user_id uuid,p_scope text default 'list',p_party_id uuid default null,p_cursor text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare legacy jsonb; party jsonb; my_member uuid;
begin
  legacy:=public.night_flock_v4_state_membership_legacy(p_user_id,p_scope,p_party_id,p_cursor);
  if p_scope='list' then
    return jsonb_set(legacy,'{parties}',coalesce((select jsonb_agg(value||jsonb_build_object('sharingScope','membership')) from jsonb_array_elements(legacy->'parties')),'[]'::jsonb));
  end if;
  select id into my_member from private.night_flock_v4_memberships where party_id=p_party_id and user_id=p_user_id and status='active';
  party:=legacy->'party';
  party:=party||jsonb_build_object(
    'summary',(party->'summary')||jsonb_build_object('sharingScope','membership'),
    'sharedActivities',coalesce((select jsonb_agg(jsonb_build_object('activityID',q.id,'partyID',q.party_id,'memberID',q.member_id,'roundID',q.round_id,'day',q.activity_day,'kind',q.kind,'status',q.outcome,'roundedMinutes',q.rounded_minutes,'occurredAt',q.occurred_at,'roundActivityID',q.round_activity_id,'mySourceEventID',case when q.member_id=my_member then q.source_event_id else null end) order by q.occurred_at desc) from (select a.*,round_activity.id round_activity_id,greatest(0,least(case when a.kind='windDown' then 180 else 240 end,(round((case when a.kind='windDown' then a.wind_down_minutes else a.phone_away_minutes end)::numeric/5)*5)::integer)) rounded_minutes from private.night_flock_v4_membership_stream_activities a join private.night_flock_v4_memberships owner on owner.id=a.member_id and owner.status='active' join private.night_flock_v4_membership_epochs epoch on epoch.id=a.member_epoch_id and epoch.ended_at is null left join lateral(select party_activity.id from public.night_flock_v4_party_activities party_activity join private.night_flock_v4_activity_ledger ledger on ledger.id=party_activity.ledger_id where party_activity.party_id=a.party_id and ledger.user_id=owner.user_id and ledger.source_event_id=a.source_event_id and ledger.kind=a.kind order by party_activity.observed_at desc limit 1) round_activity on true where a.party_id=p_party_id and a.occurred_at>=now()-interval '90 days' and not private.night_flock_users_blocked(p_user_id,owner.user_id) order by a.occurred_at desc limit 100) q),'[]'::jsonb),
    'sharedLiveStatuses',coalesce((select jsonb_agg(jsonb_build_object('statusID',s.id,'partyID',s.party_id,'memberID',s.member_id,'roundID',s.round_id,'status',s.status,'revision',s.revision,'observedAt',s.observed_at,'expiresAt',s.expires_at)) from private.night_flock_v4_membership_stream_statuses s join private.night_flock_v4_memberships owner on owner.id=s.member_id and owner.status='active' join private.night_flock_v4_membership_epochs epoch on epoch.id=s.member_epoch_id and epoch.ended_at is null where s.party_id=p_party_id and s.terminal_at is null and s.expires_at>now() and not private.night_flock_users_blocked(p_user_id,owner.user_id)),'[]'::jsonb),
    'sharedCheers',coalesce((select jsonb_agg(jsonb_build_object('activityID',a.id,'cheer',g.reaction,'count',g.reaction_count,'sentByMe',g.sent_by_me)) from private.night_flock_v4_membership_stream_activities a join private.night_flock_v4_memberships owner on owner.id=a.member_id and owner.status='active' join private.night_flock_v4_membership_epochs owner_epoch on owner_epoch.id=a.member_epoch_id and owner_epoch.ended_at is null cross join lateral(select x.reaction,count(*)::int reaction_count,bool_or(x.reactor_member_id=my_member) sent_by_me from (select reaction,reactor_member_id,reactor_epoch_id from private.night_flock_v4_membership_stream_reactions where activity_id=a.id union select live.reaction,live.reactor_member_id,live.reactor_epoch_id from private.night_flock_v4_membership_stream_live_reactions live join private.night_flock_v4_membership_stream_statuses status_row on status_row.id=live.status_id where status_row.party_id=a.party_id and status_row.member_epoch_id=a.member_epoch_id and status_row.source_event_id=a.source_event_id union select legacy_reaction.reaction,legacy_reaction.member_id,legacy_epoch.id from public.night_flock_v4_reactions legacy_reaction join public.night_flock_v4_party_activities legacy_activity on legacy_activity.id=legacy_reaction.party_activity_id join private.night_flock_v4_activity_ledger legacy_ledger on legacy_ledger.id=legacy_activity.ledger_id join private.night_flock_v4_memberships legacy_reactor on legacy_reactor.id=legacy_reaction.member_id and legacy_reactor.status='active' join private.night_flock_v4_membership_epochs legacy_epoch on legacy_epoch.membership_id=legacy_reactor.id and legacy_epoch.ended_at is null where legacy_activity.party_id=a.party_id and legacy_activity.member_id=a.member_id and legacy_ledger.user_id=owner.user_id and legacy_ledger.source_event_id=a.source_event_id and legacy_ledger.kind=a.kind and legacy_reaction.created_at>=legacy_epoch.joined_at) x join private.night_flock_v4_memberships reactor on reactor.id=x.reactor_member_id and reactor.status='active' join private.night_flock_v4_membership_epochs reactor_epoch on reactor_epoch.id=x.reactor_epoch_id and reactor_epoch.ended_at is null where not private.night_flock_users_blocked(p_user_id,reactor.user_id) group by x.reaction) g where a.party_id=p_party_id and a.occurred_at>=now()-interval '90 days' and not private.night_flock_users_blocked(p_user_id,owner.user_id)),'[]'::jsonb),
    'sharedLiveCheers',coalesce((select jsonb_agg(jsonb_build_object('statusID',s.id,'memberID',s.member_id,'cheer',g.reaction,'count',g.reaction_count,'sentByMe',g.sent_by_me,'mySourceEventID',case when s.member_id=my_member then s.source_event_id else null end)) from private.night_flock_v4_membership_stream_statuses s join private.night_flock_v4_memberships owner on owner.id=s.member_id and owner.status='active' join private.night_flock_v4_membership_epochs owner_epoch on owner_epoch.id=s.member_epoch_id and owner_epoch.ended_at is null cross join lateral(select r.reaction,count(*)::int reaction_count,bool_or(r.reactor_member_id=my_member) sent_by_me from private.night_flock_v4_membership_stream_live_reactions r join private.night_flock_v4_memberships reactor on reactor.id=r.reactor_member_id and reactor.status='active' join private.night_flock_v4_membership_epochs reactor_epoch on reactor_epoch.id=r.reactor_epoch_id and reactor_epoch.ended_at is null where r.status_id=s.id and not private.night_flock_users_blocked(p_user_id,reactor.user_id) group by r.reaction) g where s.party_id=p_party_id and s.created_at>=now()-interval '90 days' and not private.night_flock_users_blocked(p_user_id,owner.user_id)),'[]'::jsonb)
  );
  return jsonb_build_object('party',party);
end
$$;

alter function public.purge_night_flock_retention(timestamptz) rename to purge_night_flock_retention_v3_legacy;
create or replace function public.purge_night_flock_retention(p_now timestamptz default now())
returns jsonb language plpgsql security definer set search_path='' as $$
declare legacy jsonb; activities int; statuses int; sources int;
begin
  legacy:=public.purge_night_flock_retention_v3_legacy(p_now);
  delete from private.night_flock_v4_membership_stream_statuses where created_at<p_now-interval '90 days'; get diagnostics statuses=row_count;
  delete from private.night_flock_v4_membership_stream_activities where occurred_at<p_now-interval '90 days'; get diagnostics activities=row_count;
  delete from private.night_flock_v4_membership_stream_sources where purge_after<p_now; get diagnostics sources=row_count;
  return legacy||jsonb_build_object('membershipStreamActivitiesPurged',activities,'membershipStreamStatusesPurged',statuses,'membershipStreamTombstonesPurged',sources);
end
$$;
revoke all on function public.night_flock_v4_state_membership_legacy(uuid,text,uuid,text),public.purge_night_flock_retention_v3_legacy(timestamptz) from public,anon,authenticated,service_role;
revoke all on function public.night_flock_v4_state(uuid,text,uuid,text),public.purge_night_flock_retention(timestamptz) from public,anon,authenticated;
grant execute on function public.night_flock_v4_state(uuid,text,uuid,text),public.purge_night_flock_retention(timestamptz) to service_role;
revoke all on private.night_flock_v4_membership_epochs,private.night_flock_v4_membership_stream_sources,private.night_flock_v4_membership_stream_activities,private.night_flock_v4_membership_stream_statuses,private.night_flock_v4_membership_stream_reactions,private.night_flock_v4_membership_stream_live_reactions from public,anon,authenticated;
revoke all on function private.night_flock_v4_membership_epoch_sync(),private.night_flock_v4_membership_stream_signal_change(),private.night_flock_v4_apply_round_legacy(uuid,jsonb),private.night_flock_v4_apply_activity_with_round_fence(uuid,jsonb,boolean),private.night_flock_v4_apply_status_with_round_fence(uuid,jsonb),private.night_flock_v4_apply(uuid,jsonb) from public,anon,authenticated;
