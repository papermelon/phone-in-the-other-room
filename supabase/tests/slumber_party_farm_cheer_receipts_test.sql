begin;
-- Exercise the current provider-neutral account predicate: Apple recipient,
-- verified password sender, and an unverified account with misleading metadata.
insert into auth.users(id,is_anonymous,email_confirmed_at,raw_app_meta_data) values
 ('94000000-0000-4000-8000-000000000001',false,null,'{"provider":"apple"}'),
 ('94000000-0000-4000-8000-000000000002',false,now(),'{"provider":"email"}'),
 ('94000000-0000-4000-8000-000000000003',false,now(),'{"provider":"email"}'),
 ('94000000-0000-4000-8000-000000000004',false,null,'{"provider":"apple"}');
insert into auth.identities(id,user_id,provider_id,provider,identity_data)
values(gen_random_uuid(),'94000000-0000-4000-8000-000000000001','receipt-apple-test','apple','{"sub":"receipt-apple-test"}');
-- The additive social migration also supports installations before account sync.
-- Current installations keep the email sender above; legacy ones use their Apple contract.
do $$ begin
 if to_regprocedure('private.account_verified_farm_owner_v1(uuid)') is null then
   update auth.users set raw_app_meta_data='{"provider":"apple","providers":["apple"]}'
   where id in ('94000000-0000-4000-8000-000000000001','94000000-0000-4000-8000-000000000002','94000000-0000-4000-8000-000000000003');
 end if;
end $$;
do $$
#variable_conflict use_variable
declare
 host_id uuid:='94000000-0000-4000-8000-000000000001'; sender uuid:='94000000-0000-4000-8000-000000000002';
 stranger uuid:='94000000-0000-4000-8000-000000000003'; party_id uuid; member_id uuid; activity_id uuid; reaction_id uuid;
 snapshot jsonb; profile_command jsonb; rev int; first_received timestamptz;
