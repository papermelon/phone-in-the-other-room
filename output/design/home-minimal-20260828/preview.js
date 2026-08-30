const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => [...document.querySelectorAll(selector)];
const notes = {
  personal: 'Chosen direction: your Ollie is the focal point. The group preview connects through its colour, avatars and a single recent highlight. Your own Shepherd can be compared as a quiet companion.',
  shared: 'Deferred: this gathering felt too busy and the characters were not distinct enough. Retained only for comparison. A shared Farm is a possible future direction, not part of this Home implementation.',
  motion: 'Approved photo-based ears and tongue greeting, planned for both Home and Farm. The older playable sheet is body timing only; rebuilding coherent frames and cosmetic layers is still required.'
};
let currentMode = 'personal';
let paused = matchMedia('(prefers-reduced-motion: reduce)').matches;
let animationToken = 0;
let toastTimer;
const names = ['Sitting', 'Ears sweep back', 'Lean forward', 'Soft flop', 'Settle on paws', 'Eyes soften', 'Rest', 'Head lifts', 'Push up', 'Rise', 'Regain balance', 'Sitting again'];
// These rectangles register generated keyframes for this prototype only.
// They do not modify the source images or constitute export-ready sprites.
const rects = [
  [55,12,290,355], [422,40,291,326], [757,100,318,267], [1099,153,367,200],
  [42,449,338,182], [396,450,330,181], [750,452,339,179], [1115,424,355,207],
  [48,695,338,281], [423,680,307,303], [777,638,288,345], [1180,638,257,350]
];
function pose(index) {
  const [x,y,w,h] = rects[index];
  $$('.sprite-clip').forEach(node => { node.style.width = w+'px'; node.style.height = h+'px'; });
  $$('.sprite-source').forEach(node => { node.style.left = -x+'px'; node.style.top = -y+'px'; });
  $('#pose').value = index;
  $('#pose-name').textContent = `${index+1} · ${names[index]}`;
  $('.motion-caption').textContent = names[index];
}
function cancelMotion() {
  animationToken++;
  $('.candidate-pose').hidden=true;
  $('.hero-motion').hidden = true;
  $('.hero-ollie').hidden = false;
}
function direction(mode) {
  cancelMotion(); currentMode = mode;
  ['personal','shared','motion'].forEach(id => { $('#'+id).classList.toggle('selected',id===mode); $('#'+id).setAttribute('aria-pressed',String(id===mode)); });
  $('#direction-note').textContent = notes[mode];
  $('#home-controls').hidden = mode==='motion'; $('#motion-controls').hidden = mode!=='motion';
  $('.preview-area').hidden = mode==='motion'; $('.motion-panel').hidden = mode!=='motion';
  $('#phone').classList.toggle('shared',mode==='shared');
  $('#phone').classList.toggle('with-shepherd',mode==='personal' && $('#personal-shepherd').checked);
  $('#personal-shepherd').disabled=mode!=='personal';
  $('#preview-label').textContent = mode==='shared'?'B · SHARED SCENE STUDY':'A · PERSONAL WELCOME';
  $('#greeting').textContent = mode==='shared'?'A quiet corner, together.':'Welcome home.';
  $('#welcome-line').textContent = mode==='shared'?'Your little circle, with room for rest.':'Ollie saved you a quiet spot.';
  $('#under-preview').textContent = mode==='shared'?'One window · illustrative gathering, not live co-presence.':'Two ornaments. One welcoming Ollie. One group highlight.';
  $('#study-canvas').hidden = false; $('.study-idle').hidden = true; pose(0);
}
['personal','shared','motion'].forEach(id=>$('#'+id).addEventListener('click',()=>direction(id)));
$('#personal-shepherd').addEventListener('change',event=>$('#phone').classList.toggle('with-shepherd',currentMode==='personal' && event.target.checked));
$('#header-mark').addEventListener('change',event=>{
  const useLogo=event.target.value==='logo';
  $('.moon').hidden=useLogo; $('.brand-logo').hidden=!useLogo;
  $('#header-note').textContent=useLogo?'Exact supplied file at 28 px: its padding makes the sheep small and the dark tile visible. A clean sheep-only source would be better for the header.':'The moon stays light at this size. The supplied logo is shown unchanged for a fair comparison.';
});
const highlights = {
  winddown:['☾','Moss completed 30 quiet minutes of Wind Down.'],
  phoneaway:['❧','Moss completed 20 quiet minutes of Phone Away.'],
  cheers:['✧','2 warm waves for your last Wind Down.'],
  round:['☾','Your group finished its seven-night round.'],
  quiet:['☾','No recent shared moments. Your group is here whenever you are.']
};
$('#highlight').addEventListener('change',event=>{
  const key=event.target.value; const [icon,copy]=highlights[key];
  $('.highlight-icon').textContent=icon; $('#highlight-copy').textContent=copy;
  $('#round-note').textContent=key==='round'?'Between rounds':'Night 2 of 7';
  $('#member-status').textContent=key==='quiet'?'No shared update':'Phone is away';
});
$('#bedtime').addEventListener('change',event=>$('.start-winddown').hidden=!event.target.checked);
$('#larger').addEventListener('change',event=>$('#phone').classList.toggle('large',event.target.checked));
$('#pause').textContent=paused?'Resume motion':'Pause motion';
$('#pause').addEventListener('click',()=>{ paused=!paused; cancelMotion(); $('#pause').textContent=paused?'Resume motion':'Pause motion'; });
$$('.demo-action').forEach(button=>button.addEventListener('click',()=>{
  clearTimeout(toastTimer); $('.toast').textContent=button.dataset.message; $('.toast').hidden=false;
  toastTimer=setTimeout(()=>$('.toast').hidden=true,3000);
}));
const nap = ms => new Promise(resolve=>setTimeout(resolve,ms));
async function play(kind,hero=false) {
  cancelMotion(); const token=animationToken;
  if(hero){$('.hero-ollie').hidden=true;$('.hero-motion').hidden=false;}
  $('#study-canvas').hidden=false;$('.study-idle').hidden=true;
  const steps = kind==='tuck'?[[0,700],[1,1600],[0,600]]:[[0,900],[1,450],[2,180],[3,110],[4,250],[5,350],[6,3000],[7,350],[8,200],[9,250],[10,200],[11,1200]];
  for(const [index,duration] of steps){if(token!==animationToken)return;pose(index);await nap(duration);}
  if(token!==animationToken)return;
  if(hero){$('.hero-motion').hidden=true;$('.hero-ollie').hidden=false;}
  $('.motion-caption').textContent='At rest · replay or inspect a keyframe';
}
$('#play-flop').addEventListener('click',()=>play('flop'));
$('#show-ears').addEventListener('click',()=>showCandidate('ears'));
$('#show-tongue').addEventListener('click',()=>showCandidate('tongue'));
$('#flop-preview').addEventListener('click',()=>play('flop',true));
$('#play-tilt').addEventListener('click',()=>{cancelMotion();$('#study-canvas').hidden=true;$('.study-idle').hidden=false;$('.motion-caption').textContent='Existing six-frame head tilt · separate action';});
$('#pose').addEventListener('input',event=>{cancelMotion();$('#study-canvas').hidden=false;$('.study-idle').hidden=true;pose(Number(event.target.value));});
setInterval(()=>{
  if(document.hidden)return;
  const phase=(Date.now()/1000)%5.2;
  const frame=paused?1:phase<2.8?1:phase<2.95?2:phase<3.12?3:phase<3.38?4:phase<4.18?5:6;
  $$('.idle').forEach(img=>{const path=`assets/ollie-idle-${frame}.png`;if(img.getAttribute('src')!==path)img.src=path;});
},83);
pose(0);

function showCandidate(kind) {
 cancelMotion(); $('#study-canvas').hidden=true; $('.study-idle').hidden=true;
 const img=$('.candidate-pose'); img.src=kind==='ears'?'assets/ollie-ear-reference-study.png':'assets/ollie-tongue-welcome-study.png'; img.alt=kind==='ears'?'Approved photo-based ear pose':'Approved tongue greeting pose, original pointed ears'; img.hidden=false;
 $('.motion-caption').textContent=kind==='ears'?'Approved photo-based ear pose · Home + Farm':'Approved tongue greeting pose · Home + Farm';
}
const onlyPreview = new URLSearchParams(location.search).get('preview');
if (onlyPreview === 'personal' || onlyPreview === 'shared') { document.body.classList.add('solo'); direction(onlyPreview); }
const previewOptions = new URLSearchParams(location.search);
if (previewOptions.get('mark')==='logo') { $('#header-mark').value='logo'; $('#header-mark').dispatchEvent(new Event('change')); }
if (previewOptions.get('shepherd')==='1') { $('#personal-shepherd').checked=true; $('#personal-shepherd').dispatchEvent(new Event('change')); }
