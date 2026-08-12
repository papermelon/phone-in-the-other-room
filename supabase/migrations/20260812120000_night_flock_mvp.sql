create table public.night_flock_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  alias text not null check (alias ~ '^[A-Za-z]+ [A-Za-z]+$' and length(alias) between 5 and 40),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.night_flocks (
  id uuid primary key default gen_random_uuid(),
  identity text not null check (identity in ('moonlitMeadow', 'orchardGate', 'starlightHill')),
  created_by uuid references auth.users(id) on delete set null,
  idempotency_key text not null unique check (length(idempotency_key) between 16 and 128),
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.night_flock_members (
  id uuid primary key default gen_random_uuid(),
  flock_id uuid not null references public.night_flocks(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  alias text not null check (alias ~ '^[A-Za-z]+ [A-Za-z]+$' and length(alias) between 5 and 40),
  role text not null check (role in ('keeper', 'member')),
  status text not null default 'active' check (status in ('active', 'left', 'removed')),
  sharing_enabled boolean not null default true,
  join_idempotency_key text check (
    join_idempotency_key is null or length(join_idempotency_key) between 16 and 128
  ),
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  check ((status = 'active' and left_at is null) or (status <> 'active' and left_at is not null))
);

create unique index night_flock_members_one_active_flock_per_user
  on public.night_flock_members (user_id) where status = 'active';
create unique index night_flock_members_one_active_record_per_flock
  on public.night_flock_members (flock_id, user_id) where status = 'active';
create unique index night_flock_members_active_alias
  on public.night_flock_members (flock_id, lower(alias)) where status = 'active';

create table public.night_flock_invites (
  id uuid primary key default gen_random_uuid(),
  flock_id uuid not null references public.night_flocks(id) on delete cascade,
  created_by_member_id uuid not null references public.night_flock_members(id) on delete cascade,
  token_hash bytea not null unique check (octet_length(token_hash) = 32),
  idempotency_key text not null unique check (length(idempotency_key) between 16 and 128),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  redeemed_by_member_id uuid references public.night_flock_members(id) on delete set null,
  redeemed_at timestamptz,
  created_at timestamptz not null default now(),
  check (expires_at <= created_at + interval '7 days 5 minutes'),
  check ((redeemed_at is null) = (redeemed_by_member_id is null))
);

create table public.night_flock_challenges (
  id uuid primary key default gen_random_uuid(),
  flock_id uuid not null references public.night_flocks(id) on delete cascade,
  time_zone_identifier text not null check (length(time_zone_identifier) between 1 and 64),
  starts_on date not null,
  ends_on date generated always as (starts_on + 6) stored,
  status text not null default 'pending' check (status in ('pending', 'active', 'completed', 'cancelled')),
  summary jsonb,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  check ((status = 'completed' and completed_at is not null) or status <> 'completed')
);

create unique index night_flock_challenges_one_active_per_flock
  on public.night_flock_challenges (flock_id)
  where status in ('pending', 'active');

create table public.night_flock_checkins (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.night_flock_challenges(id) on delete cascade,
  member_id uuid not null references public.night_flock_members(id) on delete cascade,
  challenge_day smallint not null check (challenge_day between 1 and 7),
  state text not null check (state in ('phoneTucked', 'morningQuietCompleted')),
  idempotency_key text not null unique check (idempotency_key ~ '^[0-9a-f]{64}$'),
  received_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (challenge_id, member_id, challenge_day)
);

create table public.night_flock_reactions (
  id uuid primary key default gen_random_uuid(),
  checkin_id uuid not null references public.night_flock_checkins(id) on delete cascade,
  member_id uuid not null references public.night_flock_members(id) on delete cascade,
  kind text not null check (kind in ('warmWave', 'moonGlow', 'pawPrint')),
  idempotency_key text not null unique check (length(idempotency_key) between 16 and 128),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (checkin_id, member_id)
);

create table public.night_flock_blocks (
  blocker_user_id uuid not null references auth.users(id) on delete cascade,
  blocked_user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_user_id, blocked_user_id),
  check (blocker_user_id <> blocked_user_id)
);

create table public.night_flock_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_user_id uuid references auth.users(id) on delete set null,
  reported_user_id uuid references auth.users(id) on delete set null,
  flock_id uuid references public.night_flocks(id) on delete set null,
  reason text not null check (
    reason in ('unwantedContact', 'harmfulConduct', 'impersonation', 'otherSafetyConcern')
  ),
  idempotency_key text not null unique check (length(idempotency_key) between 16 and 128),
  moderation_status text not null default 'pending' check (
    moderation_status in ('pending', 'reviewed', 'actioned', 'dismissed')
  ),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);

