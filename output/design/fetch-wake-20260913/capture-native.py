"""Capture actual resting renderer -> rise -> fetch and barn crop in a disposable Farm."""
from pathlib import Path
import subprocess, time, signal, json
out = Path(__file__).resolve().parent
sim = '60935BFC-7044-4BE8-9712-7D1B6C568A16'
bundle = 'com.ngawangchime.countingsheep'
def run(*args, check=True):
    return subprocess.run(['xcrun','simctl',*args], check=check, capture_output=True, text=True)
run('install',sim,'/private/tmp/counting-sheep-shop-build/Build/Products/Debug-iphonesimulator/Counting Sheep.app')
run('ui',sim,'appearance','dark')
run('terminate',sim,bundle,check=False)
(out/'wake-and-fetch.mp4').unlink(missing_ok=True)
video = subprocess.Popen(['xcrun','simctl','io',sim,'recordVideo','--codec=h264',str(out/'wake-and-fetch.mp4')],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
time.sleep(0.5)
run('launch',sim,bundle,'--slumber-farm-fixture','--farm-state=fetch','--fetch-review','--fetch-resting')
start = time.monotonic()
manifest=[]
for at in [1,2,2.3,2.6,2.9,3.2,3.5,3.8,4.1,4.4,4.7,5,7,9,12]:
    time.sleep(max(0,start+at-time.monotonic()))
    name=f'frame-{at:04.1f}.png'
    manifest.append({'file':name,'elapsed':time.monotonic()-start})
    run('io',sim,'screenshot',str(out/name))
video.send_signal(signal.SIGINT)
video.wait(timeout=15)
(out/'capture-times.json').write_text(json.dumps(manifest,indent=2))
print('Recorded rest, wake, throw and return on the native Farm card.')
