begin;

insert into auth.users (id, instance_id, aud, role, created_at, updated_at)
values
  (
    '10000000-0000-0000-0000-000000000021',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    now(),
    now()
  ),
  (
    '10000000-0000-0000-0000-000000000022',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    now(),
    now()
  );

do $$
begin
  if has_table_privilege('authenticated', 'public.app_feedback', 'select')
    or has_table_privilege('authenticated', 'public.app_feedback', 'insert') then
    raise exception 'authenticated clients received direct feedback-table access';
  end if;
  if exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'app_feedback'
  ) then
    raise exception 'app_feedback unexpectedly exposes a client RLS policy';
  end if;
  if not exists (
    select 1 from storage.buckets
    where id = 'feedback-attachments'
      and public is false
      and file_size_limit = 3000000
      and allowed_mime_types = array['image/jpeg']
  ) then
    raise exception 'private feedback attachment bucket is misconfigured';
  end if;
  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'feedback_attachments_insert_own_prefix'
  ) then
    raise exception 'attachment ownership policy is missing';
  end if;
end;
$$;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000021',
  true
);
select set_config('request.jwt.claim.role', 'authenticated', true);

insert into storage.objects (bucket_id, name, owner_id)
values (
  'feedback-attachments',
  '10000000-0000-0000-0000-000000000021/50000000-0000-4000-8000-000000000021/attachment-1.jpg',
  '10000000-0000-0000-0000-000000000021'
);

insert into storage.objects (bucket_id, name, owner_id, created_at)
values (
  'feedback-attachments',
  '10000000-0000-0000-0000-000000000021/50000000-0000-4000-8000-000000000021/attachment-2.jpg',
  '10000000-0000-0000-0000-000000000021',
  now() - interval '181 days'
);

do $$
begin
  begin
    insert into storage.objects (bucket_id, name, owner_id)
    values (
      'feedback-attachments',
      '10000000-0000-0000-0000-000000000022/50000000-0000-4000-8000-000000000021/attachment-1.jpg',
      '10000000-0000-0000-0000-000000000021'
    );
    raise exception 'foreign storage prefix was accepted';
  exception when insufficient_privilege then null;
  end;
end;
$$;

set local role service_role;

do $$
begin
  if not exists (
    select 1 from public.expired_feedback_attachment_paths()
    where path = '10000000-0000-0000-0000-000000000021/50000000-0000-4000-8000-000000000021/attachment-2.jpg'
  ) then
    raise exception 'expired orphan attachment was not selected for cleanup';
  end if;
end;
$$;

select * from public.submit_app_feedback(
  '50000000-0000-4000-8000-000000000021',
  '10000000-0000-0000-0000-000000000021',
  'bug',
  'The start button did not respond.',
  null,
  true,
  '1.0',
  '1',
  'iOS 19.0',
  'iPhone',
  array[
    '10000000-0000-0000-0000-000000000021/50000000-0000-4000-8000-000000000021/attachment-1.jpg'
  ]
);

-- Replaying the same UUID is idempotent and does not create another row.
select * from public.submit_app_feedback(
  '50000000-0000-4000-8000-000000000021',
  '10000000-0000-0000-0000-000000000021',
  'bug',
  'The start button did not respond.',
  null,
  true,
  '1.0',
  '1',
  'iOS 19.0',
  'iPhone',
  array[
    '10000000-0000-0000-0000-000000000021/50000000-0000-4000-8000-000000000021/attachment-1.jpg'
  ]
);

do $$
begin
  if (select count(*) from public.app_feedback
      where id = '50000000-0000-4000-8000-000000000021') <> 1 then
    raise exception 'idempotent replay created a duplicate';
  end if;
end;
$$;

