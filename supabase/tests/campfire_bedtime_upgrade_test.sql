-- Run after the previous migrations, before the bedtime migration. All fixtures
-- and schema changes roll back; the runner then applies the migration normally.
begin;
insert into auth.users(id,is_anonymous,email_confirmed_at) values ('97200000-0000-4000-8000-000000000001',false,now());
select public.night_flock_v4_command('97200000-0000-4000-8000-000000000001',
 '{"command":"createParty","name":"Upgrade fixture","timeZoneIdentifier":"UTC"}'::jsonb);
insert into private.campfire_agreements(member_epoch_id,revision,enabled)
 select id,1,true from private.night_flock_v4_membership_epochs where user_id='97200000-0000-4000-8000-000000000001';
insert into private.campfire_sessions
 select a.member_epoch_id,'97200000-0000-4000-8000-000000000002',a.id,1,'windDown',null,now(),now(),now()+interval '8 hours',false
 from private.campfire_agreements a join private.night_flock_v4_membership_epochs e on e.id=a.member_epoch_id
 where e.user_id='97200000-0000-4000-8000-000000000001';
\ir ../migrations/20260919130000_campfire_bedtime.sql
do $$
declare s private.campfire_sessions%rowtype; p uuid; result jsonb;
begin
 select * into strict s from private.campfire_sessions where source_id='97200000-0000-4000-8000-000000000002';
 if s.intended_bedtime is not null or s.ended then raise exception 'legacy row changed'; end if;
 select party_id into p from private.night_flock_v4_membership_epochs where id=s.member_epoch_id;
 result:=public.night_flock_v4_state('97200000-0000-4000-8000-000000000001','party',p,null);
 if result#>>'{party,pasture,campfire,sessions,0,intendedBedtime}' is not null
 or result#>>'{party,pasture,campfire,supportsIntendedBedtime}'<>'true' then raise exception 'legacy projection changed'; end if;
 perform public.night_flock_v4_command('97200000-0000-4000-8000-000000000001',jsonb_build_object(
 'command','publishCampfireSession','partyID',p,'memberEpochID',s.member_epoch_id,'agreementID',s.agreement_id,
 'sourceID',s.source_id,'kind',s.kind,'startedAt',s.started_at,'observedAt',s.observed_at,'expiresAt',s.expires_at,'ended',true,'revision',2));
 if not (select ended from private.campfire_sessions where source_id=s.source_id) then raise exception 'legacy terminal failed after upgrade'; end if;
end $$;
rollback;
