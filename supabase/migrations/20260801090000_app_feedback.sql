create schema if not exists private;

create or replace function private.feedback_paths_owned_by(
  owner_id uuid,
  submission_id uuid,
  paths text[]
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select
    coalesce(cardinality(paths), 0) between 0 and 3
    and not exists (
      select 1
      from unnest(coalesce(paths, array[]::text[])) as path
      where path !~ (
        '^' || owner_id::text || '/' || submission_id::text ||
        '/attachment-[1-3]\.jpg$'
      )
    );
$$;

revoke all on function private.feedback_paths_owned_by(uuid, uuid, text[]) from public;
grant execute on function private.feedback_paths_owned_by(uuid, uuid, text[]) to service_role;

create table public.app_feedback (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null check (category in ('bug', 'featureRequest', 'general')),
  message text not null check (char_length(btrim(message)) between 10 and 4000),
  reply_email text check (
    reply_email is null or (
      char_length(reply_email) between 3 and 254
      and reply_email ~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
    )
  ),
  diagnostics_included boolean not null default true,
  app_version text check (app_version is null or char_length(app_version) between 1 and 64),
  app_build text check (app_build is null or char_length(app_build) between 1 and 64),
  ios_version text check (ios_version is null or char_length(ios_version) between 1 and 64),
  device_family text check (device_family is null or char_length(device_family) between 1 and 64),
  attachment_paths text[] not null default array[]::text[],
  notification_state text not null default 'pending'
    check (notification_state in ('pending', 'sending', 'sent', 'failed')),
  notification_attempts integer not null default 0
    check (notification_attempts between 0 and 5),
  notification_last_attempt_at timestamptz,
  notification_last_error text check (
    notification_last_error is null or char_length(notification_last_error) <= 1000
  ),
  created_at timestamptz not null default now(),
  notified_at timestamptz,
  constraint app_feedback_attachment_paths_owned
    check (private.feedback_paths_owned_by(user_id, id, attachment_paths)),
  constraint app_feedback_notification_consistency check (
    (notification_state = 'sent' and notified_at is not null)
    or (notification_state <> 'sent' and notified_at is null)
  ),
  constraint app_feedback_attempt_consistency check (
    (notification_attempts = 0 and notification_last_attempt_at is null)
    or (notification_attempts > 0 and notification_last_attempt_at is not null)
  )
);

create index app_feedback_pending_notification_idx
on public.app_feedback (created_at)
where notification_state in ('pending', 'sending') and notification_attempts < 5;

create index app_feedback_user_rate_limit_idx
on public.app_feedback (user_id, created_at desc);

alter table public.app_feedback enable row level security;

-- Edge Functions use the service role. App clients deliberately receive no table access.
revoke all on table public.app_feedback from public, anon, authenticated;
grant select, insert, update, delete on table public.app_feedback to service_role;

create or replace function public.submit_app_feedback(
  p_id uuid,
  p_user_id uuid,
  p_category text,
  p_message text,
  p_reply_email text,
  p_diagnostics_included boolean,
  p_app_version text,
  p_app_build text,
  p_ios_version text,
  p_device_family text,
  p_attachment_paths text[]
)
returns table(feedback_id uuid, accepted_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  existing public.app_feedback%rowtype;
begin
  select * into existing from public.app_feedback where id = p_id;
  if found then
    if existing.user_id <> p_user_id then
      raise exception 'submission ID unavailable';
    end if;
    return query select existing.id, existing.created_at;
    return;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_user_id::text, 0)
  );
  if (
    select count(*)
    from public.app_feedback
    where user_id = p_user_id
      and created_at >= now() - interval '24 hours'
  ) >= 5 then
    raise exception 'feedback limit reached';
  end if;

  return query
  insert into public.app_feedback (
    id, user_id, category, message, reply_email, diagnostics_included,
    app_version, app_build, ios_version, device_family, attachment_paths
  ) values (
    p_id, p_user_id, p_category, p_message, p_reply_email,
    p_diagnostics_included, p_app_version, p_app_build, p_ios_version,
    p_device_family, p_attachment_paths
  )
  returning app_feedback.id, app_feedback.created_at;
