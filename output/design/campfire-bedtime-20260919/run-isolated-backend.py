"""Local disposable PostgreSQL only; never connects to hosted Supabase.
Start a dedicated cluster at /private/tmp/campfire-bedtime-pg on socket
/private/tmp/campfire-bedtime-socket, port 55449, as campfire_test.
"""
import json
import subprocess
from pathlib import Path

pg = Path('/opt/homebrew/opt/postgresql@17/bin')
base = ['-h', '/private/tmp/campfire-bedtime-socket', '-p', '55449', '-U', 'campfire_test']
evidence = Path(__file__).resolve().parent
fixtures = Path('docs/evidence/pasture-redesign-20260912')
subprocess.run([str(pg/'createdb'), *base, 'campfire_bedtime_test'], check=True)
p = [str(pg/'psql'), *base, '-d', 'campfire_bedtime_test', '-v', 'ON_ERROR_STOP=1']
source = (fixtures/'isolated-bootstrap.sql').read_text()
source += '\n'.join(f.read_text() for f in sorted(Path('supabase/migrations').glob('*.sql'))
                    if '20260812120000' <= f.name < '20260919130000')
source = '\n'.join(line for line in source.splitlines()
                   if not ('create extension' in line.lower() and 'pg_cron' in line.lower()))
with (evidence/'migrations.log').open('w') as log:
    subprocess.run(p, input=source, text=True, stdout=log, stderr=subprocess.STDOUT, check=True)
with (evidence/'upgrade.log').open('w') as log:
    subprocess.run([*p, '-f', 'supabase/tests/campfire_bedtime_upgrade_test.sql'], stdout=log, stderr=subprocess.STDOUT, check=True)
with (evidence/'migration-bedtime.log').open('w') as log:
    subprocess.run([*p, '-f', 'supabase/migrations/20260919130000_campfire_bedtime.sql'], stdout=log, stderr=subprocess.STDOUT, check=True)
subprocess.run([*p, '-f', str(fixtures/'legacy-auth-fixture-adapter.sql')], capture_output=True, check=True)
legacy = {'night_flock_v4_test.sql', 'night_flock_membership_sharing_test.sql', 'night_flock_v4_social_avatar_test.sql', 'night_flock_shared_habits_test.sql'}
suites = ['campfire_bedtime_test.sql', 'campfire_test.sql', 'campfire_buddies_test.sql', 'shared_pasture_test.sql',
          'night_flock_v4_test.sql', 'night_flock_membership_sharing_test.sql', 'night_flock_v4_social_avatar_test.sql',
          'slumber_party_farm_cheer_receipts_test.sql', 'night_flock_shared_habits_test.sql', 'farm_save_test.sql', 'account_identity_test.sql']
results = []
for suite in suites:
    flag = 'enable' if suite in legacy else 'disable'
    subprocess.run(p, input=f'alter table auth.users {flag} trigger fixture_apple_identity; alter table auth.users {flag} trigger fixture_apple_unlink;',
                   text=True, capture_output=True, check=True)
    with (evidence/(suite+'.log')).open('w') as log:
        result = subprocess.run([*p, '-f', 'supabase/tests/'+suite], stdout=log, stderr=subprocess.STDOUT)
    results.append(dict(suite=suite, exitCode=result.returncode, legacyAuthAdapter=suite in legacy))
    print(suite, result.returncode, flush=True)
(evidence/'backend-results.json').write_text(json.dumps(results, indent=2)+'\n')
assert all(r['exitCode'] == 0 for r in results)
