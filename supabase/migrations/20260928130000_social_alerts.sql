-- Account-level invitations can arrive before membership. Reuse the APNs device
-- registry, quiet windows and dispatcher, without a fabricated membership epoch.
create table private.social_alert_events (
 id uuid primary key default gen_random_uuid(), recipient uuid not null references auth.users(id) on delete cascade,
 event_id text not null, kind text not null check(kind in('invitation','cheer')), is_global boolean not null default false,
 created_at timestamptz not null default now(), due_at timestamptz not null, expires_at timestamptz not null,
 state text not null default 'pending' check(state in('pending','accepted','terminal')),
 lease uuid, lease_until timestamptz, batch_cutoff timestamptz, attempts int not null default 0,
 accepted_tokens text[] not null default '{}', sent_at timestamptz,
 unique(recipient,event_id)
);
create index social_alert_due on private.social_alert_events(due_at) where state='pending';
alter table private.social_alert_events enable row level security;
revoke all on private.social_alert_events from public,anon,authenticated,service_role;

create function private.queue_social_alert() returns trigger language plpgsql security definer set search_path='' as $$
declare recipient_id uuid; event text; category text:='cheer'; expiry timestamptz:=now()+interval '24 hours'; global_message boolean:=false;
begin
 if tg_table_name='slumber_party_invitations' then
  recipient_id:=new.recipient_id; event:='invite:'||new.id; category:='invitation'; expiry:=new.expires_at;
 elsif tg_table_name='social_support' then
  if new.source->>'partyID' is not null then perform private.night_flock_v4_signal_party((new.source->>'partyID')::uuid); end if;
  if tg_op='UPDATE' then return null; end if;
  recipient_id:=new.recipient; event:='support:'||new.id; global_message:=new.source->>'kind'='global';
 elsif tg_table_name='night_flock_v4_membership_stream_reactions' then
  select e.user_id into recipient_id from private.night_flock_v4_membership_stream_activities a
   join private.night_flock_v4_membership_epochs e on e.id=a.member_epoch_id where a.id=new.activity_id;
  event:='legacy:'||new.id;
 elsif tg_table_name='night_flock_v4_membership_stream_live_reactions' then
  select user_id into recipient_id from private.night_flock_v4_memberships where id=new.target_member_id;
  event:='legacy:'||new.id;
 elsif tg_table_name='night_flock_v4_reactions' then
  select m.user_id into recipient_id from public.night_flock_v4_party_activities a
   join private.night_flock_v4_memberships m on m.id=a.member_id where a.id=new.party_activity_id;
  event:='legacy:'||new.id;
 elsif tg_table_name='campfire_encouragements' then
  select user_id into recipient_id from private.night_flock_v4_membership_epochs where id=new.member_epoch_id;
  event:='campfire:'||new.member_epoch_id||':'||new.source_id||':'||new.sender_epoch_id;
 elsif tg_table_name='global_campfire_encouragements' then
  select user_id into recipient_id from private.global_campfire_sessions where id=new.session_id;
  event:='global:'||new.session_id||':'||md5(new.sender::text); global_message:=true;
 end if;
 if recipient_id is null then return null; end if;
 -- Opting in later does not flood someone with historical alerts.
 if exists(select 1 from private.social_notification_preferences p where p.user_id=recipient_id
   and (case when category='invitation' then p.invitations else p.cheers and (not global_message or p.global_cheers) end)) then
  insert into private.social_alert_events(recipient,event_id,kind,is_global,due_at,expires_at)
  values(recipient_id,event,category,global_message,now()+case when category='cheer' then interval '2 minutes' else interval '0' end,expiry)
  on conflict do nothing;
 end if;
 return null;
end $$;
create trigger social_invitation_alert after insert on private.slumber_party_invitations for each row execute function private.queue_social_alert();
create trigger social_support_alert after insert or update on private.social_support for each row execute function private.queue_social_alert();
create trigger social_legacy_cheer_alert after insert on private.night_flock_v4_membership_stream_reactions for each row execute function private.queue_social_alert();
create trigger social_global_cheer_alert after insert on private.global_campfire_encouragements for each row execute function private.queue_social_alert();
create trigger social_live_cheer_alert after insert on private.night_flock_v4_membership_stream_live_reactions for each row execute function private.queue_social_alert();
create trigger social_round_cheer_alert after insert on public.night_flock_v4_reactions for each row execute function private.queue_social_alert();
create trigger social_campfire_cheer_alert after insert on private.campfire_encouragements for each row execute function private.queue_social_alert();

