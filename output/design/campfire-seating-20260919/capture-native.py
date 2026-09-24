"""Local, network-free fixtures using the production Campfire components."""
from pathlib import Path
import subprocess
import time
root = Path(__file__).resolve().parent
device = '60935BFC-7044-4BE8-9712-7D1B6C568A16'
for name, mode, flags in [
    ('eight-dark', 'bedtime-eight', []),
    ('mixed-light', 'bedtime', ['--buddy-light']),
    ('buddy-party', 'unified-party', ['--buddy-light']),
    ('buddy-actions', 'unified-party', ['--buddy-light', '--buddy-bottom']),
    ('buddy-large-text', 'unified-party', ['--buddy-light', '--buddy-max-text']),
    ('global-unavailable', 'unified-unavailable', ['--buddy-light']),
    ('global-connection', 'unified-failed', ['--buddy-light']),
    ('global-empty', 'unified-empty', ['--buddy-light']),
]:
    subprocess.run(['xcrun','simctl','launch','--terminate-running-process',device,
                    'com.ngawangchime.countingsheep','--campfire-buddies-qa','--buddy-view='+mode,*flags], check=True, capture_output=True)
    time.sleep(4)
    subprocess.run(['xcrun','simctl','io',device,'screenshot',str(root/(name+'.png'))], check=True, capture_output=True)
    print(name, flush=True)
