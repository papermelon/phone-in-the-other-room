-- A selected social character is a small curated profile field. It is not an
-- inventory assertion: a client may choose only a discovered sheep locally,
-- while the server validates the catalogue identifier it is asked to display.
alter table private.night_flock_v4_profiles
  add column avatar_id text not null default 'shepherd'
  check (avatar_id in (
    'shepherd', 'ollie',
    'sheep:mabel', 'sheep:pippin', 'sheep:bramble', 'sheep:clementine',
    'sheep:oat', 'sheep:midnight', 'sheep:juniper', 'sheep:hazel',
    'sheep:ramsey', 'sheep:luna', 'sheep:marigold', 'sheep:wisp'
  ));

create or replace function private.night_flock_v4_profile_json(
  pr private.night_flock_v4_profiles
)
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select jsonb_build_object(
    'displayName', pr.display_name,
    'revision', pr.revision,
    'hasEstablishedDisplayName', true,
    'presentation', jsonb_build_object(
      'skinToneID', pr.skin_tone_id,
      'hairStyleID', pr.hair_style_id,
      'shepherdOutfitID', pr.shepherd_outfit_id,
      'shepherdAccessoryID', pr.shepherd_accessory_id,
      'ollieOrnamentID', pr.ollie_ornament_id,
      'featuredSheepDefinitionID', pr.featured_sheep_definition_id,
      'pastureThemeID', pr.pasture_theme_id,
      'avatarID', pr.avatar_id
    )
  )
$$;

-- Preserve the established command implementation and its name-limit behavior.
-- The wrapper adds avatar-only conditional mutation after the legacy profile
-- write, increasing revision exactly once whether the request changes only an
-- avatar or combines it with another curated-profile field.
alter function private.night_flock_v4_apply(uuid, jsonb)
  rename to night_flock_v4_apply_before_social_avatar;

create function private.night_flock_v4_apply(u uuid, c jsonb)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  before_profile private.night_flock_v4_profiles%rowtype;
  current_profile private.night_flock_v4_profiles%rowtype;
  result jsonb;
  requested_avatar text;
begin
  if c->>'command' <> 'updatePublicProfile' or not (c ? 'avatarID') then
    return private.night_flock_v4_apply_before_social_avatar(u, c);
  end if;

  requested_avatar := c->>'avatarID';
  if requested_avatar is null or requested_avatar not in (
    'shepherd', 'ollie',
    'sheep:mabel', 'sheep:pippin', 'sheep:bramble', 'sheep:clementine',
    'sheep:oat', 'sheep:midnight', 'sheep:juniper', 'sheep:hazel',
    'sheep:ramsey', 'sheep:luna', 'sheep:marigold', 'sheep:wisp'
  ) then
    raise exception 'Invalid avatarID';
  end if;

  select * into before_profile
  from private.night_flock_v4_profiles
  where user_id=u;

  result := private.night_flock_v4_apply_before_social_avatar(u, c);

  select * into current_profile
  from private.night_flock_v4_profiles
  where user_id=u
  for update;

  if current_profile.avatar_id <> requested_avatar then
    update private.night_flock_v4_profiles
    set avatar_id=requested_avatar,
        revision=revision + case
          when current_profile.revision = coalesce(before_profile.revision, 0)
          then 1
          else 0
        end,
        updated_at=now()
    where user_id=u
    returning * into current_profile;
  end if;

  return (result - 'profile')
    || jsonb_build_object('profile', private.night_flock_v4_profile_json(current_profile));
end
$$;

-- A list response advertises this additive wire field independently of party
-- count. Old server snapshots omit it, so older clients remain compatible.
alter function public.night_flock_v4_state(uuid, text, uuid, text)
  rename to night_flock_v4_state_before_social_avatar;

create function public.night_flock_v4_state(
  p_user_id uuid,
  p_scope text default 'list',
  p_party_id uuid default null,
  p_cursor text default null
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  snapshot jsonb;
begin
  snapshot := public.night_flock_v4_state_before_social_avatar(
    p_user_id, p_scope, p_party_id, p_cursor
  );
  if p_scope='list' then
    return snapshot || jsonb_build_object('profileAvatarVersion', 1);
  end if;
  return snapshot;
end
$$;

-- These helper functions are invoked only through the established command and
-- state wrappers. New SECURITY DEFINER functions must not inherit PUBLIC
-- execution merely because they are newly created in this migration.
revoke all on function private.night_flock_v4_apply(uuid, jsonb)
  from public, anon, authenticated, service_role;
revoke all on function private.night_flock_v4_apply_before_social_avatar(uuid, jsonb)
  from public, anon, authenticated, service_role;
revoke all on function private.night_flock_v4_profile_json(private.night_flock_v4_profiles)
  from public, anon, authenticated, service_role;
revoke all on function public.night_flock_v4_state_before_social_avatar(uuid, text, uuid, text)
  from public, anon, authenticated, service_role;
revoke all on function public.night_flock_v4_state(uuid, text, uuid, text)
  from public, anon, authenticated;
grant execute on function public.night_flock_v4_state(uuid, text, uuid, text)
  to service_role;
