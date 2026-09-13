begin;
insert into auth.users(id,is_anonymous,email_confirmed_at) values
 ('97000000-0000-4000-8000-000000000001',false,now()),
 ('97000000-0000-4000-8000-000000000002',false,now()),
 ('97000000-0000-4000-8000-000000000003',false,now());
do $$
#variable_conflict use_variable
declare a uuid:='97000000-0000-4000-8000-000000000001'; b uuid:='97000000-0000-4000-8000-000000000002';
 outsider uuid:='97000000-0000-4000-8000-000000000003'; p uuid; am uuid; bm uuid; ae uuid; be uuid; agreement uuid; source uuid:=gen_random_uuid();
 cmd jsonb; state jsonb; consent jsonb; result jsonb;
begin
 perform public.night_flock_v4_command(a,jsonb_build_object('command','createParty','name','Campfire test','timeZoneIdentifier','UTC'));
 select party_id,id into p,am from private.night_flock_v4_memberships where user_id=a;
 insert into private.night_flock_v4_memberships(party_id,user_id,role) values(p,b,'member') returning id into bm;
 select id into ae from private.night_flock_v4_membership_epochs where membership_id=am and ended_at is null;
 select id into be from private.night_flock_v4_membership_epochs where membership_id=bm and ended_at is null;
 state:=public.night_flock_v4_state(a,'party',p,null);
 if state#>>'{party,pasture,campfire,version}'<>'1' or state#>>'{party,pasture,campfire,agreement}' is not null then raise exception 'implicit consent or missing capability'; end if;
 consent:=jsonb_build_object('command','setCampfireSharing','partyID',p,'memberEpochID',ae,'consentVersion',1,'expectedRevision',0,'enabled',true,'idempotencyKey',repeat('a',64));
 perform public.night_flock_v4_command(a,consent);
 perform public.night_flock_v4_command(a,consent);
 if (select revision from private.campfire_agreements where member_epoch_id=ae)<>1 then raise exception 'duplicate acceptance'; end if;
 select id into agreement from private.campfire_agreements where member_epoch_id=ae;
 cmd:=jsonb_build_object('command','publishCampfireSession','partyID',p,'memberEpochID',ae,'agreementID',agreement,'sourceID',source,'kind','phoneAway','activity','reading',
 'startedAt',now(),'observedAt',now(),'expiresAt',now()+interval '30 minutes','ended',false,'revision',1);
 -- A terminal source may arrive first. A delayed start cannot revive it.
 perform public.night_flock_v4_command(a,cmd||'{"ended":true,"revision":2}');
 perform public.night_flock_v4_command(a,cmd);
 if not (select ended from private.campfire_sessions where member_epoch_id=ae and source_id=source) then raise exception 'late start resurrected'; end if;
 source:=gen_random_uuid(); cmd:=cmd||jsonb_build_object('sourceID',source,'startedAt',now()+interval '1 second','observedAt',now()+interval '1 second');
 perform public.night_flock_v4_command(a,cmd);
 state:=public.night_flock_v4_state(b,'party',p,null);
 if state#>>'{party,pasture,campfire,sessions,0,activity}'<>'reading' then raise exception 'peer cannot see shared invitation'; end if;
 if state#>>'{party,pasture,campfire,agreement}' is not null then raise exception 'peer received consent receipt'; end if;
 if state#>>'{party,pasture,lantern,contributions}'<>'0' then raise exception 'presence earned reward'; end if;
 begin perform public.night_flock_v4_command(outsider,cmd); raise exception 'outsider published'; exception when others then if sqlerrm='outsider published' then raise; end if; end;
 begin perform public.night_flock_v4_command(b,cmd||jsonb_build_object('memberEpochID',be)); raise exception 'unconsented peer published'; exception when others then if sqlerrm='unconsented peer published' then raise; end if; end;
 begin perform public.night_flock_v4_command(a,cmd||jsonb_build_object('expiresAt',now()+interval '48 hours')); raise exception 'unbounded presence'; exception when others then if sqlerrm='unbounded presence' then raise; end if; end;
 begin perform public.night_flock_v4_command(a,cmd||jsonb_build_object('startedAt',now()-interval '1 day')); raise exception 'private backfill'; exception when others then if sqlerrm='private backfill' then raise; end if; end;
 insert into public.night_flock_blocks(blocker_user_id,blocked_user_id) values(b,a);
 state:=public.night_flock_v4_state(b,'party',p,null);
 if jsonb_array_length(state#>'{party,pasture,campfire,sessions}')<>0 then raise exception 'blocked presence visible'; end if;
 delete from public.night_flock_blocks where blocker_user_id=b and blocked_user_id=a;
 perform public.night_flock_v4_command(a,(consent-'idempotencyKey')||'{"expectedRevision":1,"enabled":false}');
 if exists(select 1 from private.campfire_sessions where member_epoch_id=ae) then raise exception 'withdrawal kept presence'; end if;
 result:=public.night_flock_v4_command(a,consent-'idempotencyKey');
 if result->>'conflict'<>'true' or (select enabled from private.campfire_agreements where member_epoch_id=ae) then raise exception 'old consent reenabled sharing'; end if;
 begin perform public.night_flock_v4_command(a,cmd); raise exception 'old receipt admitted'; exception when others then if sqlerrm='old receipt admitted' then raise; end if; end;
 perform public.night_flock_v4_command(a,(consent-'idempotencyKey')||'{"expectedRevision":2,"enabled":true}');
 select id into agreement from private.campfire_agreements where member_epoch_id=ae;
 perform public.night_flock_v4_command(a,cmd||jsonb_build_object('agreementID',agreement));
 update private.night_flock_v4_membership_epochs set ended_at=now() where id=ae;
 state:=public.night_flock_v4_state(b,'party',p,null);
 if jsonb_array_length(state#>'{party,pasture,campfire,sessions}')<>0 then raise exception 'ended epoch visible'; end if;
 begin perform public.night_flock_v4_command(a,cmd); raise exception 'old epoch admitted'; exception when others then if sqlerrm='old epoch admitted' then raise; end if; end;
end $$;
rollback;
