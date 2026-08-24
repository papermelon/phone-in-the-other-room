-- Recoverable schema-two invitations. Plaintext codes are generated and kept
-- only by the client; the database receives a UUID and SHA-256 digest.
alter function private.night_flock_commitment_snapshot(uuid)
  rename to night_flock_commitment_snapshot_before_invite_recovery;

create or replace function private.night_flock_commitment_snapshot(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  base jsonb := private.night_flock_commitment_snapshot_before_invite_recovery(p_user_id);
  membership public.night_flock_members%rowtype;
  active_invite jsonb;
begin
  if base is null then return null; end if;
  select * into membership from public.night_flock_members
    where user_id = p_user_id and status = 'active' limit 1;
  if membership.role = 'keeper' and base -> 'challenge' ->> 'status' = 'pending' then
    select jsonb_build_object('id', invite.id, 'expiresAt', invite.expires_at)
      into active_invite
      from public.night_flock_invites invite
      where invite.flock_id = membership.flock_id
        and invite.revoked_at is null and invite.expires_at > now() and invite.redeemed_at is null
      order by invite.created_at desc limit 1;
  end if;
  if membership.role = 'keeper'
     and base -> 'challenge' ->> 'status' = 'pending'
     and active_invite is not null then
    return base || jsonb_build_object('activeInvite', active_invite);
  end if;
  return base;
end;
$$;

alter function public.night_flock_commitment_command(uuid, jsonb)
  rename to night_flock_commitment_command_before_invite_recovery;

create or replace function public.night_flock_commitment_command(p_user_id uuid, p_command jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  command_name text := p_command ->> 'command';
  membership public.night_flock_members%rowtype;
  existing public.night_flock_invites%rowtype;
  expected public.night_flock_invites%rowtype;
  candidate_id uuid;
  candidate_digest bytea;
  key_value text := lower(p_command ->> 'idempotencyKey');
begin
  if command_name not in ('createInvite', 'replaceInvite') then
    return public.night_flock_commitment_command_before_invite_recovery(p_user_id, p_command);
  end if;
  if p_user_id is null or not private.is_apple_linked_night_flock_user(p_user_id) then
    raise exception 'Apple-linked account required' using errcode = '28000';
  end if;
  if exists (select 1 from public.night_flock_moderation_actions where target_user_id = p_user_id
    and action in ('socialSuspension', 'accountSuspension', 'accountDeletion')
    and (expires_at is null or expires_at > now())) then
    raise exception 'Slumber Party unavailable for this account' using errcode = '42501';
  end if;
  select * into membership from public.night_flock_members
    where user_id = p_user_id and status = 'active' limit 1;
  if membership.id is null or membership.role <> 'keeper' then
    raise exception 'Host permission required' using errcode = '42501';
  end if;
  if not exists (select 1 from public.night_flock_challenges
      where flock_id = membership.flock_id and status = 'pending') then
    raise exception 'Invitations close when the seven nights begin' using errcode = 'P0001';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(membership.flock_id::text, 0));
  if command_name = 'createInvite' and not (p_command ? 'inviteID') then
    return public.night_flock_commitment_command_before_invite_recovery(p_user_id, p_command);
  end if;

  candidate_id := (p_command ->> 'inviteID')::uuid;
  candidate_digest := decode(lower(p_command ->> 'inviteDigest'), 'hex');

  select * into existing from public.night_flock_invites
    where id = candidate_id and flock_id = membership.flock_id;
  if existing.id is not null then
    if existing.created_by_member_id = membership.id
       and existing.token_hash = candidate_digest
       and existing.idempotency_key = key_value then
      return jsonb_build_object('accepted', true, 'inviteCode', null, 'inviteID', existing.id,
        'snapshot', private.night_flock_commitment_snapshot(p_user_id));
    end if;
    raise exception 'active_invite_exists' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.night_flock_invites invite
      where invite.id = candidate_id or invite.idempotency_key = key_value
        or invite.token_hash = candidate_digest) then
    raise exception 'active_invite_exists' using errcode = 'P0001';
  end if;

  if command_name = 'replaceInvite' then
    select * into expected from public.night_flock_invites
      where id = (p_command ->> 'expectedInviteID')::uuid
        and flock_id = membership.flock_id and revoked_at is null and expires_at > now()
        and redeemed_at is null
      for update;
    if expected.id is null then
      raise exception 'active_invite_exists' using errcode = 'P0001';
    end if;
    update public.night_flock_invites
      set revoked_at = now()
      where flock_id = membership.flock_id
        and revoked_at is null and expires_at > now() and redeemed_at is null;
  elsif exists (select 1 from public.night_flock_invites
      where flock_id = membership.flock_id and revoked_at is null and expires_at > now()
        and redeemed_at is null) then
    raise exception 'active_invite_exists' using errcode = 'P0001';
  end if;

  insert into public.night_flock_invites (
    id, flock_id, created_by_member_id, token_hash, idempotency_key, expires_at
  ) values (
    candidate_id, membership.flock_id, membership.id, candidate_digest, key_value,
    now() + interval '7 days'
  ) returning * into existing;
  return jsonb_build_object('accepted', true, 'inviteCode', null, 'inviteID', existing.id,
    'snapshot', private.night_flock_commitment_snapshot(p_user_id));
end;
$$;

revoke all on function private.night_flock_commitment_snapshot_before_invite_recovery(uuid) from public, anon, authenticated;
revoke execute on function private.night_flock_commitment_snapshot_before_invite_recovery(uuid) from service_role;
revoke all on function private.night_flock_commitment_snapshot(uuid) from public, anon, authenticated;
revoke all on function public.night_flock_commitment_command_before_invite_recovery(uuid, jsonb) from public, anon, authenticated;
revoke execute on function public.night_flock_commitment_command_before_invite_recovery(uuid, jsonb) from service_role;
revoke all on function public.night_flock_commitment_command(uuid, jsonb) from public, anon, authenticated;
grant execute on function public.night_flock_commitment_command(uuid, jsonb) to service_role;
