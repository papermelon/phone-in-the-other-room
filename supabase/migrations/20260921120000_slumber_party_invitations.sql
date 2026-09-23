-- Addressed invitations replace code exchange as the primary entry. No public
-- group directory: only an exact handle/user ID lookup by an existing member.
create table private.slumber_party_invitations (
 id uuid primary key default gen_random_uuid(),
 party_id uuid not null references private.night_flock_v4_parties(id),
 sender_id uuid not null references auth.users(id) on delete cascade,
 recipient_id uuid not null references auth.users(id) on delete cascade,
 status text not null default 'pending' check(status in('pending','accepted','declined','revoked')),
 created_at timestamptz not null default now(),
 expires_at timestamptz not null default now()+interval '7 days',
 check(sender_id<>recipient_id)
);
create unique index slumber_party_pending_recipient on private.slumber_party_invitations(party_id,recipient_id) where status='pending';
create index slumber_party_invitation_inbox on private.slumber_party_invitations(recipient_id,created_at desc);
alter table private.slumber_party_invitations enable row level security;
revoke all on private.slumber_party_invitations from public,anon,authenticated,service_role;

create function public.slumber_party_connections_v1(p_request jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 u uuid:=auth.uid(); action text:=p_request->>'action'; pid uuid;
 target uuid; query text; result jsonb; person jsonb:=null; accepted_party uuid;
 invitation private.slumber_party_invitations%rowtype;
 party private.night_flock_v4_parties%rowtype;
begin
 if u is null or not private.account_verified_farm_owner_v1(u) then raise exception 'linked_account_required' using errcode='42501'; end if;
 if jsonb_typeof(p_request) is distinct from 'object' or action is null or action not in('state','search','invite','accept','decline','revoke') then raise exception 'invalid_request'; end if;
 if (action='state' and p_request-array['action','partyID']<>'{}'::jsonb)
 or (action='search' and p_request-array['action','partyID','query']<>'{}'::jsonb)
 or (action='invite' and p_request-array['action','partyID','userID']<>'{}'::jsonb)
 or (action in('accept','decline','revoke') and p_request-array['action','invitationID']<>'{}'::jsonb) then raise exception 'invalid_request'; end if;
 perform pg_advisory_xact_lock(hashtextextended(u::text,0));
 perform private.global_campfire_rate(u,'party-'||action,case when action='state' then 120 when action='search' then 30 else 20 end,case when action in('state','search') then 'minute' else 'hour' end);
 delete from private.slumber_party_invitations where (sender_id=u or recipient_id=u) and expires_at<now()-interval '30 days';
 if action in('search','invite') or (action='state' and p_request ? 'partyID') then
  pid:=(p_request->>'partyID')::uuid;
  select p.* into party from private.night_flock_v4_parties p
  join private.night_flock_v4_memberships m on m.party_id=p.id and m.user_id=u and m.status='active'
  where p.id=pid and p.deleted_at is null for update of p;
  if party.id is null then raise exception 'membership_required' using errcode='42501'; end if;
 end if;
 if action='search' then
  query:=lower(ltrim(btrim(p_request->>'query'),'@'));
  if query is null or not(query ~ '^[a-z][a-z0-9_]{2,23}$' or query ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') then raise exception 'invalid_request'; end if;
  select a.id into target from auth.users a left join private.account_usernames n on n.user_id=a.id
  where (n.username=query or a.id::text=query) and a.id<>u and private.account_verified_farm_owner_v1(a.id)
  and not exists(select 1 from private.night_flock_v4_memberships m where m.party_id=pid and m.status='active' and private.night_flock_users_blocked(a.id,m.user_id));
  if target is not null then
   select jsonb_build_object('userID',target,'name',coalesce(nullif(p.display_name,''),n.username,'A Shepherd'),'handle',n.username,
    'isMember',exists(select 1 from private.night_flock_v4_memberships m where m.party_id=pid and m.user_id=target and m.status='active'),
    'isInvited',exists(select 1 from private.slumber_party_invitations i where i.party_id=pid and i.recipient_id=target and i.status='pending' and i.expires_at>now())) into person
   from auth.users a left join private.night_flock_v4_profiles p on p.user_id=a.id left join private.account_usernames n on n.user_id=a.id where a.id=target;
  end if;
 end if;
 if action='invite' then
  target:=(p_request->>'userID')::uuid;
  if target is null or target=u or not private.account_verified_farm_owner_v1(target) then raise exception 'invite_unavailable'; end if;
  if exists(select 1 from private.night_flock_v4_memberships m where m.party_id=pid and m.status='active' and private.night_flock_users_blocked(target,m.user_id)) then raise exception 'invite_unavailable'; end if;
  if exists(select 1 from private.night_flock_v4_memberships m where m.party_id=pid and m.user_id=target and m.status='active') then raise exception 'already_member'; end if;
  if (select count(*) from private.night_flock_v4_memberships m where m.party_id=pid and m.status='active')>=8 then raise exception 'party_full'; end if;
  -- A declined request cannot be resent immediately. A pending request is an idempotent success.
  if exists(select 1 from private.slumber_party_invitations i where i.party_id=pid and i.recipient_id=target and i.status='declined' and i.expires_at>now()) then raise exception 'invite_unavailable'; end if;
  update private.slumber_party_invitations set status='revoked' where party_id=pid and recipient_id=target and status='pending' and expires_at<=now();
  insert into private.slumber_party_invitations(party_id,sender_id,recipient_id) values(pid,u,target) on conflict do nothing;
 end if;
 if action in('accept','decline','revoke') then
  select * into invitation from private.slumber_party_invitations where id=(p_request->>'invitationID')::uuid;
  if invitation.id is null then raise exception 'invite_unavailable'; end if;
  pid:=invitation.party_id;
  select * into party from private.night_flock_v4_parties where id=pid and deleted_at is null for update;
  if party.id is null then raise exception 'invite_unavailable'; end if;
  select * into invitation from private.slumber_party_invitations where id=invitation.id for update;
  if action='revoke' then
   if not exists(select 1 from private.night_flock_v4_memberships m where m.party_id=pid and m.user_id=u and m.status='active' and (m.role='host' or u=invitation.sender_id)) then raise exception 'membership_required' using errcode='42501'; end if;
   update private.slumber_party_invitations set status='revoked' where id=invitation.id and status='pending';
  else
   if invitation.recipient_id<>u then raise exception 'invite_unavailable' using errcode='42501'; end if;
   if action='decline' then
    update private.slumber_party_invitations set status='declined' where id=invitation.id and status='pending';
   elsif invitation.status='accepted' and exists(select 1 from private.night_flock_v4_memberships m where m.party_id=pid and m.user_id=u and m.status='active') then
    accepted_party:=pid;
   else
    if invitation.status<>'pending' or invitation.expires_at<=now()
    or not exists(select 1 from private.night_flock_v4_memberships m where m.party_id=pid and m.user_id=invitation.sender_id and m.status='active')
    or exists(select 1 from private.night_flock_v4_memberships m where m.party_id=pid and m.status='active' and private.night_flock_users_blocked(u,m.user_id)) then raise exception 'invite_unavailable'; end if;
    if not exists(select 1 from private.night_flock_v4_memberships m where m.party_id=pid and m.user_id=u and m.status='active') then
     if (select count(*) from private.night_flock_v4_memberships m where m.user_id=u and m.status='active')>=5 then raise exception 'party_limit'; end if;
     if (select count(*) from private.night_flock_v4_memberships m where m.party_id=pid and m.status='active')>=8 then raise exception 'party_full'; end if;
     insert into private.night_flock_v4_memberships(party_id,user_id,role,status,joined_at,left_at) values(pid,u,'member','active',now(),null)
     on conflict(party_id,user_id) do update set status='active',role='member',joined_at=excluded.joined_at,left_at=null;
     update private.night_flock_v4_parties set revision=revision+1,updated_at=now() where id=pid;
    end if;
    update private.slumber_party_invitations set status='accepted' where id=invitation.id;
    accepted_party:=pid;
   end if;
  end if;
 end if;
 select jsonb_build_object('version',1,'userID',u,'handle',(select username from private.account_usernames where user_id=u),'person',person,'acceptedPartyID',accepted_party,
 'invitations',coalesce(jsonb_agg(jsonb_build_object('id',i.id,'partyID',p.id,'partyName',p.name,'senderName',coalesce(nullif(sp.display_name,''),'A Shepherd'),
 'recipientName',coalesce(nullif(rp.display_name,''),rn.username,'A Shepherd'),'recipientID',i.recipient_id,'isIncoming',i.recipient_id=u,
 'canRevoke',i.sender_id=u or p.host_user_id=u,'expiresAt',i.expires_at) order by i.created_at desc) filter(where i.id is not null),'[]'::jsonb)) into result
 from private.slumber_party_invitations i
 join private.night_flock_v4_parties p on p.id=i.party_id and p.deleted_at is null
 left join private.night_flock_v4_profiles sp on sp.user_id=i.sender_id
 left join private.night_flock_v4_profiles rp on rp.user_id=i.recipient_id
 left join private.account_usernames rn on rn.user_id=i.recipient_id
 where i.status='pending' and i.expires_at>now()
 and (i.recipient_id=u or (i.party_id=pid and exists(select 1 from private.night_flock_v4_memberships m where m.party_id=i.party_id and m.user_id=u and m.status='active')))
 and exists(select 1 from private.night_flock_v4_memberships m where m.party_id=i.party_id and m.user_id=i.sender_id and m.status='active')
 and not exists(select 1 from private.night_flock_v4_memberships m where m.party_id=i.party_id and m.status='active' and private.night_flock_users_blocked(i.recipient_id,m.user_id));
 return result;
end $$;
revoke all on function public.slumber_party_connections_v1(jsonb) from public,anon,service_role;
grant execute on function public.slumber_party_connections_v1(jsonb) to authenticated;

alter function public.night_flock_v4_state(uuid,text,uuid,text) rename to night_flock_v4_state_before_direct_invites;
create function public.night_flock_v4_state(p_user_id uuid,p_scope text default 'list',p_party_id uuid default null,p_cursor text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 result:=public.night_flock_v4_state_before_direct_invites(p_user_id,p_scope,p_party_id,p_cursor);
 if p_scope='list' then result:=result||jsonb_build_object('directInvitationsVersion',1); end if;
 return result;
end $$;
revoke all on function public.night_flock_v4_state_before_direct_invites(uuid,text,uuid,text) from public,anon,authenticated,service_role;
revoke all on function public.night_flock_v4_state(uuid,text,uuid,text) from public,anon,authenticated;
grant execute on function public.night_flock_v4_state(uuid,text,uuid,text) to service_role;
