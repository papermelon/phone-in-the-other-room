CREATE OR REPLACE FUNCTION private.night_flock_v4_apply(u uuid, c jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare cmd text:=c->>'command'; p uuid:=(c->>'partyID')::uuid; epoch uuid; a private.campfire_agreements%rowtype;
 start_time timestamptz; observed timestamptz; expiry timestamptz; terminal boolean; rev int;
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
 expiry:=(c->>'expiresAt')::timestamptz; terminal:=(c->>'ended')::boolean; rev:=(c->>'revision')::int;
 if start_time is null or observed is null or expiry is null or terminal is null or rev is null
 or start_time<a.accepted_at or start_time>now()+interval '5 minutes' or observed<start_time
 or observed>now()+interval '5 minutes' or expiry<=start_time or expiry>start_time+interval '24 hours'
 or start_time<now()-interval '7 days' or (terminal and rev<>2) or (not terminal and rev<>1)
 or c->>'kind' not in('windDown','phoneAway') or c->>'sourceID' is null then raise exception 'Invalid campfire session'; end if;
 insert into private.campfire_sessions values(epoch,(c->>'sourceID')::uuid,a.id,rev,c->>'kind',c->>'activity',start_time,observed,expiry,terminal)
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
end $function$


CREATE OR REPLACE FUNCTION public.night_flock_v4_state(p_user_id uuid, p_scope text DEFAULT 'list'::text, p_party_id uuid DEFAULT NULL::uuid, p_cursor text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
 'startedAt',s.started_at,'observedAt',s.observed_at,'expiresAt',s.expires_at,'ended',s.ended,'revision',s.revision) row_value
 from private.campfire_sessions s join private.campfire_agreements a on a.member_epoch_id=s.member_epoch_id and a.id=s.agreement_id and a.enabled
 join private.night_flock_v4_membership_epochs e on e.id=s.member_epoch_id and e.ended_at is null
 join private.night_flock_v4_memberships m on m.id=e.membership_id and m.status='active'
 where e.party_id=p_party_id and not private.night_flock_users_blocked(p_user_id,e.user_id)
 and s.started_at>=now()-interval '24 hours'
 order by e.membership_id,s.started_at desc,s.revision desc,s.observed_at desc
 ) latest;
 return jsonb_set(result,'{party,pasture,campfire}',jsonb_build_object('version',1,'agreement',agreement,'sessions',sessions));
end $function$
