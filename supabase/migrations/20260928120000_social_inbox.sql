-- Meaningful support is a new contract: legacy reaction enums stay unchanged.
create table private.social_support (
 id uuid primary key, sender uuid not null references auth.users(id) on delete cascade,
 recipient uuid not null references auth.users(id) on delete cascade,
 source jsonb not null, scope_key text not null, sender_epoch uuid,
 message_id text not null check(message_id in('rootingForYou','youveGotThis','cheeringYouOn','niceWork','highFive','lovelyProgress','restWell','goodNight','peacefulEvening')),
 created_at timestamptz not null default now(), removed_at timestamptz,
 unique(sender,scope_key), check(sender<>recipient)
);
create index social_support_recipient on private.social_support(recipient,created_at desc);
create table private.social_inbox_reads (
 user_id uuid not null references auth.users(id) on delete cascade,
 event_id text not null, read_at timestamptz not null default now(), primary key(user_id,event_id)
);
create table private.social_notification_preferences (
 user_id uuid primary key references auth.users(id) on delete cascade,
 invitations boolean not null default false, cheers boolean not null default false,
 global_cheers boolean not null default false
);
do $$ declare t text; begin
 foreach t in array array['social_support','social_inbox_reads','social_notification_preferences'] loop
 execute format('alter table private.%I enable row level security',t);
 execute format('revoke all on private.%I from public,anon,authenticated,service_role',t);
 end loop;
end $$;

-- Resolve original context under current membership, block and agreement fences.
-- Only identifiers are stored in support rows; withdrawn content is never copied.
create function private.social_source(u uuid, src jsonb) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare k text:=src->>'kind'; sid uuid:=(src->>'id')::uuid; p uuid:=(src->>'partyID')::uuid;
 target uuid; se uuid; te uuid; source_event uuid; occurred timestamptz; title text; label text;
 activity_kind text; recognized boolean:=false; active boolean:=false; epoch private.night_flock_v4_membership_epochs%rowtype;
 a private.campfire_agreements%rowtype; g private.global_campfire_sessions%rowtype; recipient_profile private.global_campfire_profiles%rowtype;
 options jsonb:='["rootingForYou","youveGotThis","cheeringYouOn"]';
