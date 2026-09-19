-- Alert tokens are account-bound and never exposed in party projections.
create table private.campfire_devices (
 installation_id uuid primary key, user_id uuid not null references auth.users(id) on delete cascade,
 token text not null check(char_length(token) between 32 and 512 and token ~ '^[0-9a-f]+$'), environment text not null check(environment in('sandbox','production')),
 enabled boolean not null, quiet_until timestamptz not null default now(),
 time_zone text not null, quiet_start int not null check(quiet_start between 0 and 23), quiet_end int not null check(quiet_end between 0 and 23),
 updated_at timestamptz not null default now(), revision bigint not null default 1, unique(token,environment)
);
-- A tombstone also fences sign-out before the first registration arrives.
create table private.campfire_device_revocations (
 installation_id uuid primary key, user_id uuid not null references auth.users(id) on delete cascade,
 revision bigint not null, updated_at timestamptz not null default now()
);
alter table private.campfire_device_revocations enable row level security;
revoke all on private.campfire_device_revocations from public,anon,authenticated,service_role;
create table private.campfire_alert_events (
 id uuid primary key default gen_random_uuid(), event_kind text not null default 'start' check(event_kind in('start','result','checkIn')), accepted_tokens text[] not null default '{}', source_epoch uuid not null, source_id uuid not null,
 recipient_epoch uuid not null references private.night_flock_v4_membership_epochs(id) on delete cascade,
 recipient_user uuid not null references auth.users(id) on delete cascade, party_id uuid not null,
 created_at timestamptz not null default now(), expires_at timestamptz not null,
 due_at timestamptz not null default now(), lease uuid, lease_until timestamptz, attempts int not null default 0,
 state text not null default 'pending' check(state in('pending','accepted','terminal')),
 unique(recipient_user,source_id,event_kind),
 foreign key(source_epoch,source_id) references private.campfire_buddy_sessions(member_epoch_id,source_id) on delete cascade
);
alter table private.campfire_devices enable row level security;
alter table private.campfire_alert_events enable row level security;
revoke all on private.campfire_devices,private.campfire_alert_events from public,anon,authenticated,service_role;

create function public.register_campfire_device(p_user_id uuid,p_installation_id uuid,p_token text,p_environment text,p_enabled boolean,
 p_quiet_until timestamptz,p_time_zone text,p_quiet_start int,p_quiet_end int,p_revision bigint) returns boolean
language plpgsql security definer set search_path='' as $$
begin
 if not private.is_apple_linked_night_flock_user(p_user_id) then raise exception 'linked_account_required'; end if;
 if not exists(select 1 from pg_catalog.pg_timezone_names where name=p_time_zone) or p_quiet_until>now()+interval '30 hours'
  or p_quiet_until is null or p_enabled is null or p_revision is null or p_revision<1 then raise exception 'Invalid notification preferences'; end if;
 -- Serialize token rotation, account handoff and sign-out before any mutation.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_token||p_environment,1));
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_installation_id::text,2));
 if exists(select 1 from private.campfire_device_revocations where installation_id=p_installation_id and revision>=p_revision)
  or exists(select 1 from private.campfire_devices where (installation_id=p_installation_id or (token=p_token and environment=p_environment)) and revision>=p_revision)
 then return false; end if;
 -- Rebind the installation atomically when its authenticated account changes.
 delete from private.campfire_devices where token=p_token and environment=p_environment and installation_id<>p_installation_id;
 insert into private.campfire_devices values(p_installation_id,p_user_id,p_token,p_environment,p_enabled,p_quiet_until,p_time_zone,p_quiet_start,p_quiet_end,now(),p_revision)
 on conflict(installation_id) do update set user_id=excluded.user_id,token=excluded.token,environment=excluded.environment,
 enabled=excluded.enabled,quiet_until=excluded.quiet_until,time_zone=excluded.time_zone,quiet_start=excluded.quiet_start,quiet_end=excluded.quiet_end,updated_at=now(),revision=excluded.revision
 where private.campfire_devices.revision<excluded.revision;
 return true;
end $$;
create function public.unregister_campfire_device(p_user_id uuid,p_installation_id uuid,p_revision bigint) returns boolean
language plpgsql security definer set search_path='' as $$
begin
 if p_revision is null or p_revision<1 then raise exception 'Invalid notification revision'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_installation_id::text,2));
 if exists(select 1 from private.campfire_devices where installation_id=p_installation_id and user_id<>p_user_id) then return false; end if;
 insert into private.campfire_device_revocations values(p_installation_id,p_user_id,p_revision,now())
 on conflict(installation_id) do update set user_id=excluded.user_id,revision=excluded.revision,updated_at=now()
 where private.campfire_device_revocations.revision<excluded.revision;
 update private.campfire_devices set enabled=false,revision=p_revision where installation_id=p_installation_id and user_id=p_user_id and revision<p_revision;
 return true;
