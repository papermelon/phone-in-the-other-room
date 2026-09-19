"""Recreate ONLY campfire_buddies_test on the disposable local PostgreSQL socket/port.
Requires the dedicated pasture_test cluster at /private/tmp:55439; never hosted Supabase.
Run from repository root. The cron registration and legacy Auth adapters are test-only.
"""
import json, subprocess
from pathlib import Path
base=['-h','/private/tmp','-p','55439','-U','pasture_test']
pg=Path('/opt/homebrew/opt/postgresql@17/bin')
e=Path('output/design/campfire-buddies-20260913'); e.mkdir(parents=True,exist_ok=True)
fixtures=Path('docs/evidence/pasture-redesign-20260912')
source=(fixtures/'isolated-bootstrap.sql').read_text()
source+='\n'.join(f.read_text() for f in sorted(Path('supabase/migrations').glob('*.sql')) if f.name>='20260812120000')
source='\n'.join(line for line in source.split('\n') if not ('create extension' in line.lower() and 'pg_cron' in line.lower()))
Path('/private/tmp/pasture-release-migrations.sql').write_text(source)
subprocess.run([str(pg/'dropdb'),*base,'--if-exists','campfire_buddies_test'],check=True)
subprocess.run([str(pg/'createdb'),*base,'campfire_buddies_test'],check=True)
p=[str(pg/'psql'),*base,'-d','campfire_buddies_test','-v','ON_ERROR_STOP=1']
with open('/private/tmp/pasture-release-migrations.log','w') as f:
 subprocess.run([*p,'-f','/private/tmp/pasture-release-migrations.sql'],stdout=f,stderr=subprocess.STDOUT,check=True)
subprocess.run([*p,'-f',str(fixtures/'legacy-auth-fixture-adapter.sql')],capture_output=True,check=True)
legacy={'night_flock_v4_test.sql','night_flock_membership_sharing_test.sql','night_flock_v4_social_avatar_test.sql','night_flock_shared_habits_test.sql'}
suites=['campfire_buddies_test.sql','campfire_test.sql','shared_pasture_test.sql','night_flock_v4_test.sql','night_flock_membership_sharing_test.sql','night_flock_v4_social_avatar_test.sql','slumber_party_farm_cheer_receipts_test.sql','night_flock_shared_habits_test.sql','farm_save_test.sql','account_identity_test.sql']
results=[]
for suite in suites:
 flag='enable' if suite in legacy else 'disable'
 subprocess.run(p,input=f'alter table auth.users {flag} trigger fixture_apple_identity; alter table auth.users {flag} trigger fixture_apple_unlink;',text=True,capture_output=True,check=True)
 with (e/(suite+'.log')).open('w') as f:
  r=subprocess.run([*p,'-f','supabase/tests/'+suite],stdout=f,stderr=subprocess.STDOUT)
 results.append(dict(suite=suite,exitCode=r.returncode,legacyAuthAdapter=suite in legacy))
 print(suite,r.returncode,flush=True)
(e/'backend-results.json').write_text(json.dumps(results,indent=2)+'\n')
assert all(r['exitCode']==0 for r in results)
