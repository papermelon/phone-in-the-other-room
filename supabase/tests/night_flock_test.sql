begin;

insert into auth.users (
  id, instance_id, aud, role, is_anonymous, raw_app_meta_data, created_at, updated_at
)
select
  ('10000000-0000-4000-8000-' || lpad(value::text, 12, '0'))::uuid,
  '00000000-0000-0000-0000-000000000000'::uuid,
  'authenticated',
  'authenticated',
  false,
  '{"provider":"apple","providers":["apple"]}'::jsonb,
  now(),
  now()
from generate_series(1, 12) value;

insert into auth.users (
  id, instance_id, aud, role, is_anonymous, raw_app_meta_data, created_at, updated_at
) values
(
  '10000000-0000-4000-8000-000000000098',
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  false,
  '{"provider":"email","providers":["email"]}'::jsonb,
  now(),
  now()
),
(
  '10000000-0000-4000-8000-000000000099',
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  true,
  '{"provider":"anonymous","providers":[]}'::jsonb,
  now(),
  now()
);

do $$
declare
  owner_id uuid := '10000000-0000-4000-8000-000000000001';
  anonymous_id uuid := '10000000-0000-4000-8000-000000000099';
  non_apple_id uuid := '10000000-0000-4000-8000-000000000098';
  member_ids uuid[] := array[
    '10000000-0000-4000-8000-000000000002'::uuid,
    '10000000-0000-4000-8000-000000000003'::uuid,
    '10000000-0000-4000-8000-000000000004'::uuid,
    '10000000-0000-4000-8000-000000000005'::uuid,
    '10000000-0000-4000-8000-000000000006'::uuid,
    '10000000-0000-4000-8000-000000000007'::uuid,
    '10000000-0000-4000-8000-000000000008'::uuid
  ];
  candidate uuid;
  result jsonb;
  invite_code text;
  v_invite_id uuid;
  v_flock_id uuid;
  v_challenge_id uuid;
  v_owner_member_id uuid;
  v_checkin_id uuid;
  projected text;
  index_value integer := 0;
