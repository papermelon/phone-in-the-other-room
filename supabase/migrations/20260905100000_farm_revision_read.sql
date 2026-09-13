-- Reading a retained copy never changes the head or uploads this device's Farm.
create function public.farm_save_revision_v1(c jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare current_state jsonb; revision jsonb;
begin
  if jsonb_typeof(c)<>'object' or c - array['action','revisionID'] <> '{}'::jsonb
    or c->>'action' is distinct from 'read' or c->>'revisionID' is null
  then raise exception 'farm_invalid_request'; end if;
  -- Reuse the Apple identity check and account lock of the main RPC.
  current_state := public.farm_save_v1('{"action":"lookup"}'::jsonb);
  revision := private.farm_save_revision(auth.uid(),(c->>'revisionID')::uuid);
  if revision is null then raise exception 'farm_revision_unavailable'; end if;
  return jsonb_build_object('capability','farm_save_v1','generation',current_state->'generation',
    'head',revision,'currentRevisionID',current_state#>'{head,id}','revisions','[]'::jsonb);
end $$;
revoke all on function public.farm_save_revision_v1(jsonb) from public, anon;
grant execute on function public.farm_save_revision_v1(jsonb) to authenticated;