end $$;

create function private.campfire_queue_start() returns trigger language plpgsql security definer set search_path='' as $$
declare s private.campfire_sessions%rowtype; e private.night_flock_v4_membership_epochs%rowtype;
begin
 if not new.announce_start then return new; end if;
 select * into s from private.campfire_sessions where member_epoch_id=new.member_epoch_id and source_id=new.source_id;
 select * into e from private.night_flock_v4_membership_epochs where id=new.member_epoch_id;
 if s.ended or s.expires_at<=now() or s.started_at<now()-interval '5 minutes' then return new; end if;
 insert into private.campfire_alert_events(source_epoch,source_id,recipient_epoch,recipient_user,party_id,expires_at)
 select e.id,s.source_id,re.id,re.user_id,e.party_id,least(s.expires_at,s.started_at+interval '5 minutes')
 from private.night_flock_v4_membership_epochs re join private.night_flock_v4_memberships m on m.id=re.membership_id and m.status='active'
 join private.campfire_agreements a on a.member_epoch_id=re.id and a.version=2 and a.enabled and a.accepted_at<=s.started_at
 join private.campfire_alert_preferences pref on pref.member_epoch_id=re.id and pref.enabled
 where re.party_id=e.party_id and re.ended_at is null and re.user_id<>e.user_id and not private.night_flock_users_blocked(e.user_id,re.user_id)
 and not exists(select 1 from private.campfire_alert_events prior_event where prior_event.recipient_user=re.user_id and prior_event.party_id=e.party_id and prior_event.created_at>now()-interval '10 minutes')
 on conflict(recipient_user,source_id,event_kind) do nothing;
 return new;
end $$;
create trigger campfire_queue_start after insert on private.campfire_buddy_sessions for each row execute function private.campfire_queue_start();

create function private.campfire_queue_followup() returns trigger language plpgsql security definer set search_path='' as $$
declare recipient uuid; event_type text; e private.night_flock_v4_membership_epochs%rowtype;
begin
 if new.outcome is not null and old.outcome is null and new.buddy_epoch_id is not null then
  recipient:=new.buddy_epoch_id; event_type:='result';
 elsif new.check_in_requested and not old.check_in_requested then recipient:=new.member_epoch_id; event_type:='checkIn';
 else return new; end if;
 select * into e from private.night_flock_v4_membership_epochs where id=recipient and ended_at is null;
 if e.id is null or not exists(select 1 from private.campfire_alert_preferences where member_epoch_id=e.id and enabled) then return new; end if;
 insert into private.campfire_alert_events(event_kind,source_epoch,source_id,recipient_epoch,recipient_user,party_id,due_at,expires_at)
 values(event_type,new.member_epoch_id,new.source_id,e.id,e.user_id,e.party_id,greatest(now(),new.check_in_after),greatest(now(),new.check_in_after)+interval '24 hours')
 on conflict(recipient_user,source_id,event_kind) do nothing;
 return new;
end $$;
create trigger campfire_queue_followup after update on private.campfire_buddy_sessions for each row execute function private.campfire_queue_followup();

