-- Schema three adds independently controlled sharing, nightly shared metrics,
-- and server-authoritative Farm grants. Schema-one and schema-two RPCs stay
-- untouched so older clients keep decoding and queued outbox records still route.

alter table public.night_flock_members
  add column if not exists share_wind_down_completion boolean not null default true,
  add column if not exists share_wind_down_minutes boolean not null default true,
  add column if not exists share_phone_away_minutes boolean not null default true,
  add column if not exists share_phone_tucked_away boolean not null default true,
  add column if not exists share_shielding_status boolean not null default true,
  add column if not exists share_sleep_duration boolean not null default false,
  add column if not exists share_restfulness boolean not null default false;

update public.night_flock_members
set
  share_wind_down_completion = sharing_enabled,
  share_wind_down_minutes = sharing_enabled,
  share_phone_away_minutes = sharing_enabled,
  share_phone_tucked_away = sharing_enabled,
  share_shielding_status = sharing_enabled
where sharing_enabled = false;

create table if not exists public.night_flock_shared_metrics (
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
  wind_down_minutes smallint not null default 0 check (wind_down_minutes between 0 and 180),
  phone_away_minutes smallint not null default 0 check (phone_away_minutes between 0 and 240),
  sleep_duration_minutes smallint check (
    sleep_duration_minutes is null or sleep_duration_minutes between 0 and 720
  ),
  restfulness text check (
    restfulness is null or restfulness in ('notMuch', 'somewhat', 'rested', 'notSure')
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (challenge_id, member_id, challenge_day)
);

create table if not exists public.night_flock_reward_grants (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.night_flock_challenges(id) on delete cascade,
  member_id uuid not null references public.night_flock_members(id) on delete cascade,
  milestone text not null check (
    milestone in (
      'qualifyingNight:1', 'qualifyingNight:2', 'qualifyingNight:3', 'qualifyingNight:4',
      'qualifyingNight:5', 'qualifyingNight:6', 'qualifyingNight:7',
      'threeNightParticipation', 'sevenNightCompletion', 'groupCompletion'
    )
  ),
  reward_kind text not null check (reward_kind in ('wool', 'itemOrWool', 'sheepSearch')),
  wool_amount smallint not null default 0 check (wool_amount between 0 and 12),
  item_id text,
  sheep_search_entitlement boolean not null default false,
  created_at timestamptz not null default now(),
  claimed_at timestamptz,
  unique (challenge_id, member_id, milestone)
);

create index if not exists night_flock_shared_metrics_projection_idx
  on public.night_flock_shared_metrics (challenge_id, challenge_day, updated_at);
create index if not exists night_flock_reward_grants_member_idx
  on public.night_flock_reward_grants (member_id, claimed_at);

alter table public.night_flock_shared_metrics enable row level security;
alter table public.night_flock_reward_grants enable row level security;
revoke all on table public.night_flock_shared_metrics, public.night_flock_reward_grants
from public, anon, authenticated;
grant select, insert, update, delete on table public.night_flock_shared_metrics,
  public.night_flock_reward_grants to service_role;

create or replace function private.night_flock_round_minutes(p_value integer, p_step integer, p_max integer)
returns integer
language sql
immutable
as $$
  select greatest(0, least(p_max,
    (round(greatest(0, coalesce(p_value, 0))::numeric / p_step) * p_step)::integer
  ));
$$;

create or replace function private.night_flock_status_rank(p_status text)
returns integer
language sql
immutable
as $$
  select case p_status
    when 'privateNoUpdate' then 0
    when 'goalAccepted' then 1
    when 'setupReady' then 2
    when 'phoneTuckedAway' then 3
    when 'partiallyCompleted' then 4
    when 'sharedGoalCompleted' then 5
    when 'morningQuietCompleted' then 6
    else -1
  end;
$$;

create or replace function private.night_flock_evaluate_rewards(p_challenge_id uuid, p_member_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  qualifying_days integer;
  challenge_status text;
  eligible_members integer;
begin
  select count(distinct challenge_day) into qualifying_days
  from public.night_flock_shared_metrics
  where challenge_id = p_challenge_id and member_id = p_member_id
    and status in ('sharedGoalCompleted', 'morningQuietCompleted');

  insert into public.night_flock_reward_grants (
    challenge_id, member_id, milestone, reward_kind, wool_amount
  )
  select p_challenge_id, p_member_id, 'qualifyingNight:' || challenge_day, 'wool', 1
  from public.night_flock_shared_metrics
  where challenge_id = p_challenge_id and member_id = p_member_id
    and status in ('sharedGoalCompleted', 'morningQuietCompleted')
  on conflict (challenge_id, member_id, milestone) do nothing;

  if qualifying_days >= 3 then
    insert into public.night_flock_reward_grants (
      challenge_id, member_id, milestone, reward_kind, wool_amount, item_id
    ) values (
      p_challenge_id, p_member_id, 'threeNightParticipation', 'itemOrWool', 3, 'collectible_trail_pin'
    ) on conflict (challenge_id, member_id, milestone) do nothing;
  end if;

  select status into challenge_status from public.night_flock_challenges where id = p_challenge_id;
  if challenge_status = 'completed' and qualifying_days >= 4 then
    insert into public.night_flock_reward_grants (
      challenge_id, member_id, milestone, reward_kind, sheep_search_entitlement
    ) values (
      p_challenge_id, p_member_id, 'sevenNightCompletion', 'sheepSearch', true
    ) on conflict (challenge_id, member_id, milestone) do nothing;
  end if;

  if challenge_status = 'completed' then
    select count(*) into eligible_members
    from (
      select member_id
      from public.night_flock_shared_metrics
      where challenge_id = p_challenge_id
        and status in ('sharedGoalCompleted', 'morningQuietCompleted')
      group by member_id
      having count(distinct challenge_day) >= 4
    ) eligible;
    if eligible_members >= 2 and qualifying_days >= 4 then
      insert into public.night_flock_reward_grants (
        challenge_id, member_id, milestone, reward_kind, wool_amount
      ) values (
        p_challenge_id, p_member_id, 'groupCompletion', 'wool', 2
      ) on conflict (challenge_id, member_id, milestone) do nothing;
    end if;
  end if;
end;
$$;

create or replace function private.night_flock_social_snapshot(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  base jsonb := private.night_flock_commitment_snapshot(p_user_id);
  membership public.night_flock_members%rowtype;
  challenge public.night_flock_challenges%rowtype;
  sharing jsonb;
  grants jsonb;
  day_rows jsonb;
begin
  if base is null then return null; end if;
  select * into membership from public.night_flock_members
  where user_id = p_user_id and status = 'active' limit 1;
  if membership.id is null then return null; end if;
  select * into challenge from public.night_flock_challenges
  where id = (base -> 'challenge' ->> 'id')::uuid;

  if challenge.status = 'active'
     and (now() at time zone challenge.time_zone_identifier)::date > challenge.ends_on then
    update public.night_flock_challenges
      set status = 'completed', completed_at = coalesce(completed_at, now())
      where id = challenge.id;
    challenge.status := 'completed';
    perform private.night_flock_evaluate_rewards(challenge.id, member.id)
    from public.night_flock_members member
    where member.flock_id = challenge.flock_id and member.status = 'active';
  end if;

  sharing := jsonb_build_object(
    'shareGoalProgress', membership.sharing_enabled,
    'shareWindDownCompletion', membership.share_wind_down_completion,
    'shareWindDownMinutes', membership.share_wind_down_minutes,
    'sharePhoneAwayMinutes', membership.share_phone_away_minutes,
    'sharePhoneTuckedAway', membership.share_phone_tucked_away,
    'shareShieldingStatus', membership.share_shielding_status,
    'shareRoutineIdeas', membership.share_routine_ideas,
    'shareSleepDuration', membership.share_sleep_duration,
    'shareRestfulness', membership.share_restfulness
  );

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', reward_grant.id,
    'challengeID', reward_grant.challenge_id,
    'memberID', reward_grant.member_id,
    'milestone', reward_grant.milestone,
    'rewardKind', reward_grant.reward_kind,
    'woolAmount', reward_grant.wool_amount,
    'itemID', reward_grant.item_id,
    'sheepSearchEntitlement', reward_grant.sheep_search_entitlement,
    'createdAt', reward_grant.created_at,
    'claimedAt', reward_grant.claimed_at
  ) order by reward_grant.created_at), '[]'::jsonb)
  into grants
  from public.night_flock_reward_grants reward_grant
  where reward_grant.member_id = membership.id and reward_grant.claimed_at is null;

  select jsonb_agg(jsonb_build_object(
    'day', day_number,
    'phoneTuckedCount', coalesce((base -> 'days' -> (day_number - 1) ->> 'phoneTuckedCount')::int, 0),
    'morningQuietCompletedCount', coalesce((base -> 'days' -> (day_number - 1) ->> 'morningQuietCompletedCount')::int, 0),
    'pasture', coalesce(base -> 'days' -> (day_number - 1) -> 'pasture', '[]'::jsonb),
    'memberProgress', coalesce((
      select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
        'memberID', member.id,
        'day', day_number,
        'status', case
          when coalesce(metrics.status, progress.status, 'privateNoUpdate') in ('goalAccepted', 'setupReady')
            and member.sharing_enabled
            then coalesce(metrics.status, progress.status)
          when coalesce(metrics.status, progress.status) in (
            'partiallyCompleted', 'sharedGoalCompleted', 'morningQuietCompleted'
          ) and member.share_wind_down_completion
            then coalesce(metrics.status, progress.status)
          when coalesce(metrics.status, progress.status) in (
            'phoneTuckedAway', 'partiallyCompleted', 'sharedGoalCompleted', 'morningQuietCompleted'
          ) and member.share_phone_tucked_away
            then 'phoneTuckedAway'
          else 'privateNoUpdate'
        end,
        'shieldingEvidence', case when member.share_shielding_status
          then coalesce(metrics.shielding_evidence, progress.shielding_evidence, 'notRequested')
          else 'notRequested' end,
        'windDownMinutes', case when member.share_wind_down_minutes then metrics.wind_down_minutes else null end,
        'phoneAwayMinutes', case when member.share_phone_away_minutes then metrics.phone_away_minutes else null end,
        'sleepDurationMinutes', case when member.share_sleep_duration then metrics.sleep_duration_minutes else null end,
        'restfulness', case when member.share_restfulness then metrics.restfulness else null end
      )) order by member.joined_at)
      from public.night_flock_members member
      left join public.night_flock_shared_metrics metrics
        on metrics.member_id = member.id and metrics.challenge_id = challenge.id
        and metrics.challenge_day = day_number
      left join public.night_flock_goal_progress progress
        on progress.member_id = member.id and progress.challenge_id = challenge.id
        and progress.challenge_day = day_number
      where member.flock_id = challenge.flock_id and member.status = 'active'
        and not private.night_flock_users_blocked(p_user_id, member.user_id)
        and (
          metrics.id is not null or progress.id is not null
        )
    ), '[]'::jsonb)
  ) order by day_number)
  into day_rows
  from generate_series(1, 7) day_number;

  return base || jsonb_build_object(
    'sharing', sharing,
    'pendingGrants', grants,
    'days', coalesce(day_rows, base -> 'days'),
    'memberSetups', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'memberID', member.id,
        'goalAccepted', member.goal_accepted,
        'setupReady', member.setup_ready,
        'sharingEnabled', member.sharing_enabled,
        'shareRoutineIdeas', member.share_routine_ideas,
        'shieldingEvidence', member.shielding_evidence,
        'sharing', jsonb_build_object(
          'shareGoalProgress', member.sharing_enabled,
          'shareWindDownCompletion', member.share_wind_down_completion,
          'shareWindDownMinutes', member.share_wind_down_minutes,
          'sharePhoneAwayMinutes', member.share_phone_away_minutes,
          'sharePhoneTuckedAway', member.share_phone_tucked_away,
          'shareShieldingStatus', member.share_shielding_status,
          'shareRoutineIdeas', member.share_routine_ideas,
          'shareSleepDuration', member.share_sleep_duration,
          'shareRestfulness', member.share_restfulness
        )
      ) order by member.joined_at), '[]'::jsonb)
      from public.night_flock_members member
      where member.flock_id = challenge.flock_id and member.status = 'active'
        and not private.night_flock_users_blocked(p_user_id, member.user_id)
    )
  );