begin
  begin
    perform public.night_flock_command(anonymous_id, jsonb_build_object(
      'command', 'createFlock', 'identity', 'moonlitMeadow',
      'timeZoneIdentifier', 'UTC', 'idempotencyKey', repeat('0', 64)
    ));
    raise exception 'anonymous social mutation was accepted';
  exception when invalid_authorization_specification then
    null;
  end;

  begin
    perform public.night_flock_command(non_apple_id, jsonb_build_object(
      'command', 'createFlock', 'identity', 'moonlitMeadow',
      'timeZoneIdentifier', 'UTC', 'idempotencyKey', repeat('0a', 32)
    ));
    raise exception 'non-Apple social mutation was accepted';
  exception when invalid_authorization_specification then
    null;
  end;

  result := public.night_flock_command(owner_id, jsonb_build_object(
    'command', 'createFlock', 'identity', 'moonlitMeadow',
    'timeZoneIdentifier', 'UTC', 'idempotencyKey', repeat('a', 64)
  ));
  v_flock_id := (result -> 'snapshot' ->> 'flockID')::uuid;
  v_challenge_id := (result -> 'snapshot' -> 'challenge' ->> 'id')::uuid;
  v_owner_member_id := (result -> 'snapshot' ->> 'myMemberID')::uuid;

  if (result -> 'snapshot' -> 'challenge' ->> 'status') <> 'pending' then
    raise exception 'single-member flock must remain pending';
  end if;

  foreach candidate in array member_ids loop
    index_value := index_value + 1;
    result := public.night_flock_command(owner_id, jsonb_build_object(
      'command', 'createInvite', 'idempotencyKey', lpad(to_hex(index_value + 20), 64, 'b')
    ));
    invite_code := result ->> 'inviteCode';
    v_invite_id := (result ->> 'inviteID')::uuid;
    if invite_code !~ '^[A-HJ-NP-Z2-9]{12}$' then raise exception 'invalid invite code shape'; end if;
    if exists (
      select 1 from public.night_flock_invites
      where id = v_invite_id and token_hash = extensions.digest(invite_code, 'sha256')
    ) then
      null;
    else
      raise exception 'invite token was not stored as a SHA-256 digest';
    end if;

    result := public.night_flock_command(candidate, jsonb_build_object(
      'command', 'join', 'shortCode', invite_code,
      'idempotencyKey', lpad(to_hex(index_value + 50), 64, 'c')
    ));
    if index_value = 1 and (result -> 'snapshot' -> 'challenge' ->> 'status') <> 'active' then
      raise exception 'second member did not start the challenge';
    end if;
  end loop;

  if (select count(*) from public.night_flock_members where flock_id = v_flock_id and status = 'active') <> 8 then
    raise exception 'membership capacity setup failed';
  end if;

  begin
    insert into public.night_flock_challenges (
      flock_id, time_zone_identifier, starts_on, status
    ) values (v_flock_id, 'UTC', current_date, 'pending');
    raise exception 'second active challenge was accepted';
  exception when unique_violation then
    null;
  end;

  begin
    perform public.night_flock_command(
      '10000000-0000-4000-8000-000000000009',
      jsonb_build_object(
        'command', 'join', 'shortCode', invite_code,
        'idempotencyKey', repeat('ca', 32)
      )
    );
    raise exception 'redeemed invite replay was accepted';
  exception when raise_exception then
    if sqlerrm not like '%already used%' then raise; end if;
  end;

  result := public.night_flock_command(owner_id, jsonb_build_object(
    'command', 'createInvite', 'idempotencyKey', repeat('d', 64)
  ));
  invite_code := result ->> 'inviteCode';
  begin
    perform public.night_flock_command(owner_id, jsonb_build_object(
      'command', 'createInvite', 'idempotencyKey', repeat('d', 64)
    ));
    raise exception 'invite creation replay revealed a new code';
  exception when raise_exception then
    if sqlerrm not like '%Invite replay%' then raise; end if;
  end;
  begin
    perform public.night_flock_command(
      '10000000-0000-4000-8000-000000000009',
      jsonb_build_object(
        'command', 'join', 'shortCode', invite_code,
        'idempotencyKey', repeat('e', 64)
      )
    );
    raise exception 'ninth active member was accepted';
  exception when raise_exception then
    if sqlerrm not like '%full%' then raise; end if;
  end;

  begin
    perform public.night_flock_command(
      '10000000-0000-4000-8000-000000000002',
      jsonb_build_object(
        'command', 'createFlock', 'identity', 'orchardGate',
        'timeZoneIdentifier', 'UTC', 'idempotencyKey', repeat('f', 64)
      )
    );
    raise exception 'second active flock was accepted';
  exception when raise_exception then
    if sqlerrm not like '%One active Slumber Party%' then raise; end if;
  end;

  result := public.night_flock_command(owner_id, jsonb_build_object(
    'command', 'createInvite', 'idempotencyKey', repeat('1', 64)
  ));
  invite_code := result ->> 'inviteCode';
  v_invite_id := (result ->> 'inviteID')::uuid;
  perform public.night_flock_command(owner_id, jsonb_build_object(
    'command', 'revokeInvite', 'inviteID', v_invite_id,
    'idempotencyKey', repeat('1a', 32)
  ));
  begin
    perform public.night_flock_command(
      '10000000-0000-4000-8000-000000000009',
      jsonb_build_object(
        'command', 'join', 'shortCode', invite_code,
        'idempotencyKey', repeat('2', 64)
      )
    );
    raise exception 'revoked invite was accepted';
  exception when raise_exception then
    if sqlerrm not like '%Invite revoked%' then raise; end if;
  end;

  result := public.night_flock_command(owner_id, jsonb_build_object(
    'command', 'createInvite', 'idempotencyKey', repeat('3', 64)
  ));
  invite_code := result ->> 'inviteCode';
  v_invite_id := (result ->> 'inviteID')::uuid;
  update public.night_flock_invites set expires_at = now() - interval '1 second' where id = v_invite_id;
  begin
    perform public.night_flock_command(
      '10000000-0000-4000-8000-000000000009',
      jsonb_build_object(
        'command', 'join', 'shortCode', invite_code,
        'idempotencyKey', repeat('4', 64)
      )
    );
    raise exception 'expired invite was accepted';
  exception when raise_exception then
    if sqlerrm not like '%Invite expired%' then raise; end if;
  end;

  begin
    perform public.night_flock_command(
      '10000000-0000-4000-8000-000000000009',
      jsonb_build_object(
        'command', 'join', 'shortCode', invite_code,
        'idempotencyKey', repeat('5', 64)
      )
    );
    raise exception 'expired invite replay was accepted';
  exception when raise_exception then
    if sqlerrm not like '%Invite expired%' then raise; end if;
  end;

  perform public.night_flock_command(owner_id, jsonb_build_object(
    'command', 'publishCheckIn', 'challengeID', v_challenge_id,
    'day', 1, 'state', 'phoneTucked', 'idempotencyKey', repeat('6', 64)
  ));
  perform public.night_flock_command(owner_id, jsonb_build_object(
    'command', 'publishCheckIn', 'challengeID', v_challenge_id,
    'day', 1, 'state', 'phoneTucked', 'idempotencyKey', repeat('6', 64)
  ));
  if (select count(*) from public.night_flock_checkins where challenge_id = v_challenge_id and member_id = v_owner_member_id) <> 1 then
    raise exception 'duplicate start call was not idempotent';
  end if;

  perform public.night_flock_command(owner_id, jsonb_build_object(
    'command', 'publishCheckIn', 'challengeID', v_challenge_id,
    'day', 1, 'state', 'morningQuietCompleted', 'idempotencyKey', repeat('7', 64)
  ));
  perform public.night_flock_command(owner_id, jsonb_build_object(
    'command', 'publishCheckIn', 'challengeID', v_challenge_id,
    'day', 1, 'state', 'morningQuietCompleted', 'idempotencyKey', repeat('7', 64)
  ));
  perform public.night_flock_command(owner_id, jsonb_build_object(
    'command', 'publishCheckIn', 'challengeID', v_challenge_id,
    'day', 1, 'state', 'phoneTucked', 'idempotencyKey', repeat('8', 64)
  ));
  if (select state from public.night_flock_checkins where challenge_id = v_challenge_id and member_id = v_owner_member_id) <> 'morningQuietCompleted' then
    raise exception 'check-in state was downgraded';
  end if;

  select id into v_checkin_id from public.night_flock_checkins
  where challenge_id = v_challenge_id and member_id = v_owner_member_id;
  perform public.night_flock_command(
    '10000000-0000-4000-8000-000000000002',
    jsonb_build_object(
      'command', 'react', 'checkInID', v_checkin_id,
      'reaction', 'warmWave', 'idempotencyKey', repeat('9', 64)
    )
  );

  projected := public.night_flock_state(owner_id)::text;
  if projected ~* '"(userID|ownerID|runID|receivedAt|updatedAt|startedAt|endedAt|privateNight|health|screenTime|selectedApps|nfc|purpose|wool|impact)"[[:space:]]*:' then
    raise exception 'peer projection exposed a forbidden field';
  end if;
