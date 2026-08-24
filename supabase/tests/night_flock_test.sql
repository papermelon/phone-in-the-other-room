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

insert into auth.users (
  id, instance_id, aud, role, is_anonymous, raw_app_meta_data, created_at, updated_at
) values
(
  '10000000-0000-4000-8000-000000000013',
  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', false,
  '{"provider":"apple","providers":["apple"]}'::jsonb, now(), now()
),
(
  '10000000-0000-4000-8000-000000000014',
  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', false,
  '{"provider":"apple","providers":["apple"]}'::jsonb, now(), now()
);

do $$
declare
  owner_id uuid := '10000000-0000-4000-8000-000000000013';
  member_id uuid := '10000000-0000-4000-8000-000000000014';
  result jsonb;
  invite_code text;
  challenge_id uuid;
  owner_member_id uuid;
begin
  result := public.night_flock_commitment_command(owner_id, jsonb_build_object(
    'schemaVersion', 2, 'command', 'createParty', 'goalKind', 'quietMinutes',
    'targetMinutes', 30, 'appDisplayName', null, 'identity', 'moonlitMeadow',
    'timeZoneIdentifier', 'UTC', 'idempotencyKey', repeat('1a', 32)
  ));
  challenge_id := (result -> 'snapshot' -> 'challenge' ->> 'id')::uuid;
  owner_member_id := (result -> 'snapshot' ->> 'myMemberID')::uuid;
  if (result -> 'snapshot' -> 'challenge' ->> 'status') <> 'pending' then
    raise exception 'schema-two party did not start in a lobby';
  end if;
  if result -> 'snapshot' -> 'challenge' -> 'sharedGoal' ->> 'kind' <> 'quietMinutes' then
    raise exception 'schema-two goal was not projected';
  end if;

  result := public.night_flock_commitment_command(owner_id, jsonb_build_object(
    'schemaVersion', 2, 'command', 'createInvite', 'idempotencyKey', repeat('1b', 32)
  ));
  invite_code := result ->> 'inviteCode';
  result := public.night_flock_commitment_command(member_id, jsonb_build_object(
    'schemaVersion', 2, 'command', 'previewInvite', 'shortCode', invite_code,
    'idempotencyKey', repeat('1c', 32)
  ));
  if result -> 'invitePreview' ->> 'isReusable' <> 'true' then raise exception 'invite was not reusable'; end if;
  perform public.night_flock_commitment_command(member_id, jsonb_build_object(
    'schemaVersion', 2, 'command', 'redeemInvite', 'shortCode', invite_code,
    'idempotencyKey', repeat('1d', 32)
  ));
  if (select status from public.night_flock_challenges where id = challenge_id) <> 'pending' then
    raise exception 'joining started the schema-two lobby';
  end if;

  perform public.night_flock_commitment_command(owner_id, jsonb_build_object(
    'schemaVersion', 2, 'command', 'acceptGoal', 'challengeID', challenge_id, 'idempotencyKey', repeat('1e', 32)
  ));
  perform public.night_flock_commitment_command(member_id, jsonb_build_object(
    'schemaVersion', 2, 'command', 'acceptGoal', 'challengeID', challenge_id, 'idempotencyKey', repeat('1f', 32)
  ));
  perform public.night_flock_commitment_command(owner_id, jsonb_build_object(
    'schemaVersion', 2, 'command', 'setLocalSetup', 'challengeID', challenge_id,
    'setupReady', true, 'shieldingEvidence', 'notRequested', 'idempotencyKey', repeat('20', 32)
  ));
  perform public.night_flock_commitment_command(member_id, jsonb_build_object(
    'schemaVersion', 2, 'command', 'setLocalSetup', 'challengeID', challenge_id,
    'setupReady', true, 'shieldingEvidence', 'observed', 'idempotencyKey', repeat('21', 32)
  ));
  result := public.night_flock_commitment_command(owner_id, jsonb_build_object(
    'schemaVersion', 2, 'command', 'startChallenge', 'challengeID', challenge_id, 'idempotencyKey', repeat('22', 32)
  ));
  if (result -> 'snapshot' -> 'challenge' ->> 'status') <> 'active' then raise exception 'host could not start ready lobby'; end if;
  perform public.night_flock_commitment_command(member_id, jsonb_build_object(
    'schemaVersion', 2, 'command', 'publishProgress', 'challengeID', challenge_id,
    'day', 1, 'status', 'partiallyCompleted', 'shieldingEvidence', 'observed', 'idempotencyKey', repeat('23', 32)
  ));
  result := public.night_flock_commitment_command(member_id, jsonb_build_object(
    'schemaVersion', 2, 'command', 'publishProgress', 'challengeID', challenge_id,
    'day', 1, 'status', 'morningQuietCompleted', 'shieldingEvidence', 'observed', 'idempotencyKey', repeat('24', 32)
  ));
  if result -> 'snapshot' -> 'days' -> 0 -> 'memberProgress' is null then raise exception 'member progress was not projected'; end if;
  if result -> 'snapshot' -> 'days' -> 0 -> 'pasture' -> 0 ->> 'state' <> 'morningQuietCompleted' then
    raise exception 'schema-two progress did not preserve reaction-compatible check-in';
  end if;
  perform public.night_flock_command(owner_id, jsonb_build_object(
    'command', 'react',
    'checkInID', result -> 'snapshot' -> 'days' -> 0 -> 'pasture' -> 0 ->> 'id',
    'reaction', 'warmWave',
    'idempotencyKey', repeat('25', 32)
  ));
  result := public.night_flock_commitment_state(owner_id);
  if result -> 'days' -> 0 -> 'pasture' -> 0 -> 'reactions' -> 0 ->> 'kind' <> 'warmWave' then
    raise exception 'fixed reaction was not projected for schema-two progress';
  end if;
  if result::text ~* 'selectedApps|applicationTokens|healthKit|exactBedtime|wakeTime|runID' then raise exception 'schema-two projection exposed local data'; end if;
