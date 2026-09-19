from pathlib import Path
import subprocess,time
sim='60935BFC-7044-4BE8-9712-7D1B6C568A16'
bundle='com.ngawangchime.countingsheep'
out=Path('output/design/campfire-live-repair-20260913')
subprocess.run(['xcrun','simctl','install',sim,'/private/tmp/counting-sheep-shop-build/Build/Products/Debug-iphonesimulator/Counting Sheep.app'],check=True)
for mode,large in [('empty-party',False),('campfire-solo',False),('active-party',False),('large-party',False),('stale-party',False),('campfire-expired',False),('campfire-solo',True)]:
 subprocess.run(['xcrun','simctl','terminate',sim,bundle],capture_output=True)
 subprocess.run(['xcrun','simctl','launch',sim,bundle,'--slumber-farm-fixture','--campfire-direct','--farm-state='+mode,*(['--farm-accessibility'] if large else [])],check=True,capture_output=True)
 time.sleep(5)
 subprocess.run(['xcrun','simctl','io',sim,'screenshot',str(out/(mode+('-large' if large else '')+'.png'))],check=True,capture_output=True)
 print(mode,large,flush=True)
