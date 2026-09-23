-- Frozen bedtime for private Campfire presentation; no new agreement or event.
-- Deploy the additive night-flock-command validator before this capability.
alter table private.campfire_sessions add column intended_bedtime timestamptz;
alter table private.campfire_sessions add constraint campfire_bedtime_valid check (
 intended_bedtime is null or (kind='windDown' and isfinite(intended_bedtime) and intended_bedtime<=expires_at)
);

-- Replace the existing Campfire layer, preserving the Buddies wrappers above it.
create or replace function private.night_flock_v4_apply_before_buddies(u uuid,c jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare cmd text:=c->>'command'; p uuid:=(c->>'partyID')::uuid; epoch uuid; a private.campfire_agreements%rowtype;
 start_time timestamptz; observed timestamptz; expiry timestamptz; terminal boolean; rev int; bedtime timestamptz;
begin
 if cmd not in('setCampfireSharing','publishCampfireSession') then return private.night_flock_v4_apply_before_campfire(u,c); end if;
 if not private.is_apple_linked_night_flock_user(u) then raise exception 'linked_account_required'; end if;
 perform 1 from private.night_flock_v4_parties where id=p and deleted_at is null for update;
 if not found then raise exception 'invite_unavailable'; end if;
 select e.id into epoch from private.night_flock_v4_membership_epochs e
 join private.night_flock_v4_memberships m on m.id=e.membership_id
 where e.party_id=p and e.user_id=u and e.ended_at is null and m.status='active';
 if epoch is null or epoch is distinct from (c->>'memberEpochID')::uuid then raise exception 'invite_unavailable'; end if;
 if exists(select 1 from private.night_flock_v4_memberships m where m.party_id=p and m.status='active'
 and private.night_flock_users_blocked(u,m.user_id)) then raise exception 'invite_unavailable'; end if;
 select * into a from private.campfire_agreements where member_epoch_id=epoch;
 if cmd='setCampfireSharing' then
 if c->>'consentVersion' is distinct from '1' or jsonb_typeof(c->'enabled') is distinct from 'boolean' then raise exception 'agreement_required'; end if;
 -- Compare-and-set stops a delayed acceptance from undoing a later withdrawal.
 if coalesce(a.revision,0) is distinct from (c->>'expectedRevision')::int then return jsonb_build_object('accepted',true,'conflict',true); end if;
 insert into private.campfire_agreements(member_epoch_id,revision,enabled) values(epoch,1,(c->>'enabled')::boolean)
 on conflict(member_epoch_id) do update set id=gen_random_uuid(),revision=private.campfire_agreements.revision+1,
 enabled=excluded.enabled,accepted_at=now();
 delete from private.campfire_sessions where member_epoch_id=epoch;
 else
 if a.id is null or not a.enabled or a.id is distinct from (c->>'agreementID')::uuid then raise exception 'agreement_required'; end if;
 start_time:=(c->>'startedAt')::timestamptz; observed:=(c->>'observedAt')::timestamptz;
 bedtime:=(c->>'intendedBedtime')::timestamptz;
 expiry:=(c->>'expiresAt')::timestamptz; terminal:=(c->>'ended')::boolean; rev:=(c->>'revision')::int;
 if start_time is null or observed is null or expiry is null or terminal is null or rev is null
 or start_time<a.accepted_at or start_time>now()+interval '5 minutes' or observed<start_time
 or observed>now()+interval '5 minutes' or expiry<=start_time or expiry>start_time+interval '24 hours'
 or start_time<now()-interval '7 days' or (terminal and rev<>2) or (not terminal and rev<>1)
 or c->>'kind' not in('windDown','phoneAway') or c->>'sourceID' is null then raise exception 'Invalid campfire session'; end if;
 if bedtime is not null and (c->>'kind' is distinct from 'windDown' or not isfinite(bedtime) or bedtime>expiry)
 then raise exception 'Invalid campfire bedtime'; end if;
 -- First accepted source freezes bedtime. In particular, a legacy terminal
 -- without this optional field must still end a newer client's session.
 insert into private.campfire_sessions(member_epoch_id,source_id,agreement_id,revision,kind,activity,started_at,observed_at,expires_at,ended,intended_bedtime)
 values(epoch,(c->>'sourceID')::uuid,a.id,rev,c->>'kind',c->>'activity',start_time,observed,expiry,terminal,bedtime)
 on conflict(member_epoch_id,source_id) do update set revision=excluded.revision,observed_at=excluded.observed_at,ended=excluded.ended
 where private.campfire_sessions.revision<excluded.revision
 and private.campfire_sessions.started_at=excluded.started_at and private.campfire_sessions.expires_at=excluded.expires_at
 and private.campfire_sessions.kind=excluded.kind and private.campfire_sessions.agreement_id=excluded.agreement_id;
 -- Expired starts can never become current again. Keep tombstones beyond the
 -- accepted publication window, then prune without a new background scheduler.
 delete from private.campfire_sessions where member_epoch_id=epoch and started_at<now()-interval '8 days';
 end if;
 perform private.night_flock_v4_signal_party(p);
 return jsonb_build_object('accepted',true,'conflict',false);
end $$;

create or replace function public.night_flock_v4_state_before_buddies(p_user_id uuid,p_scope text default 'list',p_party_id uuid default null,p_cursor text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb; epoch uuid; agreement jsonb; sessions jsonb;
begin
 result:=public.night_flock_v4_state_before_campfire(p_user_id,p_scope,p_party_id,p_cursor);
 if p_scope<>'party' or result#>'{party,pasture}' is null then return result; end if;
 epoch:=(result#>>'{party,pasture,memberEpochID}')::uuid;
 select jsonb_build_object('id',a.id,'version',a.version,'revision',a.revision,'enabled',a.enabled,'acceptedAt',a.accepted_at)
 into agreement from private.campfire_agreements a where a.member_epoch_id=epoch;
 select coalesce(jsonb_agg(row_value),'[]') into sessions from (
 select distinct on(e.membership_id) e.membership_id,
 jsonb_build_object('id',s.source_id,'memberID',e.membership_id,'kind',s.kind,'activity',s.activity,
 'startedAt',s.started_at,'observedAt',s.observed_at,'expiresAt',s.expires_at,'ended',s.ended,'revision',s.revision,'intendedBedtime',s.intended_bedtime) row_value
 from private.campfire_sessions s join private.campfire_agreements a on a.member_epoch_id=s.member_epoch_id and a.id=s.agreement_id and a.enabled
 join private.night_flock_v4_membership_epochs e on e.id=s.member_epoch_id and e.ended_at is null
 join private.night_flock_v4_memberships m on m.id=e.membership_id and m.status='active'
 where e.party_id=p_party_id and not private.night_flock_users_blocked(p_user_id,e.user_id)
 and s.started_at>=now()-interval '24 hours'
 order by e.membership_id,s.started_at desc,s.revision desc,s.observed_at desc
 ) latest;
 return jsonb_set(result,'{party,pasture,campfire}',jsonb_build_object('version',1,'agreement',agreement,'sessions',sessions,'supportsIntendedBedtime',true));
end $$;
revoke all on function private.night_flock_v4_apply_before_buddies(uuid,jsonb),
 public.night_flock_v4_state_before_buddies(uuid,text,uuid,text) from public,anon,authenticated,service_role;
