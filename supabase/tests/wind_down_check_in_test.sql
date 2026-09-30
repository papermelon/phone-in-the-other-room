-- Disposable accounts only; every fixture and command rolls back.
begin;
insert into auth.users(id,is_anonymous,email_confirmed_at) values
 ('d9300000-0000-4000-8000-000000000001',false,now()),
 ('d9300000-0000-4000-8000-000000000002',false,now()),
 ('d9300000-0000-4000-8000-000000000003',false,now());
do $$
#variable_conflict use_variable
declare a uuid:='d9300000-0000-4000-8000-000000000001'; b uuid:='d9300000-0000-4000-8000-000000000002';
 c uuid:='d9300000-0000-4000-8000-000000000003'; p uuid; am uuid; ae uuid; be uuid; ce uuid; aa uuid; ba uuid;
 source uuid; cmd jsonb; action jsonb; state jsonb; item jsonb; answer text; context jsonb;
begin
 if has_function_privilege('anon','public.night_flock_v4_state(uuid,text,uuid,text)','EXECUTE')
 or has_function_privilege('authenticated','private.night_flock_v4_apply_before_wardrobe(uuid,jsonb)','EXECUTE')
 then raise exception 'raw access'; end if;
 perform public.night_flock_v4_command(a,'{"command":"createParty","name":"Wind Down check-in test","timeZoneIdentifier":"UTC"}');
 select party_id,id into p,am from private.night_flock_v4_memberships where user_id=a;
 insert into private.night_flock_v4_memberships(party_id,user_id,role) values(p,b,'member'),(p,c,'member');
 select id into ae from private.night_flock_v4_membership_epochs where party_id=p and user_id=a and ended_at is null;
 select id into be from private.night_flock_v4_membership_epochs where party_id=p and user_id=b and ended_at is null;
 select id into ce from private.night_flock_v4_membership_epochs where party_id=p and user_id=c and ended_at is null;
 perform public.night_flock_v4_command(a,jsonb_build_object('command','setCampfireSharing','partyID',p,'memberEpochID',ae,'consentVersion',2,'expectedRevision',0,'enabled',true));
 perform public.night_flock_v4_command(b,jsonb_build_object('command','setCampfireSharing','partyID',p,'memberEpochID',be,'consentVersion',2,'expectedRevision',0,'enabled',true));
 perform public.night_flock_v4_command(c,jsonb_build_object('command','setCampfireSharing','partyID',p,'memberEpochID',ce,'consentVersion',1,'expectedRevision',0,'enabled',true));
 select id into aa from private.campfire_agreements where member_epoch_id=ae;
 select id into ba from private.campfire_agreements where member_epoch_id=be;
 perform public.night_flock_v4_command(b,jsonb_build_object('command','setCampfireAlerts','partyID',p,'memberEpochID',be,'agreementID',ba,'startAlerts',true));
 for answer in select unnest(array['windDownEasy','windDownSomeEffort','windDownHard']) loop
  source:=gen_random_uuid();
  cmd:=jsonb_build_object('command','publishCampfireSession','partyID',p,'memberEpochID',ae,'agreementID',aa,
   'sourceID',source,'kind','windDown','startedAt',now(),'observedAt',now(),'expiresAt',now()+interval '1 hour',
   'ended',false,'revision',1,'publicIntention','','asksForBuddy',true,'announceStart',false,'checkInAfter',now()+interval '2 hours');
  perform public.night_flock_v4_command(a,cmd);
  action:=jsonb_build_object('command','campfireBuddyAction','partyID',p,'memberEpochID',ae,'agreementID',aa,
   'sourceID',source,'targetMemberID',am,'buddyAction','reflect','outcome',answer,'reflection','A busy evening');
  -- Early ending does not bypass morning quiet.
  perform public.night_flock_v4_command(a,cmd||'{"ended":true,"revision":2}');
  begin perform public.night_flock_v4_command(a,action); raise exception 'premature reflection';
   exception when others then if sqlerrm='premature reflection' then raise; end if; end;
  update private.campfire_buddy_sessions set check_in_after=now(),buddy_epoch_id=be where member_epoch_id=ae and source_id=source;
  begin perform public.night_flock_v4_command(b,action||jsonb_build_object('memberEpochID',be,'agreementID',ba)); raise exception 'owner spoof';
   exception when others then if sqlerrm='owner spoof' then raise; end if; end;
  perform public.night_flock_v4_command(a,action);
  perform public.night_flock_v4_command(a,action||'{"outcome":"didIt","reflection":"stale replay"}');
  perform public.night_flock_v4_command(a,action||'{"outcome":"windDownHard","reflection":"changed answer"}');
  if (select outcome from private.campfire_buddy_sessions where member_epoch_id=ae and source_id=source) is distinct from answer
   or (select reflection from private.campfire_buddy_sessions where member_epoch_id=ae and source_id=source)<>'A busy evening'
   then raise exception 'first answer overwritten'; end if;
  if not exists(select 1 from private.campfire_alert_events e where e.source_id=source and event_kind='result' and private.campfire_alert_eligible(e))
   then raise exception 'buddy result notification missing'; end if;
  state:=public.night_flock_v4_state(b,'party',p,null);
  select value into item from jsonb_array_elements(state#>'{party,pasture,campfire,buddies,sessions}') where value->>'sourceID'=source::text;
  if state#>>'{party,pasture,campfire,buddies,supportsWindDownEase}'<>'true'
   or item->>'windDownOutcome' is distinct from answer or item->>'outcome' is not null
   or item->>'reflection'<>'A busy evening' then raise exception 'ease projection or legacy decoding'; end if;
  context:=private.social_source(b,jsonb_build_object('kind','campfire','id',source,'partyID',p,'memberID',am));
  if context is null or context->'messages' ? 'niceWork' then raise exception 'ease inferred task completion'; end if;
 end loop;
 -- A legacy Wind Down result remains unchanged and wins against a newer queued answer.
 source:=gen_random_uuid(); cmd:=cmd||jsonb_build_object('sourceID',source);
 perform public.night_flock_v4_command(a,cmd);
 update private.campfire_buddy_sessions set check_in_after=now() where member_epoch_id=ae and source_id=source;
 action:=action||jsonb_build_object('sourceID',source,'outcome','didIt');
 perform public.night_flock_v4_command(a,action);
 perform public.night_flock_v4_command(a,action||'{"outcome":"windDownEasy"}');
 state:=public.night_flock_v4_state(b,'party',p,null);
 select value into item from jsonb_array_elements(state#>'{party,pasture,campfire,buddies,sessions}') where value->>'sourceID'=source::text;
 if item->>'outcome'<>'didIt' or item ? 'windDownOutcome' then raise exception 'historical outcome relabelled'; end if;
 -- Phone Away cannot receive an ease answer.
 source:=gen_random_uuid(); cmd:=cmd||jsonb_build_object('sourceID',source,'kind','phoneAway','activity','reading');
 perform public.night_flock_v4_command(a,cmd);
 perform public.night_flock_v4_command(a,cmd||'{"ended":true,"revision":2}');
 action:=action||jsonb_build_object('sourceID',source,'outcome','windDownEasy');
 begin perform public.night_flock_v4_command(a,action); raise exception 'phone away accepted ease';
  exception when others then if sqlerrm='phone away accepted ease' then raise; end if; end;
 perform public.night_flock_v4_command(a,action||'{"outcome":"madeProgress"}');
 -- Existing consent, block and withdrawal fences cover the new field too.
 state:=public.night_flock_v4_state(c,'party',p,null);
 if jsonb_array_length(state#>'{party,pasture,campfire,buddies,sessions}')<>0 then raise exception 'v1 consent leaked reflection'; end if;
 insert into public.night_flock_blocks(blocker_user_id,blocked_user_id) values(b,a);
 state:=public.night_flock_v4_state(b,'party',p,null);
 if jsonb_array_length(state#>'{party,pasture,campfire,buddies,sessions}')<>0 then raise exception 'blocked reflection visible'; end if;
 delete from public.night_flock_blocks where blocker_user_id=b and blocked_user_id=a;
 perform public.night_flock_v4_command(a,jsonb_build_object('command','setCampfireSharing','partyID',p,'memberEpochID',ae,'consentVersion',2,'expectedRevision',1,'enabled',false));
 if exists(select 1 from private.campfire_buddy_sessions where member_epoch_id=ae) then raise exception 'withdrawal retained reflection'; end if;
 if exists(select 1 from private.campfire_alert_events where source_epoch=ae) then raise exception 'withdrawal retained alerts'; end if;
end $$;
rollback;
