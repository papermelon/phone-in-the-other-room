begin;
insert into auth.users(id,is_anonymous,email_confirmed_at) values
 ('be000000-0000-4000-8000-000000000001',false,now()),
 ('be000000-0000-4000-8000-000000000002',false,now());
insert into private.night_flock_v4_profiles(user_id,display_name,normalized_display_name,skin_tone_id,hair_style_id,shepherd_outfit_id,shepherd_accessory_id,ollie_ornament_id,featured_sheep_definition_id,pasture_theme_id)
values('be000000-0000-4000-8000-000000000001','Tommy','tommy','warm','waves','none','none','none','none','pasture_meadow');
do $$
declare a uuid:='be000000-0000-4000-8000-000000000001'; b uuid:='be000000-0000-4000-8000-000000000002';
 appearance jsonb:='{"skinToneID":"warm","hairStyleID":"waves","shepherdOutfitID":"none","shepherdAccessoryID":"none","headShapeID":"boxy"}';
 profile jsonb; agreement jsonb; receipt uuid; source uuid:=gen_random_uuid(); participant uuid; public_id uuid; result jsonb; publish jsonb;
 party uuid:=gen_random_uuid(); member uuid:=gen_random_uuid();
begin
 update private.global_campfire_settings set enabled=true;
 profile:=jsonb_build_object('session',jsonb_build_array('Wind Down · Active'),'tasks',jsonb_build_array('Read one chapter'),'routines',jsonb_build_array('Read at 22:30'),'intention','A quiet evening','history',jsonb_build_array('Wind Down · Completed'),'partyNames',jsonb_build_array('Family'),'inventory','[]'::jsonb,'sheep','[]'::jsonb,'appearance',appearance,'decorations','{}'::jsonb,'collectibles','{}'::jsonb,'ollieAccessory','none','barnCapacityLevel',0);
 if not private.valid_campfire_profile(profile) then raise exception 'valid profile rejected'; end if;
 if private.valid_campfire_profile(profile||'{"health":{}}') or private.valid_campfire_profile(profile||'{"tasks":[{}]}') then raise exception 'unlisted or malformed data accepted'; end if;
 agreement:=jsonb_build_object('id',gen_random_uuid(),'command','agreement','consentVersion',1,'expectedRevision',0,'enabled',true,'publicName','Fern','appearance',appearance-'headShapeID');
 perform public.global_campfire_command(a,agreement);
 select agreement_id into receipt from private.global_campfire_profiles where user_id=a;
 begin
 perform public.global_campfire_command(a,jsonb_build_object('id',gen_random_uuid(),'command','profile','agreementID',receipt,'sourceID',source,'capturedAt',now(),'profile',profile));
 raise exception 'legacy receipt exposed profile';
 exception when others then if sqlerrm='legacy receipt exposed profile' then raise; end if; end;
 agreement:=agreement||jsonb_build_object('id',gen_random_uuid(),'consentVersion',2,'expectedRevision',1,'publicName','Tommy','appearance',appearance);
 begin perform public.global_campfire_command(a,agreement||jsonb_build_object('publicName','Impersonated'));
 raise exception 'character name spoof accepted'; exception when others then if sqlerrm='character name spoof accepted' then raise; end if; end;
 result:=public.global_campfire_command(a,agreement);
 if result#>>'{agreement,version}' is distinct from '2' then raise exception 'profile receipt missing'; end if;
 receipt:=(result#>>'{agreement,id}')::uuid;
 perform public.global_campfire_command(a,jsonb_build_object('id',gen_random_uuid(),'command','profile','agreementID',receipt,'sourceID',source,'capturedAt',now(),'profile',profile));
 publish:=jsonb_build_object('id',gen_random_uuid(),'command','publish','agreementID',receipt,'sourceID',source,'kind','windDown','startedAt',now(),'expiresAt',now()+interval '8 hours','ended',false);
 perform public.global_campfire_command(a,publish);
 result:=public.global_campfire_state(b);
 participant:=(result#>>'{participants,0,id}')::uuid;
 public_id:=(result#>>'{participants,0,profileID}')::uuid;
 if result#>>'{participants,0,name}' is distinct from 'Tommy' or result#>>'{participants,0,thought}' is distinct from 'Read one chapter' or result#>>'{participants,0,startedAt}' is null then raise exception 'character or activity preview missing'; end if;
 if public.global_campfire_detail(b,participant,null)->'profile' is distinct from profile then raise exception 'global details missing'; end if;
 -- A profile for another source must never masquerade as the visible session's tasks.
 perform public.global_campfire_command(a,jsonb_build_object('id',gen_random_uuid(),'command','profile','agreementID',receipt,'sourceID',gen_random_uuid(),'capturedAt',now(),'profile',profile));
 if public.global_campfire_detail(b,participant,null)->>'profile' is not null then raise exception 'other source profile exposed'; end if;
 perform public.global_campfire_command(a,jsonb_build_object('id',gen_random_uuid(),'command','profile','agreementID',receipt,'sourceID',source,'capturedAt',now(),'profile',profile));

 insert into private.night_flock_v4_parties(id,host_user_id,name,normalized_name,time_zone_identifier) values(party,a,'Family','family','Asia/Singapore');
 insert into private.night_flock_v4_memberships(id,party_id,user_id,role) values(member,party,a,'host'),(gen_random_uuid(),party,b,'member');
 if public.global_campfire_detail(b,null,member)->'profile' is distinct from profile then raise exception 'party details missing'; end if;
 perform public.global_campfire_command(b,jsonb_build_object('id',gen_random_uuid(),'command','block','targetID',public_id));
 if public.global_campfire_detail(b,participant,null)->>'profile' is not null or public.global_campfire_detail(b,null,member)->>'profile' is not null then raise exception 'blocked details remain'; end if;
 delete from public.night_flock_blocks where blocker_user_id=b;
 perform public.global_campfire_command(a,publish||jsonb_build_object('id',gen_random_uuid(),'ended',true));
 if public.global_campfire_detail(b,participant,null)->>'profile' is not null then raise exception 'ended details remain'; end if;
 perform public.global_campfire_command(a,jsonb_build_object('id',gen_random_uuid(),'command','agreement','consentVersion',2,'expectedRevision',2,'enabled',false));
 if (select p.profile is not null from private.global_campfire_profiles p where user_id=a) then raise exception 'withdrawal retained profile'; end if;
 begin perform public.global_campfire_command(a,jsonb_build_object('id',gen_random_uuid(),'command','profile','agreementID',receipt,'sourceID',source,'capturedAt',now(),'profile',profile));
 raise exception 'withdrawal replay escaped'; exception when others then if sqlerrm='withdrawal replay escaped' then raise; end if; end;
 if has_function_privilege('authenticated','public.global_campfire_detail(uuid,uuid,uuid)','EXECUTE') then raise exception 'direct details access'; end if;
end $$;
rollback;
