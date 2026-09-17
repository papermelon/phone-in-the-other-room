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
 for(const change of [{consentVersion:2},{enabled:'true'},{expectedRevision:-1},{expectedRevision:0.5},{activity:'reading'}]) assert.throws(()=>validate({...c,...change}));
});
