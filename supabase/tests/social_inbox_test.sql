begin;
insert into auth.users(id,is_anonymous,email_confirmed_at) values
 ('d9280000-0000-4000-8000-000000000001',false,now()),
 ('d9280000-0000-4000-8000-000000000002',false,now()),
 ('d9280000-0000-4000-8000-000000000003',false,now());
do $$
declare a uuid:='d9280000-0000-4000-8000-000000000001'; b uuid:='d9280000-0000-4000-8000-000000000002';
 c uuid:='d9280000-0000-4000-8000-000000000003'; p uuid; am uuid; ae uuid; be uuid; aid uuid; inv uuid;
 cmd uuid:=gen_random_uuid(); src jsonb; result jsonb; request jsonb; event text; alert jsonb; payload jsonb;
begin
 if has_function_privilege('anon','public.social_inbox_v1(jsonb)','EXECUTE') or has_table_privilege('authenticated','private.social_support','SELECT') then raise exception 'raw access'; end if;
 perform set_config('request.jwt.claim.sub',a::text,true);
 result:=public.night_flock_v4_command(a,'{"command":"createParty","name":"Social test","timeZoneIdentifier":"UTC"}');
 p:=(result->>'resolvedPartyID')::uuid;
 insert into private.night_flock_v4_memberships(party_id,user_id,role) values(p,b,'member');
 select id into am from private.night_flock_v4_memberships where party_id=p and user_id=a;
 select id into ae from private.night_flock_v4_membership_epochs where party_id=p and user_id=a and ended_at is null;
 select id into be from private.night_flock_v4_membership_epochs where party_id=p and user_id=b and ended_at is null;
 -- Invitations appear before membership, independently of OS permission.
 result:=public.slumber_party_connections_v1(jsonb_build_object('action','invite','partyID',p,'userID',c));
 inv:=(result#>>'{invitations,0,id}')::uuid;
 perform set_config('request.jwt.claim.sub',c::text,true);
 result:=public.social_inbox_v1(jsonb_build_object('action','inbox','ownerID',c));
 if result->>'pendingInvitations'<>'1' or result->>'unreadCount'<>'1' then raise exception 'new invitation missing'; end if;
 perform public.social_inbox_v1(jsonb_build_object('action','read','ownerID',c,'eventIDs',jsonb_build_array('invite:'||inv)));
 result:=public.social_inbox_v1(jsonb_build_object('action','summary','ownerID',c));
 if result->>'pendingInvitations'<>'1' or result->>'unreadCount'<>'0' then raise exception 'read cleared pending'; end if;
 begin
  perform public.social_inbox_v1(jsonb_build_object('action','inbox','ownerID',a)); raise exception 'owner spoof';
 exception when insufficient_privilege then null; end;
 -- A new cheer on an old update is ordered by arrival, not activity time.
 update private.night_flock_v4_membership_epochs set joined_at=now()-interval '10 days' where party_id=p;
 insert into private.night_flock_v4_membership_stream_activities(party_id,member_id,member_epoch_id,source_event_id,kind,outcome,wind_down_minutes,phone_away_minutes,revision,occurred_at)
 values(p,am,ae,gen_random_uuid(),'windDown','completed',10,0,1,now()-interval '3 days') returning id into aid;
 src:=jsonb_build_object('kind','activity','id',aid,'partyID',p);
 perform set_config('request.jwt.claim.sub',b::text,true);
 request:=jsonb_build_object('action','send','ownerID',b,'source',src,'messageID','niceWork','commandID',cmd);
 result:=public.social_inbox_v1(request);
 if result#>>'{detail,sentMessageID}'<>'niceWork' then raise exception 'message not confirmed'; end if;
 perform public.social_inbox_v1(request);
 if (select count(*) from private.social_support where sender=b)<>1 then raise exception 'duplicate support'; end if;
 perform set_config('request.jwt.claim.sub',a::text,true);
 result:=public.social_inbox_v1(jsonb_build_object('action','inbox','ownerID',a));
 if result#>>'{events,0,messageID}'<>'niceWork' or (result#>>'{events,0,arrivedAt}')::timestamptz<=now()-interval '1 minute'
 or (result#>>'{events,0,occurredAt}')::timestamptz>=now()-interval '2 days' then raise exception 'arrival/context mixup'; end if;
 event:=result#>>'{events,0,id}';
 perform public.social_inbox_v1(jsonb_build_object('action','read','ownerID',a,'eventIDs',jsonb_build_array(event)));
 if public.social_inbox_v1(jsonb_build_object('action','summary','ownerID',a))->>'unreadCount'<>'0' then raise exception 'read not durable'; end if;
 perform set_config('request.jwt.claim.sub',b::text,true);
 perform public.social_inbox_v1(request||'{"action":"remove"}');
 result:=public.social_inbox_v1(request);
 if result#>>'{detail,removed}'<>'true' then raise exception 'replay resurrected removal'; end if;
 if exists(select 1 from private.social_inbox_events(a) where id=event) then raise exception 'removed message visible'; end if;
 -- Recognition is rejected for unfinished work, independently of UI filtering.
 update private.night_flock_v4_membership_stream_activities set outcome='partlyCompleted' where id=aid;
 result:=public.social_inbox_v1(request||'{"action":"source"}');
 if result#>'{detail,messages}' ? 'niceWork' then raise exception 'unearned recognition'; end if;
 perform set_config('request.jwt.claim.sub',c::text,true);
 begin
  perform public.social_inbox_v1(request||jsonb_build_object('ownerID',c,'commandID',gen_random_uuid())); raise exception 'nonmember sent';
 exception when others then if sqlerrm<>'source_unavailable' then raise; end if; end;
 -- Blocks and membership epochs fence history and replay.
 insert into public.night_flock_blocks(blocker_user_id,blocked_user_id) values(a,b);
 if private.social_source(b,src) is not null then raise exception 'blocked source'; end if;
 delete from public.night_flock_blocks where blocker_user_id=a;
 update private.night_flock_v4_memberships set status='left',left_at=now() where party_id=p and user_id=b;
 if private.social_source(b,src) is not null then raise exception 'departed source'; end if;
end $$;
rollback;
