-- Local test adapter only: model the identity row Supabase Auth creates for
-- legacy fixtures that seed only Apple provider metadata. Not a production migration.
create function auth.role() returns text language sql stable as $$ select nullif(current_setting('request.jwt.claim.role',true),'') $$;
create function auth.fixture_apple_identity() returns trigger language plpgsql as $$ begin
 if new.raw_app_meta_data->>'provider'='apple' then
 insert into auth.identities(id,user_id,provider_id,provider,identity_data)
 values(gen_random_uuid(),new.id,'fixture-'||new.id::text,'apple',jsonb_build_object('sub','fixture-'||new.id::text));
 end if; return new; end $$;
create trigger fixture_apple_identity after insert on auth.users for each row execute function auth.fixture_apple_identity();

-- Legacy tests express an Auth unlink through metadata removal. Mirror only
-- synthetic fixture identities; never touch a manually seeded real identity.
create function auth.fixture_apple_unlink() returns trigger language plpgsql as $$ begin
 if old.raw_app_meta_data->>'provider'='apple' and new.raw_app_meta_data->>'provider' is distinct from 'apple' then
 delete from auth.identities where user_id=new.id and provider_id='fixture-'||new.id::text;
 end if; return new; end $$;
create trigger fixture_apple_unlink after update of raw_app_meta_data on auth.users for each row execute function auth.fixture_apple_unlink();
