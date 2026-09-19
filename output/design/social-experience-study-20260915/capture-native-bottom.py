from pathlib import Path
import subprocess, time
sim = '60935BFC-7044-4BE8-9712-7D1B6C568A16'
bundle = 'com.ngawangchime.countingsheep'
out = Path('output/design/social-experience-study-20260915')
shots = [
    ('twoSessions', 'party', 'light', False),
    ('quiet', 'party', 'dark', False),
    ('twoSessions', 'party', 'light', True),
    ('eightPeople', 'campfire', 'dark', False),
    ('sharingOff', 'campfire', 'light', False),
]
for fixture, surface, appearance, large in shots:
    name = f'{surface}-{fixture}-{appearance}{"-ax5" if large else ""}-bottom'
    subprocess.run(['xcrun', 'simctl', 'terminate', sim, bundle], capture_output=True)
    subprocess.run(['xcrun', 'simctl', 'ui', sim, 'appearance', appearance], check=True)
    args = ['--social-study', f'--social-study-state={fixture}', f'--social-study-surface={surface}', '--social-study-bottom'] + (['--social-study-large'] if large else [])
    subprocess.run(['xcrun', 'simctl', 'launch', sim, bundle, *args], check=True, capture_output=True)
    time.sleep(4.5)
    subprocess.run(['xcrun', 'simctl', 'io', sim, 'screenshot', str(out / f'{name}.png')], check=True, capture_output=True)
    print(name, flush=True)
