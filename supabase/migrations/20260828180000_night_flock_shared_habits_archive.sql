-- Shared habits is an opt-in archive. It is separate from the V4 reward ledger and
-- keeps only rounded, derived facts that the contributor expressly agreed to share.
create table private.night_flock_v4_shared_habits_agreements (
  id uuid primary key default gen_random_uuid(), party_id uuid not null references private.night_flock_v4_parties(id) on delete cascade,
  member_epoch_id uuid not null references private.night_flock_v4_membership_epochs(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade, agreement_version smallint not null check(agreement_version=1),
  accepted_at timestamptz not null default now(), time_zone_identifier text not null check(char_length(time_zone_identifier) between 1 and 64), party_name_snapshot text not null,
  first_eligible_sleep_night date not null, first_eligible_wind_down_date date not null, first_eligible_activity_date date not null, unique(member_epoch_id,agreement_version)
);
create table private.night_flock_v4_shared_habits_records (
  id uuid primary key default gen_random_uuid(), party_id uuid not null references private.night_flock_v4_parties(id) on delete cascade,
  member_id uuid not null references private.night_flock_v4_memberships(id) on delete cascade,
  member_epoch_id uuid not null references private.night_flock_v4_membership_epochs(id) on delete cascade,
  agreement_id uuid not null references private.night_flock_v4_shared_habits_agreements(id) on delete cascade,
  author_user_id uuid not null references auth.users(id) on delete cascade, source_id uuid not null, revision bigint not null check(revision>=0),
  kind text not null check(kind in('sleep','windDown','phoneAway')), local_date date,
  activity_date date,
  time_zone_identifier text not null check(char_length(time_zone_identifier) between 1 and 64), minutes smallint not null check((kind='sleep' and minutes between 0 and 1500) or (kind='windDown' and minutes between 0 and 180) or (kind='phoneAway' and minutes between 0 and 1500)),
  outcome text check(outcome in('completed','partlyCompleted')), protection_minutes smallint check(protection_minutes between 0 and 720),
  evidence text not null check(evidence in('none','appRecorded')), profile_snapshot jsonb not null, archive_revision int not null,
  migrated_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check((protection_minutes is null) or (evidence='appRecorded' and protection_minutes<=minutes)), check(kind<>'sleep' or (outcome is null and protection_minutes is null and evidence='none')), unique(party_id,member_epoch_id,source_id,kind), unique(party_id,author_user_id,source_id,kind)
);
create index night_flock_v4_shared_habits_page on private.night_flock_v4_shared_habits_records(party_id,archive_revision,local_date desc,member_id desc,id desc);
create table private.night_flock_v4_shared_habits_tombstones (
  party_id uuid not null references private.night_flock_v4_parties(id) on delete cascade, user_id uuid not null references auth.users(id) on delete cascade,
  source_id uuid not null, member_epoch_id uuid references private.night_flock_v4_membership_epochs(id) on delete cascade,
  all_sources boolean not null default false, deleted_at timestamptz not null default now(), withdrawal_cutoff_at timestamptz,
  primary key(party_id,user_id,source_id),
  check((source_id<>'00000000-0000-0000-0000-000000000000'::uuid and not all_sources) or (source_id='00000000-0000-0000-0000-000000000000'::uuid and all_sources)),
  check((all_sources and withdrawal_cutoff_at is not null) or (not all_sources and withdrawal_cutoff_at is null))
);
alter table public.night_flock_v4_statuses add column source_event_id uuid;
create unique index night_flock_v4_shared_habits_all_sources_tombstone on private.night_flock_v4_shared_habits_tombstones(party_id,user_id) where all_sources;

-- Legacy V4 activity/status publication is account-scoped and therefore has
-- no member-epoch input to fence on a rejoin. An all-sources withdrawal keeps
-- this party-local source-time cutoff so a source that began before leaving
-- cannot fan back into this party later, while a genuinely new post-rejoin
-- source remains eligible for the new epoch.
create or replace function private.night_flock_v4_shared_habits_withdrawal_blocks(
  pid uuid,
  uid uuid,
  sid uuid,
  member_epoch uuid,
  occurred_at timestamptz
) returns boolean language sql stable security definer set search_path='' as $$
  select exists(
    select 1
    from private.night_flock_v4_shared_habits_tombstones t
    where t.party_id=pid
      and t.user_id=uid
      and (
        t.source_id=sid
        or (
          t.all_sources
          and (
            t.member_epoch_id=member_epoch
            or (t.withdrawal_cutoff_at is not null and occurred_at<=t.withdrawal_cutoff_at)
          )
        )
      )
  )
$$;

-- Keep legacy V4's durable reward ledger separate from shared-history removal.
-- The activity helper is where public activity, terminal status, and grants are
-- first materialised, so it takes the party row lock and records an exact source
-- tombstone before any of those side effects for a withdrawn source.  `started_at`
-- is the canonical source fact: an activity that crosses a leave boundary remains
-- the same pre-withdrawal activity even when its terminal/status time is later.
create or replace function private.night_flock_v4_apply_activity_with_round_fence(u uuid,c jsonb,strict_round boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare l private.night_flock_v4_activity_ledger%rowtype; m private.night_flock_v4_memberships%rowtype; e private.night_flock_v4_membership_epochs%rowtype; r private.night_flock_v4_rounds%rowtype;
begin
  insert into private.night_flock_v4_activity_ledger(user_id,source_event_id,kind,outcome,started_at,ended_at,wind_down_minutes,phone_away_minutes,status_revision)
  values(u,(c->>'sourceEventID')::uuid,c->>'kind',coalesce(c->>'outcome','completed'),(c->>'startedAt')::timestamptz,(c->>'endedAt')::timestamptz,(c->>'windDownMinutes')::smallint,(c->>'phoneAwayMinutes')::smallint,(c->>'statusRevision')::int)
  on conflict(user_id,source_event_id,kind) do update set outcome=excluded.outcome,started_at=excluded.started_at,ended_at=excluded.ended_at,wind_down_minutes=excluded.wind_down_minutes,phone_away_minutes=excluded.phone_away_minutes,status_revision=excluded.status_revision
  where excluded.status_revision>private.night_flock_v4_activity_ledger.status_revision or (excluded.status_revision=private.night_flock_v4_activity_ledger.status_revision and excluded.ended_at>=private.night_flock_v4_activity_ledger.ended_at);
  select * into l from private.night_flock_v4_activity_ledger where user_id=u and source_event_id=(c->>'sourceEventID')::uuid and kind=c->>'kind';
  if strict_round and (l.ended_at<now()-interval '90 days' or l.ended_at>now()+interval '5 minutes') then return jsonb_build_object('accepted',true); end if;
  for m in select * from private.night_flock_v4_memberships where user_id=u and status='active' order by party_id loop
    -- Serialize with deleteSharedHabitHistory's party lock.  This prevents a
    -- concurrent withdrawal from observing no projection while this command
    -- creates one after its cleanup.
    perform 1 from private.night_flock_v4_parties where id=m.party_id for update;
    select * into e from private.night_flock_v4_membership_epochs where membership_id=m.id and ended_at is null;
    if private.night_flock_v4_shared_habits_withdrawal_blocks(m.party_id,u,l.source_event_id,e.id,l.started_at) then
      insert into private.night_flock_v4_shared_habits_tombstones(party_id,user_id,source_id)
      values(m.party_id,u,l.source_event_id) on conflict(party_id,user_id,source_id) do nothing;
      continue;
    end if;
    if exists(select 1 from private.night_flock_v4_membership_stream_activities known where known.party_id=m.party_id and known.source_event_id=l.source_event_id and known.round_id is null) then continue; end if;
    select * into r from private.night_flock_v4_rounds where party_id=m.party_id and status='active' and l.ended_at>=(starts_on::timestamp at time zone time_zone_identifier) and l.ended_at<((ends_on+1)::timestamp at time zone time_zone_identifier) and (not strict_round or started_at<=l.ended_at) order by started_at desc nulls last limit 1;
    if r.id is null then continue; end if;
    insert into public.night_flock_v4_party_activities(party_id,round_id,member_id,ledger_id,kind,outcome,activity_day,wind_down_minutes,phone_away_minutes,revision,observed_at)
    values(m.party_id,r.id,m.id,l.id,l.kind,l.outcome,((l.ended_at at time zone r.time_zone_identifier)::date-r.starts_on+1),l.wind_down_minutes,l.phone_away_minutes,l.status_revision,l.ended_at)
    on conflict(party_id,ledger_id) do update set outcome=excluded.outcome,wind_down_minutes=excluded.wind_down_minutes,phone_away_minutes=excluded.phone_away_minutes,revision=excluded.revision,observed_at=excluded.observed_at
    where excluded.revision>public.night_flock_v4_party_activities.revision or (excluded.revision=public.night_flock_v4_party_activities.revision and excluded.observed_at>=public.night_flock_v4_party_activities.observed_at);
    if l.outcome='completed' then
      insert into private.night_flock_v4_grants(user_id,party_id,round_id,ledger_id) values(u,m.party_id,r.id,l.id) on conflict do nothing;
      insert into public.night_flock_v4_statuses(party_id,round_id,member_id,revision,observed_at,expires_at,status,source_event_id)
      values(m.party_id,r.id,m.id,l.status_revision,l.ended_at,l.ended_at+interval '12 hours',case when l.kind='windDown' then 'windDownCompleted' else 'phoneAwayCompleted' end,l.source_event_id)
      on conflict(party_id,member_id) do update set round_id=excluded.round_id,revision=excluded.revision,observed_at=excluded.observed_at,expires_at=excluded.expires_at,status=excluded.status,source_event_id=excluded.source_event_id
      where excluded.observed_at>public.night_flock_v4_statuses.observed_at or (excluded.observed_at=public.night_flock_v4_statuses.observed_at and excluded.revision>=public.night_flock_v4_statuses.revision);
    end if;
  end loop;
  return jsonb_build_object('accepted',true);
end
$$;

create or replace function private.night_flock_v4_shared_habits_accept(u uuid,pid uuid,tz text,requested uuid default null) returns private.night_flock_v4_shared_habits_agreements
language plpgsql security definer set search_path='' as $$
declare m private.night_flock_v4_memberships%rowtype; e private.night_flock_v4_membership_epochs%rowtype; a private.night_flock_v4_shared_habits_agreements%rowtype; frozen_name text;
begin
  if u is null or not private.is_apple_linked_night_flock_user(u) then raise exception 'Apple-linked account required'; end if;
  select * into m from private.night_flock_v4_memberships where party_id=pid and user_id=u and status='active' for update;
  if m.id is null then raise exception 'current_membership_required'; end if;
  select * into e from private.night_flock_v4_membership_epochs where membership_id=m.id and ended_at is null for update;
  if e.id is null then raise exception 'current_membership_required'; end if;
  select * into a from private.night_flock_v4_shared_habits_agreements where member_epoch_id=e.id and agreement_version=1;
  if a.id is null then
    select name into frozen_name from private.night_flock_v4_parties where id=pid;
    insert into private.night_flock_v4_shared_habits_agreements(id,party_id,member_epoch_id,user_id,agreement_version,time_zone_identifier,party_name_snapshot,first_eligible_sleep_night,first_eligible_wind_down_date,first_eligible_activity_date)
    values(coalesce(requested,gen_random_uuid()),pid,e.id,u,1,tz,coalesce(frozen_name,'Slumber Party'),
      ((now() at time zone tz)::date + case when (now() at time zone tz)::time > time '12:00' then 2 else 1 end),
      (now() at time zone tz)::date,
      (now() at time zone tz)::date) returning * into a;
  elsif requested is not null and a.id<>requested then raise exception 'stale_revision'; end if;
  return a;
end $$;

alter function private.night_flock_v4_apply(uuid,jsonb) rename to night_flock_v4_apply_pre_shared_habits;
create or replace function private.night_flock_v4_apply(u uuid,c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare cmd text:=c->>'command'; p private.night_flock_v4_parties%rowtype; m private.night_flock_v4_memberships%rowtype; e private.night_flock_v4_membership_epochs%rowtype; a private.night_flock_v4_shared_habits_agreements%rowtype; i private.night_flock_v4_invites%rowtype; existing private.night_flock_v4_shared_habits_records%rowtype; out jsonb; pr jsonb; next_revision int;
begin
  if u is null or not private.is_apple_linked_night_flock_user(u) then raise exception 'Apple-linked account required'; end if;
  if cmd='acceptSharedHabitsAgreement' then
    select * into p from private.night_flock_v4_parties where id=(c->>'partyID')::uuid and deleted_at is null for update;
    if p.id is null or not exists(select 1 from private.night_flock_v4_memberships history where history.party_id=p.id and history.user_id=u) then raise exception 'current_membership_required'; end if;
    a:=private.night_flock_v4_shared_habits_accept(u,p.id,c->>'timeZoneIdentifier');
    return jsonb_build_object('accepted',true,'agreementID',a.id,'memberEpochID',a.member_epoch_id);
  end if;
  if cmd='deleteSharedHabitHistory' then
    select * into p from private.night_flock_v4_parties where id=(c->>'partyID')::uuid for update;
    if p.id is null or not exists(select 1 from private.night_flock_v4_memberships history where history.party_id=p.id and history.user_id=u) then raise exception 'current_membership_required'; end if;
    if c ? 'allSources' then
      -- Enumerating every known source makes old archive, round, and stream
      -- replays stay deleted even after a later, newly consented epoch.
      insert into private.night_flock_v4_shared_habits_tombstones(party_id,user_id,source_id)
      select p.id,u,q.source_id from (
        select source_id from private.night_flock_v4_shared_habits_records where party_id=p.id and author_user_id=u
        union select l.source_event_id from public.night_flock_v4_party_activities x join private.night_flock_v4_activity_ledger l on l.id=x.ledger_id where x.party_id=p.id and l.user_id=u
        union select s.source_event_id from private.night_flock_v4_membership_stream_activities s join private.night_flock_v4_memberships mm on mm.id=s.member_id and mm.user_id=u where s.party_id=p.id
        union select s.source_event_id from private.night_flock_v4_membership_stream_statuses s join private.night_flock_v4_memberships mm on mm.id=s.member_id and mm.user_id=u where s.party_id=p.id
        union select x.source_event_id from public.night_flock_v4_statuses x join private.night_flock_v4_memberships mm on mm.id=x.member_id and mm.user_id=u where x.party_id=p.id and x.source_event_id is not null
      ) q on conflict do nothing;
      insert into private.night_flock_v4_shared_habits_tombstones(party_id,user_id,source_id,member_epoch_id,all_sources,withdrawal_cutoff_at)
      values(p.id,u,'00000000-0000-0000-0000-000000000000',(
        select epoch_row.id from private.night_flock_v4_membership_epochs epoch_row join private.night_flock_v4_memberships membership_row on membership_row.id=epoch_row.membership_id where membership_row.party_id=p.id and membership_row.user_id=u and epoch_row.ended_at is null
      ),true,coalesce((
        select membership_row.left_at
        from private.night_flock_v4_memberships membership_row
        where membership_row.party_id=p.id and membership_row.user_id=u and membership_row.status<>'active'
      ),now())) on conflict(party_id,user_id,source_id) do update set member_epoch_id=excluded.member_epoch_id,deleted_at=excluded.deleted_at,withdrawal_cutoff_at=excluded.withdrawal_cutoff_at;
      delete from private.night_flock_v4_shared_habits_records where party_id=p.id and author_user_id=u;
      delete from private.night_flock_v4_membership_stream_activities x using private.night_flock_v4_memberships mm where x.party_id=p.id and x.member_id=mm.id and mm.user_id=u;
      delete from private.night_flock_v4_membership_stream_statuses x using private.night_flock_v4_memberships mm where x.party_id=p.id and x.member_id=mm.id and mm.user_id=u;
      delete from public.night_flock_v4_party_activities x using private.night_flock_v4_activity_ledger l where x.party_id=p.id and x.ledger_id=l.id and l.user_id=u;
      delete from public.night_flock_v4_statuses x using private.night_flock_v4_memberships mm where x.party_id=p.id and x.member_id=mm.id and mm.user_id=u;
    else
      insert into private.night_flock_v4_shared_habits_tombstones(party_id,user_id,source_id) values(p.id,u,(c->>'sourceID')::uuid) on conflict do nothing;
      delete from private.night_flock_v4_shared_habits_records where party_id=p.id and author_user_id=u and source_id=(c->>'sourceID')::uuid;
      delete from private.night_flock_v4_membership_stream_activities x using private.night_flock_v4_memberships mm where x.party_id=p.id and x.member_id=mm.id and mm.user_id=u and x.source_event_id=(c->>'sourceID')::uuid;
      delete from private.night_flock_v4_membership_stream_statuses x using private.night_flock_v4_memberships mm where x.party_id=p.id and x.member_id=mm.id and mm.user_id=u and x.source_event_id=(c->>'sourceID')::uuid;
      delete from public.night_flock_v4_party_activities x using private.night_flock_v4_activity_ledger l where x.party_id=p.id and x.ledger_id=l.id and l.user_id=u and l.source_event_id=(c->>'sourceID')::uuid;
      -- Pre-v4.1 rows have no source association.  A source-specific delete
      -- must leave them alone rather than guessing from mutable status fields.
      delete from public.night_flock_v4_statuses x using private.night_flock_v4_memberships mm where x.party_id=p.id and x.member_id=mm.id and mm.user_id=u and x.source_event_id=(c->>'sourceID')::uuid;
    end if;
    update private.night_flock_v4_parties set revision=revision+1,updated_at=now() where id=p.id;
    return jsonb_build_object('accepted',true);
  end if;
  if cmd='publishSharedHabit' then
    select * into p from private.night_flock_v4_parties where id=(c->>'partyID')::uuid and deleted_at is null for update;
    select * into m from private.night_flock_v4_memberships where party_id=p.id and user_id=u and status='active' for update;
    select * into e from private.night_flock_v4_membership_epochs where id=(c->>'memberEpochID')::uuid and membership_id=m.id and ended_at is null for update;
    select * into a from private.night_flock_v4_shared_habits_agreements where id=(c->>'agreementID')::uuid and party_id=p.id and member_epoch_id=e.id and user_id=u;
    if p.id is null or m.id is null or e.id is null or a.id is null then raise exception 'current_membership_required'; end if;
    if exists(select 1 from private.night_flock_v4_shared_habits_tombstones t where t.party_id=p.id and t.user_id=u and (t.source_id=(c->>'sourceID')::uuid or (t.all_sources and t.member_epoch_id=e.id))) then raise exception 'shared_history_deleted'; end if;
    if c->>'kind'='sleep' and c->>'timeZoneIdentifier'<>a.time_zone_identifier then raise exception 'agreement_timezone_mismatch'; end if;
    if c->>'kind'='sleep' and (c->>'localDate')::date<a.first_eligible_sleep_night then raise exception 'publication_before_agreement'; end if;
    if c->>'kind'='windDown' and (c->>'localDate')::date<a.first_eligible_wind_down_date then raise exception 'publication_before_agreement'; end if;
    if c->>'kind'='phoneAway' and (c->>'localDate')::date<a.first_eligible_activity_date then raise exception 'publication_before_agreement'; end if;
    select * into existing from private.night_flock_v4_shared_habits_records r where r.party_id=p.id and r.author_user_id=u and r.source_id=(c->>'sourceID')::uuid and r.kind=c->>'kind' for update;
    if existing.id is not null and existing.revision>=(c->>'revision')::bigint then
      if existing.revision=(c->>'revision')::bigint and (existing.local_date,existing.time_zone_identifier,existing.minutes,existing.outcome,existing.protection_minutes,existing.evidence) is distinct from ((c->>'localDate')::date,c->>'timeZoneIdentifier',(c->>'minutes')::smallint,nullif(c->>'outcome',''),nullif(c->>'protectionMinutes','')::smallint,c->>'evidence') then raise exception 'stale_revision'; end if;
      return jsonb_build_object('accepted',true,'archiveRevision',existing.archive_revision);
    end if;
    select private.night_flock_v4_profile_json(px) into pr from private.night_flock_v4_profiles px where px.user_id=u;
    update private.night_flock_v4_parties set revision=revision+1,updated_at=now() where id=p.id returning revision into next_revision;
    if existing.id is null then
      insert into private.night_flock_v4_shared_habits_records(party_id,member_id,member_epoch_id,agreement_id,author_user_id,source_id,revision,kind,local_date,time_zone_identifier,minutes,outcome,protection_minutes,evidence,profile_snapshot,archive_revision)
      values(p.id,m.id,e.id,a.id,u,(c->>'sourceID')::uuid,(c->>'revision')::bigint,c->>'kind',(c->>'localDate')::date,c->>'timeZoneIdentifier',(c->>'minutes')::smallint,nullif(c->>'outcome',''),nullif(c->>'protectionMinutes','')::smallint,c->>'evidence',coalesce(pr,'{}'::jsonb),next_revision);
    else
      update private.night_flock_v4_shared_habits_records set revision=(c->>'revision')::bigint,local_date=(c->>'localDate')::date,time_zone_identifier=c->>'timeZoneIdentifier',minutes=(c->>'minutes')::smallint,outcome=nullif(c->>'outcome',''),protection_minutes=nullif(c->>'protectionMinutes','')::smallint,evidence=c->>'evidence',archive_revision=next_revision,updated_at=now() where id=existing.id;
    end if;
    return jsonb_build_object('accepted',true,'archiveRevision',next_revision);
  end if;
  if cmd='migrateSharedHabits' then
    select * into p from private.night_flock_v4_parties where id=(c->>'partyID')::uuid and deleted_at is null for update;
    select * into m from private.night_flock_v4_memberships where party_id=p.id and user_id=u and status='active' for update;
    select * into e from private.night_flock_v4_membership_epochs where membership_id=m.id and ended_at is null;
    select * into a from private.night_flock_v4_shared_habits_agreements where id=(c->>'agreementID')::uuid and party_id=p.id and member_epoch_id=e.id and user_id=u;
    if p.id is null or a.id is null then raise exception 'current_membership_required'; end if;
    update private.night_flock_v4_parties set revision=revision+1,updated_at=now() where id=p.id returning revision into next_revision;
    insert into private.night_flock_v4_shared_habits_records(party_id,member_id,member_epoch_id,agreement_id,author_user_id,source_id,revision,kind,local_date,activity_date,time_zone_identifier,minutes,outcome,evidence,profile_snapshot,archive_revision,migrated_at)
    select p.id,m.id,e.id,a.id,u,q.source_id,q.revision,q.kind,null,q.activity_date,a.time_zone_identifier,q.minutes,q.outcome,'none',coalesce(private.night_flock_v4_profile_json(px),'{}'::jsonb)||jsonb_build_object('snapshotLabel','migration'),next_revision,now()
    from (
      select distinct on (source_id,kind) source_id,kind,revision,activity_date,minutes,outcome,occurred_at from (
        select l.source_event_id source_id,case when x.kind='windDown' then 'windDown' else 'phoneAway' end kind,x.revision,(x.observed_at at time zone a.time_zone_identifier)::date activity_date,(round((case when x.kind='windDown' then x.wind_down_minutes else x.phone_away_minutes end)::numeric/5)*5)::int minutes,x.outcome,x.observed_at occurred_at
        from public.night_flock_v4_party_activities x join private.night_flock_v4_activity_ledger l on l.id=x.ledger_id and l.user_id=u where x.party_id=p.id and x.observed_at<a.accepted_at
        union all
        select s.source_event_id,case when s.kind='windDown' then 'windDown' else 'phoneAway' end,s.revision,(s.occurred_at at time zone a.time_zone_identifier)::date,(round((case when s.kind='windDown' then s.wind_down_minutes else s.phone_away_minutes end)::numeric/5)*5)::int,s.outcome,s.occurred_at
        from private.night_flock_v4_membership_stream_activities s join private.night_flock_v4_memberships authored on authored.id=s.member_id and authored.user_id=u where s.party_id=p.id and s.occurred_at<a.accepted_at
      ) candidates order by source_id,kind,revision desc,occurred_at desc
    ) q left join private.night_flock_v4_profiles px on px.user_id=u
    where not exists(select 1 from private.night_flock_v4_shared_habits_tombstones t where t.party_id=p.id and t.user_id=u and (t.all_sources or t.source_id=q.source_id))
    on conflict do nothing;
    return jsonb_build_object('accepted',true);
  end if;
  -- These command results bind consent to the party mutated in this very
  -- transaction. A client must never guess from its post-command list.
  if cmd='createParty' then
    if char_length(btrim(c->>'name')) not between 1 and 48 then raise exception 'Invalid party name'; end if;
    insert into private.night_flock_v4_parties(host_user_id,name,normalized_name,time_zone_identifier)
    values(u,btrim(c->>'name'),lower(btrim(c->>'name')),c->>'timeZoneIdentifier') returning * into p;
    insert into private.night_flock_v4_memberships(party_id,user_id,role) values(p.id,u,'host');
    insert into private.night_flock_v4_rounds(party_id,round_number,time_zone_identifier) values(p.id,1,p.time_zone_identifier);
    return jsonb_build_object('accepted',true,'resolvedPartyID',p.id);
  end if;
  if cmd='redeemInvite' then
    select * into i from private.night_flock_v4_invites where lookup_digest=extensions.digest(c->>'inviteCode','sha256') and revoked_at is null and expires_at>now() for update;
    if i.id is null then raise exception 'invite_unavailable'; end if;
    select * into p from private.night_flock_v4_parties where id=i.party_id and deleted_at is null for update;
    if p.id is null then raise exception 'invite_unavailable'; end if;
    select * into m from private.night_flock_v4_memberships where party_id=p.id and user_id=u for update;
    if m.id is null or m.status<>'active' then
      if exists(select 1 from private.night_flock_v4_memberships x where x.party_id=p.id and x.status='active' and private.night_flock_users_blocked(u,x.user_id)) then raise exception 'blocked_membership'; end if;
      insert into private.night_flock_v4_memberships(party_id,user_id,role,status,joined_at,left_at)
      values(p.id,u,'member','active',now(),null)
      on conflict(party_id,user_id) do update set status='active',joined_at=excluded.joined_at,left_at=null;
      update private.night_flock_v4_parties set revision=revision+1,updated_at=now() where id=p.id;
    end if;
    return jsonb_build_object('accepted',true,'resolvedPartyID',p.id);
  end if;
  if cmd='deleteAccount' then
    -- The old V4 deletion path only revises active memberships. Archive
    -- readers also need former-author removal to invalidate their cursors.
    update private.night_flock_v4_parties party set revision=party.revision+1,updated_at=now()
    where party.id in (
      select r.party_id from private.night_flock_v4_shared_habits_records r where r.author_user_id=u
      union select ag.party_id from private.night_flock_v4_shared_habits_agreements ag where ag.user_id=u
    ) and party.deleted_at is null;
  end if;
  out:=private.night_flock_v4_apply_pre_shared_habits(u,c);
  -- Atomic create/redeem agreement fields are deliberately not activated until the
  -- V4 command result returns a command-scoped party identifier.
  if cmd='deleteParty' then delete from private.night_flock_v4_shared_habits_records where party_id=(c->>'partyID')::uuid; delete from private.night_flock_v4_shared_habits_agreements where party_id=(c->>'partyID')::uuid; end if;
  if cmd='deleteAccount' then delete from private.night_flock_v4_shared_habits_records where author_user_id=u; delete from private.night_flock_v4_shared_habits_agreements where user_id=u; end if;
  if cmd='publishActivity' then
    delete from private.night_flock_v4_membership_stream_activities s using private.night_flock_v4_memberships mm where s.member_id=mm.id and mm.user_id=u and s.source_event_id=(c->>'sourceEventID')::uuid and private.night_flock_v4_shared_habits_withdrawal_blocks(s.party_id,u,s.source_event_id,s.member_epoch_id,(c->>'startedAt')::timestamptz);
    delete from public.night_flock_v4_party_activities x using private.night_flock_v4_activity_ledger l where x.ledger_id=l.id and l.user_id=u and l.source_event_id=(c->>'sourceEventID')::uuid and private.night_flock_v4_shared_habits_withdrawal_blocks(x.party_id,u,l.source_event_id,(select epoch_row.id from private.night_flock_v4_membership_epochs epoch_row where epoch_row.membership_id=x.member_id and epoch_row.ended_at is null),l.started_at);
  end if;
  return out;
end $$;

-- The pre-archive V4 implementation fans a status into every active party in
-- one call.  Split only that command out so a withdrawn party can acquire its
-- exact source tombstone before either its public status or its membership
-- stream row is written, without suppressing the same source in another party.
alter function private.night_flock_v4_apply_pre_shared_habits(uuid,jsonb) rename to night_flock_v4_apply_pre_shared_habits_status_legacy;
create or replace function private.night_flock_v4_apply_pre_shared_habits(u uuid,c jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  cmd text:=c->>'command'; obs timestamptz:=(c->>'observedAt')::timestamptz;
  m private.night_flock_v4_memberships%rowtype; e private.night_flock_v4_membership_epochs%rowtype; r private.night_flock_v4_rounds%rowtype;
begin
  if cmd<>'publishStatus' then return private.night_flock_v4_apply_pre_shared_habits_status_legacy(u,c); end if;
  if c->>'sharingScope'='membership' and (obs<now()-interval '90 days' or obs>now()+interval '5 minutes') then raise exception 'membership_status_outside_window'; end if;
  for m in select membership.* from private.night_flock_v4_memberships membership join private.night_flock_v4_parties party on party.id=membership.party_id and party.deleted_at is null where membership.user_id=u and membership.status='active' order by membership.party_id loop
    -- Match deleteSharedHabitHistory's lock order.  The source tombstone is
    -- written before the first public or membership status effect.
    perform 1 from private.night_flock_v4_parties where id=m.party_id for update;
    select * into e from private.night_flock_v4_membership_epochs where membership_id=m.id and ended_at is null;
    if private.night_flock_v4_shared_habits_withdrawal_blocks(m.party_id,u,(c->>'sourceEventID')::uuid,e.id,obs) then
      insert into private.night_flock_v4_shared_habits_tombstones(party_id,user_id,source_id)
      values(m.party_id,u,(c->>'sourceEventID')::uuid) on conflict(party_id,user_id,source_id) do nothing;
      continue;
    end if;
    if c->>'sharingScope' is distinct from 'membership' then
      select * into r from private.night_flock_v4_rounds where party_id=m.party_id and status='active' and obs>=(starts_on::timestamp at time zone time_zone_identifier) and obs<((ends_on+1)::timestamp at time zone time_zone_identifier);
      if r.id is null then continue; end if;
      insert into public.night_flock_v4_statuses(party_id,round_id,member_id,revision,observed_at,expires_at,status,source_event_id)
      values(m.party_id,r.id,m.id,(c->>'revision')::int,obs,obs+case when c->>'status' in('windDownCompleted','phoneAwayCompleted') then interval '12 hours' else interval '30 minutes' end,c->>'status',(c->>'sourceEventID')::uuid)
      on conflict(party_id,member_id) do update set round_id=excluded.round_id,revision=excluded.revision,observed_at=excluded.observed_at,expires_at=excluded.expires_at,status=excluded.status,source_event_id=excluded.source_event_id
      where excluded.observed_at>public.night_flock_v4_statuses.observed_at or (excluded.observed_at=public.night_flock_v4_statuses.observed_at and excluded.revision>=public.night_flock_v4_statuses.revision);
      continue;
    end if;
    select * into r from private.night_flock_v4_rounds where party_id=m.party_id and status='active' and started_at<=obs and obs>=(starts_on::timestamp at time zone time_zone_identifier) and obs<((ends_on+1)::timestamp at time zone time_zone_identifier) order by started_at desc nulls last limit 1;
    if r.id is not null then
      insert into public.night_flock_v4_statuses(party_id,round_id,member_id,revision,observed_at,expires_at,status,source_event_id)
      values(m.party_id,r.id,m.id,(c->>'revision')::int,obs,obs+case when c->>'status' in('windDownCompleted','phoneAwayCompleted') then interval '12 hours' else interval '30 minutes' end,c->>'status',(c->>'sourceEventID')::uuid)
      on conflict(party_id,member_id) do update set round_id=excluded.round_id,revision=excluded.revision,observed_at=excluded.observed_at,expires_at=excluded.expires_at,status=excluded.status,source_event_id=excluded.source_event_id
      where excluded.observed_at>public.night_flock_v4_statuses.observed_at or (excluded.observed_at=public.night_flock_v4_statuses.observed_at and excluded.revision>=public.night_flock_v4_statuses.revision);
    end if;
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
  return jsonb_build_object('accepted',true);
end $$;

alter function public.night_flock_v4_state(uuid,text,uuid,text) rename to night_flock_v4_state_pre_shared_habits;
-- The cursor contains only an archive revision and the ordered public record key.
-- It is not an offset: later publications cannot shift a continuation page.
create or replace function public.night_flock_v4_state(p_user_id uuid,p_scope text default 'list',p_party_id uuid default null,p_cursor text default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare p private.night_flock_v4_parties%rowtype; a private.night_flock_v4_shared_habits_agreements%rowtype;
  snap int; cursor_date date; cursor_member uuid; cursor_record uuid; page jsonb; next_cursor text; periods jsonb; retained jsonb; base jsonb;
begin
  if p_user_id is null or not private.is_apple_linked_night_flock_user(p_user_id) then raise exception 'Apple-linked account required'; end if;
  if p_scope='list' then
    base:=public.night_flock_v4_state_pre_shared_habits(p_user_id,p_scope,p_party_id,p_cursor);
    select coalesce(jsonb_agg(jsonb_build_object('partyID',q.party_id,'partyName',q.party_name,'recordCount',q.record_count) order by q.party_name),'[]'::jsonb) into retained from (
      select r.party_id,coalesce((select ag.party_name_snapshot from private.night_flock_v4_shared_habits_agreements ag where ag.party_id=r.party_id and ag.user_id=p_user_id order by ag.accepted_at desc limit 1),'Slumber Party') party_name,count(distinct (r.source_id,r.kind))::int record_count
      from private.night_flock_v4_shared_habits_records r join private.night_flock_v4_parties party on party.id=r.party_id and party.deleted_at is null
      where r.author_user_id=p_user_id and exists(select 1 from private.night_flock_v4_memberships mine where mine.party_id=r.party_id and mine.user_id=p_user_id and mine.status<>'active') group by r.party_id
    ) q;
    return base||jsonb_build_object('sharedHabitsVersion',1,'retainedSharedHabitParties',retained);
  end if;
  if p_scope<>'habits' then return public.night_flock_v4_state_pre_shared_habits(p_user_id,p_scope,p_party_id,p_cursor); end if;
  select * into p from private.night_flock_v4_parties where id=p_party_id and deleted_at is null for update;
  if p.id is null or not private.night_flock_v4_member(p_user_id,p.id) then raise exception 'current_membership_required'; end if;
  if p_cursor is null then snap:=p.revision;
  else
    begin
      snap:=split_part(p_cursor,'|',1)::int; cursor_date:=nullif(split_part(p_cursor,'|',2),'')::date; cursor_member:=split_part(p_cursor,'|',3)::uuid; cursor_record:=split_part(p_cursor,'|',4)::uuid;
    exception when others then raise exception 'Invalid cursor'; end;
    if snap<1 or snap<>p.revision then raise exception 'stale_revision'; end if;
  end if;
  select ag.* into a from private.night_flock_v4_shared_habits_agreements ag join private.night_flock_v4_membership_epochs e on e.id=ag.member_epoch_id join private.night_flock_v4_memberships m on m.id=e.membership_id where ag.party_id=p.id and ag.user_id=p_user_id and m.status='active' and e.ended_at is null order by ag.accepted_at desc limit 1;
  if a.id is null then return jsonb_build_object('agreement',null,'records','[]'::jsonb,'nextCursor',null,'snapshotRevision',p.revision,'periods','[]'::jsonb); end if;
  with ordered as (
    select r.*, m.status<>'active' former from private.night_flock_v4_shared_habits_records r join private.night_flock_v4_memberships m on m.id=r.member_id
    where r.party_id=p.id and r.archive_revision<=snap and (p_cursor is null or (case when cursor_date is null then r.local_date is null and (r.member_id,r.id)<(cursor_member,cursor_record) else r.local_date is null or r.local_date<cursor_date or (r.local_date=cursor_date and (r.member_id,r.id)<(cursor_member,cursor_record)) end))
      and not private.night_flock_users_blocked(p_user_id,r.author_user_id)
    order by r.local_date desc nulls last,r.member_id desc,r.id desc limit 101
  ), page_rows as (select * from ordered limit 100), last_row as (select * from page_rows order by local_date asc nulls first,member_id asc,id asc limit 1)
  select coalesce(jsonb_agg(jsonb_build_object('recordID',q.id,'partyID',q.party_id,'memberID',q.member_id,'sourceID',case when q.author_user_id=p_user_id then q.source_id else null end,'revision',q.revision,'kind',q.kind,'localDate',q.local_date,'activityDate',q.activity_date,'timeZoneIdentifier',q.time_zone_identifier,'minutes',q.minutes,'outcome',q.outcome,'protectionMinutes',q.protection_minutes,'evidence',q.evidence,'profileSnapshot',jsonb_build_object('displayName',coalesce(q.profile_snapshot->>'displayName','Shepherd'),'avatarID',q.profile_snapshot#>>'{presentation,avatarID}'),'isFormerMember',q.former,'migratedAt',q.migrated_at) order by q.local_date desc nulls last,q.member_id desc,q.id desc),'[]'::jsonb),case when (select count(*) from ordered)>100 then snap::text||'|'||coalesce((select local_date::text from last_row),'')||'|'||(select member_id::text from last_row)||'|'||(select id::text from last_row) else null end into page,next_cursor from page_rows q;
  with contributor as (select distinct on (r.member_id) r.member_id,r.author_user_id,ag.time_zone_identifier tz from private.night_flock_v4_shared_habits_records r join private.night_flock_v4_shared_habits_agreements ag on ag.id=r.agreement_id where r.party_id=p.id and r.archive_revision<=snap and not private.night_flock_users_blocked(p_user_id,r.author_user_id) order by r.member_id,ag.accepted_at desc,ag.id desc), basis as (select c.member_id,c.tz,case when v.kind in('sleep','windDown') then ((now() at time zone c.tz)::date-case when (now() at time zone c.tz)::time<time '12:00' then 1 else 0 end) else (now() at time zone c.tz)::date end ending_on, v.kind,v.period,v.days from contributor c cross join (values('sleep'::text,'lastNight'::text,1),('sleep','last7Nights',7),('sleep','last30Nights',30),('windDown','lastNight',1),('windDown','last7Nights',7),('windDown','last30Nights',30),('phoneAway','lastNight',1),('phoneAway','last7Nights',7),('phoneAway','last30Nights',30)) v(kind,period,days))
  select coalesce(jsonb_agg(jsonb_build_object('memberID',b.member_id,'kind',b.kind,'period',b.period,'endingOn',b.ending_on,'availableNights',b.days,'coveredNights',coalesce(s.covered,0),'averageMinutes',s.average_minutes,'method','eligibleMean') order by b.member_id,b.kind,b.days),'[]'::jsonb) into periods from basis b left join lateral (select count(*)::int covered,avg(day_minutes)::float8 average_minutes from (select r.local_date,case when b.kind='phoneAway' then sum(r.minutes) else max(r.minutes) end day_minutes from private.night_flock_v4_shared_habits_records r where r.party_id=p.id and r.member_id=b.member_id and r.kind=b.kind and r.local_date is not null and r.archive_revision<=snap and r.local_date between b.ending_on-(b.days-1) and b.ending_on group by r.local_date) daily) s on true;
  return jsonb_build_object('agreement',case when a.id is null then null else jsonb_build_object('agreementID',a.id,'memberEpochID',a.member_epoch_id,'acceptedAt',a.accepted_at,'timeZoneIdentifier',a.time_zone_identifier,'firstEligibleSleepNight',a.first_eligible_sleep_night) end,'records',page,'nextCursor',next_cursor,'snapshotRevision',snap,'periods',periods);
end $$;
revoke all on private.night_flock_v4_shared_habits_agreements,private.night_flock_v4_shared_habits_records,private.night_flock_v4_shared_habits_tombstones from public,anon,authenticated;
revoke all on function private.night_flock_v4_shared_habits_accept(uuid,uuid,text,uuid),private.night_flock_v4_shared_habits_withdrawal_blocks(uuid,uuid,uuid,uuid,timestamptz),private.night_flock_v4_apply_pre_shared_habits(uuid,jsonb),private.night_flock_v4_apply(uuid,jsonb),public.night_flock_v4_state_pre_shared_habits(uuid,text,uuid,text) from public,anon,authenticated;
revoke all on function public.night_flock_v4_state(uuid,text,uuid,text) from public,anon,authenticated; grant execute on function public.night_flock_v4_state(uuid,text,uuid,text) to service_role;