create table public.night_flock_moderation_actions (
  id uuid primary key default gen_random_uuid(),
  target_user_id uuid references auth.users(id) on delete set null,
  report_id uuid references public.night_flock_reports(id) on delete set null,
  action text not null check (action in ('warning', 'socialSuspension', 'accountSuspension', 'accountDeletion')),
  reason text not null check (length(reason) between 1 and 80),
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

create index night_flock_members_flock_status_idx
  on public.night_flock_members (flock_id, status, joined_at);
create index night_flock_invites_retention_idx
  on public.night_flock_invites (created_at, expires_at);
create index night_flock_challenges_retention_idx
  on public.night_flock_challenges (status, completed_at);
create index night_flock_checkins_retention_idx
  on public.night_flock_checkins (received_at);
create index night_flock_reactions_retention_idx
  on public.night_flock_reactions (created_at);
create index night_flock_reports_moderation_idx
  on public.night_flock_reports (moderation_status, created_at);

create or replace function private.night_flock_users_blocked(p_first uuid, p_second uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.night_flock_blocks
    where (blocker_user_id = p_first and blocked_user_id = p_second)
       or (blocker_user_id = p_second and blocked_user_id = p_first)
  );
$$;

create or replace function private.is_current_night_flock_member(p_user_id uuid, p_flock_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.night_flock_members
    where user_id = p_user_id and flock_id = p_flock_id and status = 'active'
  );
$$;

create or replace function private.is_apple_linked_night_flock_user(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from auth.users
    where id = p_user_id
      and not coalesce(is_anonymous, false)
      and coalesce(raw_app_meta_data -> 'providers', '[]'::jsonb) ? 'apple'
  );
$$;

create or replace function private.current_user_is_night_flock_member(p_flock_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.night_flock_members
    where user_id = auth.uid() and flock_id = p_flock_id and status = 'active'
  );
$$;

create or replace function private.current_user_blocked_with(p_other_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.night_flock_blocks
    where (blocker_user_id = auth.uid() and blocked_user_id = p_other_user_id)
       or (blocker_user_id = p_other_user_id and blocked_user_id = auth.uid())
  );
$$;

create or replace function private.enforce_night_flock_capacity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare active_count integer;
begin
  if new.status <> 'active' then return new; end if;
  perform pg_advisory_xact_lock(hashtextextended(new.flock_id::text, 0));
  select count(*) into active_count
  from public.night_flock_members
  where flock_id = new.flock_id and status = 'active' and id <> new.id;
  if active_count >= 8 then
    raise exception 'Night Flock is full' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger night_flock_members_capacity_guard
before insert or update of status, flock_id on public.night_flock_members
for each row execute function private.enforce_night_flock_capacity();

create or replace function private.generate_night_flock_alias(p_user_id uuid, p_flock_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  adjectives text[] := array[
    'Amber', 'Breezy', 'Cedar', 'Dewy', 'Gentle', 'Hazel', 'Juniper', 'Misty',
    'Mossy', 'Quiet', 'Silver', 'Willow', 'Woolly', 'Dappled', 'Moonlit', 'Soft'
  ];
  nouns text[] := array[
    'Bell', 'Clover', 'Fern', 'Lamb', 'Lantern', 'Meadow', 'Oat', 'Pebble',
    'Pine', 'Poppy', 'Reed', 'Robin', 'Sprig', 'Star', 'Thistle', 'Wren'
  ];
  digest_value bytea;
  candidate text;
begin
  digest_value := extensions.digest(p_user_id::text || p_flock_id::text, 'sha256');
  for offset_value in 0..255 loop
    candidate := adjectives[1 + ((get_byte(digest_value, 0) + offset_value) % array_length(adjectives, 1))]
      || ' ' || nouns[1 + ((get_byte(digest_value, 1) + offset_value) % array_length(nouns, 1))];
    if not exists (
      select 1 from public.night_flock_members
      where flock_id = p_flock_id and status = 'active' and lower(alias) = lower(candidate)
    ) then
      return candidate;
    end if;
  end loop;
  raise exception 'Alias pool unavailable';
end;
$$;

alter table public.night_flock_profiles enable row level security;
alter table public.night_flocks enable row level security;
alter table public.night_flock_members enable row level security;
alter table public.night_flock_invites enable row level security;
alter table public.night_flock_challenges enable row level security;
alter table public.night_flock_checkins enable row level security;
alter table public.night_flock_reactions enable row level security;
alter table public.night_flock_blocks enable row level security;
alter table public.night_flock_reports enable row level security;
alter table public.night_flock_moderation_actions enable row level security;

create policy night_flock_profiles_current_shared_membership
on public.night_flock_profiles for select to authenticated
using (
  exists (
    select 1
    from public.night_flock_members mine
    join public.night_flock_members peer on peer.flock_id = mine.flock_id
    where mine.user_id = auth.uid() and mine.status = 'active'
      and peer.user_id = night_flock_profiles.user_id and peer.status = 'active'
      and not private.current_user_blocked_with(peer.user_id)
  )
);

create policy night_flocks_current_membership
on public.night_flocks for select to authenticated
using (private.current_user_is_night_flock_member(id) and deleted_at is null);

create policy night_flock_members_current_unblocked_membership
on public.night_flock_members for select to authenticated
using (
  status = 'active'
  and private.current_user_is_night_flock_member(flock_id)
  and not private.current_user_blocked_with(user_id)
);

create policy night_flock_invites_current_membership
on public.night_flock_invites for select to authenticated
using (private.current_user_is_night_flock_member(flock_id));

create policy night_flock_challenges_current_membership
on public.night_flock_challenges for select to authenticated
using (private.current_user_is_night_flock_member(flock_id));

create policy night_flock_checkins_current_unblocked_membership
on public.night_flock_checkins for select to authenticated
using (
  exists (
    select 1
    from public.night_flock_challenges challenge
    join public.night_flock_members peer on peer.id = night_flock_checkins.member_id
    where challenge.id = night_flock_checkins.challenge_id
      and peer.status = 'active'
      and private.current_user_is_night_flock_member(challenge.flock_id)
      and not private.current_user_blocked_with(peer.user_id)
  )
);

create policy night_flock_reactions_current_unblocked_membership
on public.night_flock_reactions for select to authenticated
using (
  exists (
    select 1
    from public.night_flock_checkins checkin
    join public.night_flock_challenges challenge on challenge.id = checkin.challenge_id
    join public.night_flock_members reactor on reactor.id = night_flock_reactions.member_id
    where checkin.id = night_flock_reactions.checkin_id
      and reactor.status = 'active'
      and private.current_user_is_night_flock_member(challenge.flock_id)
      and not private.current_user_blocked_with(reactor.user_id)
  )
);

create policy night_flock_blocks_owner_read
on public.night_flock_blocks for select to authenticated
using (blocker_user_id = auth.uid());

create policy night_flock_reports_reporter_read
on public.night_flock_reports for select to authenticated
using (reporter_user_id = auth.uid());

revoke all on table
  public.night_flock_profiles,
  public.night_flocks,
  public.night_flock_members,
  public.night_flock_invites,
  public.night_flock_challenges,
  public.night_flock_checkins,
  public.night_flock_reactions,
  public.night_flock_blocks,
  public.night_flock_reports,
  public.night_flock_moderation_actions
from public, anon, authenticated;

grant select, insert, update, delete on table
  public.night_flock_profiles,
  public.night_flocks,
  public.night_flock_members,
  public.night_flock_invites,
  public.night_flock_challenges,
  public.night_flock_checkins,
  public.night_flock_reactions,
  public.night_flock_blocks,
  public.night_flock_reports,
  public.night_flock_moderation_actions
to service_role;

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

create or replace function private.night_flock_snapshot(p_user_id uuid)
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
  day_rows jsonb;
begin
  select * into membership
  from public.night_flock_members
  where user_id = p_user_id and status = 'active'
  limit 1;
  if membership.id is null then return null; end if;

  select * into flock from public.night_flocks
  where id = membership.flock_id and deleted_at is null;
  if flock.id is null then return null; end if;

  select * into challenge
  from public.night_flock_challenges
  where flock_id = flock.id and status in ('pending', 'active', 'completed')
  order by case status when 'active' then 0 when 'pending' then 1 else 2 end, created_at desc
  limit 1;
  if challenge.id is null then return null; end if;

  if challenge.status = 'active'
     and (now() at time zone challenge.time_zone_identifier)::date > challenge.ends_on then
    update public.night_flock_challenges
    set status = 'completed', completed_at = now()
    where id = challenge.id;
    challenge.status := 'completed';
    challenge.completed_at := now();
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', member.id,
    'alias', member.alias,
    'role', member.role
  ) order by member.joined_at), '[]'::jsonb)
  into member_rows
  from public.night_flock_members member
  where member.flock_id = flock.id and member.status = 'active'
    and not private.night_flock_users_blocked(p_user_id, member.user_id);

  if challenge.summary ? 'days' then
    day_rows := challenge.summary -> 'days';
  else
    select jsonb_agg(jsonb_build_object(
      'day', day_number,
      'phoneTuckedCount', (
        select count(*) from public.night_flock_checkins checkin
        join public.night_flock_members checked_member on checked_member.id = checkin.member_id
        where checkin.challenge_id = challenge.id and checkin.challenge_day = day_number
          and checked_member.status = 'active'
          and not private.night_flock_users_blocked(p_user_id, checked_member.user_id)
      ),
      'morningQuietCompletedCount', (
        select count(*) from public.night_flock_checkins checkin
        join public.night_flock_members checked_member on checked_member.id = checkin.member_id
        where checkin.challenge_id = challenge.id and checkin.challenge_day = day_number
          and checkin.state = 'morningQuietCompleted' and checked_member.status = 'active'
          and not private.night_flock_users_blocked(p_user_id, checked_member.user_id)
      ),
      'pasture', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', checkin.id,
          'state', checkin.state,
          'reactions', coalesce((
            select jsonb_agg(jsonb_build_object(
              'id', reaction_group.reaction_id,
              'kind', reaction_group.kind,
              'count', reaction_group.reaction_count,
              'reactedByMe', reaction_group.reacted_by_me
            ) order by reaction_group.kind)
            from (
              select min(reaction.id::text)::uuid reaction_id, reaction.kind,
                count(*) reaction_count,
                bool_or(reactor.user_id = p_user_id) reacted_by_me
              from public.night_flock_reactions reaction
              join public.night_flock_members reactor on reactor.id = reaction.member_id
              where reaction.checkin_id = checkin.id and reactor.status = 'active'
                and not private.night_flock_users_blocked(p_user_id, reactor.user_id)
              group by reaction.kind
            ) reaction_group
          ), '[]'::jsonb)
        ) order by checkin.id)
        from public.night_flock_checkins checkin
        join public.night_flock_members checked_member on checked_member.id = checkin.member_id
        where checkin.challenge_id = challenge.id and checkin.challenge_day = day_number
          and checked_member.status = 'active'
          and not private.night_flock_users_blocked(p_user_id, checked_member.user_id)
      ), '[]'::jsonb)
    ) order by day_number)
    into day_rows
    from generate_series(1, 7) day_number;
  end if;

  return jsonb_build_object(
    'profile', jsonb_build_object('alias', membership.alias),
    'flockID', flock.id,
    'identity', flock.identity,
    'myMemberID', membership.id,
    'members', member_rows,
    'challenge', jsonb_build_object(
      'id', challenge.id,
      'timeZoneIdentifier', challenge.time_zone_identifier,
      'startsOn', jsonb_build_object(
        'year', extract(year from challenge.starts_on)::integer,
        'month', extract(month from challenge.starts_on)::integer,
        'day', extract(day from challenge.starts_on)::integer
      ),
      'status', challenge.status
    ),
    'days', coalesce(day_rows, '[]'::jsonb),
    'sharingEnabled', membership.sharing_enabled
  );