begin
 if k is null or k not in('activity','status','campfire','global','round') or sid is null then return null; end if;
 if k='global' then
  if not exists(select 1 from private.global_campfire_settings where enabled) then return null; end if;
  select s.* into g from private.global_campfire_sessions s where s.id=sid and s.started_at>now()-interval '8 days';
  select * into recipient_profile from private.global_campfire_profiles where user_id=g.user_id and enabled and not suspended and agreement_id=g.agreement_id;
  if recipient_profile.user_id is null or private.night_flock_users_blocked(u,g.user_id)
   or not exists(select 1 from private.global_campfire_profiles where user_id=u and enabled and not suspended) then return null; end if;
  select agreement_id into se from private.global_campfire_profiles where user_id=u;
  target:=g.user_id; source_event:=g.id; occurred:=g.started_at; activity_kind:=g.kind;
  active:=not g.ended and g.expires_at>now(); label:=recipient_profile.name;
 else
  select e.* into epoch from private.night_flock_v4_membership_epochs e
   join private.night_flock_v4_memberships m on m.id=e.membership_id and m.status='active'
   join private.night_flock_v4_parties party on party.id=e.party_id and party.deleted_at is null
   where e.party_id=p and e.user_id=u and e.ended_at is null;
  if epoch.id is null then return null; end if;
  se:=epoch.id;
  if k='activity' then
   select member_epoch_id,source_event_id,occurred_at,kind,outcome='completed' into te,source_event,occurred,activity_kind,recognized
   from private.night_flock_v4_membership_stream_activities where id=sid and party_id=p and occurred_at>now()-interval '90 days';
  elsif k='round' then
   select e.id,l.source_event_id,l.ended_at,l.kind,l.outcome='completed' into te,source_event,occurred,activity_kind,recognized
   from public.night_flock_v4_party_activities ra join private.night_flock_v4_activity_ledger l on l.id=ra.ledger_id
   join private.night_flock_v4_membership_epochs e on e.membership_id=ra.member_id and e.ended_at is null
   where ra.id=sid and ra.party_id=p and l.ended_at>=e.joined_at and l.ended_at>now()-interval '90 days';
  elsif k='status' then
   select member_epoch_id,source_event_id,observed_at,case when status='windDownStarting' then 'windDown' else 'phoneAway' end,
    terminal_at is null and expires_at>now() into te,source_event,occurred,activity_kind,active
   from private.night_flock_v4_membership_stream_statuses where id=sid and party_id=p and observed_at>now()-interval '90 days';
  else
   select * into a from private.campfire_agreements where member_epoch_id=se and enabled and version=2;
   if a.id is null then return null; end if;
   select s.member_epoch_id,s.source_id,s.started_at,s.kind,not s.ended and s.expires_at>now(),b.outcome in('didIt','madeProgress')
   into te,source_event,occurred,activity_kind,active,recognized
   from private.campfire_sessions s join private.night_flock_v4_membership_epochs e on e.id=s.member_epoch_id and e.party_id=p
   join private.campfire_agreements ca on ca.member_epoch_id=e.id and ca.id=s.agreement_id and ca.enabled and ca.version=2
   join private.campfire_buddy_sessions b on b.member_epoch_id=s.member_epoch_id and b.source_id=s.source_id
   where s.source_id=sid and e.membership_id=(src->>'memberID')::uuid and s.started_at>=a.accepted_at and s.started_at>now()-interval '7 days';
  end if;
  select e.user_id,coalesce(nullif(pr.display_name,''),'A Shepherd') into target,label
   from private.night_flock_v4_membership_epochs e join private.night_flock_v4_memberships m on m.id=e.membership_id and m.status='active'
   left join private.night_flock_v4_profiles pr on pr.user_id=e.user_id
   where e.id=te and e.ended_at is null and occurred>=e.joined_at;
  if target is null or occurred<epoch.joined_at or private.night_flock_users_blocked(u,target) then return null; end if;
 end if;
 if target is null then return null; end if;
 title:=case when activity_kind='windDown' then 'Wind Down' else 'Phone Away' end;
 if recognized then options:='["niceWork","highFive","lovelyProgress","rootingForYou","cheeringYouOn"]';
 elsif activity_kind='windDown' and active then options:='["restWell","goodNight","peacefulEvening","rootingForYou","cheeringYouOn"]'; end if;
 if k='global' and not active or k='status' and not active then options:='[]'; end if;
 return jsonb_build_object('recipient',target,'senderEpoch',se,'scopeKey',coalesce(te::text,'global')||':'||source_event::text,
  'name',label,'context',title,'occurredAt',occurred,'messages',case when target=u then '[]'::jsonb else options end,'source',src);
end $$;

alter table private.campfire_encouragements add column created_at timestamptz;
alter table private.campfire_encouragements alter column created_at set default now();

alter table private.slumber_party_invitations add column responded_at timestamptz;
create function private.social_invitation_response_time() returns trigger language plpgsql set search_path='' as $$
begin
 if new.status is distinct from old.status and new.status='accepted' then new.responded_at:=now(); end if;
 return new;
end $$;
create trigger social_invitation_response_time before update of status on private.slumber_party_invitations
 for each row execute function private.social_invitation_response_time();
revoke all on function private.social_invitation_response_time() from public,anon,authenticated,service_role;

create function private.social_inbox_events(u uuid)
returns table(id text,kind text,source jsonb,invitation_id uuid,party_id uuid,party_name text,sender_name text,
 message_id text,context text,occurred_at timestamptz,arrived_at timestamptz,people integer)
