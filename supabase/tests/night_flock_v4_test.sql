begin;

-- Run after migrations in a local Supabase database. These are deliberately direct RPC
-- assertions: client payload validation and encryption live in Deno tests.
insert into auth.users (id, instance_id, aud, role, is_anonymous, raw_app_meta_data, created_at, updated_at)
select ('20000000-0000-4000-8000-' || lpad(value::text, 12, '0'))::uuid,
  '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', false,
  '{"provider":"apple","providers":["apple"]}'::jsonb, now(), now()
from generate_series(1, 12) value;

do $$
declare host_id uuid := '20000000-0000-4000-8000-000000000001'; member_id uuid := '20000000-0000-4000-8000-000000000002';
  former_member_id uuid := '20000000-0000-4000-8000-000000000003';
  outsider_id uuid := '20000000-0000-4000-8000-000000000009';
  v_party_id uuid; second_party_id uuid; round_id uuid; invite_id uuid;
  result jsonb; activity_payload jsonb; activity_id uuid; partial_ledger_id uuid;
  grant_id uuid; former_grant_id uuid; former_activity_id uuid; former_membership_id uuid;
  acknowledged_time timestamptz;
  host_member_id uuid; member_membership_id uuid;
  safety_host_id uuid := '20000000-0000-4000-8000-000000000010';
  safety_blocker_id uuid := '20000000-0000-4000-8000-000000000011';
  safety_target_id uuid := '20000000-0000-4000-8000-000000000012';
  safety_party_id uuid; safety_other_party_id uuid; safety_target_member_id uuid;
  survivor_grant_id uuid; safety_report_id uuid;
  signal_revision bigint; visible_reactions integer; i integer;
