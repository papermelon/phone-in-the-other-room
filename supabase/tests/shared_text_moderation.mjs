import assert from 'node:assert/strict';
import { test } from 'node:test';
import { moderateSharedText, sharedTextDecision, nightFlockSharedText, globalCampfireSharedText, SharedTextModerationError } from '../functions/_shared/shared-text-moderation.ts';
import { handleNightFlockCommand } from '../functions/_shared/night-flock-handlers.ts';
import { handleGlobalCampfire } from '../functions/_shared/global-campfire-handler.ts';

const owner = '96000000-0000-4000-8000-000000000001';
const other = '96000000-0000-4000-8000-000000000002';
const key = 'a'.repeat(64);
const scores = change => ({ flagged: true, category_scores: { hate: 0, 'hate/threatening': 0, harassment: 0, 'harassment/threatening': 0, sexual: 1, 'self-harm': 1, ...change } });
const request = (headers = {}, body = {}) => new Request('https://example.test', { method: 'POST', headers: {
  'Content-Type': 'application/json', 'Idempotency-Key': key, 'X-Campfire-Owner': owner,
  'X-Shared-Text-Owner': owner, 'X-Shared-Text-Consent': '1', ...headers,
}, body: JSON.stringify(body) });
const options = (result = scores()) => ({ enabled: true, apiKey: 'fixture-key', fetch: async (_url, init) => {
  const { input } = JSON.parse(init.body);
  return Response.json({ results: input.map(() => result) });
} });
const check = (req, texts, opts = options(), user = owner, commandID = key, scope = 'night-flock-command') => moderateSharedText(req, user, scope, commandID, texts, opts);
const errorCode = code => error => error instanceof SharedTextModerationError && error.code === code;

test('policy ignores overall flagged and unrelated categories; mild harassment stays open', () => {
  assert.equal(sharedTextDecision(scores()), 'allow');
  assert.equal(sharedTextDecision(scores({ harassment: 0.3 })), 'allow');
  assert.equal(sharedTextDecision(scores({ hate: 0.7 })), 'review');
  assert.equal(sharedTextDecision(scores({ harassment: 0.8 })), 'review');
  for (const category of ['hate', 'hate/threatening', 'harassment', 'harassment/threatening']) {
    assert.equal(sharedTextDecision(scores({ [category]: 0.99 })), 'reject');
  }
});

test('malformed or partial provider results never allow publication', () => {
  for (const result of [null, {}, { category_scores: { hate: 1 } }, scores({ hate: NaN }), scores({ harassment: 1.1 }), scores({ hate: '0' })]) {
    assert.throws(() => sharedTextDecision(result), errorCode('shared_text_unavailable'));
  }
});

test('only shared fields are extracted; private saves, identifiers and preset support stay out', () => {
  assert.deepEqual(nightFlockSharedText({ schemaVersion: 4, command: 'campfireBuddyAction', buddyAction: 'reflect', reflection: 'A quiet night', privateNote: 'secret' }), ['A quiet night']);
  assert.deepEqual(nightFlockSharedText({ schemaVersion: 4, command: 'publishCampfireSession', publicIntention: 'Read', ended: false }), ['Read']);
  for (const body of [
    { schemaVersion: 4, command: 'publishCampfireSession', publicIntention: 'Read', ended: true },
    { schemaVersion: 4, command: 'campfireBuddyAction', buddyAction: 'encourage', reflection: 'private' },
    { schemaVersion: 4, command: 'setCampfireSharing', enabled: false },
    { schemaVersion: 4, command: 'deleteAccount' },
  ]) assert.deepEqual(nightFlockSharedText(body), []);
  for (const command of ['createParty', 'renameParty']) assert.deepEqual(nightFlockSharedText({ schemaVersion: 4, command, name: 'Family' }), ['Family']);
  assert.deepEqual(nightFlockSharedText({ schemaVersion: 4, command: 'updatePublicProfile', displayName: 'Fern' }), ['Fern']);
  assert.deepEqual(nightFlockSharedText({ schemaVersion: 2, command: 'createParty', appDisplayName: 'Example app' }), ['Example app']);
  assert.deepEqual(globalCampfireSharedText({ command: 'agreement', enabled: false, publicName: 'secret' }), []);
  assert.deepEqual(globalCampfireSharedText({ command: 'agreement', enabled: true, consentVersion: 1, publicName: 'Fern' }), []);
  assert.deepEqual(globalCampfireSharedText({ command: 'agreement', enabled: true, consentVersion: 2, publicName: 'Fern' }), ['Fern']);
  assert.deepEqual(globalCampfireSharedText({ command: 'profile', profile: {
    session: ['Session'], tasks: ['Read'], routines: ['Stretch'], history: ['Recorded night'], partyNames: ['Family'], intention: 'Rest',
    sheep: [{ id: other, name: 'Mabel' }], inventory: ['item_id'], privateNote: 'secret',
  } }), ['Session', 'Read', 'Stretch', 'Recorded night', 'Family', 'item_id', 'Rest', 'Mabel']);
});

test('consent is explicit, versioned and owner-bound before any provider request', async () => {
  let calls = 0;
  const opts = { ...options(), fetch: async () => { calls++; throw new Error('must not send'); } };
  for (const headers of [{ 'X-Shared-Text-Consent': '' }, { 'X-Shared-Text-Consent': '2' }, { 'X-Shared-Text-Owner': other }]) {
    await assert.rejects(check(request(headers), ['Note'], opts), errorCode('shared_text_consent_required'));
  }
  // A queued A submission cannot acquire B's authority after an auth switch.
  await assert.rejects(check(request(), ['Note'], opts, other), errorCode('shared_text_consent_required'));
  await check(request(), [], opts);
  await check(request(), ['Note'], { ...opts, enabled: false });
  assert.equal(calls, 0);
});

