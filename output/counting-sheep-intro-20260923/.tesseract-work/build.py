import json, subprocess, struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
REPO=ROOT.parents[1]
CLI='/Users/ngawangchime/Library/Application Support/Tesseract/bin/tsrct'
P=ROOT/'Counting-Sheep.tsrct'; W=ROOT/'.tesseract-work'
def cli(*a):
 r=subprocess.run([CLI,*map(str,a)],text=True,capture_output=True)
 if r.returncode: raise RuntimeError(r.stdout+r.stderr)
 return r.stdout
assets={
 'rest-story':'Assets.xcassets/onboarding/onboarding_phone_rest_story.imageset/onboarding_phone_rest_story.png',
 'home':'output/design/home-compact-social-20260922/wind-down-compact.png',
 'farm-screen':'output/design/wardrobe-layers-20260923/fuller-farm.png',
 'wardrobe':'output/design/wardrobe-layers-20260923/coat-picker.png',
 'moonlit':'Assets.xcassets/farm/farm_journey_moonlit_backdrop.imageset/farm_journey_moonlit_backdrop.png',
 'ollie':'Assets.xcassets/dog/dog_fuller_classic_farm_idle.imageset/dog_fuller_classic_farm_idle.png',
 'sheep':'Assets.xcassets/sheep/sheep_bramble_wool_ready.imageset/sheep_bramble_wool_ready.png',
 'luna':'Assets.xcassets/sheep/sheep_luna_wool_ready.imageset/sheep_luna_wool_ready.png',
 'marigold':'Assets.xcassets/sheep/sheep_marigold_wool_ready.imageset/sheep_marigold_wool_ready.png',
}
for i in range(1,7):
 for kind,name in [('run','dog_fuller_classic_run_frame'),('sheeprun','sheep_bramble_chase_run_frame')]:
  folder='dog' if kind=='run' else 'sheep'; stem=f'{name}_{i:02}'
  assets[f'{kind}{i}']=f'Assets.xcassets/{folder}/{stem}.imageset/{stem}.png'
size={}
for key,path in assets.items():
 f=REPO/path
 with f.open('rb') as h: h.read(16); size[key]=struct.unpack('>II',h.read(8))
 cli('project','import-asset','--project',P,'--file',f,'--asset-id',key,'--kind','image')
for key in ['tap','air','chime']:
 cli('project','import-asset','--project',P,'--file',W/f'{key}.wav','--asset-id',key,'--kind','audio')
cli('project','checkout','--project',P,'--output',W/'base.json')
D=json.load(open(W/'base.json')); D['dimensions']={'width':1920,'height':1080}; D['duration']=33
D['composition']['name']='Counting Sheep • An evening with Ollie'
# New scenes are assembled from native text, rectangles and original app artwork.
layers=[]; actions=[]; groups=[]; counter=0
cream=[.98,.97,.92,1]; ink=[.12,.12,.10,1]; muted=[.45,.45,.40,1]; moss=[.37,.53,.27,1]; night=[.055,.075,.06,1]; lavender=[.70,.66,.84,1]
def tx(x=0,y=0,s=100,anchor=(0,0)):
 return {'anchorPoint':list(anchor),'position':[x,y],'scale':[s,s],'rotation':0,'opacity':100}
def base(typ,name,start,dur,x=0,y=0,s=100,anchor=(0,0)):
 global counter
 counter+=1
 return {'type':typ,'id':counter,'name':name,'blendMode':'normal','activeRange':{'start':round(start*1000),'duration':round(dur*1000)},'transform':tx(x,y,s,anchor)}
def add(l):layers.append(l);return l['id']
def rect(name,start,dur,x,y,w,h,c,r=0):
 l=base('Rect',name,start,dur,x,y);l['rect']={'size':[w,h],'fillColor':c,'roundness':r};return add(l)
def text(s,start,dur,x,y,w,h,fs=70,c=ink,mono=False,align='left',bold=True):
 l=base('Text',s.replace('\n',' / '),start,dur,x,y)
 l['sourceText']={'text':s,'fontFamily':'.SF NS Mono' if mono else 'Arial Rounded MT Bold' if bold else '.SF NS Rounded','fontStyle':'Light' if mono else 'Regular','fontSize':fs,'fillColor':c,'strokeWidth':0,'justification':align,'boxText':True,'boxPosition':[0,0],'boxSize':[w,h],'leading':fs*1.13}
 return add(l)
