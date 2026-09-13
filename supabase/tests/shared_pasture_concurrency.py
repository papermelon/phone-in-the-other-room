"""Two independent psql connections; explicitly isolated local database only.
Run after migrations: python3 supabase/tests/shared_pasture_concurrency.py
"""
import concurrent.futures
import hashlib
import json
import subprocess
import uuid

PSQL = ['/opt/homebrew/opt/postgresql@17/bin/psql', '-h', '/private/tmp', '-p', '55439',
        '-U', 'pasture_test', '-d', 'pasture_release', '-v', 'ON_ERROR_STOP=1', '-At']

def sql(query):
    return subprocess.run(PSQL, input=query, text=True, capture_output=True, check=True).stdout.strip()

def literal(value):
    return "'" + value.replace("'", "''") + "'"

def command(owner, payload):
    return f"select public.night_flock_v4_command('{owner}',{literal(json.dumps(payload))}::jsonb);"

a, b = str(uuid.uuid4()), str(uuid.uuid4())
sql(f"insert into auth.users(id,email_confirmed_at,is_anonymous) values('{a}',now(),false),('{b}',now(),false);")
party = json.loads(sql(command(a, dict(command='createParty', name='Isolated placement race', timeZoneIdentifier='UTC'))))['resolvedPartyID']
sql(f"insert into private.night_flock_v4_memberships(party_id,user_id,role) values('{party}','{b}','member');")
epochs = {owner: sql(f"select id from private.night_flock_v4_membership_epochs where party_id='{party}' and user_id='{owner}' and ended_at is null;") for owner in [a, b]}
entity = 'member-' + epochs[b]
payloads = [dict(command='movePastureEntity', partyID=party, memberEpochID=epochs[owner], sceneRevision=1,
                entityID=entity, expectedRevision=0, x=x, y=0.7,
                idempotencyKey=hashlib.sha256(uuid.uuid4().bytes).hexdigest()) for owner, x in [(a, 0.5), (b, 0.7)]]

def race_move(pair):
    owner, payload = pair
    result = sql('begin;' + command(owner, payload) + 'select pg_sleep(0.15); commit;')
    return json.loads(next(line for line in result.splitlines() if line.startswith('{')))

with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    responses = list(pool.map(race_move, zip([a, b], payloads)))
assert sorted(r['conflict'] for r in responses) == [False, True], responses
assert sql(f"select revision from private.shared_pasture_layout where party_id='{party}' and entity_id='{entity}';") == '1'
for owner, payload in zip([a, b], payloads):
    sql(command(owner, payload))
assert sql(f"select revision from private.shared_pasture_layout where party_id='{party}' and entity_id='{entity}';") == '1'
print('PASS: simultaneous peer moves produce one winner, one conflict; retries keep revision 1')

# Two already eligible personal grants for the same member/day race to settle.
ledgers = [str(uuid.uuid4()), str(uuid.uuid4())]
for ledger, mode in zip(ledgers, ['windDown', 'phoneAway']):
    sql(f"insert into private.night_flock_v4_activity_ledger(id,user_id,source_event_id,kind,outcome,started_at,ended_at,wind_down_minutes,phone_away_minutes,status_revision) values('{ledger}','{a}',gen_random_uuid(),'{mode}','completed',now(),now(),0,0,1);")
def grant(ledger):
    return sql(f"begin; insert into private.night_flock_v4_grants(user_id,party_id,ledger_id) values('{a}','{party}','{ledger}'); select pg_sleep(0.15); commit;")
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    list(pool.map(grant, ledgers))
assert sql(f"select contributions from private.shared_pasture_projects where party_id='{party}';") == '1'
assert sql(f"select count(*) from private.night_flock_v4_grants where party_id='{party}';") == '2'
print('PASS: simultaneous daily grants add one project contribution and preserve both personal grants')
print('Fixtures remain only in disposable pasture_release, never in hosted Supabase')
