begin;
insert into auth.users(id,is_anonymous,email_confirmed_at) values
 ('d9290000-0000-4000-8000-000000000001',false,now()),
 ('d9290000-0000-4000-8000-000000000002',false,now()),
 ('d9290000-0000-4000-8000-000000000003',false,now());
do $$
declare a uuid:='d9290000-0000-4000-8000-000000000001'; b uuid:='d9290000-0000-4000-8000-000000000002';
 c uuid:='d9290000-0000-4000-8000-000000000003'; p uuid; am uuid; ae uuid; be uuid; aa uuid; ba uuid;
 source_id uuid:=gen_random_uuid(); global_id uuid; src jsonb; result jsonb; event jsonb; payload jsonb; request jsonb;
 installation uuid:=gen_random_uuid(); token text:=repeat('b',64); command_id uuid:=gen_random_uuid();
begin
 if has_function_privilege('authenticated','public.claim_social_alerts()','EXECUTE') then raise exception 'client can dispatch'; end if;
 perform set_config('request.jwt.claim.sub',a::text,true);
 result:=public.night_flock_v4_command(a,'{"command":"createParty","name":"Alert test","timeZoneIdentifier":"UTC"}');
 p:=(result->>'resolvedPartyID')::uuid;
 select id into am from private.night_flock_v4_memberships where party_id=p and user_id=a;
 insert into private.night_flock_v4_memberships(party_id,user_id,role) values(p,b,'member');
 select id into ae from private.night_flock_v4_membership_epochs where party_id=p and user_id=a and ended_at is null;
 select id into be from private.night_flock_v4_membership_epochs where party_id=p and user_id=b and ended_at is null;
 perform public.night_flock_v4_command(a,jsonb_build_object('command','setCampfireSharing','partyID',p,'memberEpochID',ae,'consentVersion',2,'expectedRevision',0,'enabled',true));
 perform public.night_flock_v4_command(b,jsonb_build_object('command','setCampfireSharing','partyID',p,'memberEpochID',be,'consentVersion',2,'expectedRevision',0,'enabled',true));
 select id into aa from private.campfire_agreements where member_epoch_id=ae;
 select id into ba from private.campfire_agreements where member_epoch_id=be;
 perform public.night_flock_v4_command(a,jsonb_build_object('command','publishCampfireSession','partyID',p,'memberEpochID',ae,'agreementID',aa,
  'sourceID',source_id,'kind','windDown','startedAt',now(),'observedAt',now(),'expiresAt',now()+interval '8 hours','ended',false,'revision',1,
  'publicIntention','','asksForBuddy',false,'announceStart',false,'checkInAfter',now()+interval '8 hours'));
 src:=jsonb_build_object('kind','campfire','id',source_id,'partyID',p,'memberID',am);
 perform public.social_inbox_v1(jsonb_build_object('action','preferences','ownerID',a,'preferences',jsonb_build_object('invitations',true,'cheers',true,'globalCheers',false)));
 perform public.register_campfire_device(a,installation,token,'production',true,now(),'America/New_York',0,0,1);
 perform set_config('request.jwt.claim.sub',b::text,true);
 request:=jsonb_build_object('action','send','ownerID',b,'source',src,'messageID','restWell','commandID',command_id);
 result:=public.social_inbox_v1(request);
 if result#>>'{detail,sentMessageID}'<>'restWell' then raise exception 'wind down message'; end if;
 if result#>'{detail,messages}' ? 'niceWork' then raise exception 'active session recognition'; end if;
 perform public.social_inbox_v1(request);
 if (select count(*) from private.social_alert_events where recipient=a)<>1 then raise exception 'alert duplication'; end if;
 if public.claim_social_alerts()<>'[]'::jsonb then raise exception 'two minute batching missing'; end if;
 update private.social_alert_events set due_at=now()-interval '1 second' where recipient=a;
 event:=public.claim_social_alerts()->0;
 if event is null then raise exception 'no due alert'; end if;
 if public.claim_social_alerts()<>'[]'::jsonb then raise exception 'concurrent recipient claimed'; end if;
 payload:=public.social_alert_payload((event->>'id')::uuid,(event->>'lease')::uuid);
 if payload->>'ownerID'<>a::text or jsonb_array_length(payload->'devices')<>1 or payload::text like '%Alert test%' then raise exception 'push privacy'; end if;
 update private.campfire_devices set quiet_until=now()+interval '1 hour' where installation_id=installation;
 payload:=public.social_alert_payload((event->>'id')::uuid,(event->>'lease')::uuid);
 if payload->>'defer'<>'true' then raise exception 'active quiet not deferred'; end if;
 update private.campfire_devices set quiet_until=now(),quiet_start=extract(hour from now() at time zone time_zone)::int,
  quiet_end=(extract(hour from now() at time zone time_zone)::int+1)%24 where installation_id=installation;
 if public.social_alert_payload((event->>'id')::uuid,(event->>'lease')::uuid)->>'defer'<>'true' then raise exception 'scheduled quiet not deferred'; end if;
 perform public.settle_social_alert((event->>'id')::uuid,(event->>'lease')::uuid,'defer');
 if (select attempts from private.social_alert_events where id=(event->>'id')::uuid)<>0 then raise exception 'quiet spent retry budget'; end if;
 update private.campfire_devices set quiet_start=0,quiet_end=0 where installation_id=installation;
 update private.social_alert_events set due_at=now()-interval '1 second' where recipient=a;
 event:=public.claim_social_alerts()->0;
 perform public.settle_social_alert((event->>'id')::uuid,(event->>'lease')::uuid,'device',token,true);
 if jsonb_array_length(public.social_alert_payload((event->>'id')::uuid,(event->>'lease')::uuid)->'devices')<>0 then raise exception 'accepted token resent'; end if;
 perform public.settle_social_alert((event->>'id')::uuid,(event->>'lease')::uuid,'finish');
 if (select state from private.social_alert_events where id=(event->>'id')::uuid)<>'accepted' then raise exception 'APNs acceptance not recorded'; end if;
 -- Hourly limits defer another valid cheer without removing its inbox record.
 update private.social_alert_events set event_id='quota-fixture' where id=(event->>'id')::uuid;
 insert into private.social_alert_events(recipient,event_id,kind,due_at,expires_at)
 values(a,'support:'||command_id,'cheer',now(),now()+interval '1 day');
 event:=public.claim_social_alerts()->0;
 if public.social_alert_payload((event->>'id')::uuid,(event->>'lease')::uuid)->>'defer'<>'true' then raise exception 'hourly cheer cap'; end if;
 -- A second phone's quiet window suppresses the account; device reassignment
 -- must never send the previous owner's queue to its new account.
 update private.social_alert_events set sent_at=now()-interval '2 hours' where event_id='quota-fixture';
 perform public.register_campfire_device(a,gen_random_uuid(),repeat('c',64),'production',true,now()+interval '1 hour','UTC',0,0,1);
 if public.social_alert_payload((event->>'id')::uuid,(event->>'lease')::uuid)->>'defer'<>'true' then raise exception 'second device quiet ignored'; end if;
 update private.campfire_devices set quiet_until=now() where user_id=a;
 perform public.register_campfire_device(b,installation,token,'production',true,now(),'UTC',0,0,2);
 payload:=public.social_alert_payload((event->>'id')::uuid,(event->>'lease')::uuid);
 if exists(select 1 from jsonb_array_elements(payload->'devices') d where d->>'token'=token) then raise exception 'device owner crossed'; end if;
 perform public.settle_social_alert((event->>'id')::uuid,(event->>'lease')::uuid,'terminal');
 -- Global support stays anonymous and is not pushed without separate opt-in.
 update private.global_campfire_settings set enabled=true;
 insert into private.global_campfire_profiles(user_id,name,appearance) values(a,'A','{}'),(b,'B','{}');
 insert into private.global_campfire_sessions(user_id,source_id,agreement_id,kind,started_at,expires_at,ended)
 select a,gen_random_uuid(),agreement_id,'windDown',now(),now()+interval '1 hour',false from private.global_campfire_profiles where user_id=a returning id into global_id;
 src:=jsonb_build_object('kind','global','id',global_id);
 perform public.social_inbox_v1(jsonb_build_object('action','send','ownerID',b,'source',src,'messageID','goodNight','commandID',gen_random_uuid()));
 if exists(select 1 from private.social_alert_events where recipient=a and is_global) then raise exception 'global auto opted in'; end if;
 if exists(select 1 from private.social_inbox_events(a) where source->>'kind'='global' and sender_name is not null) then raise exception 'global identity exposed'; end if;
 update private.global_campfire_profiles set enabled=false where user_id=b;
 if exists(select 1 from private.social_inbox_events(a) where source->>'kind'='global') then raise exception 'withdrawn global support visible'; end if;
 -- An invitation can alert a nonmember and becomes ineligible on revocation.
 perform set_config('request.jwt.claim.sub',c::text,true);
 perform public.social_inbox_v1(jsonb_build_object('action','preferences','ownerID',c,'preferences',jsonb_build_object('invitations',true,'cheers',false,'globalCheers',false)));
 perform set_config('request.jwt.claim.sub',b::text,true);
 perform public.slumber_party_connections_v1(jsonb_build_object('action','invite','partyID',p,'userID',c));
 event:=public.claim_social_alerts()->0;
 if event is null then raise exception 'nonmember invitation not queued'; end if;
 update private.slumber_party_invitations set status='revoked' where party_id=p and recipient_id=c;
 if public.social_alert_payload((event->>'id')::uuid,(event->>'lease')::uuid) is not null then raise exception 'revoked invite still dispatches'; end if;
end $$;
rollback;
