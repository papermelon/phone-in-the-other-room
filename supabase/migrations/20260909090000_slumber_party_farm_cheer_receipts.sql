-- Additive public appearance and participant-only app-delivery receipts.
-- No private Farm document, read timestamp, reward or membership system is added.
alter table private.night_flock_v4_profiles add column head_shape_id text
  check (head_shape_id in ('pear','round','boxy','triangular'));
alter function private.night_flock_v4_profile_json(private.night_flock_v4_profiles)
  rename to night_flock_v4_profile_json_before_head_shape;
create function private.night_flock_v4_profile_json(pr private.night_flock_v4_profiles)
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_set(private.night_flock_v4_profile_json_before_head_shape(pr),
    '{presentation,headShapeID}',coalesce(to_jsonb(pr.head_shape_id),'null'::jsonb))
$$;

create table private.night_flock_v4_cheer_app_receipts (
  reaction_id uuid primary key,
  membership_reaction_id uuid unique references private.night_flock_v4_membership_stream_reactions(id) on delete cascade,
  round_reaction_id uuid unique references public.night_flock_v4_reactions(id) on delete cascade,
  live_reaction_id uuid unique references private.night_flock_v4_membership_stream_live_reactions(id) on delete cascade,
  received_at timestamptz not null default now(),
  check(num_nonnulls(membership_reaction_id,round_reaction_id,live_reaction_id)=1),
  check(reaction_id=coalesce(membership_reaction_id,round_reaction_id,live_reaction_id))
);
revoke all on private.night_flock_v4_cheer_app_receipts from public,anon,authenticated,service_role;

-- Normalize already-published reactions to their original shared update. Both
-- participants must still belong to their current epoch; blocked pairs disappear.
create function private.night_flock_v4_update_cheers(u uuid, p uuid)
returns table(reaction_id uuid, source text, activity_id uuid, sender_id uuid,
  recipient_id uuid, cheer text, accepted_at timestamptz, received_at timestamptz)
language sql stable security definer set search_path='' as $$
 with candidates as (
   select r.id, 'membership'::text source, a.id activity_id, r.reactor_member_id sender_id,
     a.member_id recipient_id,r.reaction,r.created_at,a.party_id,a.occurred_at,
     a.member_epoch_id target_epoch,r.reactor_epoch_id sender_epoch
   from private.night_flock_v4_membership_stream_reactions r
   join private.night_flock_v4_membership_stream_activities a on a.id=r.activity_id
   union all
   select r.id,'live',a.id,r.reactor_member_id,a.member_id,r.reaction,r.created_at,
     a.party_id,a.occurred_at,a.member_epoch_id,r.reactor_epoch_id
   from private.night_flock_v4_membership_stream_live_reactions r
   join private.night_flock_v4_membership_stream_statuses s on s.id=r.status_id
   join private.night_flock_v4_membership_stream_activities a
     on a.party_id=s.party_id and a.member_epoch_id=s.member_epoch_id and a.source_event_id=s.source_event_id
   union all
   select r.id,'round',coalesce(a.id,ra.id),r.member_id,ra.member_id,r.reaction,r.created_at,
     ra.party_id,l.ended_at,a.member_epoch_id,null::uuid
   from public.night_flock_v4_reactions r
   join public.night_flock_v4_party_activities ra on ra.id=r.party_activity_id
   join private.night_flock_v4_activity_ledger l on l.id=ra.ledger_id
   left join private.night_flock_v4_membership_stream_activities a
     on a.party_id=ra.party_id and a.member_id=ra.member_id and a.source_event_id=l.source_event_id
 ), eligible as (
   select c.* from candidates c
   join private.night_flock_v4_parties party on party.id=c.party_id and party.deleted_at is null
   join private.night_flock_v4_memberships sender on sender.id=c.sender_id and sender.status='active'
   join private.night_flock_v4_memberships recipient on recipient.id=c.recipient_id and recipient.status='active'
   join private.night_flock_v4_membership_epochs se on se.membership_id=sender.id and se.ended_at is null
   join private.night_flock_v4_membership_epochs te on te.membership_id=recipient.id and te.ended_at is null
   where c.party_id=p and u in(sender.user_id,recipient.user_id)
     and c.sender_id<>c.recipient_id and not private.night_flock_users_blocked(sender.user_id,recipient.user_id)
     and c.occurred_at>=now()-interval '90 days' and c.occurred_at>=te.joined_at
     and c.created_at>=se.joined_at
     and (c.target_epoch is null or c.target_epoch=te.id)
     and (c.sender_epoch is null or c.sender_epoch=se.id)
 )
 select e.id,e.source,e.activity_id,e.sender_id,e.recipient_id,e.reaction,e.created_at,ack.received_at
 from eligible e left join private.night_flock_v4_cheer_app_receipts ack on ack.reaction_id=e.id
$$;

alter function private.night_flock_v4_apply(uuid,jsonb) rename to night_flock_v4_apply_before_farm_cheers;
create function private.night_flock_v4_apply(u uuid,c jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
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
$$;

alter function public.night_flock_v4_state(uuid,text,uuid,text) rename to night_flock_v4_state_before_farm_cheers;
create function public.night_flock_v4_state(p_user_id uuid,p_scope text default 'list',p_party_id uuid default null,p_cursor text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
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
$$;
revoke all on function private.night_flock_v4_profile_json_before_head_shape(private.night_flock_v4_profiles),
 private.night_flock_v4_profile_json(private.night_flock_v4_profiles),
 private.night_flock_v4_update_cheers(uuid,uuid),private.night_flock_v4_apply(uuid,jsonb),
 private.night_flock_v4_apply_before_farm_cheers(uuid,jsonb),
 public.night_flock_v4_state_before_farm_cheers(uuid,text,uuid,text)
 from public,anon,authenticated,service_role;
revoke all on function public.night_flock_v4_state(uuid,text,uuid,text) from public,anon,authenticated;
grant execute on function public.night_flock_v4_state(uuid,text,uuid,text) to service_role;