language sql stable security definer set search_path='' as $$
 with supports as (
 select s.*,private.social_source(s.sender,s.source) resolved from private.social_support s
 where s.recipient=u and s.removed_at is null and s.created_at>now()-interval '30 days'
 ), eligible as (
 select s.* from supports s where resolved is not null and (resolved->>'recipient')::uuid=u
 and (resolved->>'senderEpoch')::uuid is not distinct from s.sender_epoch
 ), invitations as (
 select i.*,p.name from private.slumber_party_invitations i
 join private.night_flock_v4_parties p on p.id=i.party_id and p.deleted_at is null
 where ((i.recipient_id=u and i.status='pending' and i.expires_at>now()) or
 (i.sender_id=u and i.status='accepted' and coalesce(i.responded_at,i.created_at)>now()-interval '30 days'
  and exists(select 1 from private.night_flock_v4_memberships m where m.party_id=i.party_id and m.user_id=i.recipient_id and m.status='active')))
 and exists(select 1 from private.night_flock_v4_memberships m where m.party_id=i.party_id and m.user_id=i.sender_id and m.status='active')
 and not exists(select 1 from private.night_flock_v4_memberships m where m.party_id=i.party_id and m.status='active' and private.night_flock_users_blocked(i.recipient_id,m.user_id))
 )
 select 'invite:'||i.id,case when i.status='accepted' then 'joined' else 'invitation' end,null::jsonb,i.id,i.party_id,i.name,
 coalesce(pr.display_name,'A Shepherd'),null::text,'Slumber Party',coalesce(i.responded_at,i.created_at),coalesce(i.responded_at,i.created_at),1
 from invitations i left join private.night_flock_v4_profiles pr on pr.user_id=case when i.status='accepted' then i.recipient_id else i.sender_id end
 union all
 select 'support:'||s.id,'cheer',s.source,null::uuid,(s.source->>'partyID')::uuid,p.name,
 case when s.source->>'kind'='global' then null else coalesce(pr.display_name,'A Shepherd') end,
 s.message_id,s.resolved->>'context',(s.resolved->>'occurredAt')::timestamptz,s.created_at,1
 from eligible s left join private.night_flock_v4_profiles pr on pr.user_id=s.sender
 left join private.night_flock_v4_parties p on p.id=(s.source->>'partyID')::uuid
 union all
 select 'legacy:'||r.reaction_id,'cheer',jsonb_build_object('kind',case when a.id is null then 'round' else 'activity' end,'id',r.activity_id,'partyID',m.party_id),
 null::uuid,m.party_id,p.name,coalesce(pr.display_name,'A Shepherd'),r.cheer,'Shared moment',coalesce(a.occurred_at,l.ended_at),r.accepted_at,1
 from private.night_flock_v4_memberships m
 join private.night_flock_v4_parties p on p.id=m.party_id
 cross join lateral private.night_flock_v4_update_cheers(u,m.party_id) r
 join private.night_flock_v4_memberships sender on sender.id=r.sender_id
 left join private.night_flock_v4_profiles pr on pr.user_id=sender.user_id
 left join private.night_flock_v4_membership_stream_activities a on a.id=r.activity_id
 left join public.night_flock_v4_party_activities ra on ra.id=r.activity_id and r.source='round'
 left join private.night_flock_v4_activity_ledger l on l.id=ra.ledger_id
 where m.user_id=u and m.status='active' and r.recipient_id=m.id and r.source<>'live' and r.accepted_at>now()-interval '30 days'
 union all
 select 'legacy:'||r.id,'cheer',jsonb_build_object('kind','status','id',st.id,'partyID',st.party_id),null::uuid,st.party_id,p.name,
 coalesce(pr.display_name,'A Shepherd'),r.reaction,case when st.status='windDownStarting' then 'Wind Down' else 'Phone Away' end,st.observed_at,r.created_at,1
 from private.night_flock_v4_membership_stream_live_reactions r
 join private.night_flock_v4_membership_stream_statuses st on st.id=r.status_id
 join private.night_flock_v4_membership_epochs recipient on recipient.id=st.member_epoch_id and recipient.user_id=u
 join private.night_flock_v4_membership_epochs sender on sender.id=r.reactor_epoch_id and sender.ended_at is null
 join private.night_flock_v4_parties p on p.id=st.party_id
 left join private.night_flock_v4_profiles pr on pr.user_id=sender.user_id
 where r.created_at>now()-interval '30 days' and private.social_source(sender.user_id,jsonb_build_object('kind','status','id',st.id,'partyID',st.party_id)) is not null
 union all
 select 'campfire:'||s.member_epoch_id||':'||s.source_id||':'||ch.sender_epoch_id,'cheer',
 jsonb_build_object('kind','campfire','id',s.source_id,'partyID',recipient.party_id,'memberID',recipient.membership_id),
 null::uuid,recipient.party_id,p.name,coalesce(pr.display_name,'A Shepherd'),'encouragement',
 case when s.kind='windDown' then 'Wind Down' else 'Phone Away' end,s.started_at,coalesce(ch.created_at,s.started_at),1
 from private.campfire_encouragements ch join private.campfire_sessions s using(member_epoch_id,source_id)
 join private.night_flock_v4_membership_epochs recipient on recipient.id=s.member_epoch_id and recipient.user_id=u
 join private.night_flock_v4_membership_epochs sender on sender.id=ch.sender_epoch_id and sender.ended_at is null
 join private.night_flock_v4_parties p on p.id=recipient.party_id
 left join private.night_flock_v4_profiles pr on pr.user_id=sender.user_id
 where private.social_source(sender.user_id,jsonb_build_object('kind','campfire','id',s.source_id,'partyID',recipient.party_id,'memberID',recipient.membership_id)) is not null
 union all
 select 'global:'||g.id||':'||md5(ch.sender::text),'cheer',jsonb_build_object('kind','global','id',g.id),null::uuid,null::uuid,null::text,null::text,
 'encouragement',case when g.kind='windDown' then 'Wind Down' else 'Phone Away' end,g.started_at,ch.created_at,1
 from private.global_campfire_encouragements ch join private.global_campfire_sessions g on g.id=ch.session_id
 where g.user_id=u and private.social_source(ch.sender,jsonb_build_object('kind','global','id',g.id)) is not null
 $$;

