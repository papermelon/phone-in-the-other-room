-- Disposable local PostgreSQL only. Never apply to Supabase.
do $$ begin if not exists(select 1 from pg_roles where rolname='anon') then create role anon; end if; end $$;
do $$ begin if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated; end if; end $$;
do $$ begin if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role; end if; end $$;
create schema auth;
create schema private;
create schema extensions;
create extension pgcrypto with schema extensions;
create table auth.users(id uuid primary key,instance_id uuid,aud text,role text,is_anonymous bool default false,email text,email_confirmed_at timestamptz,raw_app_meta_data jsonb default '{}',raw_user_meta_data jsonb default '{}',created_at timestamptz default now(),updated_at timestamptz default now());
create table auth.identities(id uuid primary key,user_id uuid references auth.users(id) on delete cascade,provider_id text,provider text,identity_data jsonb);
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
create function auth.jwt() returns jsonb language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb $$;
grant usage on schema auth to authenticated,service_role;
create publication supabase_realtime;
-- Local-only cron registration shim: tests do not claim scheduler execution.
create schema cron;
create function cron.schedule(text,text,text) returns bigint language sql as $$select 1::bigint$$;
