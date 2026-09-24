-- Run after 20260923120000_campfire_wardrobe.sql against an isolated test DB.
begin;
insert into auth.users(id,is_anonymous,email_confirmed_at) values
 ('9b000000-0000-4000-8000-000000000001',false,now());
insert into private.night_flock_v4_profiles(user_id,display_name,normalized_display_name,
 skin_tone_id,hair_style_id,shepherd_outfit_id,shepherd_accessory_id,
 ollie_ornament_id,featured_sheep_definition_id,pasture_theme_id)
values('9b000000-0000-4000-8000-000000000001','Clover','clover',
 'warm','waves','shepherd_moss_coat','none','none','none','pasture_meadow');
do $$
declare u uuid:='9b000000-0000-4000-8000-000000000001';
  v4 jsonb; agreement jsonb; profile jsonb; result jsonb; receipt uuid;
begin
  v4:=jsonb_build_object('command','updatePublicProfile','idempotencyKey',repeat('a',64),
    'expectedRevision',0,'nameSelectionKind','migration','displayName','Clover',
    'skinToneID','warm','hairStyleID','waves','shepherdOutfitID','shepherd_moss_coat',
    'shepherdAccessoryID','none','ollieOrnamentID','none',
    'featuredSheepDefinitionID','none','pastureThemeID','pasture_meadow',
    'shepherdShirtID','shepherd_dusk_shirt',
    'shepherdOuterwearID','shepherd_open_moss_coat','ollieCoatID','fuller');
  result:=public.night_flock_v4_command(u,v4);
  if result#>>'{profile,presentation,shepherdShirtID}'<>'shepherd_dusk_shirt'
    or result#>>'{profile,presentation,ollieCoatID}'<>'fuller'
    or public.night_flock_v4_state(u,'list',null,null)->>'profileWardrobeVersion'<>'1'
    then raise exception 'V4 wardrobe projection missing'; end if;
  if public.night_flock_v4_command(u,v4) is distinct from result then
    raise exception 'V4 same-payload replay changed result'; end if;
  begin
    perform public.night_flock_v4_command(u,jsonb_set(v4,'{ollieCoatID}','"classic"'::jsonb));
    raise exception 'V4 changed-payload replay accepted';
  exception when others then
    if sqlerrm='V4 changed-payload replay accepted' then raise; end if;
  end;

  agreement:=jsonb_build_object('id',gen_random_uuid(),'command','agreement',
    'consentVersion',2,'expectedRevision',0,'enabled',true,'publicName','Clover',
    'appearance',jsonb_build_object('skinToneID','warm','hairStyleID','waves',
    'shepherdOutfitID','shepherd_moss_coat','shepherdAccessoryID','none',
    'shepherdShirtID','shepherd_dusk_shirt','shepherdOuterwearID',
    'shepherd_open_moss_coat','ollieCoatID','fuller'));
  update private.global_campfire_settings set enabled=true;
  result:=public.global_campfire_command(u,agreement);
  receipt:=(result#>>'{agreement,id}')::uuid;
  if (select appearance->>'ollieCoatID' from private.global_campfire_profiles where user_id=u)<>'fuller'
    or public.global_campfire_state(u)->>'appearanceVersion'<>'1'
    then raise exception 'Global wardrobe projection missing'; end if;
  begin
    perform public.global_campfire_command(u,jsonb_set(agreement,
      '{appearance,ollieCoatID}','"classic"'::jsonb));
    raise exception 'Global changed-payload replay accepted';
  exception when others then
    if sqlerrm<>'idempotency_conflict' then raise; end if;
  end;
  profile:=jsonb_build_object('session','[]'::jsonb,'tasks','[]'::jsonb,
    'routines','[]'::jsonb,'intention','','history','[]'::jsonb,
    'partyNames','[]'::jsonb,'inventory','[]'::jsonb,'sheep','[]'::jsonb,
    'appearance',jsonb_set(agreement->'appearance','{shepherdShirtID}',
      '"shepherd_amber_shirt"'::jsonb),
    'decorations','{}'::jsonb,'collectibles','{}'::jsonb,
    'ollieAccessory','none','barnCapacityLevel',0);
  perform public.global_campfire_command(u,jsonb_build_object('id',gen_random_uuid(),
    'command','profile','agreementID',receipt,'sourceID',gen_random_uuid(),
    'capturedAt',now(),'profile',profile));
  if (select p.profile#>>'{appearance,shepherdShirtID}'
      from private.global_campfire_profiles p where p.user_id=u)<>'shepherd_amber_shirt'
    then raise exception 'Global profile wardrobe refresh missing'; end if;
  if has_function_privilege('authenticated',
    'private.night_flock_v4_apply_before_wardrobe(uuid,jsonb)','EXECUTE')
    then raise exception 'legacy V4 wrapper exposed'; end if;
end $$;
rollback;
