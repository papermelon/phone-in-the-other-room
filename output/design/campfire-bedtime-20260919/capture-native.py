"""Capture release scene/clock in isolated DEBUG fixtures; no account/network work."""
from pathlib import Path
import subprocess
import time

device = '60935BFC-7044-4BE8-9712-7D1B6C568A16'
bundle = 'com.ngawangchime.countingsheep'
output = Path(__file__).resolve().parent

def launch(mode, *args):
    subprocess.run(['xcrun','simctl','launch','--terminate-running-process',device,bundle,
                    '--campfire-buddies-qa','--buddy-view='+mode,*args], check=True, capture_output=True)

def capture(name):
    subprocess.run(['xcrun','simctl','io',device,'screenshot',str(output/(name+'.png'))], check=True, capture_output=True)
    print(name, flush=True)

for name, mode, args in [
    ('solo-light','bedtime-solo',['--buddy-light']),
    ('mixed-light','bedtime',['--buddy-light']),
    ('eight-dark','bedtime-eight',[]),
    ('four-light','bedtime-four',['--buddy-light']),
    ('mixed-large-text','bedtime',['--buddy-light','--buddy-max-text']),
    ('legacy-light','bedtime-legacy',['--buddy-light']),
    ('stale-dark','bedtime-stale',[]),
    ('ended-light','bedtime-ended',['--buddy-light']),
]:
    launch(mode,*args)
    time.sleep(4)
    capture(name)
launch('bedtime-boundary','--buddy-light')
time.sleep(4)
capture('boundary-before')
time.sleep(6)
capture('boundary-bedtime')
time.sleep(12)
capture('boundary-expired')
