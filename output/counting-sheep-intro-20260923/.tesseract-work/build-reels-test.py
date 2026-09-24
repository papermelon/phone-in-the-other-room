import json, subprocess, struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
CLI = '/Users/ngawangchime/Library/Application Support/Tesseract/bin/tsrct'
P = ROOT / 'Style-Transition-Test-Reels.tsrct'
W = ROOT / '.tesseract-work'

def cli(*args):
    r = subprocess.run([CLI, *map(str, args)], capture_output=True, text=True)
    if r.returncode:
        raise RuntimeError(r.stdout + r.stderr)
    return r.stdout

assets = {'room': ROOT/'Assets/hallway-reels-v3.png', 'app': ROOT/'Assets/current-wind-down-full.png',
          'prairie': REPO/'Assets.xcassets/farm/farm_journey_prairie_backdrop.imageset/farm_journey_prairie_backdrop.png'}
for i in range(17):
    assets[f'pose{i}'] = ROOT/f'Assets/current-shepherd/shepherd-pose-{i:02}.png'
for i in range(1, 7):
    stem = f'dog_classic_run_frame_{i:02}'
    assets[f'run{i}'] = ROOT/f'Assets/current-ollie/ollie-bandana-run-{i:02}.png'
sizes = {}
for key, path in assets.items():
    with path.open('rb') as f:
        f.read(16)
        sizes[key] = struct.unpack('>II', f.read(8))
    cli('project', 'import-asset', '--project', P, '--file', path, '--asset-id', key, '--kind', 'image')
cli('project', 'import-asset', '--project', P, '--file', W/'tap.wav', '--asset-id', 'shelf-contact', '--kind', 'audio')
cli('project', 'checkout', '--project', P, '--output', W/'reels-base.json')
d = json.loads((W/'reels-base.json').read_text())
d['dimensions'] = {'width': 1080, 'height': 1920}
d['duration'] = 9
d['composition']['name'] = 'Counting Sheep · phone away to Ollie · style test'
layers, actions = [], []

def base(kind, name, start, duration, x=0, y=0, scale=100):
    return {'id': len(layers)+1, 'type': kind, 'name': name, 'blendMode': 'normal',
            'activeRange': {'start': round(start*1000), 'duration': round(duration*1000)},
            'transform': {'anchorPoint': [0,0], 'position': [x,y], 'scale': [scale,scale], 'rotation': 0, 'opacity': 100}}

def add(l):
    layers.append(l)
    return l['id']

def img(key, start, duration, x, y, width, crop=None):
    sw = crop[2] if crop else sizes[key][0]
    l = base('Image', key, start, duration, x, y, width/sw*100)
    l['source'] = {'assetId':key, 'fit':'contain'}
    if crop:
        l['source']['sourceRect'] = dict(zip(('x','y','width','height'),crop))
    return add(l)

def rect(name,start,duration,x,y,w,h,color,r=0):
    l=base('Rect',name,start,duration,x,y)
    l['rect']={'size':[w,h],'fillColor':color,'roundness':r}
    return add(l)

def anim(i,p,code):
    actions.append({'type':'setFxPropertyAnimator','compositionId':'main',
                    'property':{'layerId':i,'propertyType':p},
                    'animator':{'type':'jsScript','layerTimeJsCode':code},'dependencies':[]})

def caption(words,start,duration,x,y,width,fs,color):
    l=base('Text',words,start,duration,x,y)
    l['sourceText']={'text':words,'fontFamily':'Arial Rounded MT Bold','fontStyle':'Regular',
                     'fontSize':fs,'fillColor':color,'strokeWidth':0,'justification':'left',
                     'boxText':True,'boxPosition':[0,0],'boxSize':[width,200],'leading':fs*1.17}
    return add(l)

# Portrait composition; geography and action stay legible on a phone.
img('room',0,2,0,0,1080)
phone=rect('Illustrated phone outside bedroom',0,2,761,816,82,148,[.19,.15,.23,1],9)
anim(phone,'positionY','var p=Math.min(1,input.time.seconds/.7); return 816+32*p;')
screen=img('app',0,2,769,825,66)
anim(screen,'positionY','var p=Math.min(1,input.time.seconds/.7); return 825+32*p;')
for i in range(17):
    pose=img(f'pose{i}',0,2,65,444,840)
    anim(pose,'opacity',f'var t=input.time.seconds; var f=t<.7?Math.min(4,Math.floor(t/.14)):Math.min(16,4+Math.floor((t-.7)/.055)); return f=={i}?100:0;')
caption('You wind down.',0,2,88,210,880,74,[.32,.18,.27,1])

# The illustrated world waits behind a visible phone rather than masquerading as UI.
img('prairie',5.2,3.8,-1130,0,3413.333)
anchors=[500,500,451,501,500,451]
for i in range(1,7):
    dog=img(f'run{i}',5.2,3.8,80,1520-anchors[i-1]*1.25,640)
    anim(dog,'positionX','return 80+input.time.seconds*36;')
    anim(dog,'opacity',f'return Math.floor(input.time.seconds*3)%6=={i-1}?100:0;')
rect('Paper story caption',5.7,3.3,72,228,850,255,[.97,.93,.80,.96],20)
caption('You wind down.\nOllie follows the trail.',5.7,3.3,110,257,785,62,[.25,.22,.27,1])

# Hold a complete actual app view in a recognisable device frame.
rect('Paper behind device',2,3.2,0,0,1080,1920,[.98,.96,.90,1])
ui=[]
ui.append(caption('In Counting Sheep',2,3.7,130,115,820,45,[.32,.18,.27,1]))
ui.append(rect('Phone bezel — app experience',2,3.7,138,235,756,1575,[.20,.16,.22,1],58))
ui.append(rect('Screen surround',2,3.7,150,247,732,1551,[.047,.043,.035,1],48))
ui.append(img('app',2,3.7,169,274,694))
# The home indicator and real navigation belong to the capture; do not invent UI.
for item in ui:
    anim(item,'opacity','return 100*Math.max(0,Math.min(1,(3.7-input.time.seconds)/.5));')

layers.append({'id':len(layers)+1,'type':'Audio','name':'Soft shelf contact',
               'activeRange':{'start':700,'duration':250},'sourceRange':{'start':0,'duration':250},
               'sourceIntrinsicDuration':250,'source':{'assetId':'shelf-contact'},'volume':.6,'captionsEnabled':False})
d['composition']['layers']=list(reversed(layers))
(W/'reels-assembly.json').write_text(json.dumps(d,indent=2))
(W/'reels-actions.json').write_text(json.dumps(actions,indent=2))
print(cli('project','commit','--project',P,'--file',W/'reels-assembly.json'))
print(cli('project','apply','--project',P,'--actions',W/'reels-actions.json'))
(W/'reels-source-manifest.json').write_text(json.dumps({k:str(v) for k,v in assets.items()},indent=2))
