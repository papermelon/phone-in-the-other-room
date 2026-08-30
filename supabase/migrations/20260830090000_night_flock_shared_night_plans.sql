-- Additive V4 social-habit-loop storage. These rows contain only seven-night
-- plan instances and factual receipt dimensions; no recurrence, app token,
-- custom text, Health sample, or Farm data is accepted here.
alter table private.night_flock_v4_shared_habits_agreements
  drop constraint if exists night_flock_v4_shared_habits_agreements_agreement_version_check;
alter table private.night_flock_v4_shared_habits_agreements
  add constraint night_flock_v4_shared_habits_agreements_agreement_version_check check(agreement_version in (1,2));

create table private.night_flock_v4_shared_night_plans (
  id uuid primary key, party_id uuid not null references private.night_flock_v4_parties(id) on delete cascade,
  member_id uuid not null references private.night_flock_v4_memberships(id) on delete cascade,
  member_epoch_id uuid not null references private.night_flock_v4_membership_epochs(id) on delete cascade,
  agreement_id uuid not null references private.night_flock_v4_shared_habits_agreements(id) on delete cascade,
  author_user_id uuid not null references auth.users(id) on delete cascade, revision bigint not null check(revision>=0),
  night_ending_date date not null, time_zone_identifier text not null check(char_length(time_zone_identifier) between 1 and 64),
  planned_wind_down_start timestamptz not null, intended_bedtime timestamptz not null, intended_wake_time timestamptz not null,
  morning_quiet_end timestamptz not null, before_bed_minutes smallint not null check(before_bed_minutes between 0 and 180),
  after_waking_minutes smallint not null check(after_waking_minutes between 0 and 180), evening_suggestion_ids jsonb not null default '[]'::jsonb,
  morning_suggestion_ids jsonb not null default '[]'::jsonb, superseded_at timestamptz, profile_snapshot jsonb not null,
  archive_revision int not null, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(party_id,member_epoch_id,night_ending_date,revision),
  check(jsonb_typeof(evening_suggestion_ids)='array' and jsonb_array_length(evening_suggestion_ids)<=3),
  check(jsonb_typeof(morning_suggestion_ids)='array' and jsonb_array_length(morning_suggestion_ids)<=2)
);
create table private.night_flock_v4_shared_night_plan_tombstones (
  party_id uuid not null references private.night_flock_v4_parties(id) on delete cascade,
  member_epoch_id uuid not null references private.night_flock_v4_membership_epochs(id) on delete cascade,
  agreement_id uuid not null references private.night_flock_v4_shared_habits_agreements(id) on delete cascade,
  author_user_id uuid not null references auth.users(id) on delete cascade,
  night_ending_date date not null, time_zone_identifier text not null check(char_length(time_zone_identifier) between 1 and 64),
  revision bigint not null check(revision >= 0), cancellation_authority text not null check(cancellation_authority in ('schedule','privacy')), archive_revision int not null,
  cancelled_at timestamptz not null default now(),
  primary key(party_id,member_epoch_id,night_ending_date)
);
create table private.night_flock_v4_shared_night_receipts (
  id uuid primary key, party_id uuid not null references private.night_flock_v4_parties(id) on delete cascade,
  member_id uuid not null references private.night_flock_v4_memberships(id) on delete cascade,
  member_epoch_id uuid not null references private.night_flock_v4_membership_epochs(id) on delete cascade,
  agreement_id uuid not null references private.night_flock_v4_shared_habits_agreements(id) on delete cascade,
  plan_id uuid references private.night_flock_v4_shared_night_plans(id) on delete set null, plan_revision bigint,
  author_user_id uuid not null references auth.users(id) on delete cascade, source_id uuid not null, revision bigint not null check(revision>=0),
  night_ending_date date not null, time_zone_identifier text not null check(char_length(time_zone_identifier) between 1 and 64),
  actual_start timestamptz, terminal_at timestamptz, outcome text not null check(outcome in('completed','partlyCompleted','unknown')),
  wind_down_minutes smallint check(wind_down_minutes between 0 and 180), protection_minutes smallint check(protection_minutes between 0 and 180),
  protection_evidence text not null check(protection_evidence in('observed','partial','unavailable','failedOpen','unknown')),
  emergency_exit_used boolean, profile_snapshot jsonb not null, archive_revision int not null, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  -- A terminal record is corrected in place for one contributor night. The
  -- source UUID is still retained for command provenance, but cannot create
  -- a second factual receipt for the same member/epoch/night.
  unique(party_id,member_epoch_id,night_ending_date),
  unique(party_id,member_epoch_id,source_id),
  check(protection_minutes is null or protection_evidence in('observed','partial'))
);
create index night_flock_shared_night_plans_party_date on private.night_flock_v4_shared_night_plans(party_id,night_ending_date,member_id);
create index night_flock_shared_night_receipts_party_date on private.night_flock_v4_shared_night_receipts(party_id,night_ending_date desc,member_id);

