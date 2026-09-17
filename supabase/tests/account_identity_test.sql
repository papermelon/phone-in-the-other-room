begin;

insert into auth.users (id,instance_id,aud,role,email,email_confirmed_at,is_anonymous,created_at,updated_at) values
  ('61000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','apple@example.test',null,false,now(),now()),
  ('61000000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','password@example.test',now(),false,now(),now()),
  ('61000000-0000-4000-8000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','unverified@example.test',null,false,now(),now()),
  ('61000000-0000-4000-8000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','second@example.test',now(),false,now(),now());
insert into auth.identities(id,user_id,provider_id,provider,identity_data)
values (gen_random_uuid(),'61000000-0000-4000-8000-000000000001','apple-test','apple','{"sub":"apple-test"}'::jsonb);

do $$
declare apple_id uuid := '61000000-0000-4000-8000-000000000001';
  password_id uuid := '61000000-0000-4000-8000-000000000002';
  unverified_id uuid := '61000000-0000-4000-8000-000000000003';
  second_id uuid := '61000000-0000-4000-8000-000000000004';
  state jsonb; generation uuid; saved jsonb; revision_id uuid;
  payload jsonb := '{"schemaVersion":1,"economyVersion":1,"lineageID":"62000000-0000-4000-8000-000000000001","farm":{"cumulativeCredit":{"migrationCompleted":true}},"search":{},"welcome":{},"socialRewards":{},"sunrise":{},"completedWindDownCount":0,"keepsakes":[],"deliveredWindDownRunIDs":[],"deliveredEffectIDs":[]}'::jsonb;
begin
  -- Legacy Apple-only entrypoints retain their authorization and payload behavior.
  perform set_config('request.jwt.claim.sub',apple_id::text,true);
  if public.farm_save_v1('{"action":"lookup"}'::jsonb)->>'capability' <> 'farm_save_v1' then
    raise exception 'legacy farm capability changed';
  end if;
  perform set_config('request.jwt.claim.sub',password_id::text,true);
  begin perform public.farm_save_v1('{"action":"lookup"}'::jsonb); raise exception 'legacy endpoint accepted password account';
  exception when insufficient_privilege then null; end;
  if not private.is_apple_linked_night_flock_user(password_id) then
    raise exception 'verified password account remained excluded from account features';
  end if;
  if private.is_apple_linked_night_flock_user(unverified_id) then
    raise exception 'unverified password account became eligible';
  end if;

  state := public.farm_account_sync_v1('{"action":"status"}'::jsonb);
  if state->>'accepted' <> 'false' then raise exception 'account sync was accepted without the client action'; end if;
  begin perform public.farm_account_sync_v1('{"action":"lookup"}'::jsonb); raise exception 'account sync read before acceptance';
  exception when insufficient_privilege then null; end;
  state := public.farm_account_sync_v1('{"action":"accept"}'::jsonb);
  if state->>'status' <> 'accepted' or state->>'capability' <> 'farm_account_sync_v1' then raise exception 'account sync acceptance failed'; end if;
  generation := (state->>'generation')::uuid;
  saved := public.farm_account_sync_v1(jsonb_build_object('action','put','generation',generation,'operationID',gen_random_uuid(),'payload',payload));
  if saved->>'status' <> 'saved' or saved->>'capability' <> 'farm_account_sync_v1' then raise exception 'password Farm save failed'; end if;
  revision_id := (saved#>>'{revision,id}')::uuid;
  if (public.farm_account_sync_revision_v1(jsonb_build_object('action','read','revisionID',revision_id))#>>'{head,id}')::uuid <> revision_id then
    raise exception 'password Farm revision read failed';
  end if;
  if public.farm_account_sync_v1(jsonb_build_object('action','status'))->>'accepted' <> 'true' then raise exception 'acceptance marker not durable'; end if;

  perform set_config('request.jwt.claim.sub',second_id::text,true);
  state := public.farm_account_sync_v1('{"action":"accept"}'::jsonb);
  if state->'head' <> 'null' then raise exception 'account sync exposed another owner head'; end if;
  begin perform public.farm_account_sync_revision_v1(jsonb_build_object('action','read','revisionID',revision_id)); raise exception 'account sync read crossed owners';
  exception when raise_exception then if sqlerrm <> 'farm_revision_unavailable' then raise; end if; end;

  perform set_config('request.jwt.claim.sub',password_id::text,true);
  state := public.account_username_v1('get');
  if state->'username' <> 'null' then raise exception 'unexpected username'; end if;
  state := public.account_username_v1('claim','Shepherd_1');
  if state->>'username' <> 'shepherd_1' then raise exception 'username normalization failed'; end if;
  if public.account_username_v1('claim','shepherd_1') <> state then raise exception 'username retry was not idempotent'; end if;
  perform set_config('request.jwt.claim.sub',second_id::text,true);
  begin perform public.account_username_v1('claim','shepherd_1'); raise exception 'duplicate username accepted';
  exception when unique_violation then null; end;
  perform set_config('request.jwt.claim.sub',unverified_id::text,true);
  begin perform public.account_username_v1('claim','unverified'); raise exception 'unverified email claimed username';
  exception when insufficient_privilege then null; end;

  -- Only the service-role path can obtain an email for username login.
  perform set_config('request.jwt.claim.role','service_role',true);
  if public.account_username_login_email_v1('shepherd_1') <> 'password@example.test' then raise exception 'service username lookup failed'; end if;
  if public.account_password_login_rate_limit_v1(repeat('a',64),repeat('b',64),1,1,300) is distinct from true
    or public.account_password_login_rate_limit_v1(repeat('a',64),repeat('b',64),1,1,300) is distinct from false
  then raise exception 'rate limiter did not reject repeated credentials'; end if;

  if has_table_privilege('authenticated','private.account_usernames','select')
    or has_table_privilege('authenticated','private.account_password_login_limits','select')
    or has_function_privilege('authenticated','public.account_username_login_email_v1(text)','execute')
    or has_function_privilege('authenticated','public.account_password_login_rate_limit_v1(text,text,integer,integer,integer)','execute')
  then raise exception 'private account identity surface exposed to authenticated clients'; end if;
  raise notice 'Account identity, username, rate limit, and account Farm sync tests passed';
end $$;

rollback;