end;
$$;

insert into auth.users (
  id, instance_id, aud, role, is_anonymous, raw_app_meta_data, created_at, updated_at
) values
(
  '10000000-0000-4000-8000-000000000015',
  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', false,
  '{"provider":"apple","providers":["apple"]}'::jsonb, now(), now()
),
(
  '10000000-0000-4000-8000-000000000016',
  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', false,
  '{"provider":"apple","providers":["apple"]}'::jsonb, now(), now()
),
(
  '10000000-0000-4000-8000-000000000017',
  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', false,
  '{"provider":"apple","providers":["apple"]}'::jsonb, now(), now()
);

do $$
declare
  owner_id uuid := '10000000-0000-4000-8000-000000000015';
  member_user_id uuid := '10000000-0000-4000-8000-000000000016';
  outsider_id uuid := '10000000-0000-4000-8000-000000000017';
  result jsonb;
  invite_code text;
  challenge_id uuid;
  owner_member uuid;
  member_member uuid;
  grant_count integer;
  day_number integer;
begin
  result := public.night_flock_commitment_command(owner_id, jsonb_build_object(
    'schemaVersion', 2, 'command', 'createParty', 'goalKind', 'phoneAway',
    'targetMinutes', null, 'appDisplayName', null, 'identity', 'moonlitMeadow',
    'timeZoneIdentifier', 'UTC', 'idempotencyKey', repeat('3a', 32)
  ));
  challenge_id := (result -> 'snapshot' -> 'challenge' ->> 'id')::uuid;
  owner_member := (result -> 'snapshot' ->> 'myMemberID')::uuid;
  result := public.night_flock_commitment_command(owner_id, jsonb_build_object(
    'schemaVersion', 2, 'command', 'createInvite', 'idempotencyKey', repeat('3b', 32)
  ));
  invite_code := result ->> 'inviteCode';
  perform public.night_flock_commitment_command(member_user_id, jsonb_build_object(
    'schemaVersion', 2, 'command', 'redeemInvite', 'shortCode', invite_code,
    'idempotencyKey', repeat('3c', 32)
  ));
  member_member := (public.night_flock_commitment_state(member_user_id) ->> 'myMemberID')::uuid;
  perform public.night_flock_commitment_command(owner_id, jsonb_build_object(
    'schemaVersion', 2, 'command', 'acceptGoal', 'challengeID', challenge_id, 'idempotencyKey', repeat('3d', 32)
  ));
  perform public.night_flock_commitment_command(member_user_id, jsonb_build_object(
    'schemaVersion', 2, 'command', 'acceptGoal', 'challengeID', challenge_id, 'idempotencyKey', repeat('3e', 32)
  ));
  perform public.night_flock_commitment_command(owner_id, jsonb_build_object(
    'schemaVersion', 2, 'command', 'setLocalSetup', 'challengeID', challenge_id,
    'setupReady', true, 'shieldingEvidence', 'notRequested', 'idempotencyKey', repeat('3f', 32)
  ));
  perform public.night_flock_commitment_command(member_user_id, jsonb_build_object(
    'schemaVersion', 2, 'command', 'setLocalSetup', 'challengeID', challenge_id,
    'setupReady', true, 'shieldingEvidence', 'observed', 'idempotencyKey', repeat('40', 32)
  ));
  perform public.night_flock_commitment_command(owner_id, jsonb_build_object(
    'schemaVersion', 2, 'command', 'startChallenge', 'challengeID', challenge_id, 'idempotencyKey', repeat('41', 32)
  ));

  begin
    perform public.night_flock_social_command(outsider_id, jsonb_build_object(
      'schemaVersion', 3, 'command', 'publishNightMetrics', 'challengeID', challenge_id,
      'day', 1, 'status', 'morningQuietCompleted', 'shieldingEvidence', 'observed',
      'windDownMinutes', 40, 'phoneAwayMinutes', 0, 'sleepDurationMinutes', null,
      'restfulness', null, 'idempotencyKey', repeat('42', 32)
    ));
    raise exception 'non-member published metrics';
  exception when others then
    if sqlerrm = 'non-member published metrics' then raise; end if;
  end;

  begin
    perform public.night_flock_social_state(outsider_id);
  exception when others then
    null;
  end;
  if public.night_flock_social_state(outsider_id) is not null then
    raise exception 'outsider read group metrics';
  end if;

  perform public.night_flock_social_command(member_user_id, jsonb_build_object(
    'schemaVersion', 3, 'command', 'setSharingPreferences',
    'shareGoalProgress', true, 'shareWindDownCompletion', true, 'shareWindDownMinutes', true,
    'sharePhoneAwayMinutes', true, 'sharePhoneTuckedAway', true, 'shareShieldingStatus', true,
    'shareRoutineIdeas', false, 'shareSleepDuration', true, 'shareRestfulness', true,
    'idempotencyKey', repeat('43', 32)
  ));
  perform public.night_flock_social_command(member_user_id, jsonb_build_object(
    'schemaVersion', 3, 'command', 'publishNightMetrics', 'challengeID', challenge_id,
    'day', 1, 'status', 'morningQuietCompleted', 'shieldingEvidence', 'observed',
    'windDownMinutes', 40, 'phoneAwayMinutes', 10, 'sleepDurationMinutes', 480,
    'restfulness', 'rested', 'idempotencyKey', repeat('44', 32)
  ));
  perform public.night_flock_social_command(member_user_id, jsonb_build_object(
    'schemaVersion', 3, 'command', 'publishNightMetrics', 'challengeID', challenge_id,
    'day', 1, 'status', 'morningQuietCompleted', 'shieldingEvidence', 'observed',
    'windDownMinutes', 40, 'phoneAwayMinutes', 10, 'sleepDurationMinutes', 480,
    'restfulness', 'rested', 'idempotencyKey', repeat('45', 32)
  ));
  select count(*) into grant_count from public.night_flock_reward_grants
  where member_id = member_member and milestone = 'qualifyingNight:1';
  if grant_count <> 1 then raise exception 'progress replay duplicated a reward'; end if;
  if (select count(*) from public.night_flock_shared_metrics
      where member_id = owner_member) <> 0 then
    raise exception 'member published metrics for another member';
  end if;

  result := public.night_flock_social_state(member_user_id);
  if coalesce(result -> 'days' -> 0 -> 'memberProgress', '[]'::jsonb)::text not like '%480%' then
    raise exception 'opted-in sleep minutes were not projected';
  end if;
  perform public.night_flock_social_command(member_user_id, jsonb_build_object(
    'schemaVersion', 3, 'command', 'setSharingPreferences',
    'shareGoalProgress', true, 'shareWindDownCompletion', true, 'shareWindDownMinutes', true,
    'sharePhoneAwayMinutes', true, 'sharePhoneTuckedAway', true, 'shareShieldingStatus', true,
    'shareRoutineIdeas', false, 'shareSleepDuration', false, 'shareRestfulness', false,
    'idempotencyKey', repeat('46', 32)
  ));
  result := public.night_flock_social_state(owner_id);
  if (result -> 'days' -> 0 -> 'memberProgress')::text like '%480%' then
    raise exception 'disabled sleep sharing still projected sleep minutes';
  end if;
  if result::text ~* 'selectedApps|applicationTokens|healthKit' then
    raise exception 'schema-three projection exposed local tokens';
  end if;

  perform public.night_flock_social_command(member_user_id, jsonb_build_object(
    'schemaVersion', 3, 'command', 'setSharingPreferences',
    'shareGoalProgress', true, 'shareWindDownCompletion', false, 'shareWindDownMinutes', true,
    'sharePhoneAwayMinutes', true, 'sharePhoneTuckedAway', true, 'shareShieldingStatus', true,
    'shareRoutineIdeas', false, 'shareSleepDuration', false, 'shareRestfulness', false,
    'idempotencyKey', repeat('47', 32)
  ));
  result := public.night_flock_social_state(owner_id);
  if (result -> 'days' -> 0 -> 'memberProgress')::text like '%morningQuietCompleted%' then
    raise exception 'completion remained visible after it was turned off';
  end if;
  if (result -> 'days' -> 0 -> 'memberProgress')::text not like '%phoneTuckedAway%' then
    raise exception 'hidden completion did not fall back to tucked away';
  end if;

  if coalesce(result -> 'days' -> 0 -> 'pasture' -> 0 ->> 'id', '') <> '' then
    perform public.night_flock_command(owner_id, jsonb_build_object(
      'command', 'react',
      'checkInID', result -> 'days' -> 0 -> 'pasture' -> 0 ->> 'id',
      'reaction', 'pawPrint',
      'idempotencyKey', repeat('48', 32)
    ));
  end if;
  if (select count(*) from public.night_flock_reward_grants where milestone like 'reaction%') <> 0 then
    raise exception 'reactions produced rewards';
  end if;

  begin
    perform public.night_flock_social_command(member_user_id, jsonb_build_object(
      'schemaVersion', 3, 'command', 'publishNightMetrics', 'challengeID', challenge_id,
      'day', 1, 'status', 'morningQuietCompleted', 'shieldingEvidence', 'observed',
      'windDownMinutes', 400, 'phoneAwayMinutes', 0, 'sleepDurationMinutes', null,
      'restfulness', null, 'idempotencyKey', repeat('49', 32)
    ));
    raise exception 'out-of-bounds minutes were accepted';
  exception when others then
    if sqlerrm = 'out-of-bounds minutes were accepted' then raise; end if;
  end;

  result := public.night_flock_social_state(member_user_id);
  perform public.night_flock_social_command(member_user_id, jsonb_build_object(
    'schemaVersion', 3, 'command', 'acknowledgeGrant',
    'grantID', result -> 'pendingGrants' -> 0 ->> 'id',
    'idempotencyKey', repeat('4a', 32)
  ));
  if (select claimed_at is null from public.night_flock_reward_grants
      where member_id = member_member and milestone = 'qualifyingNight:1') then
    raise exception 'acknowledged grant was not claimed';
  end if;
  if jsonb_array_length(coalesce(public.night_flock_social_state(member_user_id) -> 'pendingGrants', '[]'::jsonb)) <> 0 then
    raise exception 'claimed grant remained pending';
  end if;

  perform public.night_flock_social_command(owner_id, jsonb_build_object(
    'schemaVersion', 3, 'command', 'publishNightMetrics', 'challengeID', challenge_id,
    'day', 1, 'status', 'morningQuietCompleted', 'shieldingEvidence', 'observed',
    'windDownMinutes', 40, 'phoneAwayMinutes', 0, 'sleepDurationMinutes', null,
    'restfulness', null, 'idempotencyKey', repeat('4b', 32)
  ));
  for day_number in 2..4 loop
    perform public.night_flock_social_command(member_user_id, jsonb_build_object(
      'schemaVersion', 3, 'command', 'publishNightMetrics', 'challengeID', challenge_id,
      'day', day_number, 'status', 'morningQuietCompleted', 'shieldingEvidence', 'observed',
      'windDownMinutes', 40, 'phoneAwayMinutes', 0, 'sleepDurationMinutes', null,
      'restfulness', null, 'idempotencyKey', repeat('5' || day_number::text, 32)
    ));
    perform public.night_flock_social_command(owner_id, jsonb_build_object(
      'schemaVersion', 3, 'command', 'publishNightMetrics', 'challengeID', challenge_id,
      'day', day_number, 'status', 'morningQuietCompleted', 'shieldingEvidence', 'observed',
      'windDownMinutes', 40, 'phoneAwayMinutes', 0, 'sleepDurationMinutes', null,
      'restfulness', null, 'idempotencyKey', repeat('6' || day_number::text, 32)
    ));
  end loop;
  update public.night_flock_challenges
    set status = 'completed', completed_at = now()
    where id = challenge_id;
  perform public.night_flock_social_command(member_user_id, jsonb_build_object(
    'schemaVersion', 3, 'command', 'publishNightMetrics', 'challengeID', challenge_id,
    'day', 4, 'status', 'morningQuietCompleted', 'shieldingEvidence', 'observed',
    'windDownMinutes', 40, 'phoneAwayMinutes', 0, 'sleepDurationMinutes', null,
    'restfulness', null, 'idempotencyKey', repeat('4c', 32)
  ));
  perform public.night_flock_social_command(owner_id, jsonb_build_object(
    'schemaVersion', 3, 'command', 'publishNightMetrics', 'challengeID', challenge_id,
    'day', 4, 'status', 'morningQuietCompleted', 'shieldingEvidence', 'observed',
    'windDownMinutes', 40, 'phoneAwayMinutes', 0, 'sleepDurationMinutes', null,
    'restfulness', null, 'idempotencyKey', repeat('4f', 32)
  ));
  if not exists (
    select 1 from public.night_flock_reward_grants
    where member_id = member_member and milestone = 'sevenNightCompletion'
  ) then raise exception 'seven-night grant was not created'; end if;
  if not exists (
    select 1 from public.night_flock_reward_grants
    where member_id = member_member and milestone = 'groupCompletion'
  ) then raise exception 'group completion grant was not created'; end if;
  if not exists (
    select 1 from public.night_flock_reward_grants
    where member_id = owner_member and milestone = 'sevenNightCompletion'
  ) then raise exception 'host seven-night grant was not created'; end if;

  insert into public.night_flock_shared_metrics (
    challenge_id, member_id, challenge_day, status, wind_down_minutes, created_at, updated_at
  ) values (
    challenge_id, owner_member, 7, 'morningQuietCompleted', 40,
    now() - interval '91 days', now() - interval '91 days'
  );
  insert into public.night_flock_reward_grants (
    challenge_id, member_id, milestone, reward_kind, wool_amount, created_at
  ) values (
    challenge_id, owner_member, 'qualifyingNight:7', 'wool', 1, now() - interval '13 months'
  );
  perform public.purge_night_flock_retention(now());
  if exists (
    select 1 from public.night_flock_shared_metrics
    where member_id = owner_member and challenge_day = 7
  ) then raise exception '90-day metrics retention did not purge'; end if;
  if exists (
    select 1 from public.night_flock_reward_grants
    where member_id = owner_member and milestone = 'qualifyingNight:7'
  ) then raise exception '12-month grant retention did not purge'; end if;

  perform public.night_flock_command(member_user_id, jsonb_build_object(
    'command', 'leave', 'idempotencyKey', repeat('4d', 32)
  ));
  result := public.night_flock_social_state(owner_id);
  if result::text like '%' || member_member::text || '%' then
    raise exception 'left member still appeared in social projection';
  end if;

  perform private.delete_night_flock_user_data(member_user_id);
  if exists (
    select 1 from public.night_flock_shared_metrics where member_id = member_member
  ) then raise exception 'deleted account kept shared metrics'; end if;
  if exists (
    select 1 from public.night_flock_reward_grants where member_id = member_member
  ) then raise exception 'deleted account kept reward grants'; end if;
