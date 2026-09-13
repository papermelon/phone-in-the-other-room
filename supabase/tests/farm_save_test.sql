begin;
insert into auth.users(id,is_anonymous) values
 ('51000000-0000-4000-8000-000000000001',false),
 ('51000000-0000-4000-8000-000000000002',false),
 ('51000000-0000-4000-8000-000000000003',true);
insert into auth.identities(id,user_id,provider_id,provider,identity_data)
select gen_random_uuid(),id,id::text,'apple',jsonb_build_object('sub',id::text)
from auth.users where id in ('51000000-0000-4000-8000-000000000001','51000000-0000-4000-8000-000000000002');
do $$
declare a uuid := '51000000-0000-4000-8000-000000000001';
 b uuid := '51000000-0000-4000-8000-000000000002';
 g uuid; g2 uuid; head uuid; branch uuid; c jsonb; saved jsonb; s jsonb; deletion jsonb;
 p jsonb := '{"schemaVersion":1,"economyVersion":1,"lineageID":"52000000-0000-4000-8000-000000000001",
 "farm":{"cumulativeCredit":{"migrationCompleted":true}},"search":{},"welcome":{},"socialRewards":{},
 "sunrise":{},"completedWindDownCount":0,"keepsakes":[],"deliveredWindDownRunIDs":[],"deliveredEffectIDs":[]}';
begin
 perform set_config('request.jwt.claim.sub','51000000-0000-4000-8000-000000000003',true);
 begin perform public.farm_save_v1('{"action":"lookup"}'); raise exception 'anonymous accepted';
 exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub',a::text,true);
 s:=public.farm_save_v1('{"action":"lookup"}'); g:=(s->>'generation')::uuid;
 if s->'head'<>'null' then raise exception 'new account has a head'; end if;
 c:=jsonb_build_object('action','put','generation',g,'operationID',gen_random_uuid(),'payload',p);
 saved:=public.farm_save_v1(c); head:=(saved#>>'{revision,id}')::uuid;
 if saved->>'status'<>'saved' or public.farm_save_v1(c)<>saved then raise exception 'retry changed receipt'; end if;
 begin perform public.farm_save_v1(c||jsonb_build_object('payload',p||'{"completedWindDownCount":1}')); raise exception 'operation reused';
 exception when raise_exception then if sqlerrm<>'farm_operation_reused' then raise; end if; end;
 s:=public.farm_save_v1(c||jsonb_build_object('operationID',gen_random_uuid()));
 branch:=(s#>>'{revision,id}')::uuid;
 if s->>'status'<>'conflict' then raise exception 'initial race lost'; end if;
 s:=public.farm_save_v1('{"action":"lookup"}');
 if (s#>>'{head,id}')::uuid<>head or jsonb_array_length(s->'revisions')<>2 then raise exception 'conflict lost a branch'; end if;
 s:=public.farm_save_revision_v1(jsonb_build_object('action','read','revisionID',branch));
 if (s#>>'{head,id}')::uuid<>branch or (s->>'currentRevisionID')::uuid<>head then raise exception 'read changed active head'; end if;
 perform set_config('request.jwt.claim.sub',b::text,true);
 s:=public.farm_save_v1('{"action":"lookup"}'); g2:=(s->>'generation')::uuid;
 if s->'head'<>'null' or s->'revisions'<>'[]'::jsonb then raise exception 'cross account lookup'; end if;
 begin perform public.farm_save_revision_v1(jsonb_build_object('action','read','revisionID',head)); raise exception 'cross account read';
 exception when raise_exception then if sqlerrm<>'farm_revision_unavailable' then raise; end if; end;
 begin perform public.farm_save_v1(jsonb_build_object('action','select','generation',g2,'operationID',gen_random_uuid(),'revisionID',head)); raise exception 'cross account select';
 exception when raise_exception then if sqlerrm<>'farm_revision_unavailable' then raise; end if; end;
 perform set_config('request.jwt.claim.sub',a::text,true);
 s:=public.farm_save_v1(jsonb_build_object('action','select','generation',g,'operationID',gen_random_uuid(),'baseRevision',head,'revisionID',branch));
 if (s#>>'{revision,id}')::uuid<>branch then raise exception 'selection failed'; end if;
 insert into private.farm_save_revisions(user_id,generation,lineage_id,payload,digest,created_at)
 select a,g,gen_random_uuid(),p,'retention-fixture',now()-interval '90 days'
 from generate_series(1,12);
 insert into private.farm_save_revisions(user_id,generation,lineage_id,payload,digest,created_at,conflict)
 values(a,g,gen_random_uuid(),p,'conflict-fixture',now()-interval '100 days',true);
 perform private.prune_farm_save_revisions();
 if (select count(*) from private.farm_save_revisions where user_id=a and not conflict)<>10
   or (select count(*) from private.farm_save_revisions where user_id=a and conflict)<>1
   or not exists(select 1 from private.farm_save_revisions where id=branch)
 then raise exception 'retention removed a protected copy'; end if;
 deletion:=jsonb_build_object('action','delete','generation',g,'operationID',gen_random_uuid(),'baseRevision',branch);
 s:=public.farm_save_v1(deletion);
 if public.farm_save_v1(deletion)<>s then raise exception 'delete not retryable'; end if;
 if exists(select 1 from private.farm_save_revisions where user_id=a) then raise exception 'delete retained payload'; end if;
 begin perform public.farm_save_v1(c); raise exception 'stale upload resurrected';
 exception when raise_exception then if sqlerrm<>'farm_generation_changed' then raise; end if; end;
 if has_table_privilege('authenticated','private.farm_save_revisions','select') then raise exception 'direct table read allowed'; end if;
 if has_function_privilege('anon','public.farm_save_v1(jsonb)','execute') then raise exception 'anon rpc allowed'; end if;
 delete from auth.users where id=a;
 if exists(select 1 from private.farm_save_heads where user_id=a) then raise exception 'account cascade failed'; end if;
 raise notice 'Farm save isolation, retries, conflicts, selection, deletion, stale generation and grants passed';
end $$;
rollback;
