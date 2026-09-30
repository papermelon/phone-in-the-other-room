-- The Edge gate checks only the sheep name chosen for a party visit. Never
-- expose the private Farm payload or trust a caller-supplied replacement name.
create function public.shared_text_sheep_name(p_user_id uuid, p_command jsonb) returns text
language plpgsql stable security definer set search_path='' as $$
declare animal jsonb;
begin
  if not private.is_apple_linked_night_flock_user(p_user_id) then raise exception 'linked_account_required'; end if;
  if p_command->>'command' is distinct from 'contributePastureSheep' or not exists (
    select 1 from private.night_flock_v4_memberships m
    join private.night_flock_v4_membership_epochs e on e.membership_id=m.id and e.ended_at is null
    where m.user_id=p_user_id and m.party_id=(p_command->>'partyID')::uuid and m.status='active'
      and e.id=(p_command->>'memberEpochID')::uuid
  ) then raise exception 'current_membership_required'; end if;
  animal:=private.shared_pasture_owned_sheep(p_user_id,(p_command->>'sheepID')::uuid);
  if animal is null then raise exception 'pasture_sheep_not_owned'; end if;
  return trim(animal->>'displayName');
end $$;
revoke all on function public.shared_text_sheep_name(uuid,jsonb) from public, anon, authenticated;
grant execute on function public.shared_text_sheep_name(uuid,jsonb) to service_role;

alter function private.night_flock_v4_apply(uuid,jsonb) rename to night_flock_v4_apply_before_shared_text;
create function private.night_flock_v4_apply(u uuid,c jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare current_name text;
begin
  if c->>'command'='contributePastureSheep' and c ? 'moderatedSheepName' then
    -- Lock the same Farm head used by the existing contribution transaction.
    -- A rename while the external check was running must not publish new text.
    perform 1 from private.farm_save_heads where user_id=u for update;
    current_name:=public.shared_text_sheep_name(u,c);
    if c->>'moderatedSheepName' is distinct from current_name then raise exception 'shared_text_unavailable'; end if;
  end if;
  return private.night_flock_v4_apply_before_shared_text(u,c-'moderatedSheepName');
end $$;
revoke all on function private.night_flock_v4_apply(uuid,jsonb),private.night_flock_v4_apply_before_shared_text(uuid,jsonb)
  from public,anon,authenticated;

-- Keep the original client idempotency hash across old receipts and the
-- server-only name binding. The binding is revalidated on every new write.
create or replace function public.night_flock_v4_command(p_user_id uuid,p_command jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u alias for $1; c alias for $2; k text:=lower(c->>'idempotencyKey');
  h bytea:=extensions.digest((c-'inviteDigest'-'inviteCiphertext'-'inviteNonce'-'inviteKeyVersion'-'moderatedSheepName')::text,'sha256');
  saved private.night_flock_v4_idempotency%rowtype; answer jsonb;
begin
  -- Retain service-only SQL harness compatibility; Edge always requires a key.
  if k is null then return private.night_flock_v4_apply(u,c); end if;
  if k!~'^[0-9a-f]{64}$' then raise exception 'Invalid idempotencyKey'; end if;
  perform pg_advisory_xact_lock(hashtextextended(u::text,0));
  select * into saved from private.night_flock_v4_idempotency where user_id=u and idempotency_key=k;
  if saved.user_id is not null then
    if saved.payload_hash<>h then raise exception 'idempotency_key_reused'; end if;
    return saved.response;
  end if;
  answer:=private.night_flock_v4_apply(u,c);
  insert into private.night_flock_v4_idempotency(user_id,idempotency_key,command_name,payload_hash,response)
    values(u,k,c->>'command',h,answer);
  return answer;
end $$;

create function public.shared_text_moderation_admission(p_user_id uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
  if not private.is_apple_linked_night_flock_user(p_user_id) then raise exception 'linked_account_required'; end if;
  perform private.global_campfire_rate(p_user_id,'sharedText',30,'minute');
end $$;
revoke all on function public.shared_text_moderation_admission(uuid) from public,anon,authenticated;
grant execute on function public.shared_text_moderation_admission(uuid) to service_role;