create function private.campfire_alert_eligible(event private.campfire_alert_events) returns boolean
language sql stable security definer set search_path='' as $$
 select event.expires_at>now() and exists(
 select 1 from private.campfire_sessions s
 join private.campfire_agreements sa on sa.member_epoch_id=s.member_epoch_id and sa.id=s.agreement_id and sa.enabled and sa.version=2
 join private.night_flock_v4_membership_epochs se on se.id=s.member_epoch_id and se.ended_at is null
 join private.night_flock_v4_memberships sm on sm.id=se.membership_id and sm.status='active'
 join private.night_flock_v4_parties p on p.id=se.party_id and p.deleted_at is null
 join private.night_flock_v4_membership_epochs re on re.id=event.recipient_epoch and re.ended_at is null and re.party_id=p.id
 join private.night_flock_v4_memberships rm on rm.id=re.membership_id and rm.status='active'
 join private.campfire_agreements ra on ra.member_epoch_id=re.id and ra.enabled and ra.version=2 and ra.accepted_at<=s.started_at
 join private.campfire_alert_preferences pref on pref.member_epoch_id=re.id and pref.enabled
 where s.member_epoch_id=event.source_epoch and s.source_id=event.source_id and ((event.event_kind='start' and not s.ended and s.expires_at>now()
 and not exists(select 1 from private.campfire_sessions newer where newer.member_epoch_id=s.member_epoch_id and newer.started_at>s.started_at)
 and not exists(select 1 from private.campfire_devices quiet_device where quiet_device.user_id=re.user_id and quiet_device.enabled and quiet_device.quiet_until>now())) or
 (event.event_kind<>'start' and exists(select 1 from private.campfire_buddy_sessions bs where bs.member_epoch_id=s.member_epoch_id and bs.source_id=s.source_id
 and ((event.event_kind='result' and bs.outcome is not null and bs.buddy_epoch_id=re.id) or
 (event.event_kind='checkIn' and bs.check_in_requested and bs.outcome is null and re.id=s.member_epoch_id
 and exists(select 1 from private.night_flock_v4_membership_epochs buddy
  join private.night_flock_v4_memberships bm on bm.id=buddy.membership_id and bm.status='active'
  join private.campfire_agreements ba on ba.member_epoch_id=buddy.id and ba.enabled and ba.version=2
  where buddy.id=bs.buddy_epoch_id and buddy.ended_at is null and not private.night_flock_users_blocked(buddy.user_id,re.user_id)))))))
 and not private.night_flock_users_blocked(se.user_id,re.user_id)
 and (event.event_kind<>'start' or not exists(select 1 from private.campfire_sessions active join private.night_flock_v4_membership_epochs ae on ae.id=active.member_epoch_id and ae.ended_at is null
  where ae.user_id=re.user_id and not active.ended and active.expires_at>now() and active.started_at<=now() and not exists(select 1 from private.campfire_sessions newer where newer.member_epoch_id=active.member_epoch_id and newer.started_at>active.started_at)))
 );
$$;
create function public.claim_campfire_alerts() returns jsonb language plpgsql security definer set search_path='' as $$
declare rows jsonb;
begin
 update private.campfire_alert_events e set state='terminal' where state='pending' and (expires_at<=now() or attempts>=3 or not private.campfire_alert_eligible(e));
 with due as (select id from private.campfire_alert_events where state='pending' and due_at<=now() and (lease_until is null or lease_until<now()) order by due_at limit 10 for update skip locked),
 claimed as (update private.campfire_alert_events e set lease=gen_random_uuid(),lease_until=now()+interval '1 minute',attempts=attempts+1 from due where e.id=due.id returning e.*)
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'lease',lease,'attempts',attempts)),'[]') into rows from claimed;
 return rows;
