begin;
insert into auth.users(id,is_anonymous,email_confirmed_at,raw_app_meta_data) values
 ('97000000-0000-4000-8000-000000000001',false,now(),'{"provider":"email"}'),
 ('97000000-0000-4000-8000-000000000002',false,now(),'{"provider":"email"}');
do $$
declare a uuid:='97000000-0000-4000-8000-000000000001'; b uuid:='97000000-0000-4000-8000-000000000002';
  party uuid; epoch uuid; sheep uuid:=gen_random_uuid(); gen uuid; rev uuid:=gen_random_uuid(); cmd jsonb; i int;
begin
  if has_function_privilege('authenticated','public.shared_text_sheep_name(uuid,jsonb)','execute')
    or has_function_privilege('anon','public.shared_text_moderation_admission(uuid)','execute')
    or has_function_privilege('authenticated','public.night_flock_v4_command(uuid,jsonb)','execute') then
    raise exception 'client can bypass Edge moderation';
  end if;
  if not has_function_privilege('service_role','public.shared_text_sheep_name(uuid,jsonb)','execute') then raise exception 'service cannot preflight'; end if;
  perform public.night_flock_v4_command(a,jsonb_build_object('command','createParty','name','Safety fixture','timeZoneIdentifier','UTC'));
  select m.party_id,e.id into party,epoch from private.night_flock_v4_memberships m
    join private.night_flock_v4_membership_epochs e on e.membership_id=m.id and e.ended_at is null where m.user_id=a;
  insert into private.farm_save_heads(user_id) values(a) returning generation into gen;
  insert into private.farm_save_revisions(id,user_id,generation,lineage_id,payload,digest)
    values(rev,a,gen,gen_random_uuid(),jsonb_build_object('farm',jsonb_build_object('sheep',jsonb_build_array(
      jsonb_build_object('id',sheep,'definitionID','bramble','displayName','Bramble','status','active'))),'privateNote','never exported'),'fixture');
  update private.farm_save_heads set revision=rev where user_id=a;
  cmd:=jsonb_build_object('command','contributePastureSheep','partyID',party,'memberEpochID',epoch,'sceneRevision',1,
    'sheepID',sheep,'consentVersion',1,'idempotencyKey',repeat('a',64));
  if public.shared_text_sheep_name(a,cmd)<>'Bramble' then raise exception 'name preflight wrong'; end if;
  begin
    perform public.shared_text_sheep_name(b,cmd); raise exception 'other account read private name';
  exception when others then if sqlerrm<>'current_membership_required' then raise; end if; end;
  begin
    perform public.night_flock_v4_command(a,cmd||'{"moderatedSheepName":"Different"}'); raise exception 'unchecked rename published';
  exception when others then if sqlerrm<>'shared_text_unavailable' then raise; end if; end;
  if exists(select 1 from private.shared_pasture_visits where owner_id=a) then raise exception 'failed check created a visit'; end if;
  perform public.night_flock_v4_command(a,cmd||'{"moderatedSheepName":"Bramble"}');
  -- Older receipts/SQL callers and a new Edge binding share the same hash.
  perform public.night_flock_v4_command(a,cmd);
  if (select count(*) from private.shared_pasture_visits where owner_id=a)<>1 then raise exception 'replay duplicated visit'; end if;
  update private.farm_save_revisions set payload=jsonb_set(payload,'{farm,sheep,0,displayName}','"Renamed"') where id=rev;
  begin
    perform public.night_flock_v4_command(a,cmd||jsonb_build_object('idempotencyKey',repeat('b',64),'moderatedSheepName','Bramble'));
    raise exception 'rename race bypassed moderation';
  exception when others then if sqlerrm<>'shared_text_unavailable' then raise; end if; end;
  if public.shared_text_sheep_name(a,cmd)<>'Renamed' then raise exception 'current name not loaded'; end if;
  for i in 1..30 loop perform public.shared_text_moderation_admission(a); end loop;
  begin perform public.shared_text_moderation_admission(a); raise exception 'unbounded provider work';
  exception when others then if sqlerrm<>'rate_limited' then raise; end if; end;
end $$;
rollback;