create function public.social_inbox_v1(p_request jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); action text:=p_request->>'action'; src jsonb:=p_request->'source'; resolved jsonb;
 item private.social_support%rowtype; pref private.social_notification_preferences%rowtype;
 result jsonb; rows jsonb; unread int; pending int; next_cursor text; cmd uuid; pid uuid; selected_event record;
begin
 if u is null or not private.account_verified_farm_owner_v1(u) or u is distinct from (p_request->>'ownerID')::uuid then raise exception 'linked_account_required' using errcode='42501'; end if;
 if jsonb_typeof(p_request)<>'object' or action is null or action not in('inbox','summary','source','send','remove','read','preferences','event')
 or p_request-array['action','source','messageID','commandID','eventIDs','cursor','preferences','ownerID']<>'{}' then raise exception 'invalid_request'; end if;
 perform pg_advisory_xact_lock(hashtextextended(u::text,0));
 perform private.global_campfire_rate(u,'social-'||action,case when action in('send','remove') then 30 else 120 end,
  case when action in('send','remove') then 'hour' else 'minute' end);
 if action='event' then
  select * into selected_event from private.social_inbox_events(u) where id=p_request#>>'{eventIDs,0}';
  if selected_event.id is null then raise exception 'source_unavailable'; end if;
  if selected_event.source is not null then resolved:=private.social_source(u,selected_event.source); end if;
  result:=jsonb_build_object('detail',case when resolved is null then null else
   (resolved-array['recipient','senderEpoch','scopeKey'])||jsonb_build_object('sentMessageID',null,'removed',false) end,
   'events',jsonb_build_array(jsonb_build_object('id',selected_event.id,'kind',selected_event.kind,'source',selected_event.source,
   'invitationID',selected_event.invitation_id,'partyID',selected_event.party_id,'partyName',selected_event.party_name,
   'senderName',selected_event.sender_name,'messageID',selected_event.message_id,'context',selected_event.context,
   'occurredAt',selected_event.occurred_at,'arrivedAt',selected_event.arrived_at,'isRead',false,'count',selected_event.people)));
 elsif action in('source','send','remove') then
  if jsonb_typeof(src)<>'object' or src-array['kind','id','partyID','memberID']<>'{}' then raise exception 'invalid_request'; end if;
  pid:=(src->>'partyID')::uuid;
  if pid is not null then perform 1 from private.night_flock_v4_parties where id=pid for update; end if;
  resolved:=private.social_source(u,src);
  if resolved is null then raise exception 'source_unavailable'; end if;
  select * into item from private.social_support where sender=u and scope_key=resolved->>'scopeKey';
  if action='send' then
   cmd:=(p_request->>'commandID')::uuid;
   if cmd is null then raise exception 'invalid_request'; end if;
   if item.id is null then
    if (resolved->>'recipient')::uuid=u or not(resolved->'messages' ? (p_request->>'messageID')) then raise exception 'source_unavailable'; end if;
    insert into private.social_support(id,sender,recipient,source,scope_key,sender_epoch,message_id)
    values(cmd,u,(resolved->>'recipient')::uuid,src,resolved->>'scopeKey',(resolved->>'senderEpoch')::uuid,p_request->>'messageID') returning * into item;
   end if;
  elsif action='remove' then
   update private.social_support set removed_at=coalesce(removed_at,now()) where id=item.id returning * into item;
  end if;
  result:=jsonb_build_object('detail',(resolved-array['recipient','senderEpoch','scopeKey'])||jsonb_build_object('sentMessageID',item.message_id,'removed',item.removed_at is not null));
 else
  if action='preferences' then
   if jsonb_typeof(p_request->'preferences')<>'object' or (p_request->'preferences')-array['invitations','cheers','globalCheers']<>'{}'
    or jsonb_typeof(p_request#>'{preferences,invitations}') is distinct from 'boolean'
    or jsonb_typeof(p_request#>'{preferences,cheers}') is distinct from 'boolean'
    or jsonb_typeof(p_request#>'{preferences,globalCheers}') is distinct from 'boolean' then raise exception 'invalid_request'; end if;
   insert into private.social_notification_preferences values(u,(p_request#>>'{preferences,invitations}')::boolean,
    (p_request#>>'{preferences,cheers}')::boolean,(p_request#>>'{preferences,globalCheers}')::boolean)
   on conflict(user_id) do update set invitations=excluded.invitations,cheers=excluded.cheers,global_cheers=excluded.global_cheers;
  elsif action='read' then
   if jsonb_typeof(p_request->'eventIDs') is distinct from 'array' or jsonb_array_length(p_request->'eventIDs')>50 then raise exception 'invalid_request'; end if;
   insert into private.social_inbox_reads(user_id,event_id)
   select u,e.id from private.social_inbox_events(u) e where e.id in(select jsonb_array_elements_text(p_request->'eventIDs')) on conflict do nothing;
  end if;
  select * into pref from private.social_notification_preferences where user_id=u;
  select count(*) filter(where r.event_id is null),count(*) filter(where e.kind='invitation') into unread,pending
   from private.social_inbox_events(u) e left join private.social_inbox_reads r on r.user_id=u and r.event_id=e.id;
  if action<>'summary' then
   with page as (
    select e.*,r.event_id is not null is_read from private.social_inbox_events(u) e
    left join private.social_inbox_reads r on r.user_id=u and r.event_id=e.id
    where p_request->>'cursor' is null or (e.arrived_at,e.id)<((split_part(p_request->>'cursor','|',1))::timestamptz,split_part(p_request->>'cursor','|',2))
    order by e.arrived_at desc,e.id desc limit 50
   ) select coalesce(jsonb_agg(jsonb_build_object('id',id,'kind',kind,'source',source,'invitationID',invitation_id,'partyID',party_id,
    'partyName',party_name,'senderName',sender_name,'messageID',message_id,'context',context,'occurredAt',occurred_at,'arrivedAt',arrived_at,'isRead',is_read,'count',people)
    order by arrived_at desc,id desc),'[]'),case when count(*)=50 then (array_agg(arrived_at::text||'|'||id order by arrived_at,id))[1] end into rows,next_cursor from page;
  end if;
  result:=jsonb_build_object('events',rows,'unreadCount',unread,'pendingInvitations',pending,'nextCursor',next_cursor,
   'preferences',jsonb_build_object('invitations',coalesce(pref.invitations,false),'cheers',coalesce(pref.cheers,false),'globalCheers',coalesce(pref.global_cheers,false)));
 end if;
 return coalesce(result,'{}')||jsonb_build_object('version',1,'userID',u);
end $$;
revoke all on function private.social_source(uuid,jsonb),private.social_inbox_events(uuid),public.social_inbox_v1(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.social_inbox_v1(jsonb) to authenticated;

alter function public.night_flock_v4_state(uuid,text,uuid,text) rename to night_flock_v4_state_before_social_inbox;
create function public.night_flock_v4_state(p_user_id uuid,p_scope text default 'list',p_party_id uuid default null,p_cursor text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb; begin
 result:=public.night_flock_v4_state_before_social_inbox(p_user_id,p_scope,p_party_id,p_cursor);
 if p_scope='list' then result:=result||'{"socialInboxVersion":1}'; end if;
 return result;
end $$;
revoke all on function public.night_flock_v4_state_before_social_inbox(uuid,text,uuid,text),public.night_flock_v4_state(uuid,text,uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.night_flock_v4_state(uuid,text,uuid,text) to service_role;

alter function public.slumber_party_connections_v1(jsonb) rename to slumber_party_connections_before_inbox;
create function public.slumber_party_connections_v1(p_request jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb; invitations jsonb;
begin
 result:=public.slumber_party_connections_before_inbox(p_request);
 select coalesce(jsonb_agg(x||jsonb_build_object('senderHandle',n.username,'memberCount',
  (select count(*) from private.night_flock_v4_memberships where party_id=i.party_id and status='active'))),'[]') into invitations
 from jsonb_array_elements(result->'invitations') x
 join private.slumber_party_invitations i on i.id=(x->>'id')::uuid
 left join private.account_usernames n on n.user_id=i.sender_id;
 return jsonb_set(result,'{invitations}',invitations);
end $$;
revoke all on function public.slumber_party_connections_before_inbox(jsonb),public.slumber_party_connections_v1(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.slumber_party_connections_v1(jsonb) to authenticated;
