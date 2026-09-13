begin;

insert into auth.users (
  id, instance_id, aud, role, is_anonymous, raw_app_meta_data, created_at, updated_at
)
values (
  '20000000-0000-4000-8000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', false,
  '{"provider":"apple","providers":["apple"]}', now(), now()
);

do $$
declare
  avatar_user_id uuid := '20000000-0000-4000-8000-000000000001';
  state jsonb;
  revision_before integer;
  revision_after integer;
begin
  perform public.night_flock_v4_command(
    avatar_user_id,
    jsonb_build_object(
      'command','updatePublicProfile',
      'expectedRevision',0,
      'displayName','Avatar Keeper',
      'nameSelectionKind','initial',
      'skinToneID','warm','hairStyleID','waves',
      'shepherdOutfitID','none','shepherdAccessoryID','none',
      'ollieOrnamentID','none','featuredSheepDefinitionID','none',
      'pastureThemeID','pasture_meadow'
    )
  );

  select revision into revision_before
  from private.night_flock_v4_profiles where user_id=avatar_user_id;

  perform public.night_flock_v4_command(
    avatar_user_id,
    jsonb_build_object(
      'command','updatePublicProfile',
      'expectedRevision',revision_before,
      'displayName','Avatar Keeper',
      'nameSelectionKind','migration',
      'skinToneID','warm','hairStyleID','waves',
      'shepherdOutfitID','none','shepherdAccessoryID','none',
      'ollieOrnamentID','none','featuredSheepDefinitionID','none',
      'pastureThemeID','pasture_meadow',
      'avatarID','sheep:juniper'
    )
  );

  select revision into revision_after
  from private.night_flock_v4_profiles where user_id=avatar_user_id;
  if revision_after <> revision_before + 1 then
    raise exception 'avatar-only update did not increment revision once';
  end if;
  if exists (
    select 1 from private.night_flock_v4_name_changes
    where user_id=avatar_user_id
  ) then
    raise exception 'avatar-only update spent a name-change allowance';
  end if;

  state := public.night_flock_v4_state(
    p_user_id => avatar_user_id,
    p_scope => 'list',
    p_party_id => null,
    p_cursor => null
  );
  if state->>'profileAvatarVersion' <> '1' then
    raise exception 'list state did not advertise profile avatar capability';
  end if;
  if state#>>'{profile,presentation,avatarID}' <> 'sheep:juniper' then
    raise exception 'profile state did not include selected avatar';
  end if;

  perform public.night_flock_v4_command(
    avatar_user_id,
    jsonb_build_object(
      'command','updatePublicProfile',
      'expectedRevision',revision_after,
      'displayName','Avatar Keeper',
      'nameSelectionKind','migration',
      'skinToneID','warm','hairStyleID','waves',
      'shepherdOutfitID','none','shepherdAccessoryID','none',
      'ollieOrnamentID','none','featuredSheepDefinitionID','none',
      'pastureThemeID','pasture_meadow'
    )
  );
  if (select avatar_id from private.night_flock_v4_profiles where user_id=avatar_user_id) <> 'sheep:juniper' then
    raise exception 'old command without avatar erased stored avatar';
  end if;

  if has_function_privilege('anon', 'public.night_flock_v4_state(uuid,text,uuid,text)', 'execute')
     or has_function_privilege('authenticated', 'public.night_flock_v4_state(uuid,text,uuid,text)', 'execute')
     or not has_function_privilege('service_role', 'public.night_flock_v4_state(uuid,text,uuid,text)', 'execute') then
    raise exception 'state RPC grants were not restricted to service_role';
  end if;
  if has_function_privilege('service_role', 'public.night_flock_v4_state_before_social_avatar(uuid,text,uuid,text)', 'execute')
     or has_function_privilege('anon', 'private.night_flock_v4_apply(uuid,jsonb)', 'execute') then
    raise exception 'internal avatar wrappers retained execute access';
  end if;

  begin
    perform public.night_flock_v4_command(
      avatar_user_id,
      jsonb_build_object(
        'command','updatePublicProfile',
        'expectedRevision',(select revision from private.night_flock_v4_profiles where user_id=avatar_user_id),
        'displayName','Avatar Keeper',
        'nameSelectionKind','migration',
        'skinToneID','warm','hairStyleID','waves',
        'shepherdOutfitID','none','shepherdAccessoryID','none',
        'ollieOrnamentID','none','featuredSheepDefinitionID','none',
        'pastureThemeID','pasture_meadow',
        'avatarID','sheep:not-a-catalogue-sheep'
      )
    );
    raise exception 'invalid avatar was accepted';
  exception when raise_exception then
    if sqlerrm <> 'Invalid avatarID' then raise; end if;
  end;

  begin
    perform public.night_flock_v4_command(
      avatar_user_id,
      jsonb_build_object(
        'command','updatePublicProfile',
        'expectedRevision',(select revision from private.night_flock_v4_profiles where user_id=avatar_user_id),
        'displayName','Avatar Keeper',
        'nameSelectionKind','migration',
        'skinToneID','warm','hairStyleID','waves',
        'shepherdOutfitID','none','shepherdAccessoryID','none',
        'ollieOrnamentID','none','featuredSheepDefinitionID','none',
        'pastureThemeID','pasture_meadow',
        'avatarID',null
      )
    );
    raise exception 'null avatar was accepted';
  exception when raise_exception then
    if sqlerrm <> 'Invalid avatarID' then raise; end if;
  end;
end
$$;

rollback;
