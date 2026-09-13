begin;
insert into auth.users(id,is_anonymous,email_confirmed_at,raw_app_meta_data) values
 ('96000000-0000-4000-8000-000000000001',false,now(),'{"provider":"email"}'),
 ('96000000-0000-4000-8000-000000000002',false,now(),'{"provider":"email"}'),
 ('96000000-0000-4000-8000-000000000003',false,now(),'{"provider":"email"}');
do $$
#variable_conflict use_variable
declare a uuid:='96000000-0000-4000-8000-000000000001'; b uuid:='96000000-0000-4000-8000-000000000002';
 outsider uuid:='96000000-0000-4000-8000-000000000003'; p uuid; other_party uuid; am uuid; bm uuid; ae uuid; be uuid;
 sheep uuid:=gen_random_uuid(); gen uuid; rev uuid:=gen_random_uuid(); visit uuid; entity text; response jsonb; snapshot jsonb; cmd jsonb; ledger uuid; i int;
begin
 perform public.night_flock_v4_command(a,jsonb_build_object('command','createParty','name','Test Pasture','timeZoneIdentifier','UTC'));
 select party_id,id into p,am from private.night_flock_v4_memberships where user_id=a;
 insert into private.night_flock_v4_memberships(party_id,user_id,role) values(p,b,'member') returning id into bm;
 select id into ae from private.night_flock_v4_membership_epochs where membership_id=am and ended_at is null;
 select id into be from private.night_flock_v4_membership_epochs where membership_id=bm and ended_at is null;
 snapshot:=public.night_flock_v4_state(a,'party',p,null);
 if jsonb_array_length(snapshot#>'{party,pasture,entities}')<>2 then raise exception 'missing Shepherds'; end if;
 if snapshot#>>'{party,pasture,version}'<>'1' then raise exception 'capability missing'; end if;
 entity:='member-'||be::text;
 cmd:=jsonb_build_object('command','movePastureEntity','partyID',p,'memberEpochID',ae,'sceneRevision',1,'entityID',entity,'expectedRevision',0,'x',0.52,'y',0.71,'idempotencyKey',repeat('a',64));
 response:=public.night_flock_v4_command(a,cmd);
 if response->>'conflict'<>'false' then raise exception 'member cannot move peer'; end if;
 perform public.night_flock_v4_command(a,cmd);
 if (select revision from private.shared_pasture_layout where party_id=p and entity_id=entity)<>1 then raise exception 'retry moved twice'; end if;
 response:=public.night_flock_v4_command(b,(cmd-'idempotencyKey')||jsonb_build_object('memberEpochID',be,'x',0.70));
 if response->>'conflict'<>'true' then raise exception 'stale move overwrote'; end if;
 if (select x from private.shared_pasture_layout where party_id=p and entity_id=entity)<>0.52 then raise exception 'canonical arrangement lost'; end if;
 begin perform public.night_flock_v4_command(outsider,cmd-'idempotencyKey'); raise exception 'outsider moved'; exception when others then if sqlerrm='outsider moved' then raise; end if; end;
 begin perform public.night_flock_v4_command(a,(cmd-'idempotencyKey')||'{"x":0.1,"y":0.88}'); raise exception 'blocked ground accepted'; exception when others then if sqlerrm='blocked ground accepted' then raise; end if; end;
 begin perform public.night_flock_v4_command(a,jsonb_build_object('command','contributePastureSheep','partyID',p,'memberEpochID',ae,'sceneRevision',1,'sheepID',sheep,'consentVersion',1)); raise exception 'unowned sheep admitted'; exception when others then if sqlerrm='unowned sheep admitted' then raise; end if; end;
 insert into private.farm_save_heads(user_id) values(a) returning generation into gen;
 insert into private.farm_save_revisions(id,user_id,generation,lineage_id,payload,digest)
 values(rev,a,gen,gen_random_uuid(),jsonb_build_object('farm',jsonb_build_object('sheep',jsonb_build_array(jsonb_build_object('id',sheep,'definitionID','bramble','displayName','Bramble','status','active')))),'fixture');
 update private.farm_save_heads set revision=rev where user_id=a;
 cmd:=jsonb_build_object('command','contributePastureSheep','partyID',p,'memberEpochID',ae,'sceneRevision',1,'sheepID',sheep,'consentVersion',1,'idempotencyKey',repeat('b',64));
 perform public.night_flock_v4_command(a,cmd); perform public.night_flock_v4_command(a,cmd);
 select id into visit from private.shared_pasture_visits where party_id=p and recalled_at is null;
 if (select count(*) from private.shared_pasture_visits where party_id=p and recalled_at is null)<>1 then raise exception 'duplicate visit'; end if;
 snapshot:=public.night_flock_v4_state(b,'party',p,null);
 if snapshot#>>'{party,pasture,visits,0,ownedSheepID}' is not null then raise exception 'private sheep ID leaked'; end if;
 if snapshot#>>'{party,pasture,visits,0,sheepDefinitionID}'<>'bramble' then raise exception 'appearance lost'; end if;
 if snapshot#>'{party,pasture,visits,0}' ? 'expiresAt' then raise exception 'visit expires'; end if;
 begin perform public.night_flock_v4_command(b,jsonb_build_object('command','recallPastureSheep','partyID',p,'memberEpochID',be,'sceneRevision',1,'visitID',visit)); raise exception 'peer recalled owned sheep'; exception when others then if sqlerrm='peer recalled owned sheep' then raise; end if; end;
 perform public.night_flock_v4_command(a,jsonb_build_object('command','createParty','name','Other Pasture','timeZoneIdentifier','UTC'));
 select party_id into other_party from private.night_flock_v4_memberships where user_id=a and party_id<>p;
 begin
 perform public.night_flock_v4_command(a,(cmd-'idempotencyKey')||jsonb_build_object('partyID',other_party,'memberEpochID',(select id from private.night_flock_v4_membership_epochs where user_id=a and party_id=other_party and ended_at is null)));
 raise exception 'same sheep in two parties'; exception when others then if sqlerrm='same sheep in two parties' then raise; end if; end;
 -- Owner recall is idempotent, and a fresh explicit visit can follow it.
 response:=public.night_flock_v4_command(a,jsonb_build_object('command','recallPastureSheep','partyID',p,'memberEpochID',ae,'sceneRevision',1,'visitID',visit,'idempotencyKey',repeat('d',64)));
 perform public.night_flock_v4_command(a,jsonb_build_object('command','recallPastureSheep','partyID',p,'memberEpochID',ae,'sceneRevision',1,'visitID',visit,'idempotencyKey',repeat('d',64)));
 if exists(select 1 from private.shared_pasture_visible_visits(b,p)) then raise exception 'recall did not hide visit'; end if;
 delete from private.night_flock_v4_idempotency where user_id=a and idempotency_key=repeat('b',64);
 perform public.night_flock_v4_command(a,cmd);
 if exists(select 1 from private.shared_pasture_visible_visits(b,p)) then raise exception 'expired retry ledger resurrected recalled sheep'; end if;
 perform public.night_flock_v4_command(a,cmd-'idempotencyKey');
 select id into visit from private.shared_pasture_visits where party_id=p and recalled_at is null;
 insert into public.night_flock_blocks(blocker_user_id,blocked_user_id) values(a,b);
 if jsonb_array_length(private.shared_pasture_entities(a,p))<>2 then raise exception 'blocked peer remains in scene'; end if;
 begin
 perform public.night_flock_v4_command(a,jsonb_build_object('command','movePastureEntity','partyID',p,'memberEpochID',ae,'sceneRevision',1,'entityID',entity,'expectedRevision',1,'x',0.6,'y',0.7));
 raise exception 'blocked party movement admitted';
 exception when others then if sqlerrm<>'invite_unavailable' then raise; end if; end;
 delete from public.night_flock_blocks where blocker_user_id=a and blocked_user_id=b;
 -- Save removal invalidates public presence, but does not mutate the private Farm.
 update private.farm_save_heads set revision=null where user_id=a;
 if exists(select 1 from private.shared_pasture_visits where id=visit and recalled_at is null) then raise exception 'sold sheep still visiting'; end if;
 if (select count(*) from private.farm_save_revisions where id=rev)<>1 then raise exception 'visit changed private save'; end if;
 -- A new membership epoch changes the entity identity and rejects delayed moves.
 perform public.night_flock_v4_command(b,jsonb_build_object('command','leaveParty','partyID',p));
 update private.night_flock_v4_memberships set status='active',left_at=null,joined_at=now() where id=bm;
 begin perform public.night_flock_v4_command(b,jsonb_build_object('command','movePastureEntity','partyID',p,'memberEpochID',be,'sceneRevision',1,'entityID',entity,'expectedRevision',1,'x',0.6,'y',0.7)); raise exception 'old epoch replayed'; exception when others then if sqlerrm='old epoch replayed' then raise; end if; end;
 -- Project fixture: 12 existing eligible grants spread over party days. The
 -- first grant/day counts; another mode/session that day keeps its own wool.
 update private.shared_pasture_policy set starts_at=now()-interval '30 days';
 update private.night_flock_v4_membership_epochs set joined_at=now()-interval '30 days' where user_id=a and party_id=p;
 for i in 1..12 loop
 insert into private.night_flock_v4_activity_ledger(user_id,source_event_id,kind,outcome,started_at,ended_at,wind_down_minutes,phone_away_minutes,status_revision)
 values(a,gen_random_uuid(),'windDown','completed',now()-i*interval '1 day'-interval '30 minutes',now()-i*interval '1 day',30,0,1) returning id into ledger;
 insert into private.night_flock_v4_grants(user_id,party_id,ledger_id) values(a,p,ledger);
 end loop;
 if (select contributions from private.shared_pasture_projects where party_id=p)<>12 then raise exception 'project threshold wrong'; end if;
 if (select completed_at from private.shared_pasture_projects where party_id=p) is null then raise exception 'lantern did not unlock'; end if;
 insert into private.night_flock_v4_activity_ledger(user_id,source_event_id,kind,outcome,started_at,ended_at,wind_down_minutes,phone_away_minutes,status_revision)
 values(a,gen_random_uuid(),'phoneAway','completed',now()-interval '1 day 20 minutes',now()-interval '1 day',0,20,1) returning id into ledger;
 insert into private.night_flock_v4_grants(user_id,party_id,ledger_id) values(a,p,ledger);
 if (select contributions from private.shared_pasture_projects where party_id=p)<>12 then raise exception 'daily cap failed'; end if;
 if (select count(*) from private.night_flock_v4_grants where party_id=p)<>13 then raise exception 'personal wool changed'; end if;
 if not exists(select 1 from jsonb_array_elements(private.shared_pasture_entities(a,p)) e where e->>'kind'='lantern') then raise exception 'earned lantern invisible'; end if;
 -- Early endings still have their personal grant but never add project credit.
 insert into private.night_flock_v4_activity_ledger(user_id,source_event_id,kind,outcome,started_at,ended_at,wind_down_minutes,phone_away_minutes,status_revision)
 values(a,gen_random_uuid(),'windDown','partlyCompleted',now()-interval '20 minutes',now(),20,0,1) returning id into ledger;
 insert into private.night_flock_v4_grants(user_id,party_id,ledger_id) values(a,p,ledger);
 if (select contributions from private.shared_pasture_projects where party_id=p)<>12 then raise exception 'early ending counted'; end if;
 -- Earned structure movement uses the same optimistic concurrency boundary.
 perform public.night_flock_v4_command(a,jsonb_build_object('command','movePastureEntity','partyID',p,'memberEpochID',ae,'sceneRevision',1,'entityID','lantern-'||p::text,'expectedRevision',0,'x',0.7,'y',0.6));
 if not exists(select 1 from private.shared_pasture_layout where party_id=p and entity_id='lantern-'||p::text and revision=1) then raise exception 'lantern could not move'; end if;
 perform public.night_flock_v4_command(a,jsonb_build_object('command','deleteParty','partyID',p));
 if exists(select 1 from private.shared_pasture_projects where party_id=p) and exists(select 1 from private.night_flock_v4_parties where id=p and deleted_at is null) then raise exception 'deleted party remains active'; end if;
end $$;
-- Default positions must satisfy the same ground bounds as deliberate moves,
-- including the four-person foreground corner.
do $$ declare host_id uuid:=gen_random_uuid(); peer_id uuid; party_id uuid; i int; begin
 insert into auth.users(id,is_anonymous,email_confirmed_at) values(host_id,false,now());
 perform public.night_flock_v4_command(host_id,jsonb_build_object('command','createParty','name','Ground bounds','timeZoneIdentifier','UTC'));
 select m.party_id into party_id from private.night_flock_v4_memberships m where m.user_id=host_id;
 for i in 2..8 loop
 peer_id:=gen_random_uuid();
 insert into auth.users(id,is_anonymous,email_confirmed_at) values(peer_id,false,now());
 insert into private.night_flock_v4_memberships(party_id,user_id,role) values(party_id,peer_id,'member');
 if exists(select 1 from jsonb_array_elements(private.shared_pasture_entities(host_id,party_id)) e
 where not((e->>'x')::float8 between 0.08 and 0.92 and (e->>'y')::float8 between 0.43 and 0.89)
 or ((e->>'x')::float8<0.28 and (e->>'y')::float8>0.80)) then raise exception 'seeded layout outside walkable ground'; end if;
 end loop;
end $$;
set local role authenticated;
do $$ begin
 begin perform * from private.shared_pasture_visits; raise exception 'direct table exposed'; exception when insufficient_privilege then null; end;
 begin perform public.night_flock_v4_state('96000000-0000-4000-8000-000000000001'); raise exception 'RPC exposed'; exception when insufficient_privilege then null; end;
end $$;
reset role;
rollback;