end;
$$;

do $$
declare
  owner_id uuid := '10000000-0000-4000-8000-000000000001';
  member_id uuid := '10000000-0000-4000-8000-000000000002';
  created_flock_id uuid;
  first_id uuid := '70000000-0000-4000-8000-000000000001';
  second_id uuid := '70000000-0000-4000-8000-000000000002';
  stale_id uuid := '70000000-0000-4000-8000-000000000003';
  rogue_id uuid := '70000000-0000-4000-8000-000000000006';
  third_id uuid := '70000000-0000-4000-8000-000000000004';
  fourth_id uuid := '70000000-0000-4000-8000-000000000005';
  first_code text := 'ABCD23456789';
  second_code text := 'BCDE3456789A';
  moderation_action text;
  create_candidate uuid;
  replace_candidate uuid;
  invite_count_before integer;
  result jsonb;
begin
  if has_function_privilege(
      'service_role',
      'private.night_flock_commitment_snapshot_before_invite_recovery(uuid)',
      'EXECUTE'
    ) then
    raise exception 'service role can execute renamed snapshot backup';
  end if;
  if has_function_privilege(
      'service_role',
      'public.night_flock_commitment_command_before_invite_recovery(uuid,jsonb)',
      'EXECUTE'
    ) then
    raise exception 'service role can bypass invite recovery through renamed command backup';
  end if;
  if not has_function_privilege(
      'service_role', 'public.night_flock_commitment_command(uuid,jsonb)', 'EXECUTE'
    ) or not has_function_privilege(
      'service_role', 'public.night_flock_commitment_state(uuid)', 'EXECUTE'
    ) then
    raise exception 'service role cannot execute current commitment wrapper and state';
  end if;
  perform private.delete_night_flock_user_data(owner_id);
  perform private.delete_night_flock_user_data(member_id);
  result := public.night_flock_commitment_command(owner_id, jsonb_build_object(
    'command', 'createParty', 'goalKind', 'phoneAway', 'targetMinutes', null,
    'appDisplayName', null, 'identity', 'moonlitMeadow', 'timeZoneIdentifier', 'UTC',
    'idempotencyKey', repeat('7a', 32)
  ));
  created_flock_id := (result -> 'snapshot' ->> 'flockID')::uuid;
  if public.night_flock_commitment_state(owner_id) ? 'activeInvite' then
    raise exception 'no-invite projection contained active invite metadata';
  end if;
  if public.night_flock_social_state(owner_id) ? 'activeInvite' then
    raise exception 'schema-three no-invite projection contained active invite metadata';
  end if;

  result := public.night_flock_commitment_command(owner_id, jsonb_build_object(
    'command', 'createInvite', 'inviteID', first_id,
    'inviteDigest', encode(extensions.digest(first_code, 'sha256'), 'hex'),
    'idempotencyKey', repeat('7b', 32)
  ));
  if result ? 'inviteCode' and result ->> 'inviteCode' is not null then
    raise exception 'recoverable invite returned plaintext';
  end if;
  if not exists (select 1 from public.night_flock_invites where id = first_id
      and token_hash = extensions.digest(first_code, 'sha256')) then
    raise exception 'recoverable invite did not store only its digest';
  end if;
  if not (public.night_flock_commitment_state(owner_id) ? 'activeInvite') then
    raise exception 'keeper projection omitted active invite metadata';
  end if;
  if not (public.night_flock_social_state(owner_id) ? 'activeInvite') then
    raise exception 'schema-three keeper projection dropped eligible active invite metadata';
  end if;
  perform public.night_flock_commitment_command(owner_id, jsonb_build_object(
    'command', 'createInvite', 'inviteID', first_id,
    'inviteDigest', encode(extensions.digest(first_code, 'sha256'), 'hex'),
    'idempotencyKey', repeat('7b', 32)
  ));
  if (select count(*) from public.night_flock_invites invite where invite.flock_id = created_flock_id) <> 1 then
    raise exception 'identical recoverable invite replay inserted another row';
  end if;

  foreach moderation_action in array array['socialSuspension', 'accountSuspension', 'accountDeletion'] loop
    create_candidate := gen_random_uuid();
    replace_candidate := gen_random_uuid();
    select count(*) into invite_count_before from public.night_flock_invites
      where flock_id = created_flock_id;
    insert into public.night_flock_moderation_actions (
      target_user_id, action, reason, expires_at
    ) values (
      owner_id, moderation_action, 'invite recovery policy parity test', now() + interval '1 hour'
    );

    begin
      perform public.night_flock_commitment_command(owner_id, jsonb_build_object(
        'command', 'createInvite', 'inviteID', create_candidate,
        'inviteDigest', repeat('c', 64),
        'idempotencyKey', encode(extensions.digest(create_candidate::text, 'sha256'), 'hex')
      ));
      raise exception 'moderated digest create was accepted for %', moderation_action;
    exception when sqlstate '42501' then
      if sqlerrm <> 'Slumber Party unavailable for this account' then raise; end if;
    end;

    begin
      perform public.night_flock_commitment_command(owner_id, jsonb_build_object(
        'command', 'replaceInvite', 'expectedInviteID', first_id,
        'inviteID', replace_candidate, 'inviteDigest', repeat('d', 64),
        'idempotencyKey', encode(extensions.digest(replace_candidate::text, 'sha256'), 'hex')
      ));
      raise exception 'moderated digest replacement was accepted for %', moderation_action;
    exception when sqlstate '42501' then
      if sqlerrm <> 'Slumber Party unavailable for this account' then raise; end if;
    end;

    if (select count(*) from public.night_flock_invites where flock_id = created_flock_id) <> invite_count_before
       or exists (select 1 from public.night_flock_invites where id in (create_candidate, replace_candidate))
       or not exists (
         select 1 from public.night_flock_invites where id = first_id
           and revoked_at is null
           and token_hash = extensions.digest(first_code, 'sha256')
       ) then
      raise exception 'moderation rejection mutated invitations for %', moderation_action;
    end if;
    delete from public.night_flock_moderation_actions
      where target_user_id = owner_id and action = moderation_action
        and reason = 'invite recovery policy parity test';
  end loop;

  insert into public.night_flock_moderation_actions (
    target_user_id, action, reason, expires_at
  ) values (
    owner_id, 'socialSuspension', 'expired invite recovery policy parity test',
    now() - interval '1 second'
  );
  perform public.night_flock_commitment_command(owner_id, jsonb_build_object(
    'command', 'createInvite', 'inviteID', first_id,
    'inviteDigest', encode(extensions.digest(first_code, 'sha256'), 'hex'),
    'idempotencyKey', repeat('7b', 32)
  ));
  delete from public.night_flock_moderation_actions
    where target_user_id = owner_id and reason = 'expired invite recovery policy parity test';

  insert into public.night_flock_invites (
    id, flock_id, created_by_member_id, token_hash, idempotency_key, expires_at
  ) select rogue_id, created_flock_id, member.id, decode(repeat('f', 64), 'hex'),
      repeat('6f', 32), now() + interval '7 days'
    from public.night_flock_members member
    where member.user_id = owner_id and member.flock_id = created_flock_id and member.status = 'active';
  begin
    perform public.night_flock_commitment_command(owner_id, jsonb_build_object(
      'command', 'createInvite', 'inviteID', stale_id,
      'inviteDigest', repeat('c', 64), 'idempotencyKey', repeat('7c', 32)
    ));
    raise exception 'conflicting invite create was accepted';
  exception when raise_exception then
    if sqlerrm <> 'active_invite_exists' then raise; end if;
  end;

  begin
    perform public.night_flock_commitment_command(owner_id, jsonb_build_object(
      'command', 'replaceInvite', 'expectedInviteID', stale_id, 'inviteID', gen_random_uuid(),
      'inviteDigest', repeat('e', 64), 'idempotencyKey', repeat('7e', 32)
    ));
    raise exception 'stale replacement was accepted';
  exception when raise_exception then
    if sqlerrm <> 'active_invite_exists' then raise; end if;
  end;
  if (select count(*) from public.night_flock_invites invite
      where invite.flock_id = created_flock_id and invite.revoked_at is null
        and invite.expires_at > now() and invite.redeemed_at is null) <> 2 then
    raise exception 'stale replacement changed the deliberately duplicated active set';
  end if;

  perform public.night_flock_commitment_command(owner_id, jsonb_build_object(
    'command', 'replaceInvite', 'expectedInviteID', first_id, 'inviteID', second_id,
    'inviteDigest', encode(extensions.digest(second_code, 'sha256'), 'hex'),
    'idempotencyKey', repeat('7d', 32)
  ));
  perform public.night_flock_commitment_command(owner_id, jsonb_build_object(
    'command', 'replaceInvite', 'expectedInviteID', first_id, 'inviteID', second_id,
    'inviteDigest', encode(extensions.digest(second_code, 'sha256'), 'hex'),
    'idempotencyKey', repeat('7d', 32)
  ));
  if not exists (select 1 from public.night_flock_invites where id = first_id and revoked_at is not null)
     or not exists (select 1 from public.night_flock_invites where id = rogue_id and revoked_at is not null)
     or (select count(*) from public.night_flock_invites invite
          where invite.flock_id = created_flock_id and invite.revoked_at is null
            and invite.expires_at > now() and invite.redeemed_at is null) <> 1
     or (select count(*) from public.night_flock_invites where id = second_id and revoked_at is null) <> 1 then
    raise exception 'replacement did not revoke the full active set atomically';
  end if;

  perform public.night_flock_commitment_command(member_id, jsonb_build_object(
    'command', 'redeemInvite', 'shortCode', second_code, 'idempotencyKey', repeat('7f', 32)
  ));
  if public.night_flock_commitment_state(member_id) ? 'activeInvite' then
    raise exception 'non-host projection exposed active invite metadata';
  end if;
  if public.night_flock_social_state(member_id) ? 'activeInvite' then
    raise exception 'schema-three non-host projection exposed active invite metadata';
  end if;
  update public.night_flock_invites set revoked_at = now() where id = second_id;
  if public.night_flock_commitment_state(owner_id) ? 'activeInvite' then
    raise exception 'revoked invite remained in host metadata';
  end if;
  result := public.night_flock_commitment_command(owner_id, jsonb_build_object(
    'command', 'createInvite', 'idempotencyKey', repeat('8a', 32)
  ));
  if result ->> 'inviteCode' !~ '^[A-HJ-NP-Z2-9]{12}$' then
    raise exception 'mixed-version legacy create did not preserve its plaintext response';
  end if;
  begin
    perform public.night_flock_commitment_command(owner_id, jsonb_build_object(
      'command', 'createInvite', 'inviteID', gen_random_uuid(), 'inviteDigest', repeat('c', 64),
      'idempotencyKey', repeat('8d', 32)
    ));
    raise exception 'new create raced past a legacy active invitation';
  exception when raise_exception then
    if sqlerrm <> 'active_invite_exists' then raise; end if;
  end;
  perform public.night_flock_commitment_command(owner_id, jsonb_build_object(
    'command', 'replaceInvite', 'expectedInviteID', (result ->> 'inviteID')::uuid,
    'inviteID', third_id, 'inviteDigest', repeat('a', 64), 'idempotencyKey', repeat('8c', 32)
  ));
  update public.night_flock_invites set expires_at = now() - interval '1 second' where id = third_id;
  if public.night_flock_commitment_state(owner_id) ? 'activeInvite' then
    raise exception 'expired invite remained in host metadata';
  end if;
  perform public.night_flock_commitment_command(owner_id, jsonb_build_object(
    'command', 'createInvite', 'inviteID', fourth_id, 'inviteDigest', repeat('b', 64),
    'idempotencyKey', repeat('8b', 32)
  ));
  update public.night_flock_challenges set status = 'active' where flock_id = created_flock_id;
  if public.night_flock_commitment_state(owner_id) ? 'activeInvite' then
    raise exception 'started lobby exposed active invite metadata';
  end if;
  if public.night_flock_social_state(owner_id) ? 'activeInvite' then
    raise exception 'schema-three started lobby exposed active invite metadata';
  end if;
end;
$$;

rollback;
