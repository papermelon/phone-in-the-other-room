begin;

-- Run after the v4 migration and 20260827120000.  This covers the stream separately
-- from the pre-existing v4 round/grant suite so it can prove that sharing has no grant path.
insert into auth.users (id,instance_id,aud,role,is_anonymous,raw_app_meta_data,created_at,updated_at)
values
  ('31000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated',false,'{"provider":"apple","providers":["apple"]}',now(),now()),
  ('31000000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated',false,'{"provider":"apple","providers":["apple"]}',now(),now()),
  ('31000000-0000-4000-8000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated',false,'{"provider":"apple","providers":["apple"]}',now(),now()),
  ('31000000-0000-4000-8000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated',false,'{"provider":"apple","providers":["apple"]}',now(),now());

do $$
declare
  host_id uuid:='31000000-0000-4000-8000-000000000001';
  member_id uuid:='31000000-0000-4000-8000-000000000002';
  observer_id uuid:='31000000-0000-4000-8000-000000000003';
  late_joiner_id uuid:='31000000-0000-4000-8000-000000000004';
  v_party_id uuid; v_party_two_id uuid; host_member uuid; member_membership uuid; late_joiner_membership uuid;
  first_epoch uuid; second_epoch uuid; status_id uuid; activity_id uuid; stream_activity_two_id uuid; legacy_activity_id uuid; result jsonb; grant_count int;
  source_one uuid:='32000000-0000-4000-8000-000000000001';
  source_two uuid:='32000000-0000-4000-8000-000000000002';
  source_old uuid:='32000000-0000-4000-8000-000000000003';
