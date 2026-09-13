CREATE OR REPLACE FUNCTION public.night_flock_v4_command(p_user_id uuid, p_command jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$declare u alias for $1;c alias for $2;k text:=lower(c->>'idempotencyKey');h bytea:=extensions.digest((c-'inviteDigest'-'inviteCiphertext'-'inviteNonce'-'inviteKeyVersion')::text,'sha256');saved private.night_flock_v4_idempotency%rowtype;out jsonb;begin
-- Edge validation requires the key. This branch is retained solely for the direct
-- service-role SQL harness; it is not reachable from the public HTTP contract.
if k is null then return private.night_flock_v4_apply(u,c);end if;
if k!~'^[0-9a-f]{64}$' then raise exception 'Invalid idempotencyKey';end if;perform pg_advisory_xact_lock(hashtextextended(u::text,0));select * into saved from private.night_flock_v4_idempotency where user_id=u and idempotency_key=k;if saved.user_id is not null then if saved.payload_hash<>h then raise exception 'idempotency_key_reused';end if;return saved.response;end if;out:=private.night_flock_v4_apply(u,c);insert into private.night_flock_v4_idempotency(user_id,idempotency_key,command_name,payload_hash,response) values(u,k,c->>'command',h,out);return out;end$function$


CREATE OR REPLACE FUNCTION private.night_flock_v4_apply(u uuid, c jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare result jsonb; before_revision int; pr private.night_flock_v4_profiles%rowtype; receipt record;
begin
 if c->>'command'='acknowledgeUpdateCheer' then
   if u is null or not private.is_apple_linked_night_flock_user(u) then raise exception 'Apple-linked account required'; end if;
   -- Serialize against leave/block, using the same party lock as existing commands.
   perform 1 from private.night_flock_v4_parties where id=(c->>'partyID')::uuid and deleted_at is null for update;
   select ch.* into receipt from private.night_flock_v4_update_cheers(u,(c->>'partyID')::uuid) ch
   join private.night_flock_v4_memberships m on m.id=ch.recipient_id and m.user_id=u
   where ch.reaction_id=(c->>'reactionID')::uuid;
   if receipt.reaction_id is null then raise exception 'invite_unavailable'; end if;
   insert into private.night_flock_v4_cheer_app_receipts(reaction_id,membership_reaction_id,round_reaction_id,live_reaction_id)
   values(receipt.reaction_id,case when receipt.source='membership' then receipt.reaction_id end,
     case when receipt.source='round' then receipt.reaction_id end,case when receipt.source='live' then receipt.reaction_id end)
   on conflict do nothing;
   if found then perform private.night_flock_v4_signal_party((c->>'partyID')::uuid); end if;
   return jsonb_build_object('accepted',true);
 end if;
 if c->>'command'='updatePublicProfile' and c ? 'headShapeID' then
   if c->>'headShapeID' is null or c->>'headShapeID' not in('pear','round','boxy','triangular') then raise exception 'Invalid headShapeID'; end if;
   select revision into before_revision from private.night_flock_v4_profiles where user_id=u for update;
   result:=private.night_flock_v4_apply_before_farm_cheers(u,c-'headShapeID');
   select * into pr from private.night_flock_v4_profiles where user_id=u for update;
   if pr.head_shape_id is distinct from c->>'headShapeID' then
     update private.night_flock_v4_profiles set head_shape_id=c->>'headShapeID',
       revision=revision+case when revision=coalesce(before_revision,0) then 1 else 0 end,updated_at=now()
     where user_id=u returning * into pr;
   end if;
   return (result-'profile')||jsonb_build_object('profile',private.night_flock_v4_profile_json(pr));
 end if;
 return private.night_flock_v4_apply_before_farm_cheers(u,c);
end
$function$


CREATE OR REPLACE FUNCTION public.night_flock_v4_state(p_user_id uuid, p_scope text DEFAULT 'list'::text, p_party_id uuid DEFAULT NULL::uuid, p_cursor text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare snapshot jsonb; receipts jsonb; member_updates jsonb;
begin
 snapshot:=public.night_flock_v4_state_before_farm_cheers(p_user_id,p_scope,p_party_id,p_cursor);
 if p_scope='list' then return snapshot||jsonb_build_object('profileHeadShapeVersion',1); end if;
 if p_scope<>'party' then return snapshot; end if;
 select coalesce(jsonb_agg(jsonb_build_object('reactionID',r.reaction_id,'activityID',r.activity_id,
   'senderMemberID',r.sender_id,'recipientMemberID',r.recipient_id,'cheer',r.cheer,
   'acceptedAt',r.accepted_at,'receivedByAppAt',r.received_at) order by r.accepted_at,r.reaction_id),'[]'::jsonb)
 into receipts from private.night_flock_v4_update_cheers(p_user_id,p_party_id) r;
 -- The global latest-100 feed must not hide a quieter member's newest moment
 -- or the original update behind a durable cheer. This projection stays bounded
 -- by current membership, the existing 90-day stream retention and reaction rows.
 with eligible as (
   select a.*,row_number() over(partition by a.member_id order by a.occurred_at desc,a.id) position
   from private.night_flock_v4_membership_stream_activities a
   join private.night_flock_v4_memberships m on m.id=a.member_id and m.status='active'
   join private.night_flock_v4_membership_epochs e on e.id=a.member_epoch_id and e.ended_at is null
   where a.party_id=p_party_id and a.occurred_at>=now()-interval '90 days'
     and not private.night_flock_users_blocked(p_user_id,m.user_id)
 )
 select coalesce(jsonb_agg(jsonb_build_object('activityID',a.id,'partyID',a.party_id,'memberID',a.member_id,
   'roundID',a.round_id,'day',a.activity_day,'kind',a.kind,'status',a.outcome,
   'roundedMinutes',greatest(0,least(case when a.kind='windDown' then 180 else 240 end,
     (round((case when a.kind='windDown' then a.wind_down_minutes else a.phone_away_minutes end)::numeric/5)*5)::int)),
   'occurredAt',a.occurred_at,'roundActivityID',(select ra.id from public.night_flock_v4_party_activities ra
     join private.night_flock_v4_activity_ledger l on l.id=ra.ledger_id
     where ra.party_id=a.party_id and ra.member_id=a.member_id and l.source_event_id=a.source_event_id
     order by ra.id limit 1)) order by a.occurred_at desc,a.id),'[]'::jsonb)
 into member_updates from eligible a where a.position=1
   or a.id in(select r.activity_id from private.night_flock_v4_update_cheers(p_user_id,p_party_id) r);
 return jsonb_set(snapshot,'{party}',(snapshot->'party')||jsonb_build_object('updateCheerReceiptVersion',1,'updateCheerReceipts',receipts,'memberUpdates',member_updates));
end
$function$