begin
 if to_regprocedure('private.account_verified_farm_owner_v1(uuid)') is not null
    and private.is_apple_linked_night_flock_user('94000000-0000-4000-8000-000000000004') then
   raise exception 'unverified account admitted through provider metadata';
 end if;
 perform public.night_flock_v4_command(host_id,jsonb_build_object('command','createParty','name','Receipt Meadow','timeZoneIdentifier','UTC'));
 select m.party_id,m.id into party_id,member_id from private.night_flock_v4_memberships m where user_id=host_id;
 insert into private.night_flock_v4_memberships(party_id,user_id,role) values(party_id,sender,'member');
 perform public.night_flock_v4_command(host_id,jsonb_build_object('command','publishActivity','sharingScope','membership',
   'sourceEventID',gen_random_uuid(),'kind','windDown','outcome','completed','startedAt',now(),'endedAt',now()+interval '1 minute',
   'windDownMinutes',5,'phoneAwayMinutes',0,'statusRevision',1));
 select a.id into activity_id from private.night_flock_v4_membership_stream_activities a where a.party_id=party_id;
 for i in 1..3 loop
   perform public.night_flock_v4_command(sender,jsonb_build_object('command','react','sharingScope','membership','partyID',party_id,
     'activityID',activity_id,'cheer','warmWave'));
 end loop;
 snapshot:=public.night_flock_v4_state(host_id,'party',party_id,null);
 if jsonb_array_length(snapshot#>'{party,updateCheerReceipts}')<>1 then raise exception 'duplicate or missing named receipt'; end if;
 if snapshot#>>'{party,updateCheerReceipts,0,receivedByAppAt}' is not null then raise exception 'send inferred app receipt'; end if;
 reaction_id:=(snapshot#>>'{party,updateCheerReceipts,0,reactionID}')::uuid;
 if snapshot#>>'{party,updateCheerReceipts,0,activityID}'<>activity_id::text then raise exception 'wrong update'; end if;
 begin
   perform public.night_flock_v4_command(sender,jsonb_build_object('command','acknowledgeUpdateCheer','partyID',party_id,'reactionID',reaction_id));
   raise exception 'sender acknowledged recipient delivery';
 exception when others then if sqlerrm='sender acknowledged recipient delivery' then raise; end if; end;
 begin
   perform public.night_flock_v4_state(stranger,'party',party_id,null);
   raise exception 'unauthorized reader admitted';
 exception when others then if sqlerrm='unauthorized reader admitted' then raise; end if; end;
 perform public.night_flock_v4_command(host_id,jsonb_build_object('command','acknowledgeUpdateCheer','partyID',party_id,'reactionID',reaction_id));
 select a.received_at into first_received from private.night_flock_v4_cheer_app_receipts a where a.reaction_id=reaction_id;
 perform public.night_flock_v4_command(host_id,jsonb_build_object('command','acknowledgeUpdateCheer','partyID',party_id,'reactionID',reaction_id));
 if (select count(*) from private.night_flock_v4_cheer_app_receipts)<>1 then raise exception 'duplicate acknowledgement'; end if;
 snapshot:=public.night_flock_v4_state(sender,'party',party_id,null);
 if snapshot#>>'{party,updateCheerReceipts,0,receivedByAppAt}' is null then raise exception 'sender cannot recover durable app confirmation'; end if;
 -- A busy member cannot displace another member's latest/cheered update.
 insert into private.night_flock_v4_membership_stream_activities(party_id,member_id,member_epoch_id,source_event_id,
   kind,outcome,wind_down_minutes,phone_away_minutes,revision,occurred_at)
 select party_id,m.id,e.id,gen_random_uuid(),'phoneAway','completed',0,5,1,now()+interval '2 minutes'+i*interval '1 second'
 from private.night_flock_v4_memberships m join private.night_flock_v4_membership_epochs e on e.membership_id=m.id and e.ended_at is null
 cross join generate_series(1,101) i where m.user_id=sender;
 snapshot:=public.night_flock_v4_state(host_id,'party',party_id,null);
 if not exists(select 1 from jsonb_array_elements(snapshot#>'{party,memberUpdates}') x where x->>'activityID'=activity_id::text)
 then raise exception 'cheered update fell off the global feed'; end if;
 -- A third current member cannot inspect a pair's delivery metadata.
 insert into private.night_flock_v4_memberships(party_id,user_id,role) values(party_id,stranger,'member');
 snapshot:=public.night_flock_v4_state(stranger,'party',party_id,null);
 if jsonb_array_length(snapshot#>'{party,updateCheerReceipts}')<>0 then raise exception 'receipt leaked to third member'; end if;
 insert into public.night_flock_blocks(blocker_user_id,blocked_user_id) values(host_id,sender);
 snapshot:=public.night_flock_v4_state(host_id,'party',party_id,null);
 if jsonb_array_length(snapshot#>'{party,updateCheerReceipts}')<>0 then raise exception 'blocked pair retained receipt visibility'; end if;
 delete from public.night_flock_blocks where blocker_user_id=host_id and blocked_user_id=sender;
 -- Leave/rejoin creates a new epoch and cannot revive receipt or acknowledge it.
 perform public.night_flock_v4_command(sender,jsonb_build_object('command','leaveParty','partyID',party_id));
 update private.night_flock_v4_memberships set status='active',left_at=null,joined_at=now()+interval '2 minutes' where user_id=sender;
 snapshot:=public.night_flock_v4_state(host_id,'party',party_id,null);
 if jsonb_array_length(snapshot#>'{party,updateCheerReceipts}')<>0 then raise exception 'old epoch receipt resurrected'; end if;

 select revision into rev from private.night_flock_v4_profiles where user_id=host_id;
 profile_command:=jsonb_build_object('command','updatePublicProfile','expectedRevision',rev,'displayName','Clover','nameSelectionKind','initial',
 'skinToneID','warm','hairStyleID','long','shepherdOutfitID','shepherd_moon_coat','shepherdAccessoryID','none',
 'ollieOrnamentID','none','featuredSheepDefinitionID','none','pastureThemeID','pasture_meadow','headShapeID','round');
 perform public.night_flock_v4_command(host_id,profile_command);
 select revision into rev from private.night_flock_v4_profiles where user_id=host_id;
 perform public.night_flock_v4_command(host_id,jsonb_set(profile_command-'headShapeID','{expectedRevision}',to_jsonb(rev)));
 snapshot:=public.night_flock_v4_state(host_id,'list',null,null);
 if snapshot#>>'{profile,presentation,headShapeID}'<>'round' or snapshot->>'profileHeadShapeVersion'<>'1' then raise exception 'legacy profile write erased head or capability missing'; end if;
 begin
   perform public.night_flock_v4_command(host_id,jsonb_set(jsonb_set(profile_command,'{expectedRevision}',to_jsonb(rev)),'{headShapeID}','"private-farm-document"'));
   raise exception 'unsupported head accepted';
 exception when others then if sqlerrm='unsupported head accepted' then raise; end if; end;
 if has_function_privilege('authenticated','private.night_flock_v4_update_cheers(uuid,uuid)','execute')
   or has_function_privilege('service_role','private.night_flock_v4_apply_before_farm_cheers(uuid,jsonb)','execute')
   or has_table_privilege('authenticated','private.night_flock_v4_cheer_app_receipts','select') then raise exception 'helper privilege leak'; end if;
end $$;
set local role authenticated;
do $$ begin
 begin
   perform * from private.night_flock_v4_cheer_app_receipts;
   raise exception 'direct receipt table read admitted';
 exception when insufficient_privilege then null; end;
 begin
   perform public.night_flock_v4_state('94000000-0000-4000-8000-000000000001','list',null,null);
   raise exception 'direct impersonating state RPC admitted';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
rollback;