begin
  -- Five concurrent memberships are allowed; the sixth is consistently classified.
  for i in 1..5 loop
    result := public.night_flock_v4_command(host_id, jsonb_build_object('command','createParty','name','Party '||i,'timeZoneIdentifier','UTC'));
  end loop;
  begin
    perform public.night_flock_v4_command(host_id, jsonb_build_object('command','createParty','name','Sixth','timeZoneIdentifier','UTC'));
    raise exception 'sixth party was accepted';
  exception when raise_exception then
    if sqlerrm <> 'max_parties' then raise; end if;
  end;
  select membership.party_id into v_party_id from private.night_flock_v4_memberships membership where user_id=host_id and status='active' order by joined_at limit 1;

  -- A v1-v3 singular call cannot choose an arbitrary party after the v4 fan-out upgrade.
  begin perform public.night_flock_state(host_id); raise exception 'legacy ambiguity fence missing';
  exception when raise_exception then if sqlerrm <> 'client_upgrade_required' then raise; end if; end;

  -- Party capacity trigger and host leave rule apply even if a future service path bypasses the RPC.
  select revision into signal_revision
  from public.night_flock_v4_party_signals where party_id=v_party_id;
  if signal_revision is null then
    raise exception 'new party had no sanitized realtime signal';
  end if;
  insert into private.night_flock_v4_memberships(party_id,user_id,role)
  values(v_party_id,member_id,'member');
  if (
    select revision from public.night_flock_v4_party_signals where party_id=v_party_id
  )<=signal_revision then
    raise exception 'new party member did not invalidate people-first party state';
  end if;
  select id into round_id from private.night_flock_v4_rounds where party_id=v_party_id;
  perform public.night_flock_v4_command(host_id,jsonb_build_object('command','startRound','partyID',v_party_id,'timeZoneIdentifier','UTC'));
  begin perform public.night_flock_v4_command(host_id,jsonb_build_object('command','leaveParty','partyID',v_party_id)); raise exception 'host left';
  exception when raise_exception then if sqlerrm <> 'host_cannot_leave' then raise; end if; end;
  for i in 3..8 loop insert into private.night_flock_v4_memberships(party_id,user_id,role) values(v_party_id,('20000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'member'); end loop;
  begin insert into private.night_flock_v4_memberships(party_id,user_id,role) values(v_party_id,('20000000-0000-4000-8000-000000000009')::uuid,'member'); raise exception 'ninth member accepted';
  exception when raise_exception then if sqlerrm <> 'flock_full' then raise; end if; end;

  -- The invite secret is private: member retrieval is authorized through the RPC but no
  -- public/realtime table carries either digest or ciphertext.
  result := public.night_flock_v4_command(host_id,jsonb_build_object('command','createInvite','partyID',v_party_id,'inviteDigest',encode(extensions.digest('ABCDEFGHJKLM','sha256'),'hex'),'inviteCiphertext',encode(extensions.gen_random_bytes(32),'base64'),'inviteNonce',encode(extensions.gen_random_bytes(12),'base64'),'inviteKeyVersion',1));
  invite_id := (result->>'inviteID')::uuid;
  if not exists(select 1 from private.night_flock_v4_invites where id=invite_id and revoked_at is null) then raise exception 'invite was not stored privately'; end if;
  perform public.night_flock_v4_command(host_id,jsonb_build_object('command','revokeInvite','partyID',v_party_id,'inviteID',invite_id));
  begin perform public.night_flock_v4_command(member_id,jsonb_build_object('command','retrieveInvite','partyID',v_party_id)); raise exception 'revoked invite retrieved';
  exception when raise_exception then if sqlerrm <> 'invite_unavailable' then raise; end if; end;

  -- Source-event fan-out remains separate from transport idempotency: replaying the
  -- same source with a fresh command key reaches a party joined after its first send.
  activity_payload := jsonb_build_object(
    'command','publishActivity',
    'sourceEventID','30000000-0000-4000-8000-000000000001',
    'kind','windDown',
    'startedAt',to_char(now()-interval '10 minutes','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'endedAt',to_char(now(),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'windDownMinutes',10,
    'phoneAwayMinutes',0,
    'statusRevision',2
  );
  perform public.night_flock_v4_command(
    host_id,activity_payload||jsonb_build_object('idempotencyKey',repeat('a',64))
  );
  select id into activity_id from public.night_flock_v4_party_activities where party_id=v_party_id;
  if (select count(*) from public.night_flock_v4_party_activities where party_id=v_party_id) <> 1 then raise exception 'activity was not idempotent'; end if;

  select membership.party_id into second_party_id
  from private.night_flock_v4_memberships membership
  where membership.user_id=host_id
    and membership.status='active'
    and membership.party_id<>v_party_id
  order by membership.joined_at
  limit 1;
  insert into private.night_flock_v4_memberships(party_id,user_id,role)
  values(second_party_id,member_id,'member');
  perform public.night_flock_v4_command(
    host_id,jsonb_build_object(
      'command','startRound','partyID',second_party_id,'timeZoneIdentifier','UTC'
    )
  );
  perform public.night_flock_v4_command(
    host_id,activity_payload||jsonb_build_object('idempotencyKey',repeat('b',64))
  );
  perform public.night_flock_v4_command(
    host_id,activity_payload||jsonb_build_object('idempotencyKey',repeat('b',64))
  );
  if (
    select count(*) from public.night_flock_v4_party_activities activity
    join private.night_flock_v4_activity_ledger ledger on ledger.id=activity.ledger_id
    where ledger.source_event_id='30000000-0000-4000-8000-000000000001'::uuid
  )<>2 then
    raise exception 'existing source did not fan out once to the newly active party';
  end if;
  if (
    select count(*) from private.night_flock_v4_grants grant_row
    join private.night_flock_v4_activity_ledger ledger on ledger.id=grant_row.ledger_id
    where ledger.source_event_id='30000000-0000-4000-8000-000000000001'::uuid
  )<>2 then
    raise exception 'replayed completed source did not grant exactly once per party';
  end if;

  -- Partial factual records are social history, not completed status or Farm rewards.
  activity_payload := jsonb_build_object(
    'command','publishActivity',
    'sourceEventID','30000000-0000-4000-8000-000000000002',
    'kind','phoneAway',
    'outcome','partlyCompleted',
    'startedAt',to_char(now()-interval '5 minutes','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'endedAt',to_char(now(),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'windDownMinutes',0,
    'phoneAwayMinutes',5,
    'statusRevision',3
  );
  perform public.night_flock_v4_command(
    host_id,activity_payload||jsonb_build_object('idempotencyKey',repeat('c',64))
  );
  select id into partial_ledger_id
  from private.night_flock_v4_activity_ledger
  where source_event_id='30000000-0000-4000-8000-000000000002'::uuid;
  if (
    select count(*) from public.night_flock_v4_party_activities
    where ledger_id=partial_ledger_id and outcome='partlyCompleted'
  )<>2 then
    raise exception 'partial source did not fan out as factual party history';
  end if;
  if exists(
    select 1 from private.night_flock_v4_grants where ledger_id=partial_ledger_id
  ) then
    raise exception 'partial source incorrectly granted a Farm reward';
  end if;
  if exists(
    select 1 from public.night_flock_v4_statuses status_row
    join private.night_flock_v4_memberships membership
      on membership.id=status_row.member_id
    where membership.user_id=host_id and status_row.revision>=3
  ) then
    raise exception 'partial source incorrectly emitted a completed live status';
  end if;

  perform public.night_flock_v4_command(
    host_id,
    activity_payload||jsonb_build_object(
      'outcome','completed','statusRevision',4,'idempotencyKey',repeat('d',64)
    )
  );
  if (
    select count(*) from private.night_flock_v4_grants where ledger_id=partial_ledger_id
  )<>2 then
    raise exception 'partial-to-complete upgrade did not grant exactly once per party';
  end if;
  if (
    select count(*) from public.night_flock_v4_party_activities
    where ledger_id=partial_ledger_id and outcome='completed' and revision=4
  )<>2 then
    raise exception 'partial-to-complete upgrade did not replace factual history';
  end if;
  if (
    select count(*) from public.night_flock_v4_statuses status_row
    join private.night_flock_v4_memberships membership
      on membership.id=status_row.member_id
    where membership.user_id=host_id
      and status_row.revision=4
      and status_row.status='phoneAwayCompleted'
  )<>2 then
    raise exception 'partial-to-complete upgrade did not emit completed statuses';
  end if;

  -- Revisions restart for every iPhone run, so observed time must order separate
  -- runs while revision only breaks ties for the same observation.
  activity_payload := jsonb_build_object(
    'command','publishActivity',
    'sourceEventID','30000000-0000-4000-8000-000000000004',
    'kind','windDown',
    'startedAt',to_char(now(),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'endedAt',to_char(now()+interval '1 minute','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'windDownMinutes',1,
    'phoneAwayMinutes',0,
    'statusRevision',3
  );
  perform public.night_flock_v4_command(
    host_id,activity_payload||jsonb_build_object('idempotencyKey',repeat('1',64))
  );
  if (
    select count(*) from public.night_flock_v4_statuses status_row
    join private.night_flock_v4_memberships membership
      on membership.id=status_row.member_id
    where membership.user_id=host_id
      and status_row.revision=3
      and status_row.status='windDownCompleted'
  )<>2 then
    raise exception 'newer completed run could not replace prior higher revision';
  end if;

  perform public.night_flock_v4_command(
    host_id,jsonb_build_object(
      'command','publishStatus',
      'sourceEventID','30000000-0000-4000-8000-000000000005',
      'status','windDownStarting',
      'revision',1,
      'observedAt',to_char(now()+interval '2 minutes','YYYY-MM-DD"T"HH24:MI:SS"Z"')
    )
  );
  if (
    select count(*) from public.night_flock_v4_statuses status_row
    join private.night_flock_v4_memberships membership
      on membership.id=status_row.member_id
    where membership.user_id=host_id
      and status_row.revision=1
      and status_row.status='windDownStarting'
  )<>2 then
    raise exception 'next run starting revision one was rejected';
  end if;

  perform public.night_flock_v4_command(
    host_id,jsonb_build_object(
      'command','publishStatus',
      'sourceEventID','30000000-0000-4000-8000-000000000005',
      'status','phoneAwayActive',
      'revision',2,
      'observedAt',to_char(now()+interval '3 minutes','YYYY-MM-DD"T"HH24:MI:SS"Z"')
    )
  );
  if (
    select count(*) from public.night_flock_v4_statuses status_row
    join private.night_flock_v4_memberships membership
      on membership.id=status_row.member_id
    where membership.user_id=host_id
      and status_row.revision=2
      and status_row.status='phoneAwayActive'
  )<>2 then
    raise exception 'next run active revision two was rejected';
  end if;

  -- A fixed silent cheer is available while the run is active, before any
  -- completed activity exists, and remains visible as a bounded summary.
  select id into host_member_id
  from private.night_flock_v4_memberships
  where party_id=v_party_id and user_id=host_id;
  select id into member_membership_id
  from private.night_flock_v4_memberships
  where party_id=v_party_id and user_id=member_id;
  select revision into signal_revision
  from public.night_flock_v4_party_signals where party_id=v_party_id;
  perform public.night_flock_v4_command(
    member_id,jsonb_build_object(
      'command','cheerMember','partyID',v_party_id,'memberID',host_member_id,
      'cheer','warmWave','idempotencyKey',repeat('3',64)
    )
  );
  perform public.night_flock_v4_command(
    member_id,jsonb_build_object(
      'command','cheerMember','partyID',v_party_id,'memberID',host_member_id,
      'cheer','warmWave','idempotencyKey',repeat('3',64)
    )
  );
  perform public.night_flock_v4_command(
    member_id,jsonb_build_object(
      'command','cheerMember','partyID',v_party_id,'memberID',host_member_id,
      'cheer','warmWave','idempotencyKey',repeat('4',64)
    )
  );
  if (
    select count(*) from private.night_flock_v4_live_reactions
    where party_id=v_party_id
      and target_member_id=host_member_id
      and reactor_member_id=member_membership_id
      and reaction='warmWave'
  )<>1 then
    raise exception 'active-run cheer was missing or duplicated';
  end if;
  if (
    select revision from public.night_flock_v4_party_signals where party_id=v_party_id
  )<=signal_revision then
    raise exception 'active-run cheer did not send a sanitized party signal';
  end if;
  begin
    perform public.night_flock_v4_command(
      member_id,jsonb_build_object(
        'command','cheerMember','partyID',v_party_id,
        'memberID',member_membership_id,'cheer','pawPrint'
      )
    );
    raise exception 'member could cheer their own active run';
  exception when raise_exception then
    if sqlerrm<>'Invalid cheer target' then raise; end if;
  end;
  begin
    perform public.night_flock_v4_command(
      outsider_id,jsonb_build_object(
        'command','cheerMember','partyID',v_party_id,
        'memberID',host_member_id,'cheer','moonGlow'
      )
    );
    raise exception 'outsider could cheer another party member';
  exception when raise_exception then
    if sqlerrm<>'current_membership_required' then raise; end if;
  end;
  result:=public.night_flock_v4_state(member_id,'party',v_party_id,null);
  if not exists(
    select 1 from jsonb_array_elements(result#>'{party,liveCheers}') cheer
    where cheer->>'memberID'=host_member_id::text
      and cheer->>'cheer'='warmWave'
      and (cheer->>'count')::int=1
      and (cheer->>'sentByMe')::boolean
  ) then
    raise exception 'active-run cheer was missing from the safe party projection';
  end if;

  perform public.night_flock_v4_command(
    host_id,activity_payload||jsonb_build_object('idempotencyKey',repeat('2',64))
  );
  if (
    select count(*) from public.night_flock_v4_statuses status_row
    join private.night_flock_v4_memberships membership
      on membership.id=status_row.member_id
    where membership.user_id=host_id
      and status_row.revision=2
      and status_row.status='phoneAwayActive'
  )<>2 then
    raise exception 'stale completed event overwrote the newer active run';
  end if;

  perform public.night_flock_v4_command(
    host_id,jsonb_build_object(
      'command','publishActivity',
      'sourceEventID','30000000-0000-4000-8000-000000000005',
      'kind','phoneAway',
      'startedAt',to_char(now()+interval '2 minutes','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'endedAt',to_char(now()+interval '4 minutes','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'windDownMinutes',0,
      'phoneAwayMinutes',2,
      'statusRevision',3
    )
  );
  if (
    select count(*) from public.night_flock_v4_statuses status_row
    join private.night_flock_v4_memberships membership
      on membership.id=status_row.member_id
    where membership.user_id=host_id
      and status_row.revision=3
      and status_row.status='phoneAwayCompleted'
  )<>2 then
    raise exception 'next run completion did not replace its active status';
  end if;

  -- Reaction RLS can resolve party membership without exposing the activity table.
  perform public.night_flock_v4_command(
    member_id,jsonb_build_object(
      'command','react','partyID',v_party_id,'activityID',activity_id,'cheer','warmWave'
    )
  );
  perform set_config('request.jwt.claim.sub',member_id::text,true);
  execute 'set local role authenticated';
  execute 'select count(*) from public.night_flock_v4_reactions'
  into visible_reactions;
  if visible_reactions<>1 then
    raise exception 'authenticated current member could not read their party cheer';
  end if;
  execute 'select count(*) from public.night_flock_v4_party_signals where party_id=$1'
  into visible_reactions
  using v_party_id;
  if visible_reactions<>1 then
    raise exception 'authenticated current member could not read the sanitized party signal';
  end if;
  begin
    execute 'select count(*) from public.night_flock_v4_party_activities';
    raise exception 'authenticated member could directly read private party activities';
  exception when insufficient_privilege then
    null;
  end;
  begin
    execute 'update public.night_flock_v4_party_signals set revision=revision+1';
    raise exception 'authenticated member could directly mutate the party signal';
  exception when insufficient_privilege then
    null;
  end;
  execute 'reset role';

  perform set_config('request.jwt.claim.sub',outsider_id::text,true);
  execute 'set local role authenticated';
  execute 'select count(*) from public.night_flock_v4_reactions'
  into visible_reactions;
  if visible_reactions<>0 then
    raise exception 'outsider could read another party cheer';
  end if;
  execute 'select count(*) from public.night_flock_v4_party_signals where party_id=$1'
  into visible_reactions
  using v_party_id;
  if visible_reactions<>0 then
    raise exception 'outsider could read another party signal';
  end if;
  execute 'reset role';

  perform public.night_flock_v4_command(
    former_member_id,jsonb_build_object(
      'command','publishActivity',
      'sourceEventID','30000000-0000-4000-8000-000000000003',
      'kind','windDown',
      'startedAt',to_char(now()-interval '8 minutes','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'endedAt',to_char(now(),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'windDownMinutes',8,
      'phoneAwayMinutes',0,
      'statusRevision',1
    )
  );
  select id into former_grant_id
  from private.night_flock_v4_grants
  where user_id=former_member_id and party_id=v_party_id;
  if former_grant_id is null then
    raise exception 'current member did not earn the pre-leave reward';
  end if;
  select id into former_membership_id
  from private.night_flock_v4_memberships
  where party_id=v_party_id and user_id=former_member_id;
  select activity.id into former_activity_id
  from public.night_flock_v4_party_activities activity
  join private.night_flock_v4_activity_ledger ledger on ledger.id=activity.ledger_id
  where activity.party_id=v_party_id and ledger.user_id=former_member_id;
  perform public.night_flock_v4_command(
    member_id,jsonb_build_object(
      'command','react','partyID',v_party_id,
      'activityID',former_activity_id,'cheer','pawPrint'
    )
  );
  perform public.night_flock_v4_command(
    former_member_id,jsonb_build_object(
      'command','react','partyID',v_party_id,
      'activityID',activity_id,'cheer','moonGlow'
    )
  );

  perform public.night_flock_v4_command(
    former_member_id,jsonb_build_object('command','leaveParty','partyID',v_party_id)
  );
  perform set_config('request.jwt.claim.sub',former_member_id::text,true);
  execute 'set local role authenticated';
  execute 'select count(*) from public.night_flock_v4_reactions'
  into visible_reactions;
  if visible_reactions<>0 then
    raise exception 'former member retained access to party cheers';
  end if;
  execute 'reset role';

  perform set_config('request.jwt.claim.sub',member_id::text,true);
  execute 'set local role authenticated';
  execute
    'select count(*) from public.night_flock_v4_statuses where member_id=$1'
  into visible_reactions
  using former_membership_id;
  if visible_reactions<>0 then
    raise exception 'authenticated reader could select a removed member retained status';
  end if;
  execute
    'select count(*) from public.night_flock_v4_reactions where party_activity_id=$1'
  into visible_reactions
  using former_activity_id;
  if visible_reactions<>0 then
    raise exception 'authenticated reader could select a removed owner retained reaction';
  end if;
  execute
    'select count(*) from public.night_flock_v4_reactions where member_id=$1'
  into visible_reactions
  using former_membership_id;
  if visible_reactions<>0 then
    raise exception 'authenticated reader could select a removed reactor retained reaction';
  end if;
  execute
    'select count(*) from public.night_flock_v4_statuses where member_id=$1'
  into visible_reactions
  using host_member_id;
  if visible_reactions<>1 then
    raise exception 'active host status became invisible to a current member';
  end if;
  execute 'reset role';

  perform public.night_flock_v4_command(
    former_member_id,jsonb_build_object(
      'command','acknowledgeGrant','grantID',former_grant_id,
      'idempotencyKey',repeat('e',64)
    )
  );
  if not exists(
    select 1 from private.night_flock_v4_grants
    where id=former_grant_id and acknowledged_at is not null
  ) then
    raise exception 'earned grant could not be acknowledged after leaving';
  end if;
  select membership.id into member_membership_id
  from private.night_flock_v4_memberships membership
  where membership.party_id=v_party_id and membership.user_id=former_member_id;
  result:=public.night_flock_v4_state(host_id,'party',v_party_id,null);
  if exists(
    select 1 from jsonb_array_elements(result#>'{party,memberships}') projected
    where projected->>'memberID'=member_membership_id::text
  ) or exists(
    select 1 from jsonb_array_elements(result#>'{party,activities}') projected
    where projected->>'memberID'=member_membership_id::text
  ) or exists(
    select 1 from jsonb_array_elements(result#>'{party,liveStatuses}') projected
    where projected->>'memberID'=member_membership_id::text
  ) then
    raise exception 'former member remained visible in people, records, or live status';
  end if;
  select activity.id into activity_id
  from public.night_flock_v4_party_activities activity
  join private.night_flock_v4_activity_ledger ledger on ledger.id=activity.ledger_id
  where activity.party_id=v_party_id and ledger.user_id=former_member_id;
  begin
    perform public.night_flock_v4_command(
      member_id,jsonb_build_object(
        'command','react','partyID',v_party_id,
        'activityID',activity_id,'cheer','pawPrint'
      )
    );
    raise exception 'current member could react to a former member record';
  exception when raise_exception then
    if sqlerrm<>'invite_unavailable' then raise; end if;
  end;

  perform public.night_flock_v4_command(
    host_id,jsonb_build_object(
      'command','publishActivity',
      'sourceEventID','30000000-0000-4000-8000-000000000006',
      'kind','windDown','outcome','partlyCompleted',
      'startedAt',to_char(now()-interval '17 minutes','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'endedAt',to_char(now(),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'windDownMinutes',17,'phoneAwayMinutes',0,'statusRevision',1
    )
  );
  perform public.night_flock_v4_command(
    host_id,jsonb_build_object(
      'command','publishActivity',
      'sourceEventID','30000000-0000-4000-8000-000000000007',
      'kind','phoneAway','outcome','partlyCompleted',
      'startedAt',to_char(now()-interval '18 minutes','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'endedAt',to_char(now(),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'windDownMinutes',0,'phoneAwayMinutes',18,'statusRevision',1
    )
  );

  -- The detail endpoint returns only member-safe records: rich people/status/cheer
  -- projections, no source-ledger or invite-secret fields.
  result := public.night_flock_v4_state(host_id, 'party', v_party_id, null);
  if result #> '{party,memberships}' = '[]'::jsonb or result #> '{party,activities}' = '[]'::jsonb or result #> '{party,liveStatuses}' = '[]'::jsonb then
    raise exception 'rich party state was empty';
  end if;
  if result::text like '%ledger_id%' or result::text like '%source_event%' then raise exception 'private ledger leaked'; end if;
  if not exists(
    select 1
    from public.night_flock_v4_party_activities activity
    join private.night_flock_v4_activity_ledger ledger on ledger.id=activity.ledger_id
    cross join jsonb_array_elements(result#>'{party,activities}') projected
    where ledger.source_event_id='30000000-0000-4000-8000-000000000006'::uuid
      and activity.party_id=v_party_id
      and projected->>'activityID'=activity.id::text
      and (projected->>'roundedMinutes')::int=15
  ) then
    raise exception '17 exact Wind Down minutes were not rounded to 15';
  end if;
  if not exists(
    select 1
    from public.night_flock_v4_party_activities activity
    join private.night_flock_v4_activity_ledger ledger on ledger.id=activity.ledger_id
    cross join jsonb_array_elements(result#>'{party,activities}') projected
    where ledger.source_event_id='30000000-0000-4000-8000-000000000007'::uuid
      and activity.party_id=v_party_id
      and projected->>'activityID'=activity.id::text
      and (projected->>'roundedMinutes')::int=20
  ) then
    raise exception '18 exact Phone Away minutes were not rounded to 20';
  end if;
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='night_flock_v4_statuses')
     or not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='night_flock_v4_reactions')
     or not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='night_flock_v4_party_signals') then
    raise exception 'sanitized realtime projections missing';
  end if;
  if exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='night_flock_v4_party_activities') then
    raise exception 'activity ledger projection was published';
  end if;
  select id into grant_id from private.night_flock_v4_grants
  where user_id=host_id and party_id=v_party_id
  order by created_at,id
  limit 1;
  begin
    perform public.night_flock_v4_command(
      outsider_id,jsonb_build_object('command','acknowledgeGrant','grantID',grant_id)
    );
    raise exception 'outsider acknowledged another account reward';
  exception when raise_exception then
    if sqlerrm<>'invite_unavailable' then raise; end if;
  end;
  if exists(
    select 1 from private.night_flock_v4_grants
    where id=grant_id and acknowledged_at is not null
  ) then
    raise exception 'outsider changed another account reward';
  end if;
  perform public.night_flock_v4_command(host_id,jsonb_build_object('command','deleteParty','partyID',v_party_id));
  if not exists(select 1 from private.night_flock_v4_grants where id=grant_id) then raise exception 'earned grant disappeared on delete'; end if;
  perform public.night_flock_v4_command(
    host_id,jsonb_build_object(
      'command','acknowledgeGrant','grantID',grant_id,
      'idempotencyKey',repeat('f',64)
    )
  );
  select acknowledged_at into acknowledged_time
  from private.night_flock_v4_grants where id=grant_id;
  if acknowledged_time is null then
    raise exception 'earned grant could not be acknowledged after party deletion';
  end if;
  perform public.night_flock_v4_command(
    host_id,jsonb_build_object(
      'command','acknowledgeGrant','grantID',grant_id,
      'idempotencyKey',repeat('f',64)
    )
  );
  perform public.night_flock_v4_command(
    host_id,jsonb_build_object(
      'command','acknowledgeGrant','grantID',grant_id,
      'idempotencyKey',repeat('0',64)
    )
  );
  if (
    select acknowledged_at from private.night_flock_v4_grants where id=grant_id
  )<>acknowledged_time then
    raise exception 'grant acknowledgement was not idempotent';
  end if;

  -- First name is free, no-op is free, then two rolling changes are allowed.
  select revision into signal_revision
  from public.night_flock_v4_party_signals where party_id=second_party_id;
  perform public.night_flock_v4_command(member_id,jsonb_build_object('command','updatePublicProfile','expectedRevision',0,'displayName','Mabel','nameSelectionKind','initial','skinToneID','warm','hairStyleID','waves','shepherdOutfitID','none','shepherdAccessoryID','none','ollieOrnamentID','none','featuredSheepDefinitionID','none','pastureThemeID','pasture_meadow'));
  if (
    select revision from public.night_flock_v4_party_signals where party_id=second_party_id
  )<=signal_revision then
    raise exception 'curated profile update did not invalidate current party snapshots';
  end if;
  perform public.night_flock_v4_command(member_id,jsonb_build_object('command','updatePublicProfile','expectedRevision',1,'displayName','Mabel','nameSelectionKind','change','skinToneID','warm','hairStyleID','waves','shepherdOutfitID','none','shepherdAccessoryID','none','ollieOrnamentID','none','featuredSheepDefinitionID','none','pastureThemeID','pasture_meadow'));
  perform public.night_flock_v4_command(member_id,jsonb_build_object('command','updatePublicProfile','expectedRevision',1,'displayName','Willow','nameSelectionKind','change','skinToneID','warm','hairStyleID','waves','shepherdOutfitID','none','shepherdAccessoryID','none','ollieOrnamentID','none','featuredSheepDefinitionID','none','pastureThemeID','pasture_meadow'));
  perform public.night_flock_v4_command(member_id,jsonb_build_object('command','updatePublicProfile','expectedRevision',2,'displayName','Clover','nameSelectionKind','change','skinToneID','warm','hairStyleID','waves','shepherdOutfitID','none','shepherdAccessoryID','none','ollieOrnamentID','none','featuredSheepDefinitionID','none','pastureThemeID','pasture_meadow'));
  begin perform public.night_flock_v4_command(member_id,jsonb_build_object('command','updatePublicProfile','expectedRevision',3,'displayName','Daisy','nameSelectionKind','change','skinToneID','warm','hairStyleID','waves','shepherdOutfitID','none','shepherdAccessoryID','none','ollieOrnamentID','none','featuredSheepDefinitionID','none','pastureThemeID','pasture_meadow')); raise exception 'third rolling name change accepted';
  exception when raise_exception then if sqlerrm <> 'name_change_limit' then raise; end if; end;

  -- Reports use the existing fixed moderation queue; a block separates people
  -- across every shared party without forcing a host to abandon their group.
  perform public.night_flock_v4_command(
    safety_host_id,jsonb_build_object(
      'command','createParty','name','Safety Meadow','timeZoneIdentifier','UTC'
    )
  );
  select party_id into safety_party_id
  from private.night_flock_v4_memberships
  where user_id=safety_host_id and role='host';
  insert into private.night_flock_v4_memberships(party_id,user_id,role)
  values(safety_party_id,safety_blocker_id,'member'),
        (safety_party_id,safety_target_id,'member');
  perform public.night_flock_v4_command(
    safety_host_id,jsonb_build_object(
      'command','startRound','partyID',safety_party_id,'timeZoneIdentifier','UTC'
    )
  );
  select id into safety_target_member_id
  from private.night_flock_v4_memberships
  where party_id=safety_party_id and user_id=safety_target_id;

  perform public.night_flock_v4_command(
    safety_blocker_id,jsonb_build_object(
      'command','createParty','name','Safe Harbor','timeZoneIdentifier','UTC'
    )
  );
  select party_id into safety_other_party_id
  from private.night_flock_v4_memberships
  where user_id=safety_blocker_id and role='host';
  insert into private.night_flock_v4_memberships(party_id,user_id,role)
  values(safety_other_party_id,safety_target_id,'member');

  perform public.night_flock_v4_command(
    safety_blocker_id,jsonb_build_object(
      'command','reportMember','partyID',safety_party_id,
      'memberID',safety_target_member_id,'reason','unwantedContact',
      'idempotencyKey',repeat('5',64)
    )
  );
  if not exists(
    select 1 from public.night_flock_reports
    where reporter_user_id=safety_blocker_id
      and reported_user_id=safety_target_id
      and flock_id is null
      and reason='unwantedContact'
  ) then
    raise exception 'party member report did not enter the fixed moderation queue';
  end if;
  begin
    perform public.night_flock_v4_command(
      safety_target_id,jsonb_build_object(
        'command','reportMember','partyID',safety_party_id,
        'memberID',safety_target_member_id,'reason','harmfulConduct'
      )
    );
    raise exception 'member could report themself';
  exception when raise_exception then
    if sqlerrm<>'Invalid report target' then raise; end if;
  end;

  perform public.night_flock_v4_command(
    safety_blocker_id,jsonb_build_object(
      'command','blockMember','partyID',safety_party_id,
      'memberID',safety_target_member_id,'idempotencyKey',repeat('8',64)
    )
  );
  if not exists(
    select 1 from public.night_flock_blocks
    where blocker_user_id=safety_blocker_id and blocked_user_id=safety_target_id
  ) then
    raise exception 'party block did not persist its safety boundary';
  end if;
  if not exists(
    select 1 from private.night_flock_v4_memberships
    where party_id=safety_party_id
      and user_id=safety_blocker_id
      and status='left'
  ) then
    raise exception 'ordinary blocker did not leave the shared party';
  end if;
  if not exists(
    select 1 from private.night_flock_v4_memberships
    where party_id=safety_other_party_id
      and user_id=safety_blocker_id
      and role='host'
      and status='active'
  ) or not exists(
    select 1 from private.night_flock_v4_memberships
    where party_id=safety_other_party_id
      and user_id=safety_target_id
      and status='removed'
  ) then
    raise exception 'host blocker did not remove the target from their own party';
  end if;
  if exists(
    select 1
    from private.night_flock_v4_memberships blocker
    join private.night_flock_v4_memberships blocked
      on blocked.party_id=blocker.party_id
    where blocker.user_id=safety_blocker_id
      and blocked.user_id=safety_target_id
      and blocker.status='active'
      and blocked.status='active'
  ) then
    raise exception 'blocked people remained together in another party';
  end if;

  perform public.night_flock_v4_command(
    safety_blocker_id,jsonb_build_object(
      'command','createInvite','partyID',safety_other_party_id,
      'inviteDigest',encode(extensions.digest('BLOCKEDINVITE','sha256'),'hex'),
      'inviteCiphertext',encode(extensions.gen_random_bytes(32),'base64'),
      'inviteNonce',encode(extensions.gen_random_bytes(12),'base64'),
      'inviteKeyVersion',1
    )
  );
  begin
    perform public.night_flock_v4_command(
      safety_target_id,jsonb_build_object(
        'command','redeemInvite','inviteCode','BLOCKEDINVITE'
      )
    );
    raise exception 'blocked member could rejoin through an invitation';
  exception when raise_exception then
    if sqlerrm<>'blocked_membership' then raise; end if;
  end;

  -- Account deletion is account-scoped and must survive real Auth deletion:
  -- hosted parties disappear, everyone is released, another account's grants
  -- remain, private user data is cascaded, and moderation evidence is retained.
  perform public.night_flock_v4_command(
    safety_target_id,jsonb_build_object(
      'command','publishActivity',
      'sourceEventID','30000000-0000-4000-8000-000000000008',
      'kind','windDown',
      'startedAt',to_char(now()-interval '10 minutes','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'endedAt',to_char(now(),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'windDownMinutes',10,'phoneAwayMinutes',0,'statusRevision',1
    )
  );
  select id into survivor_grant_id
  from private.night_flock_v4_grants
  where user_id=safety_target_id and party_id=safety_party_id;
  if survivor_grant_id is null then
    raise exception 'remaining member did not earn a pre-deletion reward';
  end if;
  select id into host_member_id
  from private.night_flock_v4_memberships
  where party_id=safety_party_id and user_id=safety_host_id;
  perform public.night_flock_v4_command(
    safety_target_id,jsonb_build_object(
      'command','reportMember','partyID',safety_party_id,
      'memberID',host_member_id,'reason','harmfulConduct',
      'idempotencyKey',repeat('6',64)
    )
  );
  select id into safety_report_id from public.night_flock_reports
  where reporter_user_id=safety_target_id and reported_user_id=safety_host_id;

  perform public.night_flock_v4_command(
    safety_host_id,jsonb_build_object(
      'command','updatePublicProfile','expectedRevision',0,'displayName','Harbor',
      'nameSelectionKind','initial','skinToneID','warm','hairStyleID','waves',
      'shepherdOutfitID','none','shepherdAccessoryID','none',
      'ollieOrnamentID','none','featuredSheepDefinitionID','none',
      'pastureThemeID','pasture_meadow'
    )
  );
  perform public.night_flock_v4_command(
    safety_host_id,jsonb_build_object(
      'command','updatePublicProfile','expectedRevision',1,'displayName','Willow',
      'nameSelectionKind','change','skinToneID','warm','hairStyleID','waves',
      'shepherdOutfitID','none','shepherdAccessoryID','none',
      'ollieOrnamentID','none','featuredSheepDefinitionID','none',
      'pastureThemeID','pasture_meadow'
    )
  );
  perform public.night_flock_v4_command(
    safety_host_id,jsonb_build_object(
      'command','publishActivity',
      'sourceEventID','30000000-0000-4000-8000-000000000009',
      'kind','windDown',
      'startedAt',to_char(now()-interval '10 minutes','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'endedAt',to_char(now(),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'windDownMinutes',10,'phoneAwayMinutes',0,'statusRevision',1
    )
  );
  insert into public.night_flock_blocks(blocker_user_id,blocked_user_id)
  values(safety_host_id,outsider_id);
  result:=public.night_flock_v4_command(
    safety_host_id,jsonb_build_object(
      'command','deleteAccount','idempotencyKey',repeat('7',64)
    )
  );
  if result->>'deleteAccount'<>'true' then
    raise exception 'account-scoped deletion did not authorize Auth account removal';
  end if;
  if exists(
    select 1 from private.night_flock_v4_memberships
    where party_id=safety_party_id and status='active'
  ) then
    raise exception 'host account deletion did not release all party members';
  end if;

  delete from auth.users where id=safety_host_id;
  if exists(select 1 from auth.users where id=safety_host_id) then
    raise exception 'Auth user deletion was blocked by a restrictive v4 foreign key';
  end if;
  if exists(select 1 from private.night_flock_v4_parties where id=safety_party_id)
     or exists(
       select 1 from private.night_flock_v4_memberships where party_id=safety_party_id
     ) then
    raise exception 'deleted host left an orphaned party or memberships';
  end if;
  if not exists(
    select 1 from private.night_flock_v4_grants where id=survivor_grant_id
  ) then
    raise exception 'host account deletion removed another member earned reward';
  end if;
  if exists(select 1 from private.night_flock_v4_profiles where user_id=safety_host_id)
     or exists(
       select 1 from private.night_flock_v4_name_changes where user_id=safety_host_id
     )
     or exists(
       select 1 from private.night_flock_v4_activity_ledger where user_id=safety_host_id
     )
     or exists(
       select 1 from private.night_flock_v4_idempotency where user_id=safety_host_id
     )
     or exists(
       select 1 from public.night_flock_blocks
       where blocker_user_id=safety_host_id or blocked_user_id=safety_host_id
     ) then
    raise exception 'deleted account retained private profile, activity, or block data';
  end if;
  if not exists(
    select 1 from public.night_flock_reports
    where id=safety_report_id
      and reported_user_id is null
      and reporter_user_id=safety_target_id
  ) then
    raise exception 'host account deletion removed required moderation evidence';
  end if;
end $$;

rollback;