alter function private.night_flock_v4_apply(uuid,jsonb) rename to night_flock_v4_apply_pre_social_loop;
create or replace function private.night_flock_v4_apply(u uuid,c jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare cmd text:=c->>'command'; p private.night_flock_v4_parties%rowtype; m private.night_flock_v4_memberships%rowtype; e private.night_flock_v4_membership_epochs%rowtype; a private.night_flock_v4_shared_habits_agreements%rowtype; existing_plan private.night_flock_v4_shared_night_plans%rowtype; latest_plan private.night_flock_v4_shared_night_plans%rowtype; existing_tombstone private.night_flock_v4_shared_night_plan_tombstones%rowtype; existing_receipt private.night_flock_v4_shared_night_receipts%rowtype; next_revision int; receipt_transport_revision bigint; snapshot jsonb; legacy_result jsonb;
begin
  -- The v2 branches below do not delegate to the legacy apply function, so
  -- they must repeat its authoritative Apple-linked account gate.
  if (cmd='acceptSharedHabitsAgreement' and (c->>'agreementVersion')::int=2) or cmd in ('publishSharedNightPlan','cancelSharedNightPlan','publishSharedNightReceipt') then
    if u is null or not private.is_apple_linked_night_flock_user(u) then raise exception 'Apple-linked account required'; end if;
  end if;
  if cmd='acceptSharedHabitsAgreement' and (c->>'agreementVersion')::int=2 then
    select * into p from private.night_flock_v4_parties where id=(c->>'partyID')::uuid and deleted_at is null for update;
    select * into m from private.night_flock_v4_memberships where party_id=p.id and user_id=u and status='active' for update;
    select * into e from private.night_flock_v4_membership_epochs where membership_id=m.id and ended_at is null for update;
    if p.id is null or m.id is null or e.id is null then raise exception 'current_membership_required'; end if;
    select * into a from private.night_flock_v4_shared_habits_agreements where member_epoch_id=e.id and agreement_version=2 for update;
    if a.id is null then
      insert into private.night_flock_v4_shared_habits_agreements(party_id,member_epoch_id,user_id,agreement_version,time_zone_identifier,party_name_snapshot,first_eligible_sleep_night,first_eligible_wind_down_date,first_eligible_activity_date)
      values(p.id,e.id,u,2,c->>'timeZoneIdentifier',p.name,((now() at time zone (c->>'timeZoneIdentifier'))::date + case when (now() at time zone (c->>'timeZoneIdentifier'))::time > time '12:00' then 2 else 1 end),(now() at time zone (c->>'timeZoneIdentifier'))::date,(now() at time zone (c->>'timeZoneIdentifier'))::date) returning * into a;
    end if;
    return jsonb_build_object('accepted',true,'agreementID',a.id,'memberEpochID',a.member_epoch_id,'agreementVersion',2);
  end if;
  if cmd in ('deleteSharedHabitHistory','deleteParty','deleteAccount') then
    legacy_result:=private.night_flock_v4_apply_pre_social_loop(u,c);
    if cmd='deleteSharedHabitHistory' then
      if c ? 'allSources' then
        delete from private.night_flock_v4_shared_night_receipts where party_id=(c->>'partyID')::uuid and author_user_id=u;
        delete from private.night_flock_v4_shared_night_plans where party_id=(c->>'partyID')::uuid and author_user_id=u;
        delete from private.night_flock_v4_shared_night_plan_tombstones where party_id=(c->>'partyID')::uuid and author_user_id=u;
      else
        delete from private.night_flock_v4_shared_night_receipts where party_id=(c->>'partyID')::uuid and author_user_id=u and source_id=(c->>'sourceID')::uuid;
      end if;
    elsif cmd='deleteParty' then
      delete from private.night_flock_v4_shared_night_receipts where party_id=(c->>'partyID')::uuid;
      delete from private.night_flock_v4_shared_night_plans where party_id=(c->>'partyID')::uuid;
      delete from private.night_flock_v4_shared_night_plan_tombstones where party_id=(c->>'partyID')::uuid;
    else
      delete from private.night_flock_v4_shared_night_receipts where author_user_id=u;
      delete from private.night_flock_v4_shared_night_plans where author_user_id=u;
      delete from private.night_flock_v4_shared_night_plan_tombstones where author_user_id=u;
    end if;
    return legacy_result;
  end if;
  if cmd not in ('publishSharedNightPlan','cancelSharedNightPlan','publishSharedNightReceipt') then return private.night_flock_v4_apply_pre_social_loop(u,c); end if;
  select * into p from private.night_flock_v4_parties where id=(c->>'partyID')::uuid and deleted_at is null for update;
  select * into m from private.night_flock_v4_memberships where party_id=p.id and user_id=u and status='active' for update;
  select * into e from private.night_flock_v4_membership_epochs where id=(c->>'memberEpochID')::uuid and membership_id=m.id and ended_at is null;
  select * into a from private.night_flock_v4_shared_habits_agreements where id=(c->>'agreementID')::uuid and member_epoch_id=e.id and agreement_version=2;
  if p.id is null or m.id is null or e.id is null or a.id is null then raise exception 'publication_before_agreement'; end if;
  if c ?| array['selectedApps','appTokens','bundleID','bundleIDs','categoryID','screenTimeData','healthSamples','customRoutineText','deviceCredential'] then raise exception 'invalid_shared_night_payload'; end if;
  if c->>'timeZoneIdentifier' is distinct from a.time_zone_identifier then raise exception 'agreement_timezone_mismatch'; end if;
  if exists(select 1 from private.night_flock_v4_shared_habits_tombstones t where t.party_id=p.id and t.user_id=u and ((t.all_sources and t.member_epoch_id=e.id) or (cmd='publishSharedNightReceipt' and not t.all_sources and t.source_id=(c->>'sourceID')::uuid))) then raise exception 'shared_history_deleted'; end if;
  if cmd='cancelSharedNightPlan' then
    if (c->>'nightEndingDate')::date < greatest(a.first_eligible_wind_down_date,((now() at time zone a.time_zone_identifier)::date)) or (c->>'nightEndingDate')::date > ((now() at time zone a.time_zone_identifier)::date+7) then raise exception 'publication_outside_plan_window'; end if;
    select * into latest_plan from private.night_flock_v4_shared_night_plans
      where party_id=p.id and member_epoch_id=e.id and night_ending_date=(c->>'nightEndingDate')::date
      order by revision desc limit 1;
    select * into existing_tombstone from private.night_flock_v4_shared_night_plan_tombstones
      where party_id=p.id and member_epoch_id=e.id and night_ending_date=(c->>'nightEndingDate')::date;

    -- Privacy is an explicit one-night authority, not a schedule revision.
    -- It upgrades a reversible schedule tombstone even when it arrived later
    -- with a lower local revision, then stays terminal for this epoch/night.
    if c->>'cancellationAuthority'='privacy' then
      if existing_tombstone.party_id is not null and existing_tombstone.cancellation_authority='privacy' then
        return jsonb_build_object('accepted',true,'staleRevision',true,'archiveRevision',p.revision);
      end if;
      next_revision:=p.revision+1;
      update private.night_flock_v4_parties set revision=next_revision,updated_at=now() where id=p.id;
      if existing_tombstone.party_id is null then
        insert into private.night_flock_v4_shared_night_plan_tombstones(party_id,member_epoch_id,agreement_id,author_user_id,night_ending_date,time_zone_identifier,revision,cancellation_authority,archive_revision)
        values(p.id,e.id,a.id,u,(c->>'nightEndingDate')::date,c->>'timeZoneIdentifier',greatest((c->>'revision')::bigint,coalesce(latest_plan.revision,0)),'privacy',next_revision);
      else
        update private.night_flock_v4_shared_night_plan_tombstones
        set revision=greatest(revision,(c->>'revision')::bigint,coalesce(latest_plan.revision,0)),
            cancellation_authority='privacy', archive_revision=next_revision, cancelled_at=now()
        where party_id=p.id and member_epoch_id=e.id and night_ending_date=(c->>'nightEndingDate')::date;
      end if;
      return jsonb_build_object('accepted',true,'archiveRevision',next_revision);
    end if;

    -- Schedule cancellation follows plan revision ordering. A delayed
    -- schedule command cannot hide the equal-or-newer occurrence already
    -- persisted by another device or an offline replay.
    if latest_plan.id is not null and latest_plan.planned_wind_down_start<=now() then
      raise exception 'shared_night_plan_frozen';
    end if;
    if existing_tombstone.party_id is not null and existing_tombstone.cancellation_authority='privacy'
       or latest_plan.id is not null and latest_plan.revision >= (c->>'revision')::bigint
       or existing_tombstone.party_id is not null and existing_tombstone.revision >= (c->>'revision')::bigint
    then return jsonb_build_object('accepted',true,'staleRevision',true,'archiveRevision',p.revision); end if;
    next_revision:=p.revision+1;
    update private.night_flock_v4_parties set revision=next_revision,updated_at=now() where id=p.id;
    insert into private.night_flock_v4_shared_night_plan_tombstones(party_id,member_epoch_id,agreement_id,author_user_id,night_ending_date,time_zone_identifier,revision,cancellation_authority,archive_revision)
    values(p.id,e.id,a.id,u,(c->>'nightEndingDate')::date,c->>'timeZoneIdentifier',(c->>'revision')::bigint,c->>'cancellationAuthority',next_revision)
    on conflict(party_id,member_epoch_id,night_ending_date) do update set revision=excluded.revision,archive_revision=excluded.archive_revision,cancelled_at=now();
    return jsonb_build_object('accepted',true,'archiveRevision',next_revision);
  end if;
  if cmd='publishSharedNightPlan' then
    if (c->>'nightEndingDate')::date < greatest(a.first_eligible_wind_down_date,((now() at time zone a.time_zone_identifier)::date+1)) or (c->>'nightEndingDate')::date > ((now() at time zone a.time_zone_identifier)::date+7) then raise exception 'publication_outside_plan_window'; end if;
    select * into latest_plan from private.night_flock_v4_shared_night_plans where party_id=p.id and member_epoch_id=e.id and night_ending_date=(c->>'nightEndingDate')::date order by revision desc limit 1;
    if exists(select 1 from private.night_flock_v4_shared_night_plan_tombstones t where t.party_id=p.id and t.member_epoch_id=e.id and t.night_ending_date=(c->>'nightEndingDate')::date and t.cancellation_authority='privacy') then raise exception 'shared_night_plan_cancelled'; end if;
    if exists(select 1 from private.night_flock_v4_shared_night_plan_tombstones t where t.party_id=p.id and t.member_epoch_id=e.id and t.night_ending_date=(c->>'nightEndingDate')::date and t.cancellation_authority='schedule' and t.revision >= (c->>'revision')::bigint) then return jsonb_build_object('accepted',true,'staleRevision',true,'archiveRevision',p.revision); end if;
    delete from private.night_flock_v4_shared_night_plan_tombstones t where t.party_id=p.id and t.member_epoch_id=e.id and t.night_ending_date=(c->>'nightEndingDate')::date and t.cancellation_authority='schedule' and t.revision<(c->>'revision')::bigint;
    if latest_plan.id is not null and latest_plan.revision >= (c->>'revision')::bigint then
      return jsonb_build_object('accepted',true,'staleRevision',true,'archiveRevision',p.revision);
    end if;
    if (c->>'plannedWindDownStart')::timestamptz<=now()
       or (latest_plan.id is not null and latest_plan.planned_wind_down_start<=now())
    then raise exception 'shared_night_plan_frozen'; end if;
    if coalesce((c->>'beforeBedMinutes')::int not between 0 and 180,true) or coalesce((c->>'afterWakingMinutes')::int not between 0 and 180,true) or (c->>'plannedWindDownStart')::timestamptz>(c->>'intendedBedtime')::timestamptz or (c->>'intendedBedtime')::timestamptz>=(c->>'intendedWakeTime')::timestamptz or (c->>'intendedWakeTime')::timestamptz>(c->>'morningQuietEnd')::timestamptz or mod(extract(epoch from (c->>'plannedWindDownStart')::timestamptz),300)<>0 or mod(extract(epoch from (c->>'intendedBedtime')::timestamptz),300)<>0 or mod(extract(epoch from (c->>'intendedWakeTime')::timestamptz),300)<>0 or mod(extract(epoch from (c->>'morningQuietEnd')::timestamptz),300)<>0 or extract(epoch from ((c->>'intendedBedtime')::timestamptz-(c->>'plannedWindDownStart')::timestamptz))<>(c->>'beforeBedMinutes')::int*60 or extract(epoch from ((c->>'morningQuietEnd')::timestamptz-(c->>'intendedWakeTime')::timestamptz))<>(c->>'afterWakingMinutes')::int*60 or ((c->>'intendedWakeTime')::timestamptz at time zone a.time_zone_identifier)::date<>(c->>'nightEndingDate')::date or ((c->>'morningQuietEnd')::timestamptz at time zone a.time_zone_identifier)::date not in ((c->>'nightEndingDate')::date,(c->>'nightEndingDate')::date+1) or ((c->>'plannedWindDownStart')::timestamptz at time zone a.time_zone_identifier)::date not in ((c->>'nightEndingDate')::date,(c->>'nightEndingDate')::date-1) or ((c->>'intendedBedtime')::timestamptz at time zone a.time_zone_identifier)::date not in ((c->>'nightEndingDate')::date,(c->>'nightEndingDate')::date-1) then raise exception 'invalid_plan_chronology'; end if;
  else
    if (c->>'nightEndingDate')::date<a.first_eligible_wind_down_date or (c->>'nightEndingDate')::date>((now() at time zone a.time_zone_identifier)::date+1) then raise exception 'publication_outside_receipt_window'; end if;
    -- Both cancellation authorities remove the current canonical occurrence.
    -- Privacy is terminal; a schedule cancellation becomes receiptable again
    -- only when a newer plan publication removes its tombstone. Do this before
    -- source/revision handling so delayed, second-device, planless, and
    -- plan-bound receipts cannot bypass the authority fence.
    if exists(
      select 1 from private.night_flock_v4_shared_night_plan_tombstones t
      where t.party_id=p.id
        and t.member_epoch_id=e.id
        and t.night_ending_date=(c->>'nightEndingDate')::date
    ) then raise exception 'shared_night_plan_cancelled'; end if;
    if nullif(c->>'sourceID','') is null then raise exception 'invalid_receipt_source'; end if;
    if c->>'outcome' in ('completed','partlyCompleted') and not (c ? 'actualStart') then raise exception 'receipt_actual_start_required'; end if;
    if c ? 'actualStart' and (c->>'actualStart')::timestamptz<a.accepted_at then raise exception 'publication_before_agreement'; end if;
    if c ? 'terminalAt' and (c->>'terminalAt')::timestamptz<a.accepted_at then raise exception 'publication_before_agreement'; end if;
    if (c ? 'planID')<>(c ? 'planRevision') then raise exception 'invalid_plan_binding'; end if;
    if (c ? 'actualStart' and mod(extract(epoch from (c->>'actualStart')::timestamptz),300)<>0) or (c ? 'terminalAt' and mod(extract(epoch from (c->>'terminalAt')::timestamptz),300)<>0) then raise exception 'invalid_receipt_chronology'; end if;
    if (c ? 'actualStart' and ((c->>'actualStart')::timestamptz at time zone a.time_zone_identifier)::date not in ((c->>'nightEndingDate')::date,(c->>'nightEndingDate')::date-1)) or (c ? 'terminalAt' and ((c->>'terminalAt')::timestamptz at time zone a.time_zone_identifier)::date not in ((c->>'nightEndingDate')::date,(c->>'nightEndingDate')::date-1,(c->>'nightEndingDate')::date+1)) or (c ? 'actualStart' and c ? 'terminalAt' and (c->>'terminalAt')::timestamptz<(c->>'actualStart')::timestamptz) then raise exception 'invalid_receipt_chronology'; end if;
    if c ? 'planID' then
      select * into existing_plan from private.night_flock_v4_shared_night_plans where id=(c->>'planID')::uuid and party_id=p.id and member_id=m.id and member_epoch_id=e.id and agreement_id=a.id and author_user_id=u and revision=(c->>'planRevision')::bigint and night_ending_date=(c->>'nightEndingDate')::date;
      if existing_plan.id is null then raise exception 'receipt_plan_mismatch'; end if;
    end if;
    -- A terminal timestamp on the following local day is only meaningful for
    -- the exact frozen plan whose morning quiet span crosses midnight. A
    -- planless receipt must not use that exception to upload arbitrary data.
    if c ? 'terminalAt' and ((c->>'terminalAt')::timestamptz at time zone a.time_zone_identifier)::date=(c->>'nightEndingDate')::date+1 then
      if not (c ? 'planID')
        or (existing_plan.morning_quiet_end at time zone a.time_zone_identifier)::date<>(c->>'nightEndingDate')::date+1
        or (c->>'terminalAt')::timestamptz<existing_plan.intended_wake_time
        or (c->>'terminalAt')::timestamptz>existing_plan.morning_quiet_end
      then raise exception 'invalid_receipt_chronology'; end if;
    end if;
    select * into existing_receipt from private.night_flock_v4_shared_night_receipts where party_id=p.id and member_epoch_id=e.id and night_ending_date=(c->>'nightEndingDate')::date for update;
    -- Corrections may add factual evidence, but a later terminal callback
    -- cannot replace the member-night winner with fewer Wind Down/protection
    -- minutes or a weaker outcome.
    if existing_receipt.id is not null and (
      coalesce((c->>'windDownMinutes')::int,0)<coalesce(existing_receipt.wind_down_minutes,0)
      or (coalesce((c->>'windDownMinutes')::int,0)=coalesce(existing_receipt.wind_down_minutes,0) and coalesce((c->>'protectionMinutes')::int,0)<coalesce(existing_receipt.protection_minutes,0))
      or (coalesce((c->>'windDownMinutes')::int,0)=coalesce(existing_receipt.wind_down_minutes,0) and coalesce((c->>'protectionMinutes')::int,0)=coalesce(existing_receipt.protection_minutes,0) and case c->>'outcome' when 'completed' then 2 when 'partlyCompleted' then 1 else 0 end < case existing_receipt.outcome when 'completed' then 2 when 'partlyCompleted' then 1 else 0 end)
      or (
        coalesce((c->>'windDownMinutes')::int,0)=coalesce(existing_receipt.wind_down_minutes,0)
        and coalesce((c->>'protectionMinutes')::int,0)=coalesce(existing_receipt.protection_minutes,0)
        and case c->>'outcome' when 'completed' then 2 when 'partlyCompleted' then 1 else 0 end = case existing_receipt.outcome when 'completed' then 2 when 'partlyCompleted' then 1 else 0 end
        and case c->>'protectionEvidence' when 'observed' then 4 when 'partial' then 3 when 'failedOpen' then 2 when 'unavailable' then 1 else 0 end
            < case existing_receipt.protection_evidence when 'observed' then 4 when 'partial' then 3 when 'failedOpen' then 2 when 'unavailable' then 1 else 0 end
      )
      or (
        coalesce((c->>'windDownMinutes')::int,0)=coalesce(existing_receipt.wind_down_minutes,0)
        and coalesce((c->>'protectionMinutes')::int,0)=coalesce(existing_receipt.protection_minutes,0)
        and case c->>'outcome' when 'completed' then 2 when 'partlyCompleted' then 1 else 0 end = case existing_receipt.outcome when 'completed' then 2 when 'partlyCompleted' then 1 else 0 end
        and case c->>'protectionEvidence' when 'observed' then 4 when 'partial' then 3 when 'failedOpen' then 2 when 'unavailable' then 1 else 0 end
            = case existing_receipt.protection_evidence when 'observed' then 4 when 'partial' then 3 when 'failedOpen' then 2 when 'unavailable' then 1 else 0 end
        and nullif(c->>'actualStart','')::timestamptz is not distinct from existing_receipt.actual_start
        and nullif(c->>'terminalAt','')::timestamptz is not distinct from existing_receipt.terminal_at
        and (not (c ? 'emergencyExitUsed') or (c->>'emergencyExitUsed')::boolean is not distinct from existing_receipt.emergency_exit_used)
      )
      or (
        coalesce((c->>'windDownMinutes')::int,0)=coalesce(existing_receipt.wind_down_minutes,0)
        and coalesce((c->>'protectionMinutes')::int,0)=coalesce(existing_receipt.protection_minutes,0)
        and case c->>'outcome' when 'completed' then 2 when 'partlyCompleted' then 1 else 0 end = case existing_receipt.outcome when 'completed' then 2 when 'partlyCompleted' then 1 else 0 end
        and case c->>'protectionEvidence' when 'observed' then 4 when 'partial' then 3 when 'failedOpen' then 2 when 'unavailable' then 1 else 0 end
            = case existing_receipt.protection_evidence when 'observed' then 4 when 'partial' then 3 when 'failedOpen' then 2 when 'unavailable' then 1 else 0 end
        and ((c->>'revision')::bigint < existing_receipt.revision
          or ((c->>'revision')::bigint = existing_receipt.revision
            and (
              coalesce(nullif(c->>'actualStart','')::timestamptz,'-infinity'::timestamptz),
              coalesce(nullif(c->>'terminalAt','')::timestamptz,'-infinity'::timestamptz),
              case c->>'emergencyExitUsed' when 'true' then 2 when 'false' then 1 else 0 end
            ) <= (
              coalesce(existing_receipt.actual_start,'-infinity'::timestamptz),
              coalesce(existing_receipt.terminal_at,'-infinity'::timestamptz),
              case existing_receipt.emergency_exit_used when true then 2 when false then 1 else 0 end
            )))
      )
    ) then return jsonb_build_object('accepted',true,'staleRevision',true,'archiveRevision',p.revision); end if;
    receipt_transport_revision:=case when existing_receipt.id is null then (c->>'revision')::bigint else greatest((c->>'revision')::bigint,existing_receipt.revision+1) end;
  end if;
  next_revision:=p.revision+1;
  update private.night_flock_v4_parties set revision=next_revision,updated_at=now() where id=p.id;
  snapshot:=jsonb_build_object('displayName',coalesce((select display_name from private.night_flock_v4_profiles where user_id=u),'Shepherd'));
  if cmd='publishSharedNightPlan' then
    update private.night_flock_v4_shared_night_plans set superseded_at=coalesce(superseded_at,now()),updated_at=now() where party_id=p.id and member_epoch_id=e.id and night_ending_date=(c->>'nightEndingDate')::date and superseded_at is null;
    insert into private.night_flock_v4_shared_night_plans(id,party_id,member_id,member_epoch_id,agreement_id,author_user_id,revision,night_ending_date,time_zone_identifier,planned_wind_down_start,intended_bedtime,intended_wake_time,morning_quiet_end,before_bed_minutes,after_waking_minutes,evening_suggestion_ids,morning_suggestion_ids,superseded_at,profile_snapshot,archive_revision)
    values((c->>'planID')::uuid,p.id,m.id,e.id,a.id,u,(c->>'revision')::bigint,(c->>'nightEndingDate')::date,c->>'timeZoneIdentifier',(c->>'plannedWindDownStart')::timestamptz,(c->>'intendedBedtime')::timestamptz,(c->>'intendedWakeTime')::timestamptz,(c->>'morningQuietEnd')::timestamptz,(c->>'beforeBedMinutes')::smallint,(c->>'afterWakingMinutes')::smallint,c->'eveningSuggestionIDs',c->'morningSuggestionIDs',null,snapshot,next_revision)
    on conflict(id) do nothing;
  else
    insert into private.night_flock_v4_shared_night_receipts(id,party_id,member_id,member_epoch_id,agreement_id,plan_id,plan_revision,author_user_id,source_id,revision,night_ending_date,time_zone_identifier,actual_start,terminal_at,outcome,wind_down_minutes,protection_minutes,protection_evidence,emergency_exit_used,profile_snapshot,archive_revision)
    values((c->>'receiptID')::uuid,p.id,m.id,e.id,a.id,nullif(c->>'planID','')::uuid,nullif(c->>'planRevision','')::bigint,u,(c->>'sourceID')::uuid,receipt_transport_revision,(c->>'nightEndingDate')::date,c->>'timeZoneIdentifier',nullif(c->>'actualStart','')::timestamptz,nullif(c->>'terminalAt','')::timestamptz,c->>'outcome',nullif(c->>'windDownMinutes','')::smallint,nullif(c->>'protectionMinutes','')::smallint,c->>'protectionEvidence',case when c ? 'emergencyExitUsed' then (c->>'emergencyExitUsed')::boolean else null end,snapshot,next_revision)
    on conflict(party_id,member_epoch_id,night_ending_date) do update set revision=excluded.revision,actual_start=excluded.actual_start,terminal_at=excluded.terminal_at,outcome=excluded.outcome,wind_down_minutes=excluded.wind_down_minutes,protection_minutes=excluded.protection_minutes,protection_evidence=excluded.protection_evidence,emergency_exit_used=coalesce(excluded.emergency_exit_used,private.night_flock_v4_shared_night_receipts.emergency_exit_used),archive_revision=excluded.archive_revision,updated_at=now() where excluded.revision>private.night_flock_v4_shared_night_receipts.revision;
  end if;
  return jsonb_build_object('accepted',true,'archiveRevision',next_revision);
end $$;

alter function public.night_flock_v4_state(uuid,text,uuid,text) rename to night_flock_v4_state_pre_social_loop;
create or replace function public.night_flock_v4_state(p_user_id uuid,p_scope text default 'list',p_party_id uuid default null,p_cursor text default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare base jsonb; plans jsonb; receipts jsonb; retained jsonb; current_v2_agreement boolean; current_agreement private.night_flock_v4_shared_habits_agreements%rowtype;
  snap int; cursor_revision int; next_shared_nights_cursor text; page_count int;
begin
  -- `sharedNights` is separately paged. It repeats the base authorization
  -- predicate without invoking the locked legacy archive reader, so this
  -- read-only state RPC never serializes writers.
  if p_scope='sharedNights' then
    if p_user_id is null or not private.is_apple_linked_night_flock_user(p_user_id) then raise exception 'Apple-linked account required'; end if;
    if p_party_id is null or not private.night_flock_v4_member(p_user_id,p_party_id) then raise exception 'current_membership_required'; end if;
    base:=jsonb_build_object('agreement',null,'records','[]'::jsonb,'nextCursor',null,'snapshotRevision',0,'periods','[]'::jsonb);
  else
    base:=public.night_flock_v4_state_pre_social_loop(p_user_id,p_scope,p_party_id,p_cursor);
  end if;
  if p_scope='list' then
    with owned as (
      select r.party_id,count(distinct (r.source_id::text||':'||r.kind))::int item_count from private.night_flock_v4_shared_habits_records r where r.author_user_id=p_user_id group by r.party_id
      union all select p0.party_id,count(*)::int from private.night_flock_v4_shared_night_plans p0 where p0.author_user_id=p_user_id group by p0.party_id
      union all select r0.party_id,count(*)::int from private.night_flock_v4_shared_night_receipts r0 where r0.author_user_id=p_user_id group by r0.party_id
    ), grouped as (
      select o.party_id,sum(o.item_count)::int item_count from owned o join private.night_flock_v4_parties p0 on p0.id=o.party_id and p0.deleted_at is null where exists(select 1 from private.night_flock_v4_memberships m0 where m0.party_id=o.party_id and m0.user_id=p_user_id and m0.status<>'active') group by o.party_id
    ) select coalesce(jsonb_agg(jsonb_build_object('partyID',g.party_id,'partyName',coalesce((select a.party_name_snapshot from private.night_flock_v4_shared_habits_agreements a where a.party_id=g.party_id and a.user_id=p_user_id order by a.accepted_at desc limit 1),'Slumber Party'),'recordCount',g.item_count) order by g.party_id),'[]'::jsonb) into retained from grouped g;
    return base||jsonb_build_object('sharedHabitsVersion',2,'sharedRoutinePlansVersion',1,'retainedSharedHabitParties',retained);
  end if;
  if p_scope not in ('habits','sharedNights') then return base; end if;
  -- The wrapped v1 state performs the membership check first. A v1 member
  -- may retain that archive, but must never receive v2 timing/routine fields.
  select a.* into current_agreement from private.night_flock_v4_shared_habits_agreements a join private.night_flock_v4_membership_epochs e on e.id=a.member_epoch_id join private.night_flock_v4_memberships m on m.id=e.membership_id where a.party_id=p_party_id and a.user_id=p_user_id and a.agreement_version=2 and m.status='active' and e.ended_at is null order by a.accepted_at desc limit 1;
  current_v2_agreement:=current_agreement.id is not null;
  if not current_v2_agreement then return base||jsonb_build_object('sharedNightPlans','[]'::jsonb,'sharedNightReceipts','[]'::jsonb,'sharedNightsNextCursor',null,'sharedNightsSnapshotRevision',null); end if;
  if p_scope='sharedNights' then
    select revision into snap from private.night_flock_v4_parties where id=p_party_id;
    if p_cursor is null then cursor_revision:=null;
    else
      begin cursor_revision:=split_part(p_cursor,'|',2)::int;
      exception when others then raise exception 'Invalid cursor'; end;
      if split_part(p_cursor,'|',1)::int<>snap or cursor_revision is null then raise exception 'stale_revision'; end if;
    end if;
    with events as (
      select p0.archive_revision,p0.id,'plan'::text item_kind from private.night_flock_v4_shared_night_plans p0 where p0.party_id=p_party_id and p0.archive_revision<=snap and not private.night_flock_users_blocked(p_user_id,p0.author_user_id) and not exists(select 1 from private.night_flock_v4_shared_night_plan_tombstones t where t.party_id=p0.party_id and t.member_epoch_id=p0.member_epoch_id and t.night_ending_date=p0.night_ending_date)
      union all
      select r0.archive_revision,r0.id,'receipt'::text from private.night_flock_v4_shared_night_receipts r0 where r0.party_id=p_party_id and r0.archive_revision<=snap and not private.night_flock_users_blocked(p_user_id,r0.author_user_id) and not exists(select 1 from private.night_flock_v4_shared_night_plan_tombstones t where t.party_id=r0.party_id and t.member_epoch_id=r0.member_epoch_id and t.night_ending_date=r0.night_ending_date)
    ), ordered as (
      select * from events where cursor_revision is null or archive_revision<cursor_revision order by archive_revision desc,id desc limit 101
    ), page as (select * from ordered limit 100)
    select count(*) into page_count from ordered;
    with events as (
      select p0.archive_revision,p0.id,'plan'::text item_kind from private.night_flock_v4_shared_night_plans p0 where p0.party_id=p_party_id and p0.archive_revision<=snap and not private.night_flock_users_blocked(p_user_id,p0.author_user_id) and not exists(select 1 from private.night_flock_v4_shared_night_plan_tombstones t where t.party_id=p0.party_id and t.member_epoch_id=p0.member_epoch_id and t.night_ending_date=p0.night_ending_date)
      union all select r0.archive_revision,r0.id,'receipt'::text from private.night_flock_v4_shared_night_receipts r0 where r0.party_id=p_party_id and r0.archive_revision<=snap and not private.night_flock_users_blocked(p_user_id,r0.author_user_id) and not exists(select 1 from private.night_flock_v4_shared_night_plan_tombstones t where t.party_id=r0.party_id and t.member_epoch_id=r0.member_epoch_id and t.night_ending_date=r0.night_ending_date)
    ), ordered as (select * from events where cursor_revision is null or archive_revision<cursor_revision order by archive_revision desc,id desc limit 101), page as (select * from ordered limit 100), last_row as (select archive_revision from page order by archive_revision asc,id asc limit 1)
    select case when page_count>100 then snap::text||'|'||(select archive_revision::text from last_row) else null end into next_shared_nights_cursor;
    with events as (
      select p0.archive_revision,p0.id,'plan'::text item_kind from private.night_flock_v4_shared_night_plans p0 where p0.party_id=p_party_id and p0.archive_revision<=snap and not private.night_flock_users_blocked(p_user_id,p0.author_user_id) and not exists(select 1 from private.night_flock_v4_shared_night_plan_tombstones t where t.party_id=p0.party_id and t.member_epoch_id=p0.member_epoch_id and t.night_ending_date=p0.night_ending_date)
      union all select r0.archive_revision,r0.id,'receipt'::text from private.night_flock_v4_shared_night_receipts r0 where r0.party_id=p_party_id and r0.archive_revision<=snap and not private.night_flock_users_blocked(p_user_id,r0.author_user_id) and not exists(select 1 from private.night_flock_v4_shared_night_plan_tombstones t where t.party_id=r0.party_id and t.member_epoch_id=r0.member_epoch_id and t.night_ending_date=r0.night_ending_date)
    ), ordered as (select * from events where cursor_revision is null or archive_revision<cursor_revision order by archive_revision desc,id desc limit 101), page as (select * from ordered limit 100), selected as (
      select id from page where item_kind='plan' union select r.plan_id from private.night_flock_v4_shared_night_receipts r join page on page.id=r.id and page.item_kind='receipt' where r.plan_id is not null
    )
    select coalesce(jsonb_agg(jsonb_build_object('planID',x.id,'partyID',x.party_id,'memberID',x.member_id,'memberEpochID',x.member_epoch_id,'agreementID',x.agreement_id,'revision',x.revision,'nightEndingDate',x.night_ending_date,'timeZoneIdentifier',x.time_zone_identifier,'plannedWindDownStart',x.planned_wind_down_start,'intendedBedtime',x.intended_bedtime,'intendedWakeTime',x.intended_wake_time,'morningQuietEnd',x.morning_quiet_end,'beforeBedMinutes',x.before_bed_minutes,'afterWakingMinutes',x.after_waking_minutes,'eveningSuggestionIDs',x.evening_suggestion_ids,'morningSuggestionIDs',x.morning_suggestion_ids,'supersededAt',x.superseded_at,'isFormerMember',x.former) order by x.night_ending_date desc,x.member_id,x.revision desc),'[]'::jsonb) into plans from (select p0.*,m.status<>'active' former from private.night_flock_v4_shared_night_plans p0 join private.night_flock_v4_memberships m on m.id=p0.member_id where p0.id in (select id from selected)) x;
    with events as (
      select p0.archive_revision,p0.id,'plan'::text item_kind from private.night_flock_v4_shared_night_plans p0 where p0.party_id=p_party_id and p0.archive_revision<=snap and not private.night_flock_users_blocked(p_user_id,p0.author_user_id) and not exists(select 1 from private.night_flock_v4_shared_night_plan_tombstones t where t.party_id=p0.party_id and t.member_epoch_id=p0.member_epoch_id and t.night_ending_date=p0.night_ending_date)
      union all select r0.archive_revision,r0.id,'receipt'::text from private.night_flock_v4_shared_night_receipts r0 where r0.party_id=p_party_id and r0.archive_revision<=snap and not private.night_flock_users_blocked(p_user_id,r0.author_user_id) and not exists(select 1 from private.night_flock_v4_shared_night_plan_tombstones t where t.party_id=r0.party_id and t.member_epoch_id=r0.member_epoch_id and t.night_ending_date=r0.night_ending_date)
    ), ordered as (select * from events where cursor_revision is null or archive_revision<cursor_revision order by archive_revision desc,id desc limit 101), page as (select * from ordered limit 100)
    select coalesce(jsonb_agg(jsonb_build_object('receiptID',x.id,'partyID',x.party_id,'memberID',x.member_id,'memberEpochID',x.member_epoch_id,'agreementID',x.agreement_id,'planID',x.plan_id,'planRevision',x.plan_revision,'sourceID',case when x.author_user_id=p_user_id then x.source_id else null end,'revision',x.revision,'nightEndingDate',x.night_ending_date,'timeZoneIdentifier',x.time_zone_identifier,'actualStart',x.actual_start,'terminalAt',x.terminal_at,'outcome',x.outcome,'windDownMinutes',x.wind_down_minutes,'protectionMinutes',x.protection_minutes,'protectionEvidence',x.protection_evidence,'emergencyExitUsed',x.emergency_exit_used,'profileSnapshot',x.profile_snapshot,'isFormerMember',x.former) order by x.night_ending_date desc,x.member_id,x.revision desc),'[]'::jsonb) into receipts from (select r0.*,m.status<>'active' former from private.night_flock_v4_shared_night_receipts r0 join private.night_flock_v4_memberships m on m.id=r0.member_id where r0.id in (select id from page where item_kind='receipt')) x;
    return jsonb_build_object('agreement',jsonb_build_object('agreementID',current_agreement.id,'memberEpochID',current_agreement.member_epoch_id,'acceptedAt',current_agreement.accepted_at,'timeZoneIdentifier',current_agreement.time_zone_identifier,'firstEligibleSleepNight',current_agreement.first_eligible_sleep_night,'agreementVersion',2),'records','[]'::jsonb,'nextCursor',null,'snapshotRevision',snap,'periods','[]'::jsonb,'sharedNightPlans',plans,'sharedNightReceipts',receipts,'sharedNightsNextCursor',next_shared_nights_cursor,'sharedNightsSnapshotRevision',snap);
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('planID',x.id,'partyID',x.party_id,'memberID',x.member_id,'memberEpochID',x.member_epoch_id,'agreementID',x.agreement_id,'revision',x.revision,'nightEndingDate',x.night_ending_date,'timeZoneIdentifier',x.time_zone_identifier,'plannedWindDownStart',x.planned_wind_down_start,'intendedBedtime',x.intended_bedtime,'intendedWakeTime',x.intended_wake_time,'morningQuietEnd',x.morning_quiet_end,'beforeBedMinutes',x.before_bed_minutes,'afterWakingMinutes',x.after_waking_minutes,'eveningSuggestionIDs',x.evening_suggestion_ids,'morningSuggestionIDs',x.morning_suggestion_ids,'supersededAt',x.superseded_at,'isFormerMember',x.former) order by x.night_ending_date,x.member_id),'[]'::jsonb) into plans from (select p0.*,m.status<>'active' former from private.night_flock_v4_shared_night_plans p0 join private.night_flock_v4_memberships m on m.id=p0.member_id where p0.party_id=p_party_id and not private.night_flock_users_blocked(p_user_id,p0.author_user_id) and not exists(select 1 from private.night_flock_v4_shared_night_plan_tombstones t where t.party_id=p0.party_id and t.member_epoch_id=p0.member_epoch_id and t.night_ending_date=p0.night_ending_date) and (p0.superseded_at is null or exists(select 1 from private.night_flock_v4_shared_night_receipts r where r.plan_id=p0.id)) order by p0.night_ending_date desc,p0.member_id,p0.revision desc limit 128) x;
  select coalesce(jsonb_agg(jsonb_build_object('receiptID',x.id,'partyID',x.party_id,'memberID',x.member_id,'memberEpochID',x.member_epoch_id,'agreementID',x.agreement_id,'planID',x.plan_id,'planRevision',x.plan_revision,'sourceID',case when x.author_user_id=p_user_id then x.source_id else null end,'revision',x.revision,'nightEndingDate',x.night_ending_date,'timeZoneIdentifier',x.time_zone_identifier,'actualStart',x.actual_start,'terminalAt',x.terminal_at,'outcome',x.outcome,'windDownMinutes',x.wind_down_minutes,'protectionMinutes',x.protection_minutes,'protectionEvidence',x.protection_evidence,'emergencyExitUsed',x.emergency_exit_used,'profileSnapshot',x.profile_snapshot,'isFormerMember',x.former) order by x.night_ending_date desc,x.member_id),'[]'::jsonb) into receipts from (select r0.*,m.status<>'active' former from private.night_flock_v4_shared_night_receipts r0 join private.night_flock_v4_memberships m on m.id=r0.member_id where r0.party_id=p_party_id and not private.night_flock_users_blocked(p_user_id,r0.author_user_id) and not exists(select 1 from private.night_flock_v4_shared_night_plan_tombstones t where t.party_id=r0.party_id and t.member_epoch_id=r0.member_epoch_id and t.night_ending_date=r0.night_ending_date) order by r0.night_ending_date desc,r0.member_id,r0.revision desc limit 128) x;
  return base||jsonb_build_object('agreement',jsonb_build_object('agreementID',current_agreement.id,'memberEpochID',current_agreement.member_epoch_id,'acceptedAt',current_agreement.accepted_at,'timeZoneIdentifier',current_agreement.time_zone_identifier,'firstEligibleSleepNight',current_agreement.first_eligible_sleep_night,'agreementVersion',2),'sharedNightPlans',plans,'sharedNightReceipts',receipts,'sharedNightsNextCursor',null,'sharedNightsSnapshotRevision',null);
end $$;
revoke all on private.night_flock_v4_shared_night_plans,private.night_flock_v4_shared_night_receipts from public,anon,authenticated;
revoke all on function private.night_flock_v4_apply_pre_social_loop(uuid,jsonb),private.night_flock_v4_apply(uuid,jsonb),public.night_flock_v4_state_pre_social_loop(uuid,text,uuid,text) from public,anon,authenticated;
revoke all on function public.night_flock_v4_state(uuid,text,uuid,text) from public,anon,authenticated;
grant execute on function public.night_flock_v4_state(uuid,text,uuid,text) to service_role;