create function private.social_alert_eligible(e private.social_alert_events) returns boolean
language sql stable security definer set search_path='' as $$
 select e.expires_at>now() and exists(select 1 from private.social_notification_preferences p where p.user_id=e.recipient
  and case when e.kind='invitation' then p.invitations else p.cheers and (not e.is_global or p.global_cheers) end)
 and exists(select 1 from private.social_inbox_events(e.recipient) v where v.id=e.event_id)
 and not exists(select 1 from private.social_inbox_reads r where r.user_id=e.recipient and r.event_id=e.event_id)
$$;

create function public.claim_social_alerts() returns jsonb language plpgsql security definer set search_path='' as $$
declare recipient_id uuid; chosen private.social_alert_events%rowtype; result jsonb:='[]';
begin
 update private.social_alert_events e set state='terminal' where state='pending' and (expires_at<=now() or attempts>=3);
 for recipient_id in select distinct recipient from private.social_alert_events where state='pending' and due_at<=now() limit 10 loop
  -- Serializes concurrent workers for a recipient, including invitations vs cheers.
  if not pg_try_advisory_xact_lock(hashtextextended(recipient_id::text,28)) then continue; end if;
  if exists(select 1 from private.social_alert_events where recipient=recipient_id and state='pending' and lease_until>now()) then continue; end if;
  select * into chosen from private.social_alert_events where recipient=recipient_id and state='pending' and due_at<=now() order by due_at,id limit 1 for update skip locked;
  if chosen.id is null then continue; end if;
  if not private.social_alert_eligible(chosen) then
   update private.social_alert_events set state='terminal' where id=chosen.id; continue;
  end if;
  update private.social_alert_events set lease=gen_random_uuid(),lease_until=now()+interval '1 minute',
   batch_cutoff=now(),attempts=attempts+1 where id=chosen.id returning * into chosen;
  result:=result||jsonb_build_array(jsonb_build_object('id',chosen.id,'lease',chosen.lease));
 end loop;
 return result;
end $$;