end;
$$;

do $$
declare
  second_owner uuid := '10000000-0000-4000-8000-000000000010';
  second_member uuid := '10000000-0000-4000-8000-000000000011';
  result jsonb;
begin
  result := public.night_flock_command(second_owner, jsonb_build_object(
    'command', 'createFlock', 'identity', 'starlightHill',
    'timeZoneIdentifier', 'Asia/Singapore', 'idempotencyKey', repeat('a1', 32)
  ));
  result := public.night_flock_command(second_owner, jsonb_build_object(
    'command', 'createInvite', 'idempotencyKey', repeat('b1', 32)
  ));
  perform public.night_flock_command(second_member, jsonb_build_object(
    'command', 'join', 'shortCode', result ->> 'inviteCode',
    'idempotencyKey', repeat('c1', 32)
  ));
end;
$$;

insert into public.night_flock_blocks (blocker_user_id, blocked_user_id)
values (
  '10000000-0000-4000-8000-000000000003',
  '10000000-0000-4000-8000-000000000004'
);

select public.night_flock_command(
  '10000000-0000-4000-8000-000000000008',
  jsonb_build_object('command', 'leave', 'idempotencyKey', repeat('d1', 32))
);

update public.night_flock_members
set status = 'removed', left_at = now()
where user_id = '10000000-0000-4000-8000-000000000007' and status = 'active';

grant select on table
  public.night_flock_profiles,
  public.night_flocks,
  public.night_flock_members,
  public.night_flock_invites,
  public.night_flock_challenges,
  public.night_flock_checkins,
  public.night_flock_reactions
to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000009', true);
do $$
begin
  if exists (select 1 from public.night_flocks) then
    raise exception 'outsider RLS access was not empty';
  end if;
end;
$$;

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000008', true);
do $$
begin
  if exists (select 1 from public.night_flock_profiles)
     or exists (select 1 from public.night_flocks)
     or exists (select 1 from public.night_flock_members)
     or exists (select 1 from public.night_flock_invites)
     or exists (select 1 from public.night_flock_challenges)
     or exists (select 1 from public.night_flock_checkins)
     or exists (select 1 from public.night_flock_reactions) then
    raise exception 'former-member RLS access was not empty';
  end if;
