begin;
insert into auth.users(id,is_anonymous,email_confirmed_at) values
 ('98000000-0000-4000-8000-000000000001',false,now()),
 ('98000000-0000-4000-8000-000000000002',false,now()),
 ('98000000-0000-4000-8000-000000000003',false,now());
do $$
#variable_conflict use_variable
declare a uuid:='98000000-0000-4000-8000-000000000001'; b uuid:='98000000-0000-4000-8000-000000000002'; c uuid:='98000000-0000-4000-8000-000000000003';
 p uuid; am uuid; bm uuid; cm uuid; ae uuid; be uuid; ce uuid; aa uuid; ba uuid; ca uuid;
 source uuid:=gen_random_uuid(); cmd jsonb; result jsonb; action jsonb; event jsonb; payload jsonb; installation uuid:=gen_random_uuid(); pending_installation uuid:=gen_random_uuid();
begin
 perform public.night_flock_v4_command(a,jsonb_build_object('command','createParty','name','Campfire buddies test','timeZoneIdentifier','UTC'));
 select party_id,id into p,am from private.night_flock_v4_memberships where user_id=a;
 insert into private.night_flock_v4_memberships(party_id,user_id,role) values(p,b,'member') returning id into bm;
 insert into private.night_flock_v4_memberships(party_id,user_id,role) values(p,c,'member') returning id into cm;
 select id into ae from private.night_flock_v4_membership_epochs where membership_id=am and ended_at is null;
 select id into be from private.night_flock_v4_membership_epochs where membership_id=bm and ended_at is null;
 select id into ce from private.night_flock_v4_membership_epochs where membership_id=cm and ended_at is null;
 perform public.night_flock_v4_command(a,jsonb_build_object('command','setCampfireSharing','partyID',p,'memberEpochID',ae,'consentVersion',2,'expectedRevision',0,'enabled',true));
 perform public.night_flock_v4_command(b,jsonb_build_object('command','setCampfireSharing','partyID',p,'memberEpochID',be,'consentVersion',2,'expectedRevision',0,'enabled',true));
 perform public.night_flock_v4_command(c,jsonb_build_object('command','setCampfireSharing','partyID',p,'memberEpochID',ce,'consentVersion',1,'expectedRevision',0,'enabled',true));
 select id into aa from private.campfire_agreements where member_epoch_id=ae;
 select id into ba from private.campfire_agreements where member_epoch_id=be;
 perform public.night_flock_v4_command(b,jsonb_build_object('command','setCampfireAlerts','partyID',p,'memberEpochID',be,'agreementID',ba,'startAlerts',true));
 perform public.register_campfire_device(b,installation,repeat('a',64),'production',true,now(),'UTC',0,0,1);
 cmd:=jsonb_build_object('command','publishCampfireSession','partyID',p,'memberEpochID',ae,'agreementID',aa,'sourceID',source,'kind','phoneAway','activity','reading',
 'startedAt',now(),'observedAt',now(),'expiresAt',now()+interval '30 minutes','ended',false,'revision',1,
 'publicIntention','Read one chapter','asksForBuddy',true,'announceStart',true,'checkInAfter',now()+interval '30 minutes');
 perform public.night_flock_v4_command(a,cmd);
 perform public.night_flock_v4_command(a,cmd);
 if (select count(*) from private.campfire_alert_events)<>1 then raise exception 'start announcement duplicated or missing'; end if;
 result:=public.night_flock_v4_state(b,'party',p,null);
 if result#>>'{party,pasture,campfire,buddies,sessions,0,publicIntention}'<>'Read one chapter' then raise exception 'missing intention'; end if;
 result:=public.night_flock_v4_state(c,'party',p,null);
 if jsonb_array_length(result#>'{party,pasture,campfire,buddies,sessions}')<>0 then raise exception 'v1 reader leaked text'; end if;
 event:=public.claim_campfire_alerts()->0;
 payload:=public.campfire_alert_payload((event->>'id')::uuid,(event->>'lease')::uuid);
 if payload is null or jsonb_array_length(payload->'devices')<>1 or payload::text like '%Read one chapter%' then raise exception 'push contract'; end if;
 update private.campfire_devices set quiet_until=now()+interval '1 hour' where installation_id=installation;
 payload:=public.campfire_alert_payload((event->>'id')::uuid,(event->>'lease')::uuid);
 if payload is not null then raise exception 'active quiet invitation was not suppressed'; end if;
 update private.campfire_devices set quiet_until=now(),quiet_start=extract(hour from now() at time zone 'UTC')::int,quiet_end=(extract(hour from now() at time zone 'UTC')::int+2)%24 where installation_id=installation;
 payload:=public.campfire_alert_payload((event->>'id')::uuid,(event->>'lease')::uuid);
 if payload is null or jsonb_array_length(payload->'devices')<>0 then raise exception 'quiet hours not applied'; end if;
 update private.campfire_devices set quiet_start=0,quiet_end=0 where installation_id=installation;
 perform public.record_campfire_alert_device((event->>'id')::uuid,(event->>'lease')::uuid,repeat('a',64));
 payload:=public.campfire_alert_payload((event->>'id')::uuid,(event->>'lease')::uuid);
 if payload is null or jsonb_array_length(payload->'devices')<>0 then raise exception 'accepted device would be resent'; end if;
 perform public.finish_campfire_alert((event->>'id')::uuid,(event->>'lease')::uuid,false);
 action:=jsonb_build_object('command','campfireBuddyAction','partyID',p,'memberEpochID',be,'agreementID',ba,'sourceID',source,'targetMemberID',am,'buddyAction','accept');
 perform public.night_flock_v4_command(b,action);
 perform public.night_flock_v4_command(b,action);
 begin perform public.night_flock_v4_command(a,action||jsonb_build_object('memberEpochID',ae,'agreementID',aa)); raise exception 'self buddy accepted'; exception when others then if sqlerrm='self buddy accepted' then raise; end if; end;
 perform public.night_flock_v4_command(c,jsonb_build_object('command','setCampfireSharing','partyID',p,'memberEpochID',ce,'consentVersion',2,'expectedRevision',1,'enabled',true));
 select id into ca from private.campfire_agreements where member_epoch_id=ce;
 result:=public.night_flock_v4_command(c,action||jsonb_build_object('memberEpochID',ce,'agreementID',ca));
 if result->>'conflict'<>'true' then raise exception 'buddy collision'; end if;
 -- A departed buddy frees the spot without adding any live presence.
 update private.night_flock_v4_membership_epochs set ended_at=now() where id=be;
 result:=public.night_flock_v4_command(c,action||jsonb_build_object('memberEpochID',ce,'agreementID',ca));
 if result->>'conflict' is distinct from 'false' then raise exception 'departed buddy retained spot'; end if;
 update private.night_flock_v4_membership_epochs set ended_at=null where id=be;
 update private.campfire_buddy_sessions set buddy_epoch_id=be where member_epoch_id=ae and source_id=source;
 perform public.night_flock_v4_command(b,action||'{"buddyAction":"encourage"}');
 perform public.night_flock_v4_command(b,action||'{"buddyAction":"encourage"}');
 if (select count(*) from private.campfire_encouragements)<>1 then raise exception 'duplicate encouragement'; end if;
 begin perform public.night_flock_v4_command(b,action||'{"buddyAction":"checkIn"}'); raise exception 'premature nudge'; exception when others then if sqlerrm='premature nudge' then raise; end if; end;
 begin perform public.night_flock_v4_command(a,action||jsonb_build_object('memberEpochID',ae,'agreementID',aa,'buddyAction','reflect','outcome','didIt')); raise exception 'premature reflection'; exception when others then if sqlerrm='premature reflection' then raise; end if; end;
 perform public.night_flock_v4_command(a,cmd||'{"ended":true,"revision":2}');
 perform public.night_flock_v4_command(a,jsonb_build_object('command','setCampfireAlerts','partyID',p,'memberEpochID',ae,'agreementID',aa,'startAlerts',true));
 update private.campfire_buddy_sessions set check_in_after=now() where member_epoch_id=ae and source_id=source;
 perform public.night_flock_v4_command(b,action||'{"buddyAction":"checkIn"}');
 if not exists(select 1 from private.campfire_alert_events e where e.event_kind='checkIn' and private.campfire_alert_eligible(e)) then raise exception 'eligible check-in missing'; end if;
 insert into public.night_flock_blocks(blocker_user_id,blocked_user_id) values(a,b);
 if exists(select 1 from private.campfire_alert_events e where e.event_kind='checkIn' and private.campfire_alert_eligible(e)) then raise exception 'blocked buddy check-in remained deliverable'; end if;
 delete from public.night_flock_blocks where blocker_user_id=a and blocked_user_id=b;
 perform public.night_flock_v4_command(a,action||jsonb_build_object('memberEpochID',ae,'agreementID',aa,'buddyAction','reflect','outcome','madeProgress','reflection','A few pages'));
 if (select count(*) from private.campfire_alert_events where event_kind='result')<>1 then raise exception 'buddy result notification missing'; end if;
 perform public.night_flock_v4_command(a,action||jsonb_build_object('memberEpochID',ae,'agreementID',aa,'buddyAction','reflect','outcome','didIt'));
 if (select outcome from private.campfire_buddy_sessions where member_epoch_id=ae and source_id=source)<>'madeProgress' then raise exception 'replayed reflection overwrote first'; end if;
 -- A sign-out can arrive before the installation's first network registration.
 perform public.unregister_campfire_device(b,pending_installation,3);
 perform public.register_campfire_device(b,pending_installation,repeat('b',64),'production',true,now(),'UTC',0,0,2);
 if exists(select 1 from private.campfire_devices where installation_id=pending_installation) then raise exception 'first registration bypassed sign-out'; end if;
 -- A delayed device registration cannot re-enable a signed-out installation.
 perform public.unregister_campfire_device(b,installation,3);
 perform public.register_campfire_device(b,installation,repeat('a',64),'production',true,now(),'UTC',0,0,2);
 if (select enabled from private.campfire_devices where installation_id=installation) then raise exception 'stale registration restored token'; end if;
 perform public.register_campfire_device(c,installation,repeat('a',64),'production',true,now(),'UTC',0,0,4);
 if (select user_id from private.campfire_devices where installation_id=installation)<>c then raise exception 'account did not rebind'; end if;
 perform public.unregister_campfire_device(b,installation,5);
 if not (select enabled from private.campfire_devices where installation_id=installation) then raise exception 'old account revoked new device'; end if;
 -- Withdrawal removes shared text, cheers, buddy commitments and queued alerts.
 perform public.night_flock_v4_command(b,jsonb_build_object('command','setCampfireSharing','partyID',p,'memberEpochID',be,'consentVersion',2,'expectedRevision',1,'enabled',false));
 if exists(select 1 from private.campfire_encouragements where sender_epoch_id=be) then raise exception 'withdrawal retained cheer'; end if;
 if exists(select 1 from private.campfire_buddy_sessions where buddy_epoch_id=be) then raise exception 'withdrawal retained buddy'; end if;
 perform public.night_flock_v4_command(a,jsonb_build_object('command','setCampfireSharing','partyID',p,'memberEpochID',ae,'consentVersion',2,'expectedRevision',1,'enabled',false));
 if exists(select 1 from private.campfire_buddy_sessions where member_epoch_id=ae) then raise exception 'withdrawal retained text'; end if;
 if exists(select 1 from private.campfire_alert_events) then raise exception 'withdrawal retained pending source'; end if;
end $$;
rollback;
