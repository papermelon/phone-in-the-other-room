-- Rollback-only synthetic accounts. Channel allocation must count all occupants, including clock-skew reservations.
begin;
do $$
declare users uuid[]:='{}'; receipts uuid[]:='{}'; sources uuid[]:='{}'; u uuid; i integer; result jsonb; command jsonb; failed_move jsonb; public_id uuid;
 appearance jsonb:='{"skinToneID":"warm","hairStyleID":"waves","shepherdOutfitID":"none","shepherdAccessoryID":"none"}';
begin
 update private.global_campfire_settings set enabled=true;
 for i in 1..17 loop
 u:=gen_random_uuid(); users:=array_append(users,u); sources:=array_append(sources,gen_random_uuid());
 insert into auth.users(id,is_anonymous,email_confirmed_at) values(u,false,now());
 insert into private.night_flock_v4_profiles(user_id,display_name,normalized_display_name,skin_tone_id,hair_style_id,shepherd_outfit_id,shepherd_accessory_id,ollie_ornament_id,featured_sheep_definition_id,pasture_theme_id)
 values(u,'Camper '||i,'camper '||i,'warm','waves','none','none','none','none','pasture_meadow');
 result:=public.global_campfire_command(u,jsonb_build_object('id',gen_random_uuid(),'command','agreement','consentVersion',2,'expectedRevision',0,'enabled',true,'publicName','Camper '||i,'appearance',appearance));
 receipts:=array_append(receipts,(result#>>'{agreement,id}')::uuid);
 command:=jsonb_build_object('id',gen_random_uuid(),'command','publish','agreementID',receipts[i],'sourceID',sources[i],'kind','windDown','startedAt',now()+case when i>9 then interval '1 second' else interval '0 seconds' end,'expiresAt',now()+interval '8 hours','ended',false,'channelID',1);
 result:=public.global_campfire_command(u,command);
 if result->>'channelID' is distinct from (((i-1)/8)+1)::text then raise exception 'capacity overflow or missing automatic channel: %',result; end if;
 perform public.global_campfire_command(u,command);
 end loop;
 if exists(select 1 from private.global_campfire_channels() where count>8) then raise exception 'overfull channel'; end if;
 result:=public.global_campfire_state(users[9],'all',null,0);
 if result->>'channelID' is distinct from '2' or result->>'ownChannelID' is distinct from '2' then raise exception 'own channel missing'; end if;
 result:=public.global_campfire_state(users[9],'all',null,1);
 if jsonb_array_length(result->'participants')<>8 or result->>'nextCursor' is not null then raise exception 'channel read escaped capacity'; end if;
 -- Filtering and blocks never free a physical seat in the channel.
 select p.public_id into public_id from private.global_campfire_profiles p where p.user_id=users[1];
 perform public.global_campfire_command(users[9],jsonb_build_object('id',gen_random_uuid(),'command','block','targetID',public_id));
 result:=public.global_campfire_state(users[9],'all',null,1);
 if jsonb_array_length(result->'participants')<>7 or result#>>'{channels,0,count}' is distinct from '8' then raise exception 'block changed allocation'; end if;
 failed_move:=jsonb_build_object('id',gen_random_uuid(),'command','channel','agreementID',receipts[9],'sourceID',sources[9],'channelID',1);
 result:=public.global_campfire_command(users[9],failed_move);
 if result->>'channelFull' is distinct from 'true' or (select channel_id from private.global_campfire_sessions where user_id=users[9])<>2 then raise exception 'full move displaced occupant'; end if;
 -- End one session, then move atomically; replaying the failed request remains failed.
 command:=jsonb_build_object('id',gen_random_uuid(),'command','publish','agreementID',receipts[1],'sourceID',sources[1],'kind','windDown','startedAt',now(),'expiresAt',now()+interval '8 hours','ended',true);
 perform public.global_campfire_command(users[1],command);
 if public.global_campfire_command(users[9],failed_move)->>'channelFull' is distinct from 'true' then raise exception 'failed move replay changed'; end if;
 result:=public.global_campfire_command(users[9],failed_move||jsonb_build_object('id',gen_random_uuid()));
 if result->>'accepted' is distinct from 'true' or result->>'channelID' is distinct from '1' then raise exception 'available seat unavailable'; end if;
 result:=public.global_campfire_state(users[9],'reading',null,1);
 if jsonb_array_length(result->'participants')<>0 or result#>>'{channels,0,count}' is distinct from '8' then raise exception 'activity filter changed occupancy'; end if;
 -- A near-future replacement keeps the currently visible seat reserved until its start.
 perform public.global_campfire_command(users[9],jsonb_build_object('id',gen_random_uuid(),'command','publish','agreementID',receipts[9],'sourceID',gen_random_uuid(),'kind','windDown','startedAt',now()+interval '2 seconds','expiresAt',now()+interval '8 hours','ended',false,'channelID',2));
 if (select count from private.global_campfire_channels() where id=1)<>8 or (select count from private.global_campfire_channels() where id=2)<>8 then raise exception 'future replacement freed a visible seat early'; end if;
 -- A terminated session cannot change channels, even with a once-valid agreement/source.
 begin
 perform public.global_campfire_command(users[1],jsonb_build_object('id',gen_random_uuid(),'command','channel','agreementID',receipts[1],'sourceID',sources[1],'channelID',2));
 raise exception 'ended source moved';
 exception when others then if sqlerrm='ended source moved' then raise; end if; end;
 if has_function_privilege('authenticated','public.global_campfire_state(uuid,text,uuid,integer)','EXECUTE') then raise exception 'direct channel access'; end if;
end $$;
rollback;