do $$
begin
  begin
    perform public.submit_app_feedback(
      '50000000-0000-4000-8000-000000000022',
      '10000000-0000-0000-0000-000000000021',
      'invalid', 'This category must be rejected.', null, false,
      null, null, null, null, array[]::text[]
    );
    raise exception 'invalid category was accepted';
  exception when check_violation then null;
  end;

  begin
    perform public.submit_app_feedback(
      '50000000-0000-4000-8000-000000000023',
      '10000000-0000-0000-0000-000000000021',
      'general', 'This path belongs to another account.', null, false,
      null, null, null, null,
      array[
        '10000000-0000-0000-0000-000000000022/50000000-0000-4000-8000-000000000023/attachment-1.jpg'
      ]
    );
    raise exception 'foreign attachment prefix was accepted';
  exception when check_violation then null;
  end;

  begin
    perform public.submit_app_feedback(
      '50000000-0000-4000-8000-000000000024',
      '10000000-0000-0000-0000-000000000021',
      'general', 'Four attachments must be rejected.', null, false,
      null, null, null, null,
      array[
        '10000000-0000-0000-0000-000000000021/50000000-0000-4000-8000-000000000024/attachment-1.jpg',
        '10000000-0000-0000-0000-000000000021/50000000-0000-4000-8000-000000000024/attachment-2.jpg',
        '10000000-0000-0000-0000-000000000021/50000000-0000-4000-8000-000000000024/attachment-3.jpg',
        '10000000-0000-0000-0000-000000000021/50000000-0000-4000-8000-000000000024/attachment-4.jpg'
      ]
    );
    raise exception 'four attachments were accepted';
  exception when check_violation then null;
  end;
end;
$$;

-- Add four more valid reports; the first report plus these reaches the rolling limit.
select * from public.submit_app_feedback(
  '50000000-0000-4000-8000-000000000031',
  '10000000-0000-0000-0000-000000000021',
  'general', 'Feedback number two is valid.', null, false,
  null, null, null, null, array[]::text[]
);
select * from public.submit_app_feedback(
  '50000000-0000-4000-8000-000000000032',
  '10000000-0000-0000-0000-000000000021',
  'general', 'Feedback number three is valid.', null, false,
  null, null, null, null, array[]::text[]
);
select * from public.submit_app_feedback(
  '50000000-0000-4000-8000-000000000033',
  '10000000-0000-0000-0000-000000000021',
  'featureRequest', 'Feedback number four is valid.', null, false,
  null, null, null, null, array[]::text[]
);
select * from public.submit_app_feedback(
  '50000000-0000-4000-8000-000000000034',
  '10000000-0000-0000-0000-000000000021',
  'bug', 'Feedback number five is valid.', null, false,
  null, null, null, null, array[]::text[]
);

do $$
begin
  begin
    perform public.submit_app_feedback(
      '50000000-0000-4000-8000-000000000035',
      '10000000-0000-0000-0000-000000000021',
      'general', 'Feedback number six must be rate limited.', null, false,
      null, null, null, null, array[]::text[]
    );
    raise exception 'sixth rolling-day report was accepted';
  exception when raise_exception then
    if sqlerrm <> 'feedback limit reached' then raise; end if;
  end;
end;
$$;

do $$
declare
  claimed public.app_feedback%rowtype;
begin
  select * into claimed
  from public.claim_feedback_delivery('50000000-0000-4000-8000-000000000021');
  if claimed.notification_state <> 'sending' or claimed.notification_attempts <> 1 then
    raise exception 'first delivery claim was not recorded';
  end if;

  perform public.finish_feedback_delivery(claimed.id, false, 'provider unavailable');
  select * into claimed
  from public.claim_feedback_delivery('50000000-0000-4000-8000-000000000021');
  if claimed.notification_attempts <> 2 then
    raise exception 'notification retry was not counted';
  end if;

  perform public.finish_feedback_delivery(claimed.id, true, null);
  if exists (
    select 1 from public.claim_feedback_delivery('50000000-0000-4000-8000-000000000021')
  ) then
    raise exception 'sent feedback was claimed again';
  end if;
  if not exists (
    select 1 from public.app_feedback
    where id = '50000000-0000-4000-8000-000000000021'
      and notification_state = 'sent'
      and notification_attempts = 2
      and notified_at is not null
  ) then
    raise exception 'successful notification was not finalized';
  end if;

  update public.app_feedback
  set notification_state = 'sending',
      notification_attempts = 1,
      notification_last_attempt_at = now() - interval '11 minutes'
  where id = '50000000-0000-4000-8000-000000000031';
  select * into claimed
  from public.claim_feedback_delivery('50000000-0000-4000-8000-000000000031');
  if claimed.notification_attempts <> 2 then
    raise exception 'stale sending notification was not reclaimed';
  end if;
end;
$$;

rollback;