end;
$$;

create or replace function public.night_flock_social_state(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_user_id is null or not private.is_apple_linked_night_flock_user(p_user_id) then
    raise exception 'Apple-linked account required' using errcode = '28000';
  end if;
  return private.night_flock_social_snapshot(p_user_id);
end;
$$;

create or replace function public.night_flock_social_command(p_user_id uuid, p_command jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  command_name text := p_command ->> 'command';
  membership public.night_flock_members%rowtype;
  target_challenge public.night_flock_challenges%rowtype;
  proposed_status text;
  current_status text;
  grant_id uuid;
  wind_minutes integer;
  away_minutes integer;
  sleep_minutes integer;
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
  if membership.id is null then raise exception 'Current membership required'; end if;

  if command_name = 'setSharingPreferences' then
    update public.night_flock_members set
      sharing_enabled = (p_command ->> 'shareGoalProgress')::boolean,
      share_wind_down_completion = (p_command ->> 'shareWindDownCompletion')::boolean,
      share_wind_down_minutes = (p_command ->> 'shareWindDownMinutes')::boolean,
      share_phone_away_minutes = (p_command ->> 'sharePhoneAwayMinutes')::boolean,
      share_phone_tucked_away = (p_command ->> 'sharePhoneTuckedAway')::boolean,
      share_shielding_status = (p_command ->> 'shareShieldingStatus')::boolean,
      share_routine_ideas = (p_command ->> 'shareRoutineIdeas')::boolean,
      share_sleep_duration = (p_command ->> 'shareSleepDuration')::boolean,
      share_restfulness = (p_command ->> 'shareRestfulness')::boolean
    where id = membership.id;

  elsif command_name = 'publishNightMetrics' then
    if p_command ? 'applicationTokens' or p_command ? 'selectedApps' or p_command ? 'familyActivitySelection'
       or p_command ? 'healthKit' or p_command ? 'runID' then
      raise exception 'Unsupported social field';
    end if;
    proposed_status := p_command ->> 'status';
    if private.night_flock_status_rank(proposed_status) < 0 then raise exception 'Invalid status'; end if;
    if p_command ->> 'shieldingEvidence' not in ('notRequested', 'unavailable', 'partial', 'observed') then
      raise exception 'Invalid shielding evidence';
    end if;
    wind_minutes := (p_command ->> 'windDownMinutes')::integer;
    away_minutes := (p_command ->> 'phoneAwayMinutes')::integer;
    if wind_minutes is null or away_minutes is null
       or wind_minutes < 0 or away_minutes < 0 or wind_minutes > 180 or away_minutes > 240 then
      raise exception 'Values outside bounds';
    end if;
    wind_minutes := private.night_flock_round_minutes(wind_minutes, 5, 180);
    away_minutes := private.night_flock_round_minutes(away_minutes, 5, 240);
    if p_command ->> 'sleepDurationMinutes' is null or p_command ->> 'sleepDurationMinutes' = '' then
      sleep_minutes := null;
    else
      sleep_minutes := (p_command ->> 'sleepDurationMinutes')::integer;
      if sleep_minutes < 0 or sleep_minutes > 720 then raise exception 'Values outside bounds'; end if;
      sleep_minutes := private.night_flock_round_minutes(sleep_minutes, 15, 720);
    end if;
    if p_command ->> 'restfulness' is not null
       and p_command ->> 'restfulness' not in ('notMuch', 'somewhat', 'rested', 'notSure') then
      raise exception 'Invalid restfulness';
    end if;
    select * into target_challenge
    from public.night_flock_challenges
    where id = (p_command ->> 'challengeID')::uuid
      and flock_id = membership.flock_id
      and status in ('active', 'completed');
    if target_challenge.id is null then raise exception 'Challenge unavailable'; end if;
    select status into current_status
    from public.night_flock_shared_metrics
    where challenge_id = target_challenge.id and member_id = membership.id
      and challenge_day = (p_command ->> 'day')::smallint;
    insert into public.night_flock_shared_metrics (
      challenge_id, member_id, challenge_day, status, shielding_evidence,
      wind_down_minutes, phone_away_minutes, sleep_duration_minutes, restfulness
    ) values (
      target_challenge.id, membership.id, (p_command ->> 'day')::smallint,
      proposed_status, p_command ->> 'shieldingEvidence',
      wind_minutes, away_minutes,
      case when membership.share_sleep_duration then sleep_minutes else null end,
      case when membership.share_restfulness then nullif(p_command ->> 'restfulness', '') else null end
    )
    on conflict (challenge_id, member_id, challenge_day) do update set
      status = case
        when private.night_flock_status_rank(excluded.status)
          >= private.night_flock_status_rank(public.night_flock_shared_metrics.status)
        then excluded.status else public.night_flock_shared_metrics.status end,
      shielding_evidence = excluded.shielding_evidence,
      wind_down_minutes = greatest(public.night_flock_shared_metrics.wind_down_minutes, excluded.wind_down_minutes),
      phone_away_minutes = greatest(public.night_flock_shared_metrics.phone_away_minutes, excluded.phone_away_minutes),
      sleep_duration_minutes = case when membership.share_sleep_duration then
        coalesce(greatest(public.night_flock_shared_metrics.sleep_duration_minutes, excluded.sleep_duration_minutes),
          excluded.sleep_duration_minutes, public.night_flock_shared_metrics.sleep_duration_minutes)
        else null end,
      restfulness = case when membership.share_restfulness then coalesce(excluded.restfulness, public.night_flock_shared_metrics.restfulness) else null end,
      updated_at = now();
    insert into public.night_flock_goal_progress (
      challenge_id, member_id, challenge_day, status, shielding_evidence
    ) values (
      target_challenge.id, membership.id, (p_command ->> 'day')::smallint, proposed_status,
      p_command ->> 'shieldingEvidence'
    ) on conflict (challenge_id, member_id, challenge_day) do update set
      status = case
        when private.night_flock_status_rank(excluded.status)
          >= private.night_flock_status_rank(public.night_flock_goal_progress.status)
        then excluded.status else public.night_flock_goal_progress.status end,
      shielding_evidence = excluded.shielding_evidence,
      updated_at = now();
    if proposed_status = 'privateNoUpdate' and current_status is null then
      null;
    elsif proposed_status <> 'privateNoUpdate' then
      insert into public.night_flock_checkins (
        challenge_id, member_id, challenge_day, state, idempotency_key
      ) values (
        target_challenge.id, membership.id, (p_command ->> 'day')::smallint,
        case when proposed_status = 'morningQuietCompleted' then 'morningQuietCompleted' else 'phoneTucked' end,
        p_command ->> 'idempotencyKey'
      ) on conflict (challenge_id, member_id, challenge_day) do update set
        state = excluded.state, idempotency_key = excluded.idempotency_key, updated_at = now();
    end if;
    perform private.night_flock_evaluate_rewards(target_challenge.id, membership.id);

  elsif command_name = 'acknowledgeGrant' then
    grant_id := (p_command ->> 'grantID')::uuid;
    update public.night_flock_reward_grants
      set claimed_at = coalesce(claimed_at, now())
      where id = grant_id and member_id = membership.id;
    if not found then raise exception 'Grant unavailable'; end if;
  else
    raise exception 'Unsupported schema-three command';
  end if;

  return jsonb_build_object('accepted', true, 'snapshot', private.night_flock_social_snapshot(p_user_id));
end;
$$;

create or replace function private.delete_night_flock_user_data(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare affected_flock uuid;
begin
  select flock_id into affected_flock
  from public.night_flock_members
  where user_id = p_user_id and status = 'active'
  limit 1;

  update public.night_flocks set created_by = null where created_by = p_user_id;
  update public.night_flock_challenges set summary = null where flock_id = affected_flock;
  delete from public.night_flock_reward_grants
  where member_id in (select id from public.night_flock_members where user_id = p_user_id);
  delete from public.night_flock_shared_metrics
  where member_id in (select id from public.night_flock_members where user_id = p_user_id);
  delete from public.night_flock_reactions
  where member_id in (select id from public.night_flock_members where user_id = p_user_id);
  delete from public.night_flock_checkins
  where member_id in (select id from public.night_flock_members where user_id = p_user_id);
  delete from public.night_flock_invites
  where created_by_member_id in (select id from public.night_flock_members where user_id = p_user_id);
  delete from public.night_flock_members where user_id = p_user_id;
  delete from public.night_flock_blocks
  where blocker_user_id = p_user_id or blocked_user_id = p_user_id;
  delete from public.night_flock_reports where reporter_user_id = p_user_id;
  update public.night_flock_reports set reported_user_id = null where reported_user_id = p_user_id;
  update public.night_flock_moderation_actions set target_user_id = null where target_user_id = p_user_id;
  delete from public.night_flock_profiles where user_id = p_user_id;

  if affected_flock is not null and not exists (
    select 1 from public.night_flock_members where flock_id = affected_flock and status = 'active'
  ) then
    delete from public.night_flocks where id = affected_flock;
  end if;
end;
$$;

create or replace function public.purge_night_flock_retention(p_now timestamptz default now())
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare invite_count integer;
declare activity_count integer;
declare summary_count integer;
declare metrics_count integer;
declare grant_count integer;
begin
  update public.night_flock_challenges
  set status = 'completed', completed_at = coalesce(completed_at, p_now)
  where status = 'active'
    and (p_now at time zone time_zone_identifier)::date > ends_on;

  update public.night_flock_challenges challenge
  set summary = jsonb_build_object(
    'days', (
      select jsonb_agg(jsonb_build_object(
        'day', day_number,
        'phoneTuckedCount', (
          select count(*) from public.night_flock_checkins checkin
          join public.night_flock_members member on member.id = checkin.member_id
          where checkin.challenge_id = challenge.id and checkin.challenge_day = day_number
            and member.status = 'active'
        ),
        'morningQuietCompletedCount', (
          select count(*) from public.night_flock_checkins checkin
          join public.night_flock_members member on member.id = checkin.member_id
          where checkin.challenge_id = challenge.id and checkin.challenge_day = day_number
            and checkin.state = 'morningQuietCompleted'
            and member.status = 'active'
        ),
        'pasture', '[]'::jsonb
      ) order by day_number)
      from generate_series(1, 7) day_number
    )
  )
  where challenge.status = 'completed' and challenge.summary is null
    and challenge.completed_at < p_now - interval '90 days';
  get diagnostics summary_count = row_count;

  delete from public.night_flock_reactions where created_at < p_now - interval '90 days';
  delete from public.night_flock_checkins where received_at < p_now - interval '90 days';
  get diagnostics activity_count = row_count;
  delete from public.night_flock_shared_metrics where created_at < p_now - interval '90 days';
  get diagnostics metrics_count = row_count;
  delete from public.night_flock_invites where created_at < p_now - interval '30 days';
  get diagnostics invite_count = row_count;
  delete from public.night_flock_reward_grants
  where created_at < p_now - interval '12 months';
  get diagnostics grant_count = row_count;
  delete from public.night_flock_challenges
  where status in ('completed', 'cancelled')
    and coalesce(completed_at, created_at) < p_now - interval '12 months';

  return jsonb_build_object(
    'invitesPurged', invite_count,
    'checkinsPurged', activity_count,
    'summariesCreated', summary_count,
    'metricsPurged', metrics_count,
    'grantsPurged', grant_count
  );
end;
$$;

revoke all on function private.night_flock_round_minutes(integer, integer, integer) from public, anon, authenticated;
revoke all on function private.night_flock_status_rank(text) from public, anon, authenticated;
revoke all on function private.night_flock_evaluate_rewards(uuid, uuid) from public, anon, authenticated;
revoke all on function private.night_flock_social_snapshot(uuid) from public, anon, authenticated;
revoke all on function public.night_flock_social_state(uuid) from public, anon, authenticated;
revoke all on function public.night_flock_social_command(uuid, jsonb) from public, anon, authenticated;
grant execute on function public.night_flock_social_state(uuid) to service_role;
grant execute on function public.night_flock_social_command(uuid, jsonb) to service_role;
grant execute on function public.purge_night_flock_retention(timestamptz) to service_role;