test('provider receives text only, no user IDs, request envelope or private data', async () => {
  const opts = { ...options(), fetch: async (url, init) => {
    assert.equal(url, 'https://api.openai.com/v1/moderations');
    assert.equal(init.headers.Authorization, 'Bearer fixture-key');
    assert.deepEqual(JSON.parse(init.body), { model: 'omni-moderation-latest', input: ['Read one chapter'] });
    return Response.json({ results: [scores()] });
  } };
  await check(request(), [' Read one chapter ', 'Read one chapter', ''], opts);
});

test('an exact warning confirmation permits review content, never high-severity content', async () => {
  let token;
  try { await check(request(), ['Quoted experience'], options(scores({ harassment: 0.8 }))); }
  catch (error) { assert.equal(error.code, 'shared_text_review_required'); token = error.reviewToken; }
  assert.match(token, /^[a-f0-9]{64}$/);
  const acknowledged = request({ 'X-Shared-Text-Review': token });
  await check(acknowledged, ['Quoted experience'], options(scores({ harassment: 0.8 })));
  await assert.rejects(check(acknowledged, ['Different text'], options(scores({ harassment: 0.8 }))), errorCode('shared_text_review_required'));
  await assert.rejects(check(acknowledged, ['Quoted experience'], options(scores({ harassment: 0.8 })), owner, 'b'.repeat(64)), errorCode('shared_text_review_required'));
  await assert.rejects(check(acknowledged, ['Quoted experience'], options(scores({ harassment: 0.8 })), owner, key, 'campfire-global'), errorCode('shared_text_review_required'));
  await assert.rejects(check(request({ 'X-Shared-Text-Owner': other, 'X-Shared-Text-Review': token }), ['Quoted experience'], options(scores({ harassment: 0.8 })), other), errorCode('shared_text_review_required'));
  await assert.rejects(check(acknowledged, ['Quoted experience'], options(scores({ hate: 0.99 }))), errorCode('shared_text_rejected'));
});

test('outages, bad credentials, throttling and incomplete results stay unshared', async () => {
  for (const opts of [
    { enabled: true },
    { ...options(), fetch: async () => new Response('provider private details', { status: 429 }) },
    { ...options(), fetch: async () => { throw new Error('provider private details'); } },
    { ...options(), fetch: async () => new Response('{bad json') },
    { ...options(), fetch: async () => Response.json({ results: [] }) },
    { ...options(), admit: async () => { throw new Error('rate_limited'); } },
  ]) await assert.rejects(check(request(), ['Note'], opts), errorCode('shared_text_unavailable'));
});

test('bounded requests never silently truncate unchecked text; all batches are checked', async () => {
  await check(request(), Array.from({ length: 300 }, (_, i) => `Recorded night ${i}`));
  await assert.rejects(check(request(), ['x'.repeat(100001)], options()), errorCode('shared_text_too_large'));
  let batches = 0;
  const opts = { ...options(), fetch: async (_url, init) => {
    const { input } = JSON.parse(init.body); assert.ok(input.length <= 4); batches++;
    return Response.json({ results: input.map(() => scores(batches === 2 ? { hate: 1 } : {})) });
  } };
  await assert.rejects(check(request(), Array.from({ length: 17 }, (_, i) => `Field ${i} ${'x'.repeat(3000)}`), opts), errorCode('shared_text_rejected'));
  assert.equal(batches, 2);
});

test('both authenticated endpoints moderate before mutation and redact rejection details', async () => {
  const logs = []; const originalLog = console.info; console.info = value => logs.push(value);
  let executions = 0;
  try {
    const body = { schemaVersion: 4, command: 'createParty', name: 'Example note', timeZoneIdentifier: 'UTC', idempotencyKey: key };
    const privateDependencies = {
      authenticate: async () => ({ id: owner, isAnonymous: false }),
      moderate: async (req, id, c) => { await check(req, nightFlockSharedText(c), options(scores({ hate: 1 })), id); return c; },
      execute: async () => { executions++; return { accepted: true }; }, deleteAccount: async () => {},
    };
    const response = await handleNightFlockCommand(request({}, body), privateDependencies);
    assert.equal(response.status, 422);
    assert.equal((await response.json()).code, 'shared_text_rejected');
    const globalBody = { id: owner, command: 'agreement', enabled: true, consentVersion: 2, expectedRevision: 0, publicName: 'Example',
      appearance: { skinToneID: 'warm', hairStyleID: 'waves', shepherdOutfitID: 'none', shepherdAccessoryID: 'none' } };
    const publicDependencies = {
      authenticate: privateDependencies.authenticate,
      moderate: async (req, id, c) => check(req, globalCampfireSharedText(c), options(scores({ harassment: 1 })), id),
      execute: async () => { executions++; return { data: { accepted: true }, error: null }; },
    };
    const globalResponse = await handleGlobalCampfire(request({}, globalBody), publicDependencies);
    assert.equal(globalResponse.status, 422);
    assert.equal((await globalResponse.json()).code, 'shared_text_rejected');
    assert.equal(executions, 0);
    assert.ok(!logs.join('').includes('Example note'));
    const invalid = await handleNightFlockCommand(request({}, { ...body, privateNote: 'secret' }), privateDependencies);
    assert.equal(invalid.status, 400);
    const anonymous = await handleGlobalCampfire(request({}, globalBody), { ...publicDependencies, authenticate: async () => ({ id: owner, isAnonymous: true }) });
    assert.equal(anonymous.status, 401);
    const wrongOwner = await handleGlobalCampfire(request({ 'X-Campfire-Owner': other }, globalBody), publicDependencies);
    assert.equal(wrongOwner.status, 409);
  } finally { console.info = originalLog; }
});
