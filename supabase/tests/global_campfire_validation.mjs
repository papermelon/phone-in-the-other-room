import assert from 'node:assert/strict';
import { test } from 'node:test';
import { validateGlobalCampfire, validatesCampfireOwner } from '../functions/_shared/global-campfire.ts';
const id='af000000-0000-4000-8000-000000000001';
const appearance={skinToneID:'warm',hairStyleID:'waves',shepherdOutfitID:'none',shepherdAccessoryID:'none'};
const agreement={id,command:'agreement',consentVersion:1,expectedRevision:0,enabled:true,publicName:'Fern',appearance};
const session={id,command:'publish',sourceID:id,agreementID:id,kind:'phoneAway',activity:'reading',startedAt:'2026-09-16T10:00:00Z',expiresAt:'2026-09-16T10:30:00Z',ended:false};
test('a queued agreement cannot follow an account switch',()=>{
  assert.equal(validatesCampfireOwner(id.toUpperCase(),id),true);
  assert.equal(validatesCampfireOwner(null,id),false);
  assert.equal(validatesCampfireOwner(id,'af000000-0000-4000-8000-000000000002'),false);
});
test('three audiences do not share through the read API',()=>{
  assert.doesNotThrow(()=>validateGlobalCampfire({command:'state',gathering:'all'}));
  for(const change of [{ownerID:id},{visibility:'global'},{privateIntention:'read'}]) assert.throws(()=>validateGlobalCampfire({command:'state',...change}));
});
test('public consent is explicitly versioned and profile fields are bounded',()=>{
  assert.doesNotThrow(()=>validateGlobalCampfire(agreement));
  for(const change of [{consentVersion:3},{expectedRevision:-1},{enabled:'true'},{publicName:'My private account name'},
    {appearance:{...appearance,partyID:id}},{appearance:{...appearance,shepherdOutfitID:'private'}},{partyID:id}]) assert.throws(()=>validateGlobalCampfire({...agreement,...change}));
  assert.doesNotThrow(()=>validateGlobalCampfire({id,command:'agreement',consentVersion:1,expectedRevision:1,enabled:false}));
  assert.throws(()=>validateGlobalCampfire({...agreement,enabled:false}));
});
test('wardrobe additions accept only the three curated appearance IDs',()=>{
  const dressed={...appearance,shepherdShirtID:'shepherd_berry_shirt',shepherdOuterwearID:'shepherd_open_moss_coat',ollieCoatID:'fuller'};
  assert.doesNotThrow(()=>validateGlobalCampfire({...agreement,appearance:dressed}));
  for(const shirt of ['shepherd_dusk_shirt','shepherd_amber_shirt']) assert.doesNotThrow(()=>validateGlobalCampfire({...agreement,appearance:{...dressed,shepherdShirtID:shirt}}));
  for(const key of ['shepherdShirtID','shepherdOuterwearID','ollieCoatID']) {
    assert.throws(()=>validateGlobalCampfire({...agreement,appearance:{...dressed,[key]:'private'}}));
    const partial={...dressed}; delete partial[key];
    assert.throws(()=>validateGlobalCampfire({...agreement,appearance:partial}));
  }
  assert.throws(()=>validateGlobalCampfire({...agreement,appearance:{...dressed,shirtItemID:'private'}}));
});
test('both kinds and terminal-before-start are accepted; private fields never ride a session',()=>{
  assert.doesNotThrow(()=>validateGlobalCampfire(session));
  assert.doesNotThrow(()=>validateGlobalCampfire({...session,ended:true}));
  const windDown={...session,kind:'windDown'}; delete windDown.activity;
  assert.doesNotThrow(()=>validateGlobalCampfire(windDown));
  for(const change of [{partyID:id},{publicIntention:'private'},{health:{}},{kind:'windDown'},{expiresAt:'2026-09-18T10:00:00Z'},
    {startedAt:'invalid'},{sourceID:'wrong'},{ended:1},{activity:'My diary'}]) assert.throws(()=>validateGlobalCampfire({...session,...change}));
});
test('Foundation timestamps normalize to the same bounded wire interval',()=>{
  const epoch=Date.UTC(2001,0,1);
  const result=validateGlobalCampfire({...session,startedAt:(Date.parse(session.startedAt)-epoch)/1000,expiresAt:(Date.parse(session.expiresAt)-epoch)/1000});
  assert.equal(Date.parse(result.startedAt),Date.parse(session.startedAt));
  assert.equal(Date.parse(result.expiresAt),Date.parse(session.expiresAt));
});
test('public actions cannot contain a chat message or private membership identity',()=>{
  for(const command of ['encourage','block']) {
    assert.doesNotThrow(()=>validateGlobalCampfire({id,command,targetID:id}));
    assert.throws(()=>validateGlobalCampfire({id,command,targetID:id,message:'hello'}));
  }
  assert.doesNotThrow(()=>validateGlobalCampfire({id,command:'report',targetID:id,reason:'profile'}));
  assert.throws(()=>validateGlobalCampfire({id,command:'report',targetID:id,reason:'free text'}));
});

const profile={session:['Phone Away · Active'],tasks:['Read my book'],routines:['Evening · 22:00–07:00'],intention:'Rest',history:['Wind Down · 21 September'],partyNames:['Family'],inventory:[],sheep:[],appearance,decorations:{},collectibles:{},ollieAccessory:'none',barnCapacityLevel:0};
test('full character profile uses one explicit version-2 choice and a bounded display snapshot',()=>{
  assert.doesNotThrow(()=>validateGlobalCampfire({...agreement,consentVersion:2,publicName:'Tommy'}));
  assert.doesNotThrow(()=>validateGlobalCampfire({...agreement,consentVersion:2,publicName:'Ngawang Chime',appearance:{...appearance,headShapeID:'boxy'}}));
  const command={id,command:'profile',agreementID:id,sourceID:id,capturedAt:'2026-09-20T12:00:00Z',profile};
  assert.doesNotThrow(()=>validateGlobalCampfire(command));
  for(const change of [{health:{}},{ownerID:id},{tasks:[{}]},{history:Array(5001).fill('x')},{appearance:{...appearance,headShapeID:'unknown'}},{sheep:[{name:'unknown'}]}]) {
    assert.throws(()=>validateGlobalCampfire({...command,profile:{...profile,...change}}));
  }
  assert.throws(()=>validateGlobalCampfire({...command,agreementID:'bad'}));
  assert.doesNotThrow(()=>validateGlobalCampfire({command:'detail',participantID:id}));
  assert.doesNotThrow(()=>validateGlobalCampfire({command:'detail',memberID:id}));
  assert.throws(()=>validateGlobalCampfire({command:'detail',memberID:id,participantID:id}));
});

test('numbered channel reads and moves are bounded and session-scoped',()=>{
  assert.doesNotThrow(()=>validateGlobalCampfire({command:'state',channelID:0}));
  assert.doesNotThrow(()=>validateGlobalCampfire({...session,channelID:2}));
  const move={id,command:'channel',agreementID:id,sourceID:id,channelID:2};
  assert.doesNotThrow(()=>validateGlobalCampfire(move));
  for(const channelID of [-1,0,1.5,'2',1000001,null]) assert.throws(()=>validateGlobalCampfire({...move,channelID}));
  assert.throws(()=>validateGlobalCampfire({...move,sourceID:'invalid'}));
  assert.throws(()=>validateGlobalCampfire({command:'state',channelID:-1}));
});
