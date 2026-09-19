begin;
insert into auth.users(id,is_anonymous,email_confirmed_at) values
 ('af000000-0000-4000-8000-000000000001',false,now()),
 ('af000000-0000-4000-8000-000000000002',false,now()),
 ('af000000-0000-4000-8000-000000000003',false,now()),
 ('af000000-0000-4000-8000-000000000004',true,null);
do $$
#variable_conflict use_variable
declare a uuid:='af000000-0000-4000-8000-000000000001'; b uuid:='af000000-0000-4000-8000-000000000002';
 d uuid:='af000000-0000-4000-8000-000000000003'; guest uuid:='af000000-0000-4000-8000-000000000004';
 agreement jsonb; result jsonb; state jsonb; publish jsonb; terminal jsonb; aid uuid; bid uuid; source uuid:=gen_random_uuid(); target uuid;
begin
 state:=public.global_campfire_state(a);
 if state->>'available'<>'false' or jsonb_array_length(state->'participants')<>0 then raise exception 'activation or fake presence'; end if;
 begin perform public.global_campfire_state(guest); raise exception 'guest admitted'; exception when others then if sqlerrm='guest admitted' then raise; end if; end;
 update private.global_campfire_settings set enabled=true;
 agreement:=jsonb_build_object('id',gen_random_uuid(),'command','agreement','consentVersion',1,'expectedRevision',0,'enabled',true,'publicName','Fern',
 'appearance',jsonb_build_object('skinToneID','warm','hairStyleID','waves','shepherdOutfitID','none','shepherdAccessoryID','none'));
 perform public.global_campfire_command(a,agreement);
 perform public.global_campfire_command(a,agreement);
 if (select revision from private.global_campfire_profiles where user_id=a)<>1 then raise exception 'duplicate consent'; end if;
 perform public.global_campfire_command(b,agreement||jsonb_build_object('id',gen_random_uuid(),'publicName','Willow'));
 select agreement_id into aid from private.global_campfire_profiles where user_id=a;
 select agreement_id into bid from private.global_campfire_profiles where user_id=b;
 publish:=jsonb_build_object('id',gen_random_uuid(),'command','publish','sourceID',source,'agreementID',aid,'kind','windDown',
 'startedAt',now(),'expiresAt',now()+interval '8 hours','ended',false);
 begin perform public.global_campfire_command(d,publish); raise exception 'unconsented publication'; exception when others then if sqlerrm='unconsented publication' then raise; end if; end;
 begin perform public.global_campfire_command(a,publish||jsonb_build_object('privateIntention','secret')); raise exception 'private data accepted'; exception when others then if sqlerrm='private data accepted' then raise; end if; end;
 perform public.global_campfire_command(a,publish);
 perform public.global_campfire_command(b,publish||jsonb_build_object('id',gen_random_uuid(),'agreementID',bid,'sourceID',gen_random_uuid(),'kind','phoneAway','activity','reading','expiresAt',now()+interval '30 minutes'));
 state:=public.global_campfire_state(d);
 if jsonb_array_length(state->'participants')<>2 then raise exception 'mixed modes missing'; end if;
 if state->>'approximateCount'<>'10' then raise exception 'exact worldwide count exposed'; end if;
 if (state->'participants')::text ~ 'sourceID|userID|startedAt|expiresAt|partyID|intention|Health' then raise exception 'private projection leaked'; end if;
 if jsonb_array_length(public.global_campfire_state(d,'reading')->'participants')<>1 then raise exception 'gathering not filtered'; end if;
 if jsonb_array_length(public.global_campfire_state(d,'windDown')->'participants')<>1 then raise exception 'Wind Down missing'; end if;
 select id into target from private.global_campfire_sessions where user_id=a;
 perform public.global_campfire_command(d,jsonb_build_object('id',gen_random_uuid(),'command','encourage','targetID',target));
 perform public.global_campfire_command(d,jsonb_build_object('id',gen_random_uuid(),'command','encourage','targetID',target));
 if (select count(*) from private.global_campfire_encouragements where sender=d and session_id=target)<>1 then raise exception 'duplicate encouragement'; end if;
 if public.global_campfire_state(a)->>'ownEncouragementCount'<>'1' then raise exception 'recipient cannot see encouragement'; end if;
 terminal:=publish||jsonb_build_object('id',gen_random_uuid(),'ended',true);
 perform public.global_campfire_command(a,terminal);
 perform public.global_campfire_command(a,publish||jsonb_build_object('id',gen_random_uuid()));
 if jsonb_array_length(public.global_campfire_state(d,'windDown')->'participants')<>0 then raise exception 'late start revived session'; end if;
 -- A terminal can arrive before its start, including from an offline outbox.
 source:=gen_random_uuid(); terminal:=terminal||jsonb_build_object('id',gen_random_uuid(),'sourceID',source);
 perform public.global_campfire_command(a,terminal);
 perform public.global_campfire_command(a,terminal||jsonb_build_object('id',gen_random_uuid(),'ended',false));
 if not(select ended from private.global_campfire_sessions where user_id=a and source_id=source) then raise exception 'terminal lost'; end if;
 select public_id into target from private.global_campfire_profiles where user_id=b;
 perform public.global_campfire_command(d,jsonb_build_object('id',gen_random_uuid(),'command','report','targetID',target,'reason','profile'));
 if (select count(*) from private.global_campfire_reports where reporter=d)<>1 then raise exception 'report missing'; end if;
 perform public.global_campfire_command(d,jsonb_build_object('id',gen_random_uuid(),'command','block','targetID',target));
 if jsonb_array_length(public.global_campfire_state(d,'reading')->'participants')<>0 then raise exception 'blocked presence visible'; end if;
 if not private.night_flock_users_blocked(b,d) then raise exception 'block not mutual'; end if;
 perform public.global_campfire_command(a,jsonb_build_object('id',gen_random_uuid(),'command','agreement','consentVersion',1,'expectedRevision',1,'enabled',false));
 result:=public.global_campfire_command(a,agreement||jsonb_build_object('id',gen_random_uuid()));
 if result->>'conflict'<>'true' then raise exception 'stale consent undid withdrawal'; end if;
 begin perform public.global_campfire_command(a,publish||jsonb_build_object('id',gen_random_uuid())); raise exception 'old receipt admitted'; exception when others then if sqlerrm='old receipt admitted' then raise; end if; end;
 -- Off must create a fence even before a delayed first acceptance arrives.
 perform public.global_campfire_command(d,jsonb_build_object('id',gen_random_uuid(),'command','agreement','consentVersion',1,'expectedRevision',0,'enabled',false));
 result:=public.global_campfire_command(d,agreement||jsonb_build_object('id',gen_random_uuid()));
 if result->>'conflict'<>'true' then raise exception 'first acceptance escaped Off'; end if;
 update private.global_campfire_profiles set suspended=true where user_id=b;
 if jsonb_array_length(public.global_campfire_state(a)->'participants')<>0 then raise exception 'suspended profile visible'; end if;
 update private.global_campfire_settings set enabled=false;
 state:=public.global_campfire_state(a);
 if state->>'available'<>'false' or jsonb_array_length(state->'participants')<>0 then raise exception 'kill switch failed'; end if;
 if has_table_privilege('authenticated','private.global_campfire_profiles','SELECT')
 or has_table_privilege('service_role','private.global_campfire_sessions','SELECT')
 or has_function_privilege('authenticated','public.global_campfire_command(uuid,jsonb)','EXECUTE') then raise exception 'direct access permitted'; end if;