def img(key,start,dur,x,y,width,crop=None):
 sw,sh=size[key]
 l=base('Image',key,start,dur,x,y,width/sw*100)
 l['source']={'assetId':key,'fit':'contain'}
 if crop: l['source']['sourceRect']=dict(zip(['x','y','width','height'],crop))
 return add(l)
def anim(i,prop,code):
 actions.append({'type':'setFxPropertyAnimator','compositionId':'main','property':{'layerId':i,'propertyType':prop},'animator':{'type':'jsScript','layerTimeJsCode':code},'dependencies':[]})
def ease(i,prop,a,b,seconds=.7):
 anim(i,prop,f'var p=Math.min(1,Math.max(0,input.time.seconds/{seconds})); p=1-Math.pow(1-p,3); return {a}+({b-a})*p;')
def fade(i,dur):
 anim(i,'opacity',f'var t=input.time.seconds; return 100*Math.min(1,t/.35,({dur}-t)/.30);')
def rise(i,y):ease(i,'positionY',y+35,y)
def begin():return len(layers)
def end(idx,name):
 # The group operation wraps contiguous siblings, preserving their timeline clocks.
 groups.append((name,[x['id'] for x in layers[idx:]]))
def label(s,t,d,c=moss):return text(s,t,d,130,130,1600,60,27,c,True)
def footer(t,d,dark=False):
 c=cream if dark else muted
 text('COUNTING SHEEP',t,d,130,972,600,50,22,c,True)
# 01: meaningful opening, product proposition visible immediately.
b=begin()
rect('Warm paper',0,5.25,0,0,1920,1080,cream)
label('A SMALL EVENING RITUAL',0,5.25)
i=text('Let the day\nsettle.',0,5.25,130,280,820,255,112);rise(i,280)
text('Put your phone in another room.\nMake a little space for yourself.',.55,4.70,136,590,790,160,39,muted,bold=False)
i=img('rest-story',0,5.25,910,260,960);ease(i,'positionX',1040,910,1.2)
footer(0,5.25)
end(b,'01 • Make space')
# 02: real Wind Down screen and a readable explanation.
b=begin()
rect('Forest green',5,6.25,0,0,1920,1080,night)
label('01  /  WIND DOWN',5,6.25,lavender)
i=text('An evening\nthat feels yours.',5.15,6.10,130,285,1000,240,88,cream);rise(i,285)
text('Choose your time.\nPick a simple routine.\nStart when you’re ready.',5.65,5.60,136,578,930,230,43,[.72,.70,.64,1],bold=False)
rect('Phone border',5.25,6,1223,71,442,954,[.30,.36,.29,1],48)
img('home',5.25,6,1235,83,418)
text('App preview',5.25,6,1710,932,160,70,21,[.72,.70,.64,1],bold=False)
footer(5,6.25,True)
end(b,'02 • Choose your Wind Down')
# 03: native animated run cycle, moonlit scene, calm narrative.
b=begin()
img('moonlit',11,6.25,0,0,1920)
rect('Quiet top tint',11,6.25,0,0,1920,400,[.045,.085,.13,.58])
label('02  /  MEET YOUR COMPANION',11,6.25,cream)
i=text('Ollie keeps you company.',11.2,6.05,130,221,1700,140,80,cream);rise(i,221)
text('Through Wind Down and into Screen-Free Morning.',11.65,5.60,136,339,1660,90,35,cream,bold=False)
for k in range(1,7):
 i=img(f'run{k}',11,6.25,640,520,455)
 anim(i,'opacity',f'return Math.floor(input.time.seconds*9)%6=={k-1}?100:0;')
 anim(i,'positionX','return 610+input.time.seconds*34;')
 i=img(f'sheeprun{k}',11,6.25,1120,665,255)
 anim(i,'opacity',f'return Math.floor(input.time.seconds*9)%6=={k-1}?100:0;')
 anim(i,'positionX','return 1080+input.time.seconds*34;')