create function public.social_alert_payload(p_id uuid,p_lease uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare e private.social_alert_events%rowtype; devices jsonb; zone text; throttled boolean;
begin
 select * into e from private.social_alert_events where id=p_id and lease=p_lease and lease_until>now() and state='pending';
 if e.id is null or not private.social_alert_eligible(e) then return null; end if;
 select time_zone into zone from private.campfire_devices where user_id=e.recipient and enabled order by updated_at desc,installation_id limit 1;
 zone:=coalesce(zone,'UTC');
 throttled:=e.kind='cheer' and e.sent_at is null and (
  exists(select 1 from private.social_alert_events where recipient=e.recipient and kind='cheer' and sent_at>now()-interval '1 hour')
  or (select count(*) from private.social_alert_events where recipient=e.recipient and kind='cheer'
   and (sent_at at time zone zone)::date=(now() at time zone zone)::date)>=3);
 if throttled then return jsonb_build_object('defer',true); end if;
 -- An active quiet window on any registered device suppresses the account.
 select coalesce(jsonb_agg(jsonb_build_object('token',d.token,'environment',d.environment)),'[]') into devices
 from private.campfire_devices d where d.user_id=e.recipient and d.enabled and d.updated_at>now()-interval '30 days'
 and not(d.token=any(e.accepted_tokens))
 and not exists(select 1 from private.campfire_devices q where q.user_id=e.recipient and q.enabled and q.updated_at>now()-interval '30 days'
  and (q.quiet_until>now() or (q.quiet_start<>q.quiet_end and case when q.quiet_start<q.quiet_end then
   extract(hour from now() at time zone q.time_zone)>=q.quiet_start and extract(hour from now() at time zone q.time_zone)<q.quiet_end
   else extract(hour from now() at time zone q.time_zone)>=q.quiet_start or extract(hour from now() at time zone q.time_zone)<q.quiet_end end)));
 return jsonb_build_object('devices',devices,'eventID',e.event_id,'ownerID',e.recipient,'expiresAt',e.expires_at,
  'defer',jsonb_array_length(devices)=0 and exists(select 1 from private.campfire_devices d where d.user_id=e.recipient and d.enabled and d.updated_at>now()-interval '30 days' and not(d.token=any(e.accepted_tokens))),
  'title','Counting Sheep','body',case when e.kind='invitation' then 'You have a Slumber Party invitation.' else 'You received encouragement.' end);
end $$;

create function public.settle_social_alert(p_id uuid,p_lease uuid,p_action text,p_token text default null,p_accepted boolean default false)
returns boolean language plpgsql security definer set search_path='' as $$
declare e private.social_alert_events%rowtype;
begin
 select * into e from private.social_alert_events where id=p_id and lease=p_lease and lease_until>now() and state='pending' for update;
 if e.id is null then return false; end if;
 if p_action='device' then
  update private.social_alert_events set accepted_tokens=array_append(accepted_tokens,p_token),
   sent_at=case when p_accepted then coalesce(sent_at,now()) else sent_at end
   where id=e.id and p_token is not null and not(p_token=any(accepted_tokens));
 elsif p_action='defer' then
  update private.social_alert_events set due_at=now()+interval '15 minutes',attempts=greatest(0,attempts-1),lease=null,lease_until=null where id=e.id;
 elsif p_action='retry' then
  update private.social_alert_events set due_at=now()+interval '30 seconds',lease=null,lease_until=null where id=e.id;
 elsif p_action in('finish','terminal') then
  update private.social_alert_events set state=case when sent_at is not null then 'accepted' else 'terminal' end,lease=null,lease_until=null where id=e.id;
  -- One generic alert represents every due cheer at claim time; later arrivals
  -- stay pending. Never coalesce addressed invitations or extend their expiry.
  if e.kind='cheer' and e.sent_at is not null then
   update private.social_alert_events set state='terminal' where recipient=e.recipient and kind='cheer'
    and state='pending' and due_at<=e.batch_cutoff and lease_until is null;
  end if;
 else raise exception 'invalid_request'; end if;
 return true;
end $$;

create function private.limit_party_invitation_recipient() returns trigger language plpgsql security definer set search_path='' as $$
begin
 -- Stable per-recipient serialization prevents many senders racing the limit.
 perform pg_advisory_xact_lock(hashtextextended(new.recipient_id::text,29));
 if not exists(select 1 from private.slumber_party_invitations where party_id=new.party_id and recipient_id=new.recipient_id and status='pending')
 and (select count(*) from private.slumber_party_invitations where recipient_id=new.recipient_id and created_at>now()-interval '1 day')>=20 then raise exception 'rate_limited'; end if;
 return new;
end $$;
create trigger social_invitation_recipient_limit before insert on private.slumber_party_invitations for each row execute function private.limit_party_invitation_recipient();

create function private.prune_social_inbox() returns void language sql security definer set search_path='' as $$
 delete from private.social_alert_events where expires_at<now()-interval '2 days';
 delete from private.social_inbox_reads where read_at<now()-interval '31 days';
 -- Keep command tombstones through the longest valid source window, including removal.
 delete from private.social_support where created_at<now()-interval '91 days';
$$;
select cron.schedule('social-inbox-retention','45 3 * * *','select private.prune_social_inbox()');
revoke all on function private.queue_social_alert(),private.social_alert_eligible(private.social_alert_events),
 private.limit_party_invitation_recipient(),private.prune_social_inbox(),public.claim_social_alerts(),public.social_alert_payload(uuid,uuid),
 public.settle_social_alert(uuid,uuid,text,text,boolean) from public,anon,authenticated,service_role;
grant execute on function public.claim_social_alerts(),public.social_alert_payload(uuid,uuid),public.settle_social_alert(uuid,uuid,text,text,boolean) to service_role;