end;
$$;

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000007', true);
do $$
begin
  if exists (select 1 from public.night_flock_profiles)
     or exists (select 1 from public.night_flocks)
     or exists (select 1 from public.night_flock_members)
     or exists (select 1 from public.night_flock_invites)
     or exists (select 1 from public.night_flock_challenges)
     or exists (select 1 from public.night_flock_checkins)
     or exists (select 1 from public.night_flock_reactions) then
    raise exception 'removed-member RLS access was not empty';
  end if;
end;
$$;

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', true);
do $$
begin
  if exists (
    select 1 from public.night_flock_members
    where user_id = '10000000-0000-4000-8000-000000000004'
  ) then raise exception 'blocked peer remained visible'; end if;
end;
$$;

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000010', true);
do $$
begin
  if (select count(*) from public.night_flocks) <> 1 then
    raise exception 'cross-flock RLS did not isolate one flock';
  end if;
  if exists (
    select 1 from public.night_flock_members
    where user_id = '10000000-0000-4000-8000-000000000001'
  ) then raise exception 'cross-flock member became visible'; end if;
  begin
    insert into public.night_flock_checkins (
      challenge_id, member_id, challenge_day, state, idempotency_key
    ) values (
      gen_random_uuid(), gen_random_uuid(), 1, 'phoneTucked', repeat('f1', 32)
    );
    raise exception 'direct client write was accepted';
  exception when insufficient_privilege then
    null;
  end;
end;
$$;

reset role;

do $$
declare
  v_challenge_id uuid;
  v_checkin_id uuid;
  v_former_member_id uuid;
  v_old_invite_id uuid;
begin
  select id into v_challenge_id from public.night_flock_challenges
  where flock_id = (
    select flock_id from public.night_flock_members
    where user_id = '10000000-0000-4000-8000-000000000001' limit 1
  ) limit 1;
  select id into v_checkin_id from public.night_flock_checkins where challenge_id = v_challenge_id limit 1;
  select id into v_former_member_id from public.night_flock_members
  where user_id = '10000000-0000-4000-8000-000000000008' limit 1;
  select id into v_old_invite_id from public.night_flock_invites limit 1;

  insert into public.night_flock_checkins (
    challenge_id, member_id, challenge_day, state, idempotency_key, received_at
  ) values (
    v_challenge_id, v_former_member_id, 2, 'phoneTucked', repeat('fa', 32),
    now() - interval '91 days'
  );
  update public.night_flock_invites
  set created_at = now() - interval '31 days', expires_at = now() - interval '24 days'
  where id = v_old_invite_id;
  update public.night_flock_checkins set received_at = now() - interval '91 days'
  where id = v_checkin_id;
  update public.night_flock_reactions set created_at = now() - interval '91 days'
  where checkin_id = v_checkin_id;
  update public.night_flock_challenges
  set status = 'completed', completed_at = now() - interval '91 days'
  where id = v_challenge_id;

  perform public.purge_night_flock_retention(now());
  if exists (select 1 from public.night_flock_invites where id = v_old_invite_id) then
    raise exception '30-day invite retention did not purge';
  end if;
  if exists (select 1 from public.night_flock_checkins where id = v_checkin_id) then
    raise exception '90-day raw check-in retention did not purge';
  end if;
  if not exists (
    select 1 from public.night_flock_challenges
    where id = v_challenge_id and summary ? 'days'
  ) then raise exception 'completed summary was not retained'; end if;
  if (
    select (summary -> 'days' -> 1 ->> 'phoneTuckedCount')::integer
    from public.night_flock_challenges where id = v_challenge_id
  ) <> 0 then
    raise exception 'retained summary exposed a former member check-in';
  end if;

  perform public.night_flock_command(
    '10000000-0000-4000-8000-000000000006',
    jsonb_build_object('command', 'leave', 'idempotencyKey', repeat('fb', 32))
  );
  if exists (
    select 1 from public.night_flock_challenges
    where id = v_challenge_id and summary is not null
  ) then raise exception 'leave did not invalidate a retained group summary'; end if;

  update public.night_flock_challenges
  set completed_at = now() - interval '13 months'
  where id = v_challenge_id;
  perform public.purge_night_flock_retention(now());
  if exists (select 1 from public.night_flock_challenges where id = v_challenge_id) then
    raise exception '12-month completed summary retention did not purge';
  end if;
end;
$$;

rollback;