footer(11,6.25,True)
end(b,'03 • Across the moonlit hills')
# 04: source Farm preview uses a native source rectangle to omit capture margins.
b=begin()
rect('Warm paper',17,6.25,0,0,1920,1080,cream)
label('03  /  YOUR FARM',17,6.25)
i=text('Small rituals.\nA growing flock.',17.15,6.10,130,290,840,235,88);rise(i,290)
text('Follow Ollie’s Search.\nMeet the sheep.\nCollect a little wool.',17.65,5.60,136,598,760,220,40,muted,bold=False)
# sourceRect is pixel coordinates in the source capture.
i=img('farm-screen',17.25,6,940,252,960,crop=(31,406,688,562));ease(i,'positionX',1050,940)
footer(17,6.25)
end(b,'04 • A farm to come back to')
# 05: wardrobe with authentic app capture.
b=begin()
rect('Soft sage',23,5.25,0,0,1920,1080,[.90,.925,.86,1])
label('04  /  MAKE IT YOURS',23,5.25)
i=text('A little more\nyou.',23.15,5.10,130,288,940,240,93);rise(i,288)
text('Dress your shepherd.\nFind a favourite look for Ollie.',23.60,4.65,136,579,980,160,39,muted,bold=False)
i=img('ollie',23.4,4.85,815,567,330);ease(i,'positionY',595,567)
rect('Shop capture border',23.2,5.05,1270,79,499,902,[.38,.46,.34,1],32)
img('wardrobe',23.2,5.05,1282,91,475)
footer(23,5.25)
end(b,'05 • A personal touch')
# 06: closing brand, characters arrive as a small flock.
b=begin()
rect('Warm paper',28,5,0,0,1920,1080,cream)
text('COUNTING SHEEP',28,5,130,133,1660,65,30,moss,True,align='center')
i=text('Your evening.\nA little quieter.',28.1,4.9,250,285,1420,270,112,ink,align='center');rise(i,285)
text('Start with putting your phone away.',28.6,4.4,290,573,1340,85,37,muted,bold=False,align='center')
for key,x,y,w,delay in [('ollie',615,703,245,0),('sheep',885,760,185,.12),('luna',1080,754,190,.24),('marigold',1275,767,175,.36)]:
 i=img(key,28.4+delay,4.6-delay,x,y,w);ease(i,'positionX',x+100,x,.85);fade(i,4.6-delay)
end(b,'06 • Counting Sheep')
# Reverse entire layer list: later created elements are in front.
D['composition']['layers']=list(reversed(layers))
for key,start,duration,volume in [('tap',5.50,.25,1),('air',16.65,.7,1),('chime',28.45,1.8,1)]:
 counter+=1
 D['composition']['layers'].insert(0,{'id':counter,'name':f'Quiet {key} accent','type':'Audio','activeRange':{'start':int(start*1000),'duration':int(duration*1000)},'sourceRange':{'start':0,'duration':int(duration*1000)},'sourceIntrinsicDuration':int(duration*1000),'source':{'assetId':key},'volume':volume,'captionsEnabled':False})
json.dump(D,open(W/'assembly.json','w'),indent=2)
print(cli('project','commit','--project',P,'--file',W/'assembly.json'))
# Group after construction; Tesseract rewrites child clocks without changing their source.
groupactions=[]
for name,ids in groups:
 counter+=1;gid=counter
 groupactions.append({'type':'groupFxCompositionLayers','compositionId':'main','layerIds':list(reversed(ids)),'groupLayerId':gid,'name':name,'transform':tx()})
 # A 250 ms dissolve brings the incoming scene over the preceding one.
 if not name.startswith('01'):
  actions.append({'type':'setFxPropertyKeyframes','compositionId':'main','property':{'layerId':gid,'propertyType':'opacity'},'keyframes':[{'id':f'scene-{gid}-in','layerTime':0,'value':{'type':'float','value':0},'easing':{'type':'linear'}},{'id':f'scene-{gid}-hold','layerTime':250,'value':{'type':'float','value':100},'easing':{'type':'linear'}}]})
json.dump(groupactions+actions,open(W/'animation-actions.json','w'),indent=2)
print(cli('project','apply','--project',P,'--actions',W/'animation-actions.json'))
cli('project','checkout','--project',P,'--output',W/'current.json')
json.dump({'sources':assets,'sizes':size},open(W/'source-manifest.json','w'),indent=2)
print('Assembly saved')
