begin;
insert into auth.users(id,is_anonymous,email_confirmed_at) values
 ('cf000000-0000-4000-8000-000000000001',false,now()),
 ('cf000000-0000-4000-8000-000000000002',false,now()),
 ('cf000000-0000-4000-8000-000000000003',false,now()),
 ('cf000000-0000-4000-8000-000000000004',true,null);
insert into private.account_usernames(user_id,username) values('cf000000-0000-4000-8000-000000000002','night_owl');
do $$
declare a uuid:='cf000000-0000-4000-8000-000000000001'; b uuid:='cf000000-0000-4000-8000-000000000002';
 c uuid:='cf000000-0000-4000-8000-000000000003'; guest uuid:='cf000000-0000-4000-8000-000000000004';
 p uuid; other_party uuid; inv uuid; extra_party uuid; extra_user uuid; out jsonb; saved jsonb; n integer;
begin
 perform set_config('request.jwt.claim.sub',a::text,true);
 out:=public.night_flock_v4_command(a,'{"command":"createParty","name":"Night Owls","timeZoneIdentifier":"Asia/Singapore"}');
 p:=(out->>'resolvedPartyID')::uuid;
 if public.night_flock_v4_state(a)->>'directInvitationsVersion' is distinct from '1' then raise exception 'capability missing'; end if;
 if has_table_privilege('authenticated','private.slumber_party_invitations','SELECT') or has_function_privilege('anon','public.slumber_party_connections_v1(jsonb)','EXECUTE') then raise exception 'invitation privacy broken'; end if;
 out:=public.slumber_party_connections_v1(jsonb_build_object('action','search','partyID',p,'query','@NIGHT_OWL'));
 if out#>>'{person,userID}' is distinct from b::text then raise exception 'exact handle lookup failed'; end if;
 if out#>'{person}' ? 'email' then raise exception 'email leaked'; end if;
 begin
  perform public.slumber_party_connections_v1(jsonb_build_object('action','search','partyID',p,'query','night%'));
  raise exception 'wildcard allowed';
 exception when others then if sqlerrm='wildcard allowed' then raise; end if; end;
 begin
  perform public.slumber_party_connections_v1(jsonb_build_object('action','state','callerID',b));
  raise exception 'caller spoof allowed';
 exception when others then if sqlerrm='caller spoof allowed' then raise; end if; end;
 perform set_config('request.jwt.claim.sub',c::text,true);
 begin
  perform public.slumber_party_connections_v1(jsonb_build_object('action','search','partyID',p,'query','night_owl'));
  raise exception 'nonmember searched';
 exception when others then if sqlerrm='nonmember searched' then raise; end if; end;
 perform set_config('request.jwt.claim.sub',guest::text,true);
 begin
  perform public.slumber_party_connections_v1('{"action":"state"}'); raise exception 'guest read';
 exception when others then if sqlerrm='guest read' then raise; end if; end;
 perform set_config('request.jwt.claim.sub',a::text,true);
 out:=public.slumber_party_connections_v1(jsonb_build_object('action','invite','partyID',p,'userID',b));
 inv:=(out#>>'{invitations,0,id}')::uuid;
 if inv is null then raise exception 'sent receipt missing'; end if;
 perform public.slumber_party_connections_v1(jsonb_build_object('action','invite','partyID',p,'userID',b));
 if (select count(*) from private.slumber_party_invitations where party_id=p)<>1 then raise exception 'duplicate invitation'; end if;
 perform set_config('request.jwt.claim.sub',c::text,true);
 begin
  perform public.slumber_party_connections_v1(jsonb_build_object('action','accept','invitationID',inv)); raise exception 'wrong recipient joined';
 exception when others then if sqlerrm='wrong recipient joined' then raise; end if; end;
 insert into public.night_flock_blocks(blocker_user_id,blocked_user_id) values(b,a);
 perform set_config('request.jwt.claim.sub',b::text,true);
 if jsonb_array_length(public.slumber_party_connections_v1('{"action":"state"}')->'invitations')<>0 then raise exception 'blocked invitation visible'; end if;
 begin
  perform public.slumber_party_connections_v1(jsonb_build_object('action','accept','invitationID',inv)); raise exception 'blocked user joined';
 exception when others then if sqlerrm='blocked user joined' then raise; end if; end;
 delete from public.night_flock_blocks where blocker_user_id=b;
 out:=public.slumber_party_connections_v1('{"action":"state"}');
 if out#>>'{invitations,0,isIncoming}' is distinct from 'true' then raise exception 'inbox missing'; end if;
 out:=public.slumber_party_connections_v1(jsonb_build_object('action','accept','invitationID',inv));
 if out->>'acceptedPartyID' is distinct from p::text then raise exception 'acceptance missing'; end if;
 saved:=public.slumber_party_connections_v1(jsonb_build_object('action','accept','invitationID',inv));
 if saved->>'acceptedPartyID' is distinct from p::text then raise exception 'replay failed'; end if;
 if (select count(*) from private.night_flock_v4_memberships where party_id=p and user_id=b and status='active')<>1 then raise exception 'membership incorrect'; end if;
 if exists(select 1 from private.night_flock_v4_shared_habits_agreements where party_id=p and user_id=b) then raise exception 'unconfirmed sharing enabled'; end if;
 -- A second party exercises decline, revocation, expiry and sender departure.
 perform set_config('request.jwt.claim.sub',a::text,true);
 out:=public.night_flock_v4_command(a,'{"command":"createParty","name":"Evening","timeZoneIdentifier":"Asia/Singapore"}');
 other_party:=(out->>'resolvedPartyID')::uuid;
 out:=public.slumber_party_connections_v1(jsonb_build_object('action','invite','partyID',other_party,'userID',b));
 inv:=(out#>>'{invitations,0,id}')::uuid;
 perform set_config('request.jwt.claim.sub',b::text,true);
 perform public.slumber_party_connections_v1(jsonb_build_object('action','decline','invitationID',inv));
 perform set_config('request.jwt.claim.sub',a::text,true);
 begin
  perform public.slumber_party_connections_v1(jsonb_build_object('action','invite','partyID',other_party,'userID',b)); raise exception 'decline ignored';
 exception when others then if sqlerrm='decline ignored' then raise; end if; end;
 out:=public.slumber_party_connections_v1(jsonb_build_object('action','invite','partyID',other_party,'userID',c));
 inv:=(out#>>'{invitations,0,id}')::uuid;
 perform public.slumber_party_connections_v1(jsonb_build_object('action','revoke','invitationID',inv));
 perform set_config('request.jwt.claim.sub',c::text,true);
 begin
  perform public.slumber_party_connections_v1(jsonb_build_object('action','accept','invitationID',inv)); raise exception 'revoked invite accepted';
 exception when others then if sqlerrm='revoked invite accepted' then raise; end if; end;
 perform set_config('request.jwt.claim.sub',a::text,true);
 out:=public.slumber_party_connections_v1(jsonb_build_object('action','invite','partyID',other_party,'userID',c));
 inv:=(out#>>'{invitations,0,id}')::uuid;
 update private.slumber_party_invitations set expires_at=now()-interval '1 minute' where id=inv;
 perform set_config('request.jwt.claim.sub',c::text,true);
 begin
  perform public.slumber_party_connections_v1(jsonb_build_object('action','accept','invitationID',inv)); raise exception 'expired invite accepted';
 exception when others then if sqlerrm='expired invite accepted' then raise; end if; end;
 -- An invitation cannot bypass the five-party limit or the eight-member cap.
 perform set_config('request.jwt.claim.sub',c::text,true);
 for n in 1..5 loop
  out:=public.night_flock_v4_command(c,jsonb_build_object('command','createParty','name','Group '||n,'timeZoneIdentifier','Asia/Singapore'));
  extra_party:=(out->>'resolvedPartyID')::uuid;
 end loop;
 perform set_config('request.jwt.claim.sub',a::text,true);
 out:=public.slumber_party_connections_v1(jsonb_build_object('action','invite','partyID',other_party,'userID',c));
 inv:=(out#>>'{invitations,0,id}')::uuid;
 perform set_config('request.jwt.claim.sub',c::text,true);
 begin
  perform public.slumber_party_connections_v1(jsonb_build_object('action','accept','invitationID',inv)); raise exception 'party limit bypassed';
 exception when others then if sqlerrm<>'party_limit' then raise; end if; end;
 perform public.night_flock_v4_command(c,jsonb_build_object('command','deleteParty','partyID',extra_party));
 for n in 1..7 loop
  extra_user:=gen_random_uuid();
  insert into auth.users(id,is_anonymous,email_confirmed_at) values(extra_user,false,now());
  insert into private.night_flock_v4_memberships(party_id,user_id,role) values(other_party,extra_user,'member');
 end loop;
 begin
  perform public.slumber_party_connections_v1(jsonb_build_object('action','accept','invitationID',inv)); raise exception 'member cap bypassed';
 exception when others then if sqlerrm<>'party_full' then raise; end if; end;
 -- Searches are rate-limited, including successful no-match lookups.
 perform set_config('request.jwt.claim.sub',b::text,true);
 for n in 1..30 loop perform public.slumber_party_connections_v1(jsonb_build_object('action','search','partyID',p,'query','nobody_here')); end loop;
 begin
  perform public.slumber_party_connections_v1(jsonb_build_object('action','search','partyID',p,'query','nobody_here')); raise exception 'unbounded search';
 exception when others then if sqlerrm<>'rate_limited' then raise; end if; end;
end $$;
rollback;
