-- Schema two adds the shared-goal lobby without changing the deployed schema-one
-- tables or the positive check-in contract used by older clients.
alter table public.night_flock_challenges
  add column if not exists goal_kind text,
  add column if not exists goal_target_minutes smallint,
  add column if not exists goal_app_display_name text,
  add column if not exists host_started_at timestamptz;

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'night_flock_challenges_goal_kind_check') then
    alter table public.night_flock_challenges add constraint night_flock_challenges_goal_kind_check
      check (goal_kind is null or goal_kind in ('phoneAway', 'quietMinutes', 'shieldInstagram'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'night_flock_challenges_goal_target_check') then
    alter table public.night_flock_challenges add constraint night_flock_challenges_goal_target_check
      check (goal_target_minutes is null or goal_target_minutes between 5 and 180);
  end if;
end $$;

alter table public.night_flock_members
  add column if not exists goal_accepted boolean not null default false,
  add column if not exists setup_ready boolean not null default false,
  add column if not exists share_routine_ideas boolean not null default false,
  add column if not exists shielding_evidence text not null default 'notRequested';

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'night_flock_members_shielding_evidence_check') then
    alter table public.night_flock_members add constraint night_flock_members_shielding_evidence_check
      check (shielding_evidence in ('notRequested', 'unavailable', 'partial', 'observed'));
  end if;
end $$;

alter table public.night_flock_invites
  add column if not exists redemption_count integer not null default 0,
  add column if not exists last_redeemed_at timestamptz;

