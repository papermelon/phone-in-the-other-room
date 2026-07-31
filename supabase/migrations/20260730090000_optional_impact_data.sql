create table if not exists public.impact_nights (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  schema_version integer not null check (schema_version between 1 and 10),
  relative_night integer not null check (relative_night between -3650 and 3650),
  planned_quiet_minutes integer not null check (planned_quiet_minutes between 0 and 1440),
  quiet_minutes integer not null check (quiet_minutes between 0 and 1440),
  completed_ritual boolean not null,
  start_method text check (
    start_method is null or start_method in ('honorTimer', 'watchPlacement', 'qrCode', 'nfcTag')
  ),
  shield_evidence text not null check (
    shield_evidence in ('notRequested', 'unavailable', 'partial', 'observed')
  ),
  sleep_minutes integer check (sleep_minutes between 0 and 1440),
  core_sleep_minutes integer check (core_sleep_minutes between 0 and 1440),
  deep_sleep_minutes integer check (deep_sleep_minutes between 0 and 1440),
  rem_sleep_minutes integer check (rem_sleep_minutes between 0 and 1440),
  restfulness text check (
    restfulness is null or restfulness in ('notMuch', 'somewhat', 'rested', 'notSure')
  ),
  app_version text not null check (length(app_version) between 1 and 64),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, relative_night)
);

alter table public.impact_nights enable row level security;

create policy "impact_nights_select_own"
on public.impact_nights for select
to authenticated
using (user_id = auth.uid());

create policy "impact_nights_insert_own"
on public.impact_nights for insert
to authenticated
with check (user_id = auth.uid());

create policy "impact_nights_update_own"
on public.impact_nights for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "impact_nights_delete_own"
on public.impact_nights for delete
to authenticated
using (user_id = auth.uid());

create or replace function public.delete_my_impact_data()
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  deleted_count integer;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  delete from public.impact_nights where user_id = auth.uid();
  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;

revoke all on function public.delete_my_impact_data() from public, anon;
grant execute on function public.delete_my_impact_data() to authenticated;

revoke all on table public.impact_nights from public, anon;
grant select, insert, update, delete on table public.impact_nights to authenticated;
