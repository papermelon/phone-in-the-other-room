from pathlib import Path
import subprocess, time, sys
sim = '60935BFC-7044-4BE8-9712-7D1B6C568A16'
bundle = 'com.ngawangchime.countingsheep'
out = Path('output/design/social-experience-study-20260915')
out.mkdir(parents=True, exist_ok=True)

# (fixture, surface, appearance, large)
shots = [
    ('twoSessions', 'party', 'light', False),
    ('twoSessions', 'party', 'dark', False),
    ('quiet', 'party', 'dark', False),
    ('eightPeople', 'party', 'light', False),
    ('sharingOff', 'party', 'light', False),
    ('loading', 'party', 'light', False),
    ('failed', 'party', 'dark', False),
    ('stale', 'party', 'light', False),
    ('returnCheckIn', 'party', 'light', False),
    ('twoSessions', 'party', 'light', True),
    ('twoSessions', 'campfire', 'light', False),
    ('eightPeople', 'campfire', 'dark', False),
    ('quiet', 'campfire', 'light', False),
    ('sharingOff', 'campfire', 'dark', False),
    ('loading', 'campfire', 'light', False),
    ('failed', 'campfire', 'light', False),
    ('stale', 'campfire', 'light', False),
    ('eightPeople', 'campfire', 'light', True),
    ('twoSessions', 'person', 'light', False),
    ('twoSessions', 'person', 'dark', True),
    ('returnCheckIn', 'person', 'light', False),
    ('twoSessions', 'public-person', 'light', False),
    ('returnCheckIn', 'public-person', 'dark', False),
    ('stale', 'home', 'light', False),
    ('twoSessions', 'home', 'dark', False),
    ('returnCheckIn', 'home', 'light', True),
]
only = sys.argv[1:]
for fixture, surface, appearance, large in shots:
    name = f'{surface}-{fixture}-{appearance}{"-ax5" if large else ""}'
    if only and name not in only:
        continue
    subprocess.run(['xcrun', 'simctl', 'terminate', sim, bundle], capture_output=True)
    subprocess.run(['xcrun', 'simctl', 'ui', sim, 'appearance', appearance], check=True)
    args = ['--social-study', f'--social-study-state={fixture}', f'--social-study-surface={surface}'] + (['--social-study-large'] if large else [])
    subprocess.run(['xcrun', 'simctl', 'launch', sim, bundle, *args], check=True, capture_output=True)
    time.sleep(4.5)
    subprocess.run(['xcrun', 'simctl', 'io', sim, 'screenshot', str(out / f'{name}.png')], check=True, capture_output=True)
    print(name, flush=True)