begin
  perform public.night_flock_v4_command(host_id,jsonb_build_object('command','createParty','name','Before Rounds','timeZoneIdentifier','UTC'));
  select membership.party_id,membership.id into v_party_id,host_member from private.night_flock_v4_memberships membership where membership.user_id=host_id and membership.role='host';
  insert into private.night_flock_v4_memberships(party_id,user_id,role) values(v_party_id,member_id,'member'),(v_party_id,observer_id,'member');
  select membership.id into member_membership from private.night_flock_v4_memberships membership where membership.party_id=v_party_id and membership.user_id=member_id;
  select epoch.id into first_epoch from private.night_flock_v4_membership_epochs epoch where epoch.membership_id=host_member and epoch.ended_at is null;

  -- Pending/no-round moments share, but the original round grant tables remain empty.
  perform public.night_flock_v4_command(host_id,jsonb_build_object(
    'command','publishActivity','sharingScope','membership','sourceEventID',source_one,
    'kind','windDown','outcome','completed','startedAt',to_char(timezone('UTC',now()-interval '12 minutes'),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'endedAt',to_char(timezone('UTC',now()+interval '1 minute'),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'windDownMinutes',10,'phoneAwayMinutes',0,'statusRevision',1
  ));
  if exists(select 1 from public.night_flock_v4_party_activities activity where activity.party_id=v_party_id) or exists(select 1 from private.night_flock_v4_grants grant_row where grant_row.party_id=v_party_id) then
    raise exception 'outside-round membership stream minted a round record or grant';
  end if;
  result:=public.night_flock_v4_state(observer_id,'party',v_party_id,null);
  if result#>>'{party,summary,sharingScope}'<>'membership' or jsonb_array_length(result#>'{party,sharedActivities}')<>1 then
    raise exception 'pending membership sharing capability or activity missing';
  end if;
  if (result#>>'{party,sharedActivities,0,roundID}') is not null or (result#>>'{party,sharedActivities,0,day}') is not null or (result#>>'{party,sharedActivities,0,roundActivityID}') is not null then
    raise exception 'general stream invented a round association';
  end if;
  if result#>>'{party,sharedActivities,0,mySourceEventID}' is not null then raise exception 'friend received source-event correlation'; end if;
  result:=public.night_flock_v4_state(host_id,'party',v_party_id,null);
  if result#>>'{party,sharedActivities,0,mySourceEventID}'<>source_one::text then raise exception 'owner did not receive own source-event correlation'; end if;
  perform public.night_flock_v4_command(host_id,jsonb_build_object('command','startRound','partyID',v_party_id,'timeZoneIdentifier','UTC'));
  update private.night_flock_v4_rounds set started_at=now()+interval '2 minutes' where party_id=v_party_id and status='active';
  perform public.night_flock_v4_command(host_id,jsonb_build_object(
    'command','publishActivity','sourceEventID',source_one,'kind','windDown','outcome','completed',
    'startedAt',to_char(timezone('UTC',now()-interval '12 minutes'),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'endedAt',to_char(timezone('UTC',now()+interval '1 minute'),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'windDownMinutes',10,'phoneAwayMinutes',0,'statusRevision',1
  ));
  if exists(select 1 from public.night_flock_v4_party_activities activity where activity.party_id=v_party_id) or exists(select 1 from private.night_flock_v4_grants grant_row where grant_row.party_id=v_party_id) then
    raise exception 'later round or legacy backfill converted frozen outside-round source into a grant';
  end if;

  -- A live cheer is pinned to the opaque status identity.  A partial terminal source
  -- clears it and its watermark rejects an old queued start from resurrecting it.
  perform public.night_flock_v4_command(host_id,jsonb_build_object('command','publishStatus','sharingScope','membership','sourceEventID',source_two,'status','windDownStarting','revision',2,'observedAt',to_char(timezone('UTC',now()+interval '1 minute'),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),'idempotencyKey',repeat('1',64)));
  result:=public.night_flock_v4_state(observer_id,'party',v_party_id,null);
  select (value->>'statusID')::uuid into status_id from jsonb_array_elements(result#>'{party,sharedLiveStatuses}') value where value->>'memberID'=host_member::text;
  if status_id is null then raise exception 'membership live status did not expose opaque identity'; end if;
  perform public.night_flock_v4_command(observer_id,jsonb_build_object('command','cheerMember','partyID',v_party_id,'memberID',host_member,'statusID',status_id,'cheer','pawPrint'));
  result:=public.night_flock_v4_state(observer_id,'party',v_party_id,null);
  if jsonb_array_length(result#>'{party,sharedLiveCheers}')<>1 or result#>>'{party,sharedLiveCheers,0,statusID}'<>status_id::text then raise exception 'live cheer was not scoped to exact status'; end if;
  if result#>>'{party,sharedLiveCheers,0,mySourceEventID}' is not null then raise exception 'friend received live-cheer source-event correlation'; end if;
  result:=public.night_flock_v4_state(host_id,'party',v_party_id,null);
  if result#>>'{party,sharedLiveCheers,0,mySourceEventID}'<>source_two::text then raise exception 'owner did not receive live-cheer source-event correlation'; end if;
  perform public.night_flock_v4_command(host_id,jsonb_build_object(
    'command','publishActivity','sharingScope','membership','sourceEventID',source_two,
    'kind','windDown','outcome','partlyCompleted','startedAt',to_char(timezone('UTC',now()-interval '5 minutes'),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'endedAt',to_char(timezone('UTC',now()+interval '1 minute'),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),'windDownMinutes',5,'phoneAwayMinutes',0,'statusRevision',3,'idempotencyKey',repeat('2',64)
  ));
  select activity.id into activity_id from private.night_flock_v4_membership_stream_activities activity where activity.party_id=v_party_id and activity.source_event_id=source_two;
  perform public.night_flock_v4_command(observer_id,jsonb_build_object('command','react','partyID',v_party_id,'activityID',activity_id,'cheer','pawPrint','sharingScope','membership'));
  perform public.night_flock_v4_command(host_id,jsonb_build_object('command','publishStatus','sharingScope','membership','sourceEventID',source_two,'status','windDownStarting','revision',1,'observedAt',to_char(timezone('UTC',now()+interval '30 seconds'),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),'idempotencyKey',repeat('3',64)));
  result:=public.night_flock_v4_state(observer_id,'party',v_party_id,null);
  if jsonb_array_length(result#>'{party,sharedLiveStatuses}')<>0 then raise exception 'terminal watermark allowed delayed live status resurrection'; end if;
  if not exists(select 1 from jsonb_array_elements(result#>'{party,sharedCheers}') cheer where cheer->>'activityID'=activity_id::text and cheer->>'cheer'='pawPrint' and (cheer->>'count')::int=1) then raise exception 'terminal live cheer did not carry to its activity exactly once'; end if;
  perform public.purge_night_flock_retention(now()+interval '31 minutes');
  result:=public.night_flock_v4_state(observer_id,'party',v_party_id,null);
  if not exists(select 1 from jsonb_array_elements(result#>'{party,sharedLiveCheers}') cheer where cheer->>'statusID'=status_id::text and cheer->>'cheer'='pawPrint' and (cheer->>'count')::int=1) then raise exception 'expiry purge removed durable live-cheer reconciliation'; end if;
  if not exists(select 1 from jsonb_array_elements(result#>'{party,sharedCheers}') cheer where cheer->>'activityID'=activity_id::text and cheer->>'cheer'='pawPrint' and (cheer->>'count')::int=1) then raise exception 'expiry purge removed terminal activity cheer'; end if;

  -- Scope is per-party, then an active round independently earns exactly one grant.
  perform public.night_flock_v4_command(host_id,jsonb_build_object('command','createParty','name','Active Round','timeZoneIdentifier','UTC'));
  select membership.party_id into v_party_two_id from private.night_flock_v4_memberships membership where membership.user_id=host_id and membership.role='host' and membership.party_id<>v_party_id order by membership.joined_at desc limit 1;
  insert into private.night_flock_v4_memberships(party_id,user_id,role) values(v_party_two_id,member_id,'member');
  perform public.night_flock_v4_command(host_id,jsonb_build_object('command','startRound','partyID',v_party_two_id,'timeZoneIdentifier','UTC'));
  perform public.night_flock_v4_command(host_id,jsonb_build_object(
    'command','publishActivity','sharingScope','membership','sourceEventID',source_old,
    'kind','phoneAway','outcome','completed','startedAt',to_char(timezone('UTC',now()-interval '9 minutes'),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'endedAt',to_char(timezone('UTC',now()+interval '1 minute'),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),'windDownMinutes',0,'phoneAwayMinutes',8,'statusRevision',1
  ));
  select count(*) into grant_count from private.night_flock_v4_grants g join private.night_flock_v4_activity_ledger l on l.id=g.ledger_id where l.source_event_id=source_old;
  if grant_count<>1 then raise exception 'eligible round did not independently grant exactly once'; end if;
  select party_activity.id into legacy_activity_id from public.night_flock_v4_party_activities party_activity join private.night_flock_v4_activity_ledger ledger on ledger.id=party_activity.ledger_id where party_activity.party_id=v_party_two_id and ledger.source_event_id=source_old;
  result:=public.night_flock_v4_state(host_id,'party',v_party_two_id,null);
  if not exists(select 1 from jsonb_array_elements(result#>'{party,sharedActivities}') activity where activity->>'mySourceEventID'=source_old::text and activity->>'roundActivityID'=legacy_activity_id::text) then raise exception 'shared activity did not reference its existing round activity'; end if;
  select activity.id into stream_activity_two_id from private.night_flock_v4_membership_stream_activities activity where activity.party_id=v_party_two_id and activity.source_event_id=source_old;
  -- Old and new clients can cheer the same factual round moment.  The stream
  -- summary merges them by current reactor epoch and cheer, so the same person
  -- is not counted twice while a distinct current member is.
  perform public.night_flock_v4_command(member_id,jsonb_build_object('command','react','partyID',v_party_two_id,'activityID',legacy_activity_id,'cheer','warmWave'));
  perform public.night_flock_v4_command(member_id,jsonb_build_object('command','react','partyID',v_party_two_id,'activityID',stream_activity_two_id,'cheer','warmWave','sharingScope','membership'));
  insert into private.night_flock_v4_memberships(party_id,user_id,role) values(v_party_two_id,observer_id,'member');
  perform public.night_flock_v4_command(observer_id,jsonb_build_object('command','react','partyID',v_party_two_id,'activityID',legacy_activity_id,'cheer','warmWave'));
  insert into private.night_flock_v4_memberships(party_id,user_id,role) values(v_party_two_id,late_joiner_id,'member') returning id into late_joiner_membership;
  perform public.night_flock_v4_command(late_joiner_id,jsonb_build_object('command','react','partyID',v_party_two_id,'activityID',legacy_activity_id,'cheer','moonGlow'));
  update private.night_flock_v4_memberships set status='left',left_at=now() where id=late_joiner_membership;
  update private.night_flock_v4_memberships set status='active',joined_at=now()+interval '1 minute',left_at=null where id=late_joiner_membership;
  result:=public.night_flock_v4_state(host_id,'party',v_party_two_id,null);
  if not exists(select 1 from jsonb_array_elements(result#>'{party,sharedCheers}') cheer where cheer->>'activityID'=stream_activity_two_id::text and cheer->>'cheer'='warmWave' and (cheer->>'count')::int=2) then raise exception 'mixed-client matching cheers did not merge once per current actor'; end if;
  if exists(select 1 from jsonb_array_elements(result#>'{party,sharedCheers}') cheer where cheer->>'activityID'=stream_activity_two_id::text and cheer->>'cheer'='moonGlow') then raise exception 'legacy cheer before current membership epoch leaked into stream'; end if;
  perform public.night_flock_v4_command(host_id,jsonb_build_object(
    'command','publishActivity','sharingScope','membership','sourceEventID',source_old,
    'kind','phoneAway','outcome','completed','startedAt',to_char(timezone('UTC',now()-interval '9 minutes'),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'endedAt',to_char(timezone('UTC',now()+interval '1 minute'),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),'windDownMinutes',0,'phoneAwayMinutes',8,'statusRevision',1
  ));
  if (select count(*) from private.night_flock_v4_grants g join private.night_flock_v4_activity_ledger l on l.id=g.ledger_id where l.source_event_id=source_old)<>1 then raise exception 'stream retry duplicated round grant'; end if;

  -- Leaving creates a new epoch on rejoin.  Replaying a pre-join source cannot populate it.
  update private.night_flock_v4_memberships set status='left',left_at=now() where id=host_member;
  update private.night_flock_v4_memberships set status='active',joined_at=now()+interval '2 minutes',left_at=null where id=host_member;
  select epoch.id into second_epoch from private.night_flock_v4_membership_epochs epoch where epoch.membership_id=host_member and epoch.ended_at is null;
  if second_epoch=first_epoch or second_epoch is null then raise exception 'rejoin did not create a durable membership epoch'; end if;
  perform public.night_flock_v4_command(host_id,jsonb_build_object(
    'command','publishActivity','sharingScope','membership','sourceEventID',source_one,
    'kind','windDown','outcome','completed','startedAt',to_char(timezone('UTC',now()-interval '12 minutes'),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'endedAt',to_char(timezone('UTC',now()+interval '1 minute'),'YYYY-MM-DD"T"HH24:MI:SS"Z"'),'windDownMinutes',10,'phoneAwayMinutes',0,'statusRevision',1
  ));
  if exists(select 1 from private.night_flock_v4_membership_stream_activities activity where activity.party_id=v_party_id and activity.member_epoch_id=second_epoch) then raise exception 'prejoin activity entered rejoined membership epoch'; end if;

  -- Direct block/removal hides old rows.  Purging stream rows never touches the ledger/grant.
  perform public.night_flock_v4_command(observer_id,jsonb_build_object('command','blockMember','partyID',v_party_id,'memberID',host_member));
  begin
    perform public.night_flock_v4_state(observer_id,'party',v_party_id,null);
    raise exception 'blocker retained party access after separation';
  exception when raise_exception then if sqlerrm<>'current_membership_required' then raise; end if; end;
  perform public.purge_night_flock_retention(now()+interval '91 days');
  if exists(select 1 from private.night_flock_v4_membership_stream_activities activity where activity.party_id=v_party_two_id) then raise exception 'membership stream retention did not remove old records'; end if;
  if exists(select 1 from private.night_flock_v4_membership_stream_statuses status_row where status_row.id=status_id) then raise exception 'membership stream status survived its 90-day retention boundary'; end if;
  if not exists(select 1 from private.night_flock_v4_grants g join private.night_flock_v4_activity_ledger l on l.id=g.ledger_id where l.source_event_id=source_old) then raise exception 'retention purged source ledger and earned grant'; end if;
  -- Rejoining through the real leave/redeem command path gets a fresh epoch even when
  -- both writes share one transaction timestamp.
  perform public.night_flock_v4_command(host_id,jsonb_build_object('command','createInvite','partyID',v_party_id,'inviteDigest',encode(extensions.digest('ABCDEFGHJKLM','sha256'),'hex'),'inviteCiphertext',encode(extensions.gen_random_bytes(32),'base64'),'inviteNonce',encode(extensions.gen_random_bytes(12),'base64'),'inviteKeyVersion',1));
  perform public.night_flock_v4_command(member_id,jsonb_build_object('command','leaveParty','partyID',v_party_id));
  perform public.night_flock_v4_command(member_id,jsonb_build_object('command','redeemInvite','inviteCode','ABCDEFGHJKLM'));
  if (select count(*) from private.night_flock_v4_membership_epochs epoch where epoch.membership_id=member_membership)<>2 then raise exception 'leave/redeem did not retain distinct membership epochs'; end if;
end
$$;

do $$
begin
  if has_table_privilege('authenticated','private.night_flock_v4_membership_stream_activities','select')
     or has_function_privilege('authenticated','private.night_flock_v4_apply(uuid,jsonb)','execute')
     or has_function_privilege('authenticated','private.night_flock_v4_apply_round_legacy(uuid,jsonb)','execute')
     or has_function_privilege('anon','public.purge_night_flock_retention(timestamptz)','execute')
     or has_function_privilege('authenticated','public.purge_night_flock_retention(timestamptz)','execute') then
    raise exception 'membership stream private or service-only privileges leaked';
  end if;
end
$$;

rollback;
