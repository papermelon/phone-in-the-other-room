-- Transactional fixtures only; use the isolated test database.
begin;
insert into auth.users(id,is_anonymous,email_confirmed_at) values
 ('97100000-0000-4000-8000-000000000001',false,now()),
 ('97100000-0000-4000-8000-000000000002',false,now());
do $$
#variable_conflict use_variable
declare a uuid:='97100000-0000-4000-8000-000000000001'; b uuid:='97100000-0000-4000-8000-000000000002';
 p uuid; ae uuid; agreement uuid; source uuid:=gen_random_uuid(); cmd jsonb; state jsonb; invalid jsonb;
 frozen timestamptz:=now()-interval '1 hour';
begin
 perform public.night_flock_v4_command(a,jsonb_build_object('command','createParty','name','Bedtime test','timeZoneIdentifier','UTC'));
 select party_id into p from private.night_flock_v4_memberships where user_id=a;
 insert into private.night_flock_v4_memberships(party_id,user_id,role) values(p,b,'member');
 select id into ae from private.night_flock_v4_membership_epochs where user_id=a and party_id=p and ended_at is null;
 perform public.night_flock_v4_command(a,jsonb_build_object('command','setCampfireSharing','partyID',p,
  'memberEpochID',ae,'consentVersion',1,'expectedRevision',0,'enabled',true));
 select id into agreement from private.campfire_agreements where member_epoch_id=ae;
 cmd:=jsonb_build_object('command','publishCampfireSession','partyID',p,'memberEpochID',ae,'agreementID',agreement,
  'sourceID',source,'kind','windDown','startedAt',now(),'observedAt',now(),'expiresAt',now()+interval '8 hours',
  'ended',false,'revision',1,'intendedBedtime',frozen,'idempotencyKey',repeat('1',64));
 perform public.night_flock_v4_command(a,cmd);
 perform public.night_flock_v4_command(a,cmd);
 state:=public.night_flock_v4_state(b,'party',p,null);
 if state#>>'{party,pasture,campfire,version}'<>'1'
  or state#>>'{party,pasture,campfire,supportsIntendedBedtime}'<>'true'
  or (state#>>'{party,pasture,campfire,sessions,0,intendedBedtime}')::timestamptz is distinct from frozen
 then raise exception 'bedtime projection or additive capability missing'; end if;
 -- Changing the payload cannot change the first accepted bedtime, even with a fresh key.
 perform public.night_flock_v4_command(a,(cmd-'idempotencyKey')||jsonb_build_object('intendedBedtime',now()));
 if (select intended_bedtime from private.campfire_sessions where member_epoch_id=ae and source_id=source) is distinct from frozen
 then raise exception 'retry moved bedtime'; end if;
 -- A legacy terminal must end a newer session without erasing its boundary.
 perform public.night_flock_v4_command(a,(cmd-'idempotencyKey'-'intendedBedtime')||'{"ended":true,"revision":2}');
 if not (select ended from private.campfire_sessions where member_epoch_id=ae and source_id=source)
 or (select intended_bedtime from private.campfire_sessions where member_epoch_id=ae and source_id=source) is distinct from frozen
 then raise exception 'legacy terminal rejected or moved bedtime'; end if;
 perform public.night_flock_v4_command(a,cmd-'idempotencyKey');
 if not (select ended from private.campfire_sessions where member_epoch_id=ae and source_id=source) then raise exception 'resurrected'; end if;
 -- Legacy source remains legacy when a newer terminal supplies metadata.
 source:=gen_random_uuid(); cmd:=(cmd-'idempotencyKey')||jsonb_build_object('sourceID',source);
 perform public.night_flock_v4_command(a,cmd-'intendedBedtime');
 perform public.night_flock_v4_command(a,cmd||'{"ended":true,"revision":2}');
 if not (select ended from private.campfire_sessions where member_epoch_id=ae and source_id=source)
 or (select intended_bedtime from private.campfire_sessions where member_epoch_id=ae and source_id=source) is not null
 then raise exception 'legacy source enriched or terminal rejected'; end if;
 -- Terminal-first delivery freezes metadata and remains terminal.
 source:=gen_random_uuid(); cmd:=cmd||jsonb_build_object('sourceID',source);
 perform public.night_flock_v4_command(a,cmd||'{"ended":true,"revision":2}');
 perform public.night_flock_v4_command(a,cmd);
 if not (select ended from private.campfire_sessions where member_epoch_id=ae and source_id=source) then raise exception 'terminal first lost'; end if;
 for invalid in select value from jsonb_array_elements(jsonb_build_array(
  jsonb_build_object('kind','phoneAway'),jsonb_build_object('intendedBedtime','infinity'),
  jsonb_build_object('intendedBedtime','-infinity'),jsonb_build_object('intendedBedtime','bad'),
  jsonb_build_object('intendedBedtime',now()+interval '9 hours'))) loop
  begin
   perform public.night_flock_v4_command(a,cmd||invalid||jsonb_build_object('sourceID',gen_random_uuid()));
   raise exception 'invalid bedtime accepted';
  exception when others then if sqlerrm='invalid bedtime accepted' then raise; end if; end;
 end loop;
 if exists(select 1 from private.campfire_sessions where member_epoch_id=ae and kind='phoneAway' and intended_bedtime is not null)
 then raise exception 'phone away bedtime stored'; end if;
 state:=public.night_flock_v4_state(b,'party',p,null);
 if state#>>'{party,pasture,lantern,contributions}'<>'0' then raise exception 'bedtime earned reward'; end if;
 insert into public.night_flock_blocks(blocker_user_id,blocked_user_id) values(b,a);
 state:=public.night_flock_v4_state(b,'party',p,null);
 if jsonb_array_length(state#>'{party,pasture,campfire,sessions}')<>0 then raise exception 'blocked bedtime leaked'; end if;
end $$;
rollback;