end;
$$;

revoke all on function public.submit_app_feedback(
  uuid, uuid, text, text, text, boolean, text, text, text, text, text[]
) from public, anon, authenticated;
grant execute on function public.submit_app_feedback(
  uuid, uuid, text, text, text, boolean, text, text, text, text, text[]
) to service_role;

create or replace function public.claim_feedback_delivery(p_id uuid default null)
returns setof public.app_feedback
language sql
security definer
set search_path = ''
as $$
  with candidate as (
    select feedback.id
    from public.app_feedback as feedback
    where (
        feedback.notification_state = 'pending'
        or (
          feedback.notification_state = 'sending'
          and feedback.notification_last_attempt_at <= now() - interval '10 minutes'
        )
      )
      and feedback.notification_attempts < 5
      and (p_id is null or feedback.id = p_id)
    order by feedback.created_at
    limit 1
    for update skip locked
  )
  update public.app_feedback as feedback
  set notification_state = 'sending',
      notification_attempts = feedback.notification_attempts + 1,
      notification_last_attempt_at = now(),
      notification_last_error = null
  from candidate
  where feedback.id = candidate.id
  returning feedback.*;
$$;

create or replace function public.finish_feedback_delivery(
  p_id uuid,
  p_succeeded boolean,
  p_error text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.app_feedback
  set notification_state = case
        when p_succeeded then 'sent'
        when notification_attempts >= 5 then 'failed'
        else 'pending'
      end,
      notification_last_error = case
        when p_succeeded then null
        else left(coalesce(p_error, 'Unknown delivery error'), 1000)
      end,
      notified_at = case when p_succeeded then now() else null end
  where id = p_id and notification_state = 'sending';
end;
$$;

revoke all on function public.claim_feedback_delivery(uuid) from public, anon, authenticated;
revoke all on function public.finish_feedback_delivery(uuid, boolean, text)
from public, anon, authenticated;
grant execute on function public.claim_feedback_delivery(uuid) to service_role;
grant execute on function public.finish_feedback_delivery(uuid, boolean, text) to service_role;

create or replace function public.feedback_delivery_candidate_ids()
returns table(id uuid)
language sql
security definer
set search_path = ''
as $$
  select feedback.id
  from public.app_feedback as feedback
  where (
      feedback.notification_state = 'pending'
      or (
        feedback.notification_state = 'sending'
        and feedback.notification_last_attempt_at <= now() - interval '10 minutes'
      )
    )
    and feedback.notification_attempts < 5
  order by feedback.created_at
  limit 25;
$$;

revoke all on function public.feedback_delivery_candidate_ids()
from public, anon, authenticated;
grant execute on function public.feedback_delivery_candidate_ids() to service_role;

create or replace function public.expired_feedback_attachment_paths()
returns table(path text)
language sql
security definer
set search_path = ''
as $$
  select objects.name
  from storage.objects as objects
  where objects.bucket_id = 'feedback-attachments'
    and objects.created_at < now() - interval '180 days'
    and not exists (
      select 1
      from public.app_feedback as feedback
      where objects.name = any(feedback.attachment_paths)
    )
  order by objects.created_at
  limit 100;
$$;

revoke all on function public.expired_feedback_attachment_paths()
from public, anon, authenticated;
grant execute on function public.expired_feedback_attachment_paths() to service_role;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'feedback-attachments',
  'feedback-attachments',
  false,
  3000000,
  array['image/jpeg']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "feedback_attachments_insert_own_prefix"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'feedback-attachments'
  and (storage.foldername(name))[1] = auth.uid()::text
  and cardinality(storage.foldername(name)) = 2
  and (storage.foldername(name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  and storage.filename(name) ~ '^attachment-[1-3]\.jpg$'
);

create policy "feedback_attachments_delete_own_prefix"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'feedback-attachments'
  and (storage.foldername(name))[1] = auth.uid()::text
  and cardinality(storage.foldername(name)) = 2
  and (storage.foldername(name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  and storage.filename(name) ~ '^attachment-[1-3]\.jpg$'
);
