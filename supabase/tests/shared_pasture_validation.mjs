// Node 22+; no dependency installation. Tests the same Edge wire validator.
// node --experimental-strip-types --test supabase/tests/shared_pasture_validation.mjs
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { classifyNightFlockError } from '../functions/_shared/night-flock-errors.ts';
import { validateNightFlockCommand } from '../functions/_shared/night-flock.ts';
const id='96000000-0000-4000-8000-000000000001';
const base={schemaVersion:4,command:'movePastureEntity',partyID:id,memberEpochID:id,sceneRevision:1,entityID:`member-${id}`,expectedRevision:0,x:0.5,y:0.7,idempotencyKey:'a'.repeat(64)};
const validate = c => validateNightFlockCommand(c,c.idempotencyKey??null);
test('accepts normalized placements for people, sheep and earned lantern',()=>{
 for(const prefix of ['member','visitor','lantern']) assert.doesNotThrow(()=>validate({...base,entityID:`${prefix}-${id}`}));
});
test('rejects invalid ground, future revisions and private payload fields',()=>{
 for(const change of [{x:NaN},{x:Infinity},{y:-Infinity},{x:0.1,y:0.88},{y:0.2},{expectedRevision:-1},{expectedRevision:0.5},{expectedRevision:2147483647},{sceneRevision:2},{entityID:'member-'+'-'.repeat(36)},{memberEpochID:'bad'},{farm:{sheep:[]}},{displayName:'Injected name'}]) assert.throws(()=>validate({...base,...change}));
});
test('visits require explicit consent and owned ID, no uploaded appearance',()=>{
 const visit={schemaVersion:4,command:'contributePastureSheep',partyID:id,memberEpochID:id,sceneRevision:1,sheepID:id,consentVersion:1,idempotencyKey:'b'.repeat(64)};
 assert.doesNotThrow(()=>validate(visit));
 for(const change of [{consentVersion:0},{sheepID:'bad'},{definitionID:'bramble'},{expiresAt:'tomorrow'}]) assert.throws(()=>validate({...visit,...change}));
});
test('recall accepts only a bounded visit reference and stable retry key',()=>{
 const recall={schemaVersion:4,command:'recallPastureSheep',partyID:id,memberEpochID:id,sceneRevision:1,visitID:id,idempotencyKey:'c'.repeat(64)};
 assert.deepEqual(validate(recall),validate(recall));
 assert.throws(()=>validate({...recall,ownerID:id}));
 assert.throws(()=>validate({...recall,visitID:null}));
});

test('ownership failures are actionable and never blindly retried',()=>{
 for(const code of ['pasture_sheep_not_owned','pasture_sheep_already_visiting']) {
  const failure=classifyNightFlockError(new Error(code));
  assert.equal(failure.code,code);assert.equal(failure.retryable,false);assert.equal(failure.status,409);
 }
});
