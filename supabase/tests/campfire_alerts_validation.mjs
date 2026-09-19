import assert from 'node:assert/strict';
import { test } from 'node:test';
import { validateCampfireDevice, campfireAlertPayload } from '../functions/_shared/campfire-alerts.ts';
const owner='96000000-0000-4000-8000-000000000001';
const registration={ownerID:owner,installationID:owner,token:'a'.repeat(64),environment:'production',enabled:true,quietUntil:'2026-09-13T12:00:00Z',timeZone:'Asia/Singapore',quietStart:23,quietEnd:7,revision:1};
test('device registration is caller bound and rejects unknown or malformed fields',()=>{
 assert.doesNotThrow(()=>validateCampfireDevice(registration,owner));
 for(const change of [{ownerID:crypto.randomUUID()},{token:'bad'},{environment:'debug'},{enabled:'yes'},{quietUntil:100},{quietStart:24},{quietEnd:-1},{revision:0},{revision:1.5},{privateTask:'secret'}]) assert.throws(()=>validateCampfireDevice({...registration,...change},owner));
 assert.doesNotThrow(()=>validateCampfireDevice({ownerID:owner,installationID:owner,unregister:true,revision:2},owner));
});
test('notification contains only approved generic copy and opaque routing IDs',()=>{
 const payload=campfireAlertPayload({partyID:owner,sourceID:owner,title:'Company',body:'A session started',publicIntention:'private',token:'secret'});
 assert.equal(payload.aps['interruption-level'],'active');
 assert.equal(payload.campfirePartyID,owner);
 assert.equal(JSON.stringify(payload).includes('private'),false);
 assert.equal(JSON.stringify(payload).includes('secret'),false);
 assert.equal(payload.aps.sound,undefined);
});

test('APNs alert uses the ordinary app topic and bounded retry policy without network', async()=>{
 const { sendCampfireAlert } = await import('../functions/_shared/apns.ts');
 const key = await crypto.subtle.generateKey({name:'ECDSA',namedCurve:'P-256'},true,['sign','verify']);
 const bytes = await crypto.subtle.exportKey('pkcs8',key.privateKey);
 const env={APNS_ENVIRONMENT:'production',APNS_ALERT_TOPIC:'example.test',APNS_KEY_ID:'fixture',APNS_TEAM_ID:'fixture',APNS_PRIVATE_KEY_P8:Buffer.from(bytes).toString('base64')};
 const originalDeno=globalThis.Deno, originalFetch=globalThis.fetch;
 globalThis.Deno={env:{get:name=>env[name]}};
 let status=200, calls=0;
 globalThis.fetch=async(url,options)=>{
  calls++;
  assert.equal(url,'https://api.push.apple.com/3/device/fixture-token');
  assert.equal(options.headers['apns-push-type'],'alert');
  assert.equal(options.headers['apns-topic'],'example.test');
  assert.equal(options.headers['apns-collapse-id'],'fixture-event');
  assert.equal(options.headers['apns-expiration'],'1789300800');
  assert.ok(options.signal instanceof AbortSignal);
  return new Response(null,{status});
 };
 try {
  const event={token:'fixture-token',environment:'production',id:'fixture-event',expiresAt:'2026-09-13T12:00:00Z',payload:{aps:{alert:{body:'generic'}}}};
  assert.equal((await sendCampfireAlert(event)).outcome,'delivered');
  status=503; assert.equal((await sendCampfireAlert(event)).outcome,'retry');
  status=410; assert.equal((await sendCampfireAlert(event)).outcome,'terminal');
  assert.equal((await sendCampfireAlert({...event,environment:'sandbox'})).outcome,'terminal');
  assert.equal(calls,3);
 } finally { globalThis.Deno=originalDeno; globalThis.fetch=originalFetch; }
});
