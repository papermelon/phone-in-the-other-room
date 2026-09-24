-- Explicitly authored intentions and support. V1 clients retain category presence.
alter table private.campfire_agreements drop constraint campfire_agreements_version_check;
alter table private.campfire_agreements add check(version in(1,2));
create table private.campfire_buddy_sessions (
 member_epoch_id uuid not null, source_id uuid not null, public_intention text not null check(char_length(public_intention)<=80),
 asks_for_buddy boolean not null, announce_start boolean not null, check_in_after timestamptz not null,
 buddy_epoch_id uuid references private.night_flock_v4_membership_epochs(id) on delete set null,
 check_in_requested boolean not null default false,
 outcome text check(outcome in('didIt','madeProgress','changedPlans')), reflection text check(char_length(reflection)<=160),
 primary key(member_epoch_id,source_id),
 foreign key(member_epoch_id,source_id) references private.campfire_sessions(member_epoch_id,source_id) on delete cascade
);
create table private.campfire_encouragements (
 member_epoch_id uuid not null, source_id uuid not null,
 sender_epoch_id uuid not null references private.night_flock_v4_membership_epochs(id) on delete cascade,
 primary key(member_epoch_id,source_id,sender_epoch_id),
 foreign key(member_epoch_id,source_id) references private.campfire_buddy_sessions(member_epoch_id,source_id) on delete cascade
);
create table private.campfire_alert_preferences (
 member_epoch_id uuid primary key references private.night_flock_v4_membership_epochs(id) on delete cascade,
 enabled boolean not null default false
);
alter table private.campfire_buddy_sessions enable row level security;
alter table private.campfire_encouragements enable row level security;
alter table private.campfire_alert_preferences enable row level security;
revoke all on private.campfire_buddy_sessions,private.campfire_encouragements,private.campfire_alert_preferences from public,anon,authenticated,service_role;

