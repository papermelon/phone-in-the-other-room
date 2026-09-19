-- Standalone local contract fixture, NOT a migration. Run only in the dedicated
-- disposable database; the full Supabase stack supplies these existing contracts.
do $$ begin
 if current_database()<>'campfire_visibility_test' then raise exception 'Use the isolated Campfire test database'; end if;
end $$;
do $$ declare r text; begin
 foreach r in array array['anon','authenticated','service_role'] loop
 if not exists(select 1 from pg_roles where rolname=r) then execute format('create role %I',r); end if;
 end loop;
end $$;
create schema auth;
create schema private;
-- Records scheduling intent only. This fixture does not claim to run pg_cron.
create schema cron;
create table cron.job(jobname text primary key,schedule text,command text);
create function cron.schedule(n text,s text,c text) returns bigint language sql as $$
 insert into cron.job values(n,s,c); select 1::bigint;
$$;
create table auth.users(id uuid primary key,is_anonymous boolean not null default false,email_confirmed_at timestamptz);
create table public.night_flock_blocks(
 blocker_user_id uuid not null references auth.users(id),blocked_user_id uuid not null references auth.users(id),
 primary key(blocker_user_id,blocked_user_id));
create function private.is_apple_linked_night_flock_user(u uuid) returns boolean language sql stable as $$
 select exists(select 1 from auth.users where id=u and not is_anonymous and email_confirmed_at is not null);
$$;
create function private.night_flock_users_blocked(a uuid,b uuid) returns boolean language sql stable as $$
 select exists(select 1 from public.night_flock_blocks where (blocker_user_id=a and blocked_user_id=b) or (blocker_user_id=b and blocked_user_id=a));
$$;