end $$;
create function public.campfire_alert_payload(p_id uuid,p_lease uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare e private.campfire_alert_events%rowtype; devices jsonb;
begin
 select * into e from private.campfire_alert_events where id=p_id and lease=p_lease and lease_until>now() and state='pending';
 if e.id is null or not private.campfire_alert_eligible(e) then return null; end if;
 select coalesce(jsonb_agg(jsonb_build_object('token',d.token,'environment',d.environment)),'[]') into devices
 from private.campfire_devices d where not(d.token=any(e.accepted_tokens)) and d.user_id=e.recipient_user and d.enabled and d.updated_at>now()-interval '30 days' and d.quiet_until<=now()
 and not exists(select 1 from private.campfire_devices quiet_device where quiet_device.user_id=e.recipient_user and quiet_device.enabled and quiet_device.quiet_until>now())
 and (d.quiet_start=d.quiet_end or not(case when d.quiet_start<d.quiet_end then
  extract(hour from now() at time zone d.time_zone)>=d.quiet_start and extract(hour from now() at time zone d.time_zone)<d.quiet_end
 else extract(hour from now() at time zone d.time_zone)>=d.quiet_start or extract(hour from now() at time zone d.time_zone)<d.quiet_end end));
 -- Generic lock-screen copy avoids exposing private intentions or account names.
 return jsonb_build_object('devices',devices,'partyID',e.party_id,'sourceID',e.source_id,'expiresAt',e.expires_at,
 'defer', e.event_kind<>'start' and jsonb_array_length(devices)=0 and exists(select 1 from private.campfire_devices d where d.user_id=e.recipient_user and d.enabled and not(d.token=any(e.accepted_tokens))),
 'title',case when e.event_kind='start' then 'Company at the campfire' else 'A campfire check-in' end,
 'body',case when e.event_kind='start' then 'Someone in your party started a session. Join when you’re ready.'
 when e.event_kind='result' then 'Your buddy shared how their plan went. Read it when you’re ready.'
 else 'Your buddy asked how your plan went. Share when you’re ready.' end);
end $$;
create function public.finish_campfire_alert(p_id uuid,p_lease uuid,p_retry boolean) returns boolean language plpgsql security definer set search_path='' as $$
begin
 update private.campfire_alert_events set state=case when p_retry and attempts<3 and expires_at>now()+interval '30 seconds' then 'pending' else 'accepted' end,
 due_at=now()+interval '30 seconds',lease=null,lease_until=null where id=p_id and lease=p_lease and lease_until>now();
 return found;
end $$;
create function public.record_campfire_alert_device(p_id uuid,p_lease uuid,p_token text) returns boolean language plpgsql security definer set search_path='' as $$
begin
 update private.campfire_alert_events set accepted_tokens=array_append(accepted_tokens,p_token)
 where id=p_id and lease=p_lease and lease_until>now() and not(p_token=any(accepted_tokens));
 return found;
end $$;
create function public.defer_campfire_alert(p_id uuid,p_lease uuid) returns boolean language plpgsql security definer set search_path='' as $$
begin
 update private.campfire_alert_events set due_at=now()+interval '15 minutes',attempts=greatest(0,attempts-1),lease=null,lease_until=null
 where id=p_id and lease=p_lease and lease_until>now() and event_kind<>'start';
 return found;
end $$;
create function private.prune_campfire_buddies() returns void language sql security definer set search_path='' as $$
 delete from private.campfire_buddy_sessions b using private.campfire_sessions s where b.member_epoch_id=s.member_epoch_id and b.source_id=s.source_id and s.started_at<now()-interval '7 days';
 delete from private.campfire_alert_events where expires_at<now()-interval '1 day';
 delete from private.campfire_devices where updated_at<now()-interval '30 days';
 delete from private.campfire_device_revocations where updated_at<now()-interval '90 days';
$$;
select cron.schedule('campfire-buddies-retention','25 3 * * *','select private.prune_campfire_buddies()');
revoke all on function public.register_campfire_device(uuid,uuid,text,text,boolean,timestamptz,text,int,int,bigint),public.unregister_campfire_device(uuid,uuid,bigint),
 public.claim_campfire_alerts(),public.campfire_alert_payload(uuid,uuid),public.finish_campfire_alert(uuid,uuid,boolean),private.prune_campfire_buddies(),private.campfire_queue_start(),private.campfire_alert_eligible(private.campfire_alert_events) from public,anon,authenticated;
grant execute on function public.register_campfire_device(uuid,uuid,text,text,boolean,timestamptz,text,int,int,bigint),public.unregister_campfire_device(uuid,uuid,bigint),
 public.claim_campfire_alerts(),public.campfire_alert_payload(uuid,uuid),public.finish_campfire_alert(uuid,uuid,boolean) to service_role;

revoke all on function private.campfire_queue_followup(),public.record_campfire_alert_device(uuid,uuid,text),public.defer_campfire_alert(uuid,uuid) from public,anon,authenticated;
grant execute on function public.record_campfire_alert_device(uuid,uuid,text),public.defer_campfire_alert(uuid,uuid) to service_role;

-- Activation supplies these two Vault secrets and enables pg_net. Missing
-- deployment configuration safely leaves the durable outbox undispatched.
create function private.invoke_campfire_dispatch() returns void language plpgsql security definer set search_path='' as $$
declare endpoint text; secret text;
begin
 if to_regclass('vault.decrypted_secrets') is null or to_regnamespace('net') is null then return; end if;
 execute 'select decrypted_secret from vault.decrypted_secrets where name=$1 limit 1' into endpoint using 'campfire_dispatch_url';
 execute 'select decrypted_secret from vault.decrypted_secrets where name=$1 limit 1' into secret using 'campfire_dispatch_secret';
 if endpoint is null or secret is null then return; end if;
 execute 'select net.http_post(url := $1, headers := $2, body := $3)' using endpoint,
  jsonb_build_object('Content-Type','application/json','x-dispatch-secret',secret),'{}'::jsonb;
end $$;
revoke all on function private.invoke_campfire_dispatch() from public,anon,authenticated,service_role;
select cron.schedule('campfire-alert-dispatch','* * * * *','select private.invoke_campfire_dispatch()');
