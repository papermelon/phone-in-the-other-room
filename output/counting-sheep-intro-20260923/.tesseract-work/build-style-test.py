import json, subprocess, struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
CLI = '/Users/ngawangchime/Library/Application Support/Tesseract/bin/tsrct'
P = ROOT / 'Style-Transition-Test.tsrct'
W = ROOT / '.tesseract-work'

def cli(*args):
    r = subprocess.run([CLI, *map(str, args)], capture_output=True, text=True)
    if r.returncode:
        raise RuntimeError(r.stdout + r.stderr)
    return r.stdout

assets = {'room': ROOT/'Assets/hallway-v2.png', 'app': ROOT/'Assets/current-journey.png',
          'prairie': REPO/'Assets.xcassets/farm/farm_journey_prairie_backdrop.imageset/farm_journey_prairie_backdrop.png'}
for i in range(17):
    assets[f'pose{i}'] = ROOT/f'Assets/current-shepherd/shepherd-pose-{i:02}.png'
for i in range(1, 7):
    stem = f'dog_classic_run_frame_{i:02}'
    assets[f'run{i}'] = REPO/f'Assets.xcassets/dog/{stem}.imageset/{stem}.png'
sizes = {}
for key, path in assets.items():
    with path.open('rb') as f:
        f.read(16)
        sizes[key] = struct.unpack('>II', f.read(8))
    cli('project', 'import-asset', '--project', P, '--file', path, '--asset-id', key, '--kind', 'image')
cli('project', 'import-asset', '--project', P, '--file', W/'tap.wav', '--asset-id', 'shelf-contact', '--kind', 'audio')
cli('project', 'checkout', '--project', P, '--output', W/'style-base.json')
d = json.loads((W/'style-base.json').read_text())
d['dimensions'] = {'width': 1920, 'height': 1080}
d['duration'] = 7
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

# Flat generated interior; true production native Shepherd is a separately editable pose sequence.
img('room',0,1.85,0,0,1920)
phone = rect('Phone on outside shelf',0,1.85,1397,325,74,140,[.19,.15,.23,1],9)
anim(phone,'positionY','var p=Math.min(1,input.time.seconds/.7); return 325+32*p;')
screen = img('app',0,1.85,1403,332,62)
anim(screen,'positionY','var p=Math.min(1,input.time.seconds/.7); return 332+32*p;')
for i in range(17):
    p=img(f'pose{i}',0,1.85,775,5,756)
    anim(p,'opacity',f'var t=input.time.seconds; var f=t<.7?Math.min(4,Math.floor(t/.14)):Math.min(16,4+Math.floor((t-.7)/.055)); return f=={i}?100:0;')

# A deliberate readable insert uses the real QA component capture, never generated UI.
rect('Screen insert background',1.85,1.2,0,0,1920,1080,[.08,.09,.07,1])
img('app',1.85,1.2,0,0,1920,(47,1040,1111,629))

# Exact background/coat from the capture; original six-frame run at production cadence.
bg=img('prairie',2.8,4.2,0,0,1920)
anim(bg,'opacity','return 100*Math.min(1,input.time.seconds/.25);')
anchors=[500,500,451,501,500,451]
for i in range(1,7):
    dog=img(f'run{i}',2.8,4.2,500,945-anchors[i-1]*.78,399.36)
    anim(dog,'positionX','return 500+input.time.seconds*45;')
    anim(dog,'opacity',f'return Math.floor(input.time.seconds*3)%6=={i-1}?100*Math.min(1,input.time.seconds/.25):0;')
panel=rect('Quiet paper caption',3.25,3.75,95,86,1130,235,[.97,.93,.80,.92],18)
line=caption('You wind down.\nOllie follows the trail.',3.25,3.75,137,112,1060,66,[.25,.22,.27,1])
for item in [panel,line]:
    anim(item,'opacity','return 100*Math.min(1,input.time.seconds/.25);')

layers.append({'id':len(layers)+1,'type':'Audio','name':'Soft shelf contact',
               'activeRange':{'start':700,'duration':250},'sourceRange':{'start':0,'duration':250},
               'sourceIntrinsicDuration':250,'source':{'assetId':'shelf-contact'},'volume':.6,'captionsEnabled':False})
d['composition']['layers']=list(reversed(layers))
(W/'style-assembly.json').write_text(json.dumps(d,indent=2))
(W/'style-actions.json').write_text(json.dumps(actions,indent=2))
print(cli('project','commit','--project',P,'--file',W/'style-assembly.json'))
print(cli('project','apply','--project',P,'--actions',W/'style-actions.json'))
(W/'style-source-manifest.json').write_text(json.dumps({k:str(v) for k,v in assets.items()},indent=2))