end $$;
-- Bounded paging, expiry, deletion and retention use only synthetic records.
do $$
declare viewer uuid:='af000000-0000-4000-8000-000000000001'; owner uuid; receipt uuid; first_page jsonb; second_page jsonb; i integer;
begin
 update private.global_campfire_settings set enabled=true;
 for i in 1..10 loop
 owner:=gen_random_uuid();
 insert into auth.users(id,is_anonymous,email_confirmed_at) values(owner,false,now());
 insert into private.global_campfire_profiles(user_id,name,appearance) values(owner,'Fern','{"skinToneID":"warm","hairStyleID":"waves","shepherdOutfitID":"none","shepherdAccessoryID":"none"}') returning agreement_id into receipt;
 insert into private.global_campfire_sessions(user_id,source_id,agreement_id,kind,activity,started_at,expires_at,ended)
 values(owner,gen_random_uuid(),receipt,'phoneAway','studying',now(),now()+interval '30 minutes',false);
 end loop;
 first_page:=public.global_campfire_state(viewer,'studying');
 second_page:=public.global_campfire_state(viewer,'studying',(first_page->>'nextCursor')::uuid);
 if jsonb_array_length(first_page->'participants')<>8 or jsonb_array_length(second_page->'participants')<>2
 or second_page->>'nextCursor' is not null then raise exception 'paging bounds failed'; end if;
 if exists(select 1 from jsonb_array_elements(first_page->'participants') a,jsonb_array_elements(second_page->'participants') b where a->>'id'=b->>'id') then raise exception 'page duplicated a session'; end if;
 delete from auth.users where id=owner;
 if exists(select 1 from private.global_campfire_profiles where user_id=owner)
 or exists(select 1 from private.global_campfire_sessions where user_id=owner) then raise exception 'account deletion left public data'; end if;
 update private.global_campfire_sessions set started_at=now()-interval '9 days',expires_at=now()-interval '8 days';
 update private.global_campfire_commands set created_at=now()-interval '9 days';
 update private.global_campfire_reports set created_at=now()-interval '91 days';
 if jsonb_array_length(public.global_campfire_state(viewer)->'participants')<>0 then raise exception 'expired sessions visible'; end if;
 perform private.prune_global_campfire();
 if exists(select 1 from private.global_campfire_sessions) or exists(select 1 from private.global_campfire_commands)
 or exists(select 1 from private.global_campfire_reports) then raise exception 'physical retention failed'; end if;
 if not exists(select 1 from cron.job where jobname='global-campfire-retention') then raise exception 'retention not scheduled'; end if;
end $$;
rollback;