alter function private.night_flock_v4_apply(uuid,jsonb) rename to night_flock_v4_apply_before_buddies;
create function private.night_flock_v4_apply(u uuid,c jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare cmd text:=c->>'command'; p uuid:=(c->>'partyID')::uuid; epoch uuid; target uuid;
 a private.campfire_agreements%rowtype; s private.campfire_sessions%rowtype; b private.campfire_buddy_sessions%rowtype;
 result jsonb; source uuid; text_value text; after_time timestamptz;
begin
 if cmd not in('setCampfireSharing','publishCampfireSession','campfireBuddyAction','setCampfireAlerts') then
  return private.night_flock_v4_apply_before_buddies(u,c);
 end if;
 if not private.is_apple_linked_night_flock_user(u) then raise exception 'linked_account_required'; end if;
 perform 1 from private.night_flock_v4_parties where id=p and deleted_at is null for update;
 if not found then raise exception 'invite_unavailable'; end if;
 select e.id into epoch from private.night_flock_v4_membership_epochs e join private.night_flock_v4_memberships m on m.id=e.membership_id
 where e.party_id=p and e.user_id=u and e.ended_at is null and m.status='active';
 if epoch is null or epoch is distinct from (c->>'memberEpochID')::uuid then raise exception 'invite_unavailable'; end if;
 if exists(select 1 from private.night_flock_v4_memberships m where m.party_id=p and m.status='active' and private.night_flock_users_blocked(u,m.user_id)) then raise exception 'invite_unavailable'; end if;
 select * into a from private.campfire_agreements where member_epoch_id=epoch;
 if cmd='setCampfireSharing' then
  if c->>'consentVersion' is null or c->>'consentVersion' not in('1','2') then raise exception 'agreement_required'; end if;
  result:=private.night_flock_v4_apply_before_buddies(u,c||'{"consentVersion":1}');
  if coalesce((result->>'conflict')::boolean,false) then return result; end if;
  update private.campfire_agreements set version=(c->>'consentVersion')::int where member_epoch_id=epoch;
  delete from private.campfire_alert_preferences where member_epoch_id=epoch;
  delete from private.campfire_encouragements where sender_epoch_id=epoch;
  update private.campfire_buddy_sessions set buddy_epoch_id=null,check_in_requested=false where buddy_epoch_id=epoch;
 elsif cmd='publishCampfireSession' then
  if c ? 'publicIntention' then
   if a.version<>2 or not a.enabled or a.id is distinct from (c->>'agreementID')::uuid then raise exception 'agreement_required'; end if;
   text_value:=c->>'publicIntention'; after_time:=(c->>'checkInAfter')::timestamptz;
   if text_value is null or char_length(text_value)>80 or text_value ~ '[[:cntrl:]]'
    or jsonb_typeof(c->'asksForBuddy') is distinct from 'boolean' or jsonb_typeof(c->'announceStart') is distinct from 'boolean'
    or after_time is null or after_time<(c->>'expiresAt')::timestamptz or after_time>(c->>'expiresAt')::timestamptz+interval '6 hours'
   then raise exception 'Invalid campfire intention'; end if;
  elsif c ?| array['asksForBuddy','announceStart','checkInAfter'] then raise exception 'Invalid campfire intention'; end if;
  result:=private.night_flock_v4_apply_before_buddies(u,c);
  select * into s from private.campfire_sessions where member_epoch_id=epoch and source_id=(c->>'sourceID')::uuid;
  if c ? 'publicIntention' and s.agreement_id=a.id and not s.ended and s.started_at=(c->>'startedAt')::timestamptz then
   insert into private.campfire_buddy_sessions(member_epoch_id,source_id,public_intention,asks_for_buddy,announce_start,check_in_after)
   values(epoch,s.source_id,text_value,(c->>'asksForBuddy')::boolean,(c->>'announceStart')::boolean,after_time)
   on conflict do nothing;
  end if;
 elsif cmd='setCampfireAlerts' then
  if a.version<>2 or not a.enabled or a.id is distinct from (c->>'agreementID')::uuid then raise exception 'agreement_required'; end if;
  if jsonb_typeof(c->'startAlerts') is distinct from 'boolean' then raise exception 'Invalid campfire alerts'; end if;
  insert into private.campfire_alert_preferences values(epoch,(c->>'startAlerts')::boolean)
   on conflict(member_epoch_id) do update set enabled=excluded.enabled;
 else
  if a.version<>2 or not a.enabled or a.id is distinct from (c->>'agreementID')::uuid then raise exception 'agreement_required'; end if;
  source:=(c->>'sourceID')::uuid;
  select e.id into target from private.night_flock_v4_membership_epochs e join private.night_flock_v4_memberships m on m.id=e.membership_id
   join private.campfire_agreements ca on ca.member_epoch_id=e.id and ca.version=2 and ca.enabled
   where e.party_id=p and e.membership_id=(c->>'targetMemberID')::uuid and e.ended_at is null and m.status='active';
  select * into s from private.campfire_sessions where member_epoch_id=target and source_id=source;
  select * into b from private.campfire_buddy_sessions where member_epoch_id=target and source_id=source for update;
  if b.source_id is null or s.started_at<a.accepted_at or s.started_at<now()-interval '7 days' then raise exception 'invite_unavailable'; end if;
  case c->>'buddyAction'
  when 'accept' then
   if target=epoch or not b.asks_for_buddy or s.ended or s.expires_at<=now() then raise exception 'invite_unavailable'; end if;
   if b.buddy_epoch_id is not null and not exists(
    select 1 from private.night_flock_v4_membership_epochs be
    join private.night_flock_v4_memberships bm on bm.id=be.membership_id and bm.status='active'
    join private.campfire_agreements ba on ba.member_epoch_id=be.id and ba.enabled and ba.version=2
    where be.id=b.buddy_epoch_id and be.ended_at is null
   ) then b.buddy_epoch_id:=null; end if;
   if b.buddy_epoch_id is not null and b.buddy_epoch_id<>epoch then return jsonb_build_object('accepted',true,'conflict',true); end if;
   update private.campfire_buddy_sessions set buddy_epoch_id=epoch,check_in_requested=false where member_epoch_id=target and source_id=source;
  when 'encourage' then
   if target=epoch then raise exception 'invite_unavailable'; end if;
   insert into private.campfire_encouragements values(target,source,epoch) on conflict do nothing;
  when 'checkIn' then
   if b.buddy_epoch_id is distinct from epoch or now()<b.check_in_after or b.outcome is not null then raise exception 'invite_unavailable'; end if;
   update private.campfire_buddy_sessions set check_in_requested=true where member_epoch_id=target and source_id=source;
  when 'reflect' then
   if target<>epoch or (s.kind='windDown' and now()<b.check_in_after) or (s.kind='phoneAway' and not s.ended and now()<s.expires_at)
     or c->>'outcome' is null or c->>'outcome' not in('didIt','madeProgress','changedPlans')
     or char_length(coalesce(c->>'reflection',''))>160 or coalesce(c->>'reflection','') ~ '[[:cntrl:]]' then raise exception 'Invalid campfire reflection'; end if;
   -- First acknowledged check-in wins; an old queued request cannot overwrite it.
   update private.campfire_buddy_sessions set outcome=c->>'outcome',reflection=nullif(c->>'reflection','')
    where member_epoch_id=target and source_id=source and outcome is null;
  else raise exception 'Invalid buddy action';
  end case;
 end if;
 delete from private.campfire_buddy_sessions old_buddy using private.campfire_sessions old_session
  where old_session.member_epoch_id=old_buddy.member_epoch_id and old_session.source_id=old_buddy.source_id and old_session.started_at<now()-interval '7 days';
 perform private.night_flock_v4_signal_party(p);
 return jsonb_build_object('accepted',true,'conflict',false);
end $$;

alter function public.night_flock_v4_state(uuid,text,uuid,text) rename to night_flock_v4_state_before_buddies;
create function public.night_flock_v4_state(p_user_id uuid,p_scope text default 'list',p_party_id uuid default null,p_cursor text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb; epoch uuid; rows jsonb; a private.campfire_agreements%rowtype; alerts boolean;
begin
 result:=public.night_flock_v4_state_before_buddies(p_user_id,p_scope,p_party_id,p_cursor);
 if p_scope<>'party' or result#>'{party,pasture}' is null then return result; end if;
 epoch:=(result#>>'{party,pasture,memberEpochID}')::uuid;
 select * into a from private.campfire_agreements where member_epoch_id=epoch;
 select enabled into alerts from private.campfire_alert_preferences where member_epoch_id=epoch;
 select coalesce(jsonb_agg(row_value order by started_at desc),'[]') into rows from (
 select s.started_at,jsonb_build_object('sourceID',s.source_id,'memberID',e.membership_id,'publicIntention',b.public_intention,
 'asksForBuddy',b.asks_for_buddy,'buddyMemberID',be.membership_id,'checkInRequested',b.check_in_requested,
 'outcome',b.outcome,'reflection',b.reflection,'startedAt',s.started_at,'expiresAt',s.expires_at,'checkInAfter',b.check_in_after,'ended',s.ended,'kind',s.kind,
 'encouragementMemberIDs',(select coalesce(jsonb_agg(ce.membership_id),'[]') from private.campfire_encouragements ch
   join private.night_flock_v4_membership_epochs ce on ce.id=ch.sender_epoch_id and ce.ended_at is null
   where ch.member_epoch_id=b.member_epoch_id and ch.source_id=b.source_id and not private.night_flock_users_blocked(p_user_id,ce.user_id))) row_value
 from private.campfire_buddy_sessions b join private.campfire_sessions s using(member_epoch_id,source_id)
 join private.campfire_agreements ca on ca.member_epoch_id=s.member_epoch_id and ca.id=s.agreement_id and ca.enabled and ca.version=2
 join private.night_flock_v4_membership_epochs e on e.id=s.member_epoch_id and e.ended_at is null
 join private.night_flock_v4_memberships m on m.id=e.membership_id and m.status='active'
 left join private.night_flock_v4_membership_epochs be on be.id=b.buddy_epoch_id and be.ended_at is null and not private.night_flock_users_blocked(p_user_id,be.user_id)
 where a.enabled and a.version=2 and e.party_id=p_party_id and s.started_at>=a.accepted_at
 and s.started_at>now()-interval '7 days' and not private.night_flock_users_blocked(p_user_id,e.user_id)
 ) visible;
 return jsonb_set(result,'{party,pasture,campfire,buddies}',jsonb_build_object('version',1,'startAlerts',coalesce(alerts,false),'sessions',rows));
end $$;
revoke all on function private.night_flock_v4_apply_before_buddies(uuid,jsonb),private.night_flock_v4_apply(uuid,jsonb),
 public.night_flock_v4_state_before_buddies(uuid,text,uuid,text) from public,anon,authenticated,service_role;
revoke all on function public.night_flock_v4_state(uuid,text,uuid,text) from public,anon,authenticated;
grant execute on function public.night_flock_v4_state(uuid,text,uuid,text) to service_role;