create table if not exists public.night_flock_invite_redemptions (
  id uuid primary key default gen_random_uuid(),
  invite_id uuid not null references public.night_flock_invites(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  idempotency_key text not null unique check (idempotency_key ~ '^[0-9a-f]{64}$'),
  redeemed_at timestamptz not null default now(),
  unique (invite_id, user_id)
);

create table if not exists public.night_flock_goal_progress (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.night_flock_challenges(id) on delete cascade,
  member_id uuid not null references public.night_flock_members(id) on delete cascade,
  challenge_day smallint not null check (challenge_day between 1 and 7),
  status text not null check (status in (
    'goalAccepted', 'setupReady', 'phoneTuckedAway', 'partiallyCompleted',
    'sharedGoalCompleted', 'morningQuietCompleted', 'privateNoUpdate'
  )),
  shielding_evidence text not null default 'notRequested' check (
    shielding_evidence in ('notRequested', 'unavailable', 'partial', 'observed')
  ),
  updated_at timestamptz not null default now(),
  unique (challenge_id, member_id, challenge_day)
);

create table if not exists public.night_flock_routine_ideas (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.night_flock_challenges(id) on delete cascade,
  member_id uuid not null references public.night_flock_members(id) on delete cascade,
  guidance_id text not null check (guidance_id in (
    'phone-bed', 'quiet-hour', 'leave-room-after-heavy-meal',
    'personal-caffeine-cutoff', 'steady-wake', 'morning-light',
    'rest-not-performance', 'bed-as-cue', 'calm-room', 'daytime-shape'
  )),
  created_at timestamptz not null default now(),
  unique (challenge_id, member_id, guidance_id)
);

create index if not exists night_flock_goal_progress_projection_idx
  on public.night_flock_goal_progress (challenge_id, challenge_day, updated_at);
create index if not exists night_flock_routine_ideas_projection_idx
  on public.night_flock_routine_ideas (challenge_id, member_id);

alter table public.night_flock_invite_redemptions enable row level security;
alter table public.night_flock_goal_progress enable row level security;
alter table public.night_flock_routine_ideas enable row level security;
revoke all on table public.night_flock_invite_redemptions,
  public.night_flock_goal_progress, public.night_flock_routine_ideas
from public, anon, authenticated;
grant select, insert, update, delete on table public.night_flock_invite_redemptions,
  public.night_flock_goal_progress, public.night_flock_routine_ideas to service_role;

create or replace function private.night_flock_commitment_snapshot(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  membership public.night_flock_members%rowtype;
  flock public.night_flocks%rowtype;
  challenge public.night_flock_challenges%rowtype;
  member_rows jsonb;
  setup_rows jsonb;
  routine_rows jsonb;
  day_rows jsonb;
begin
  select * into membership from public.night_flock_members
  where user_id = p_user_id and status = 'active' limit 1;
  if membership.id is null then return null; end if;
  select * into flock from public.night_flocks where id = membership.flock_id and deleted_at is null;
  if flock.id is null then return null; end if;
  select * into challenge from public.night_flock_challenges
  where flock_id = flock.id and status in ('pending', 'active', 'completed')
  order by case status when 'active' then 0 when 'pending' then 1 else 2 end, created_at desc limit 1;
  if challenge.id is null then return null; end if;

  if challenge.status = 'active'
     and (now() at time zone challenge.time_zone_identifier)::date > challenge.ends_on then
    update public.night_flock_challenges set status = 'completed', completed_at = coalesce(completed_at, now())
    where id = challenge.id;
    challenge.status := 'completed';
    challenge.completed_at := coalesce(challenge.completed_at, now());
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', member.id, 'alias', member.alias, 'role', member.role
  ) order by member.joined_at), '[]'::jsonb)
  into member_rows
  from public.night_flock_members member
  where member.flock_id = flock.id and member.status = 'active'
    and not private.night_flock_users_blocked(p_user_id, member.user_id);

  select coalesce(jsonb_agg(jsonb_build_object(
    'memberID', member.id,
    'goalAccepted', member.goal_accepted,
    'setupReady', member.setup_ready,
    'sharingEnabled', member.sharing_enabled,
    'shareRoutineIdeas', member.share_routine_ideas,
    'shieldingEvidence', member.shielding_evidence
  ) order by member.joined_at), '[]'::jsonb)
  into setup_rows
  from public.night_flock_members member
  where member.flock_id = flock.id and member.status = 'active'
    and not private.night_flock_users_blocked(p_user_id, member.user_id);

  select coalesce(jsonb_agg(jsonb_build_object(
    'memberID', idea.member_id, 'guidanceID', idea.guidance_id
  ) order by idea.created_at), '[]'::jsonb)
  into routine_rows
  from public.night_flock_routine_ideas idea
  join public.night_flock_members member on member.id = idea.member_id
  where idea.challenge_id = challenge.id and member.status = 'active'
    and member.share_routine_ideas
    and not private.night_flock_users_blocked(p_user_id, member.user_id);

  select jsonb_agg(jsonb_build_object(
    'day', day_number,
    'phoneTuckedCount', (select count(*) from public.night_flock_goal_progress progress
      join public.night_flock_members member on member.id = progress.member_id
      where progress.challenge_id = challenge.id and progress.challenge_day = day_number
        and progress.status in ('phoneTuckedAway', 'partiallyCompleted', 'sharedGoalCompleted', 'morningQuietCompleted')
        and member.status = 'active' and not private.night_flock_users_blocked(p_user_id, member.user_id)),
    'morningQuietCompletedCount', (select count(*) from public.night_flock_goal_progress progress
      join public.night_flock_members member on member.id = progress.member_id
      where progress.challenge_id = challenge.id and progress.challenge_day = day_number
        and progress.status = 'morningQuietCompleted' and member.status = 'active'
        and not private.night_flock_users_blocked(p_user_id, member.user_id)),
    'pasture', coalesce((select jsonb_agg(jsonb_build_object(
      'id', checkin.id,
      'state', checkin.state,
      'reactions', coalesce((select jsonb_agg(jsonb_build_object(
        'id', reaction_group.reaction_id,
        'kind', reaction_group.kind,
        'count', reaction_group.reaction_count,
        'reactedByMe', reaction_group.reacted_by_me
      ) order by reaction_group.kind) from (
        select min(reaction.id::text)::uuid reaction_id, reaction.kind,
          count(*) reaction_count, bool_or(reactor.user_id = p_user_id) reacted_by_me
        from public.night_flock_reactions reaction
        join public.night_flock_members reactor on reactor.id = reaction.member_id
        where reaction.checkin_id = checkin.id and reactor.status = 'active'
          and not private.night_flock_users_blocked(p_user_id, reactor.user_id)
        group by reaction.kind
      ) reaction_group), '[]'::jsonb)
    ) order by checkin.id) from public.night_flock_checkins checkin
      join public.night_flock_members checked_member on checked_member.id = checkin.member_id
      where checkin.challenge_id = challenge.id and checkin.challenge_day = day_number
        and checked_member.status = 'active'
        and not private.night_flock_users_blocked(p_user_id, checked_member.user_id)), '[]'::jsonb),
    'memberProgress', coalesce((select jsonb_agg(jsonb_build_object(
      'memberID', progress.member_id, 'day', progress.challenge_day,
      'status', progress.status, 'shieldingEvidence', progress.shielding_evidence
    ) order by member.joined_at)
    from public.night_flock_goal_progress progress
    join public.night_flock_members member on member.id = progress.member_id
    where progress.challenge_id = challenge.id and progress.challenge_day = day_number
      and member.status = 'active' and not private.night_flock_users_blocked(p_user_id, member.user_id)), '[]'::jsonb)
  ) order by day_number)
  into day_rows
  from generate_series(1, 7) day_number;

  return jsonb_build_object(
    'profile', jsonb_build_object('alias', membership.alias),
    'flockID', flock.id, 'identity', flock.identity, 'myMemberID', membership.id,
    'members', member_rows,
    'challenge', jsonb_build_object(
      'id', challenge.id, 'timeZoneIdentifier', challenge.time_zone_identifier,
      'startsOn', jsonb_build_object('year', extract(year from challenge.starts_on)::integer,
        'month', extract(month from challenge.starts_on)::integer, 'day', extract(day from challenge.starts_on)::integer),
      'status', challenge.status, 'hostStartedAt', challenge.host_started_at,
      'sharedGoal', case when challenge.goal_kind is null then null else jsonb_build_object(
        'kind', challenge.goal_kind, 'targetMinutes', challenge.goal_target_minutes,
        'appDisplayName', challenge.goal_app_display_name) end
    ),
    'days', coalesce(day_rows, '[]'::jsonb),
    'sharingEnabled', membership.sharing_enabled,
    'memberSetups', setup_rows, 'sharedRoutineIdeas', routine_rows
  );