end;
$$;

create or replace function public.night_flock_state(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_user_id is null or not private.is_apple_linked_night_flock_user(p_user_id) then
    raise exception 'Apple-linked account required' using errcode = '28000';
  end if;
  return private.night_flock_snapshot(p_user_id);
end;
$$;

create or replace function public.night_flock_command(p_user_id uuid, p_command jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  command_name text := p_command ->> 'command';
  v_idempotency_key text := p_command ->> 'idempotencyKey';
  membership public.night_flock_members%rowtype;
  target_member public.night_flock_members%rowtype;
  challenge public.night_flock_challenges%rowtype;
  invite public.night_flock_invites%rowtype;
  flock public.night_flocks%rowtype;
  alias_value text;
  invite_code text;
  active_count integer;
  requested_day integer;
  requested_state text;
begin
  if p_user_id is null or not private.is_apple_linked_night_flock_user(p_user_id) then
    raise exception 'Apple-linked account required' using errcode = '28000';
  end if;
  if command_name is null or length(v_idempotency_key) not between 16 and 128 then
    raise exception 'Invalid command contract';
  end if;
  if exists (
    select 1 from public.night_flock_moderation_actions
    where target_user_id = p_user_id
      and action in ('socialSuspension', 'accountSuspension', 'accountDeletion')
      and (expires_at is null or expires_at > now())
  ) then
    raise exception 'Night Flock unavailable for this account' using errcode = '42501';
  end if;

  select * into membership from public.night_flock_members
  where user_id = p_user_id and status = 'active' limit 1;

  if command_name = 'createFlock' then
    if membership.id is not null then raise exception 'One active Night Flock allowed'; end if;
    if p_command ->> 'identity' not in ('moonlitMeadow', 'orchardGate', 'starlightHill') then
      raise exception 'Invalid flock identity';
    end if;
    if not exists (
      select 1 from pg_timezone_names where name = p_command ->> 'timeZoneIdentifier'
    ) then raise exception 'Invalid challenge timezone'; end if;

    select * into flock from public.night_flocks where idempotency_key = v_idempotency_key;
    if flock.id is null then
      insert into public.night_flocks (identity, created_by, idempotency_key)
      values (p_command ->> 'identity', p_user_id, v_idempotency_key)
      returning * into flock;
      alias_value := private.generate_night_flock_alias(p_user_id, flock.id);
      insert into public.night_flock_profiles (user_id, alias)
      values (p_user_id, alias_value)
      on conflict (user_id) do update set alias = excluded.alias, updated_at = now();
      insert into public.night_flock_members (flock_id, user_id, alias, role, join_idempotency_key)
      values (flock.id, p_user_id, alias_value, 'keeper', v_idempotency_key)
      returning * into membership;
      insert into public.night_flock_challenges (
        flock_id, time_zone_identifier, starts_on, status
      ) values (
        flock.id,
        p_command ->> 'timeZoneIdentifier',
        (now() at time zone (p_command ->> 'timeZoneIdentifier'))::date,
        'pending'
      );
    end if;

  elsif command_name = 'createInvite' then
    if membership.id is null then raise exception 'Current membership required'; end if;
    select * into invite from public.night_flock_invites where idempotency_key = v_idempotency_key;
    if invite.id is null then
      for attempt in 1..12 loop
        invite_code := '';
        for code_index in 0..11 loop
          invite_code := invite_code || substr(
            'ABCDEFGHJKLMNPQRSTUVWXYZ23456789',
            1 + (get_byte(extensions.gen_random_bytes(1), 0) % 32),
            1
          );
        end loop;
        begin
          insert into public.night_flock_invites (
            flock_id, created_by_member_id, token_hash, idempotency_key, expires_at
          ) values (
            membership.flock_id, membership.id,
            extensions.digest(invite_code, 'sha256'), v_idempotency_key,
            now() + interval '7 days'
          ) returning * into invite;
          exit;
        exception when unique_violation then
          if exists (select 1 from public.night_flock_invites where idempotency_key = v_idempotency_key) then
            raise exception 'Invite replay cannot reveal the original code';
          end if;
        end;
      end loop;
      if invite.id is null then raise exception 'Invite code unavailable'; end if;
    else
      raise exception 'Invite replay cannot reveal the original code';
    end if;

  elsif command_name = 'revokeInvite' then
    if membership.id is null then raise exception 'Current membership required'; end if;
    update public.night_flock_invites
    set revoked_at = coalesce(revoked_at, now())
    where id = (p_command ->> 'inviteID')::uuid
      and flock_id = membership.flock_id and redeemed_at is null;
    if not found then raise exception 'Invite unavailable'; end if;

  elsif command_name = 'join' then
    if membership.id is not null then raise exception 'One active Night Flock allowed'; end if;
    if p_command ->> 'shortCode' !~ '^[A-HJ-NP-Z2-9]{12}$' then raise exception 'Invalid invite code'; end if;
    select * into invite from public.night_flock_invites
    where token_hash = extensions.digest(upper(p_command ->> 'shortCode'), 'sha256')
    for update;
    if invite.id is null then raise exception 'Invite unavailable'; end if;
    if invite.revoked_at is not null then raise exception 'Invite revoked'; end if;
    if invite.expires_at <= now() then raise exception 'Invite expired'; end if;
    if invite.redeemed_at is not null then raise exception 'Invite already used'; end if;
    perform pg_advisory_xact_lock(hashtextextended(invite.flock_id::text, 0));
    select count(*) into active_count from public.night_flock_members
    where flock_id = invite.flock_id and status = 'active';
    if active_count >= 8 then raise exception 'Night Flock is full'; end if;
    if exists (
      select 1 from public.night_flock_members peer
      where peer.flock_id = invite.flock_id and peer.status = 'active'
        and private.night_flock_users_blocked(p_user_id, peer.user_id)
    ) then raise exception 'Blocked membership cannot be joined' using errcode = '42501'; end if;
    alias_value := private.generate_night_flock_alias(p_user_id, invite.flock_id);
    insert into public.night_flock_profiles (user_id, alias)
    values (p_user_id, alias_value)
    on conflict (user_id) do update set alias = excluded.alias, updated_at = now();
    insert into public.night_flock_members (
      flock_id, user_id, alias, role, join_idempotency_key
    ) values (
      invite.flock_id, p_user_id, alias_value, 'member', v_idempotency_key
    ) returning * into membership;
    update public.night_flock_invites
    set redeemed_by_member_id = membership.id, redeemed_at = now()
    where id = invite.id;
    select * into challenge from public.night_flock_challenges
    where flock_id = invite.flock_id and status = 'pending' for update;
    if challenge.id is not null then
      update public.night_flock_challenges
      set status = 'active',
          starts_on = (now() at time zone challenge.time_zone_identifier)::date
      where id = challenge.id;
    end if;

  elsif command_name = 'leave' then
    if membership.id is not null then
      update public.night_flock_challenges set summary = null
      where flock_id = membership.flock_id;
      update public.night_flock_members
      set status = 'left', left_at = now()
      where id = membership.id and status = 'active';
    end if;

  elsif command_name = 'setSharing' then
    if membership.id is null then raise exception 'Current membership required'; end if;
    if jsonb_typeof(p_command -> 'enabled') <> 'boolean' then raise exception 'Invalid sharing value'; end if;
    update public.night_flock_members
    set sharing_enabled = (p_command ->> 'enabled')::boolean
    where id = membership.id;

  elsif command_name = 'block' then
    if membership.id is null then raise exception 'Current membership required'; end if;
    select * into target_member from public.night_flock_members
    where id = (p_command ->> 'memberID')::uuid
      and flock_id = membership.flock_id and status = 'active';
    if target_member.id is null or target_member.user_id = p_user_id then
      raise exception 'Invalid block target';
    end if;
    insert into public.night_flock_blocks (blocker_user_id, blocked_user_id)
    values (p_user_id, target_member.user_id) on conflict do nothing;
    update public.night_flock_challenges set summary = null
    where flock_id = membership.flock_id;
    update public.night_flock_members
    set status = 'left', left_at = now()
    where id = membership.id;

  elsif command_name = 'report' then
    if membership.id is null then raise exception 'Current membership required'; end if;
    if p_command ->> 'reason' not in (
      'unwantedContact', 'harmfulConduct', 'impersonation', 'otherSafetyConcern'
    ) then raise exception 'Invalid report reason'; end if;
    select * into target_member from public.night_flock_members
    where id = (p_command ->> 'memberID')::uuid
      and flock_id = membership.flock_id and status = 'active';
    if target_member.id is null or target_member.user_id = p_user_id then
      raise exception 'Invalid report target';
    end if;
    insert into public.night_flock_reports (
      reporter_user_id, reported_user_id, flock_id, reason, idempotency_key
    ) values (
      p_user_id, target_member.user_id, membership.flock_id,
      p_command ->> 'reason', v_idempotency_key
    ) on conflict (idempotency_key) do nothing;

  elsif command_name = 'publishCheckIn' then
    if membership.id is null or not membership.sharing_enabled then
      raise exception 'Sharing is unavailable';
    end if;
    requested_day := (p_command ->> 'day')::integer;
    requested_state := p_command ->> 'state';
    if requested_day not between 1 and 7 then raise exception 'Invalid challenge day'; end if;
    if requested_state not in ('phoneTucked', 'morningQuietCompleted') then
      raise exception 'Invalid check-in state';
    end if;
    select * into challenge from public.night_flock_challenges
    where id = (p_command ->> 'challengeID')::uuid
      and flock_id = membership.flock_id and status in ('active', 'completed');
    if challenge.id is null then raise exception 'Challenge unavailable'; end if;
    if requested_day > least(7, greatest(1,
      ((now() at time zone challenge.time_zone_identifier)::date - challenge.starts_on) + 1
    )) then raise exception 'Future challenge day'; end if;
    if not exists (
      select 1 from public.night_flock_checkins where idempotency_key = v_idempotency_key
    ) then
      insert into public.night_flock_checkins (
        challenge_id, member_id, challenge_day, state, idempotency_key
      ) values (
        challenge.id, membership.id, requested_day, requested_state, v_idempotency_key
      ) on conflict (challenge_id, member_id, challenge_day) do update set
        state = case
          when public.night_flock_checkins.state = 'morningQuietCompleted'
            then public.night_flock_checkins.state
          when excluded.state = 'morningQuietCompleted' then excluded.state
          else public.night_flock_checkins.state
        end,
        updated_at = now();
    end if;

  elsif command_name = 'react' then
    if membership.id is null then raise exception 'Current membership required'; end if;
    if p_command ->> 'reaction' not in ('warmWave', 'moonGlow', 'pawPrint') then
      raise exception 'Invalid reaction';
    end if;
    if not exists (
      select 1 from public.night_flock_checkins checkin
      join public.night_flock_challenges reaction_challenge on reaction_challenge.id = checkin.challenge_id
      join public.night_flock_members checked_member on checked_member.id = checkin.member_id
      where checkin.id = (p_command ->> 'checkInID')::uuid
        and reaction_challenge.flock_id = membership.flock_id
        and checked_member.status = 'active'
        and not private.night_flock_users_blocked(p_user_id, checked_member.user_id)
    ) then raise exception 'Check-in unavailable'; end if;
    insert into public.night_flock_reactions (
      checkin_id, member_id, kind, idempotency_key
    ) values (
      (p_command ->> 'checkInID')::uuid, membership.id,
      p_command ->> 'reaction', v_idempotency_key
    ) on conflict (checkin_id, member_id) do update set
      kind = excluded.kind, idempotency_key = excluded.idempotency_key, updated_at = now();

  elsif command_name in ('deleteNightFlockData', 'deleteAccount') then
    perform private.delete_night_flock_user_data(p_user_id);

  else
    raise exception 'Unsupported Night Flock command';
  end if;

  return jsonb_build_object(
    'accepted', true,
    'inviteCode', invite_code,
    'inviteID', invite.id,
    'deleteAccount', command_name = 'deleteAccount',
    'snapshot', private.night_flock_snapshot(p_user_id)
  );
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
  delete from public.night_flock_invites where created_at < p_now - interval '30 days';
  get diagnostics invite_count = row_count;
  delete from public.night_flock_challenges
  where status in ('completed', 'cancelled')
    and coalesce(completed_at, created_at) < p_now - interval '12 months';

  return jsonb_build_object(
    'invitesPurged', invite_count,
    'checkinsPurged', activity_count,
    'summariesCreated', summary_count
  );
end;
$$;

revoke all on function private.night_flock_users_blocked(uuid, uuid) from public, anon, authenticated;
revoke all on function private.is_current_night_flock_member(uuid, uuid) from public, anon, authenticated;
revoke all on function private.is_apple_linked_night_flock_user(uuid) from public, anon, authenticated;
revoke all on function private.current_user_is_night_flock_member(uuid) from public, anon, authenticated;
revoke all on function private.current_user_blocked_with(uuid) from public, anon, authenticated;
revoke all on function private.enforce_night_flock_capacity() from public, anon, authenticated;
revoke all on function private.generate_night_flock_alias(uuid, uuid) from public, anon, authenticated;
revoke all on function private.delete_night_flock_user_data(uuid) from public, anon, authenticated;
revoke all on function private.night_flock_snapshot(uuid) from public, anon, authenticated;
revoke all on function public.night_flock_state(uuid) from public, anon, authenticated;
revoke all on function public.night_flock_command(uuid, jsonb) from public, anon, authenticated;
revoke all on function public.purge_night_flock_retention(timestamptz) from public, anon, authenticated;

grant execute on function public.night_flock_state(uuid) to service_role;
grant execute on function public.night_flock_command(uuid, jsonb) to service_role;
grant execute on function public.purge_night_flock_retention(timestamptz) to service_role;
grant execute on function private.current_user_is_night_flock_member(uuid) to authenticated;
grant execute on function private.current_user_blocked_with(uuid) to authenticated;
