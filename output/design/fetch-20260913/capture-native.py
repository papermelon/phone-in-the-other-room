"""Isolated production Farm-card review; no account/network fixtures are used."""
import pathlib, subprocess, time, signal
OUT = pathlib.Path(__file__).resolve().parent
SIM = '60935BFC-7044-4BE8-9712-7D1B6C568A16'
APP = '/private/tmp/counting-sheep-shop-build/Build/Products/Debug-iphonesimulator/Counting Sheep.app'
BUNDLE = 'com.ngawangchime.countingsheep'
def run(*args, check=True):
    return subprocess.run(['xcrun', 'simctl', *args], check=check, capture_output=True, text=True)
run('install', SIM, APP)
run('ui', SIM, 'appearance', 'dark')
run('terminate', SIM, BUNDLE, check=False)
(OUT/'fetch-round.mp4').unlink(missing_ok=True)
video = subprocess.Popen(['xcrun','simctl','io',SIM,'recordVideo','--codec=h264',str(OUT/'fetch-round.mp4')],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
time.sleep(0.5)
run('launch', SIM, BUNDLE, '--slumber-farm-fixture', '--farm-state=fetch', '--fetch-review')
began = time.monotonic()
for at, name in [(2,'ready'),(3.5,'flight'),(4.4,'outbound'),(5.6,'pickup'),(7.8,'pickup-close'),(8.4,'return'),(11,'delivered')]:
    time.sleep(max(0, began+at-time.monotonic()))
    run('io',SIM,'screenshot',str(OUT/(name+'.png')))
video.send_signal(signal.SIGINT)
video.wait(timeout=15)
run('terminate', SIM, BUNDLE, check=False)
run('launch', SIM, BUNDLE, '--slumber-farm-fixture', '--farm-state=fetch', '--fetch-review', '--fetch-aim')
time.sleep(3)
run('io',SIM,'screenshot',str(OUT/'aim.png'))
run('terminate', SIM, BUNDLE, check=False)
run('launch', SIM, BUNDLE, '--slumber-farm-fixture', '--farm-state=fetch', '--fetch-review', '--fetch-ready', '--farm-accessibility')
time.sleep(2)
run('io',SIM,'screenshot',str(OUT/'ready-accessibility.png'))
print('Captured real Farm card, full fetch sequence and large type controls.')