end;
$$;

create or replace function public.night_flock_commitment_state(p_user_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if p_user_id is null or not private.is_apple_linked_night_flock_user(p_user_id) then
    raise exception 'Apple-linked account required' using errcode = '28000';
  end if;
  return private.night_flock_commitment_snapshot(p_user_id);
end;
$$;

create or replace function public.night_flock_commitment_command(p_user_id uuid, p_command jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  command_name text := p_command ->> 'command';
  key_value text := p_command ->> 'idempotencyKey';
  membership public.night_flock_members%rowtype;
  target_challenge public.night_flock_challenges%rowtype;
  invite public.night_flock_invites%rowtype;
  flock public.night_flocks%rowtype;
  member_count integer;
  goal_label text;
  target_minutes integer;
  preview jsonb;
  invite_code text;
begin
  if p_user_id is null or not private.is_apple_linked_night_flock_user(p_user_id) then
    raise exception 'Apple-linked account required' using errcode = '28000';
  end if;
  if exists (select 1 from public.night_flock_moderation_actions where target_user_id = p_user_id
    and action in ('socialSuspension', 'accountSuspension', 'accountDeletion')
    and (expires_at is null or expires_at > now())) then
    raise exception 'Slumber Party unavailable for this account' using errcode = '42501';
  end if;
  select * into membership from public.night_flock_members where user_id = p_user_id and status = 'active' limit 1;

  if command_name = 'createParty' then
    if membership.id is not null then raise exception 'One active Slumber Party allowed'; end if;
    if p_command ->> 'goalKind' not in ('phoneAway', 'quietMinutes', 'shieldInstagram') then raise exception 'Invalid shared goal'; end if;
    if p_command ->> 'goalKind' = 'quietMinutes' and ((p_command ->> 'targetMinutes')::integer not between 5 and 180) then
      raise exception 'Invalid quiet-minute goal';
    end if;
    if not exists (select 1 from pg_timezone_names where name = p_command ->> 'timeZoneIdentifier') then
      raise exception 'Invalid challenge timezone';
    end if;
    if exists (select 1 from public.night_flocks where idempotency_key = key_value) then
      raise exception 'Party replay cannot reveal a new lobby';
    end if;
    insert into public.night_flocks (identity, created_by, idempotency_key)
      values (p_command ->> 'identity', p_user_id, key_value) returning * into flock;
    insert into public.night_flock_profiles (user_id, alias)
      values (p_user_id, private.generate_night_flock_alias(p_user_id, flock.id))
      on conflict (user_id) do update set updated_at = now();
    insert into public.night_flock_members (flock_id, user_id, alias, role, join_idempotency_key)
      select flock.id, p_user_id, alias, 'keeper', key_value from public.night_flock_profiles where user_id = p_user_id
      returning * into membership;
    insert into public.night_flock_challenges (flock_id, time_zone_identifier, starts_on, status,
      goal_kind, goal_target_minutes, goal_app_display_name)
      values (flock.id, p_command ->> 'timeZoneIdentifier',
        (now() at time zone (p_command ->> 'timeZoneIdentifier'))::date, 'pending',
        p_command ->> 'goalKind', nullif(p_command ->> 'targetMinutes', '')::smallint, nullif(p_command ->> 'appDisplayName', ''));

  elsif command_name = 'createInvite' then
    if membership.id is null or membership.role <> 'keeper' then raise exception 'Host permission required'; end if;
    if not exists (select 1 from public.night_flock_challenges where flock_id = membership.flock_id and status = 'pending') then
      raise exception 'Invitations close when the seven nights begin';
    end if;
    if exists (select 1 from public.night_flock_invites where flock_id = membership.flock_id and revoked_at is null and expires_at > now() and redeemed_at is null) then
      raise exception 'A reusable invitation already exists';
    end if;
    for attempt in 1..12 loop
      invite_code := '';
      for code_index in 0..11 loop
        invite_code := invite_code || substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789',
          1 + (get_byte(extensions.gen_random_bytes(1), 0) % 32), 1);
      end loop;
      begin
        insert into public.night_flock_invites (flock_id, created_by_member_id, token_hash, idempotency_key, expires_at)
          values (membership.flock_id, membership.id, extensions.digest(invite_code, 'sha256'), key_value, now() + interval '7 days')
          returning * into invite;
        exit;
      exception when unique_violation then
        if exists (select 1 from public.night_flock_invites where idempotency_key = key_value) then
          raise exception 'Invite replay cannot reveal the original code';
        end if;
      end;
    end loop;
    if invite_code is null or length(invite_code) <> 12 then raise exception 'Invite code unavailable'; end if;

  elsif command_name in ('previewInvite', 'redeemInvite') then
    select * into invite from public.night_flock_invites where token_hash = extensions.digest(upper(p_command ->> 'shortCode'), 'sha256') for update;
    if invite.id is null or invite.revoked_at is not null or invite.expires_at <= now() then raise exception 'Invite unavailable'; end if;
    select * into target_challenge from public.night_flock_challenges where flock_id = invite.flock_id and status = 'pending' limit 1;
    if target_challenge.id is null then raise exception 'This lobby has already started'; end if;
    select count(*) into member_count from public.night_flock_members where flock_id = invite.flock_id and status = 'active';
    if member_count >= 8 then raise exception 'Slumber Party is full'; end if;
    preview := jsonb_build_object('goal', jsonb_build_object('kind', target_challenge.goal_kind,
      'targetMinutes', target_challenge.goal_target_minutes, 'appDisplayName', target_challenge.goal_app_display_name),
      'memberCount', member_count, 'capacity', 8, 'isReusable', true);
    if command_name = 'previewInvite' then
      return jsonb_build_object('accepted', true, 'invitePreview', preview, 'snapshot', null);
    end if;
    if membership.id is not null then raise exception 'One active Slumber Party allowed'; end if;
    if exists (select 1 from public.night_flock_invite_redemptions where invite_id = invite.id and user_id = p_user_id) then
      raise exception 'This account already joined this lobby';
    end if;
    if exists (select 1 from public.night_flock_members peer where peer.flock_id = invite.flock_id and peer.status = 'active'
      and private.night_flock_users_blocked(p_user_id, peer.user_id)) then raise exception 'Blocked membership cannot be joined'; end if;
    insert into public.night_flock_profiles (user_id, alias)
      values (p_user_id, private.generate_night_flock_alias(p_user_id, invite.flock_id))
      on conflict (user_id) do update set updated_at = now();
    insert into public.night_flock_members (flock_id, user_id, alias, role, join_idempotency_key)
      select invite.flock_id, p_user_id, alias, 'member', key_value from public.night_flock_profiles where user_id = p_user_id
      returning * into membership;
    insert into public.night_flock_invite_redemptions (invite_id, user_id, idempotency_key)
      values (invite.id, p_user_id, key_value);
    update public.night_flock_invites set redemption_count = redemption_count + 1, last_redeemed_at = now() where id = invite.id;

  elsif command_name = 'acceptGoal' then
    update public.night_flock_members set goal_accepted = true
      where user_id = p_user_id and status = 'active' and id in (
        select member.id from public.night_flock_members member join public.night_flock_challenges challenge on challenge.flock_id = member.flock_id
        where challenge.id = (p_command ->> 'challengeID')::uuid);
    if not found then raise exception 'Challenge unavailable'; end if;
  elsif command_name = 'setLocalSetup' then
    update public.night_flock_members set setup_ready = (p_command ->> 'setupReady')::boolean,
      shielding_evidence = p_command ->> 'shieldingEvidence'
      where user_id = p_user_id and status = 'active';
    if not found then raise exception 'Current membership required'; end if;
  elsif command_name = 'setSharingPreferences' then
    update public.night_flock_members set sharing_enabled = (p_command ->> 'shareGoalProgress')::boolean,
      share_routine_ideas = (p_command ->> 'shareRoutineIdeas')::boolean where user_id = p_user_id and status = 'active';
    if not found then raise exception 'Current membership required'; end if;
  elsif command_name = 'setRoutineIdeas' then
    select * into target_challenge from public.night_flock_challenges where id = (p_command ->> 'challengeID')::uuid and status = 'pending';
    if target_challenge.id is null or not exists (select 1 from public.night_flock_members where id = membership.id and flock_id = target_challenge.flock_id) then raise exception 'Lobby unavailable'; end if;
    delete from public.night_flock_routine_ideas where challenge_id = target_challenge.id and member_id = membership.id;
    insert into public.night_flock_routine_ideas (challenge_id, member_id, guidance_id)
      select target_challenge.id, membership.id, value from jsonb_array_elements_text(p_command -> 'guidanceIDs') value;
  elsif command_name = 'startChallenge' then
    if membership.id is null or membership.role <> 'keeper' then raise exception 'Host permission required'; end if;
    select * into target_challenge from public.night_flock_challenges where id = (p_command ->> 'challengeID')::uuid and flock_id = membership.flock_id and status = 'pending' for update;
    if target_challenge.id is null then raise exception 'Lobby unavailable'; end if;
    select count(*) into member_count from public.night_flock_members where flock_id = membership.flock_id and status = 'active';
    if member_count < 2 then raise exception 'Two members are needed to start'; end if;
    if exists (select 1 from public.night_flock_members where flock_id = membership.flock_id and status = 'active' and (not goal_accepted or not setup_ready)) then
      raise exception 'Everyone needs to accept the goal and finish local setup';
    end if;
    update public.night_flock_challenges set status = 'active', starts_on = (now() at time zone time_zone_identifier)::date, host_started_at = now() where id = target_challenge.id;
  elsif command_name = 'publishProgress' then
    if membership.id is null or not membership.sharing_enabled then raise exception 'Sharing is unavailable'; end if;
    select * into target_challenge from public.night_flock_challenges where id = (p_command ->> 'challengeID')::uuid and flock_id = membership.flock_id and status in ('active', 'completed');
    if target_challenge.id is null then raise exception 'Challenge unavailable'; end if;
    insert into public.night_flock_goal_progress (challenge_id, member_id, challenge_day, status, shielding_evidence)
      values (target_challenge.id, membership.id, (p_command ->> 'day')::smallint, p_command ->> 'status', p_command ->> 'shieldingEvidence')
      on conflict (challenge_id, member_id, challenge_day) do update set
        status = excluded.status, shielding_evidence = excluded.shielding_evidence, updated_at = now();
    if p_command ->> 'status' = 'privateNoUpdate' then
      delete from public.night_flock_checkins
        where challenge_id = target_challenge.id and member_id = membership.id
          and challenge_day = (p_command ->> 'day')::smallint;
    else
      insert into public.night_flock_checkins (
        challenge_id, member_id, challenge_day, state, idempotency_key
      ) values (
        target_challenge.id, membership.id, (p_command ->> 'day')::smallint,
        case when p_command ->> 'status' = 'morningQuietCompleted'
          then 'morningQuietCompleted' else 'phoneTucked' end,
        key_value
      ) on conflict (challenge_id, member_id, challenge_day) do update set
        state = excluded.state, idempotency_key = excluded.idempotency_key, updated_at = now();
    end if;
  else
    raise exception 'Unsupported schema-two command';
  end if;
  return jsonb_build_object('accepted', true, 'inviteCode', invite_code, 'inviteID', invite.id,
    'snapshot', private.night_flock_commitment_snapshot(p_user_id));
end;
$$;

revoke all on function private.night_flock_commitment_snapshot(uuid) from public, anon, authenticated;
revoke all on function public.night_flock_commitment_state(uuid) from public, anon, authenticated;
revoke all on function public.night_flock_commitment_command(uuid, jsonb) from public, anon, authenticated;
grant execute on function public.night_flock_commitment_state(uuid) to service_role;
grant execute on function public.night_flock_commitment_command(uuid, jsonb) to service_role;
