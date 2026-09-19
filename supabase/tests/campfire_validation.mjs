import assert from 'node:assert/strict';
import { test } from 'node:test';
import { validateNightFlockCommand } from '../functions/_shared/night-flock.ts';
const id='96000000-0000-4000-8000-000000000001';
const base={schemaVersion:4,command:'publishCampfireSession',partyID:id,memberEpochID:id,sceneRevision:1,agreementID:id,sourceID:id,kind:'phoneAway',activity:'reading',startedAt:'2026-09-13T12:00:00Z',observedAt:'2026-09-13T12:00:00Z',expiresAt:'2026-09-13T12:30:00Z',ended:false,revision:1,idempotencyKey:'a'.repeat(64)};
const validate=c=>validateNightFlockCommand(c,c.idempotencyKey);
test('bounded intentions and terminal revision accepted',()=>{
 for(const activity of ['phoneAway','reading','studying','making','chores','resting']) assert.doesNotThrow(()=>validate({...base,activity}));
 assert.doesNotThrow(()=>validate({...base,ended:true,revision:2}));
 const foundation={...base};
 for(const key of ['startedAt','observedAt','expiresAt']) foundation[key]=(Date.parse(base[key])-Date.UTC(2001,0,1))/1000;
 const normalized=validate(foundation);
 for(const key of ['startedAt','observedAt','expiresAt']) assert.equal(Date.parse(normalized[key]),Date.parse(base[key]));
});
test('rejects private content, invalid timestamps, oversized intervals and mismatched terminal revision',()=>{
 for(const change of [{title:'private'},{activity:'My private project'},{startedAt:'bad'},{expiresAt:'bad'},{expiresAt:'2026-09-15T12:00:00Z'},{observedAt:'2026-09-12T12:00:00Z'},{kind:'windDown',activity:'reading'},{ended:true},{revision:2},{agreementID:'bad'}]) assert.throws(()=>validate({...base,...change}));
});
test('separate versioned consent and revision required',()=>{
 const c={schemaVersion:4,command:'setCampfireSharing',partyID:id,memberEpochID:id,sceneRevision:1,consentVersion:1,expectedRevision:0,enabled:true,idempotencyKey:'b'.repeat(64)};
 assert.doesNotThrow(()=>validate(c));
 for(const change of [{consentVersion:3},{enabled:'true'},{expectedRevision:-1},{expectedRevision:0.5},{activity:'reading'}]) assert.throws(()=>validate({...c,...change}));
});
test('explicit public intentions require all v2 fields and strict bounds',()=>{
 const c={...base,publicIntention:'Read one chapter',asksForBuddy:true,announceStart:true,checkInAfter:base.expiresAt};
 assert.doesNotThrow(()=>validate(c));
 for(const change of [{publicIntention:'x'.repeat(81)},{publicIntention:'line\nbreak'},{asksForBuddy:'true'},{announceStart:null},{checkInAfter:'bad'},{checkInAfter:'2026-09-13T12:00:00Z'},{checkInAfter:'2026-09-15T12:00:00Z'}]) assert.throws(()=>validate({...c,...change}));
 assert.throws(()=>validate({...base,announceStart:true}));
});
test('buddy actions are scoped and reflections never ride an encouragement',()=>{
 const c={schemaVersion:4,command:'campfireBuddyAction',partyID:id,memberEpochID:id,agreementID:id,sourceID:id,targetMemberID:id,sceneRevision:1,buddyAction:'accept',idempotencyKey:'d'.repeat(64)};
 for(const buddyAction of ['accept','encourage','checkIn']) assert.doesNotThrow(()=>validate({...c,buddyAction}));
 assert.doesNotThrow(()=>validate({...c,buddyAction:'reflect',outcome:'madeProgress',reflection:'One page'}));
 for(const change of [{buddyAction:'unknown'},{targetMemberID:'bad'},{outcome:'didIt'},{buddyAction:'reflect',outcome:'verified'},{buddyAction:'reflect',outcome:'didIt',reflection:'x'.repeat(161)}]) assert.throws(()=>validate({...c,...change}));
});
