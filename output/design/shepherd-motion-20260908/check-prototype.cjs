const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = fs.readFileSync(`${__dirname}/shepherd-motion.html`, 'utf8');
const script = source.match(/<script>([\s\S]*?)<\/script>/)[1];
function harness(reduce = false) {
  const make = () => ({innerHTML:'',textContent:'',listeners:{},attrs:{},addEventListener(t,f){this.listeners[t]=f;},setAttribute(k,v){this.attrs[k]=v;}});
  const choices = Object.fromEntries(['head','hair','outfit','skin','hat','direction','left','texture'].map(k=>[k,Object.assign(make(),{dataset:{choice:k},type:['hat','left','texture'].includes(k)?'checkbox':'select'})]));
  const actions = Object.fromEntries(['walk','idle','stop','turn','step'].map(k=>[k,make()]));
  const renders=[make(),make()], status=make(); let pending=null;
  const root={querySelectorAll(s){return s==='[data-render]'?renders:Object.values(choices);},querySelector(s){if(s==='.motion-status')return status;const m=s.match(/data-(action|choice)="([^"]+)"/);return (m[1]==='action'?actions:choices)[m[2]];}};
  vm.runInNewContext(script,{document:{getElementById(){return root;},hidden:false},window:{matchMedia(){return {matches:reduce,addEventListener(){}};}},performance:{now(){return 0;}},requestAnimationFrame(f){pending=f;return 1;},cancelAnimationFrame(){pending=null;},console});
  return {renders,status,actions,set(k,v){choices[k].value=v;choices[k].checked=v;choices[k].listeners.change();},click(k){actions[k].listeners.click();},frame(t){const f=pending;if(f)f(t);},pending(){return !!pending;}};
}
const h=harness(); let cases=0;
for(const head of ['B','C'])for(const hair of ['short','long'])for(const outfit of ['coat','shirt','dress'])for(const skin of ['porcelain','warm','olive','brown','deep'])for(const direction of ['front','quarter','side','rear','back'])for(const left of [false,true]){
  for(const [k,v] of Object.entries({head,hair,outfit,skin,direction,left}))h.set(k,v);
  h.set('hat',false);const bare=h.renders[0].innerHTML;
  h.set('hat',true);assert.notEqual(h.renders[0].innerHTML,bare);
  h.set('hat',false);assert.equal(h.renders[0].innerHTML,bare,'Hat off must restore exact base rendering');
  assert(!/NaN|undefined/.test(bare));
  assert.equal(bare.includes('data-part="eyes"'),!['rear','back'].includes(direction),'Back views must hide facial drawing');
  cases++;
}
h.set('direction','quarter');h.click('walk');const before=h.renders[0].innerHTML;h.frame(34);h.frame(68);assert.notEqual(h.renders[0].innerHTML,before,'Walk must move parts');
h.click('stop');assert.equal(h.pending(),false);assert(h.status.textContent.startsWith('Standing'));
h.click('turn');assert(h.status.textContent.includes('Side'));
h.click('step');assert(h.status.textContent.startsWith('Walk pose'));assert.equal(h.pending(),false);
h.click('idle');assert(h.status.textContent.startsWith('Idle'));h.frame(34);h.click('stop');
const r=harness(true);r.click('walk');assert.equal(r.pending(),false);r.click('idle');assert.equal(r.pending(),false);r.click('step');assert(r.status.textContent.startsWith('Walk pose'));
console.log(`PASS: ${cases} appearance/direction combinations, exact hat restoration, rear-face hiding, walking, stop, turn, frame stepping, idle and reduced-motion controls.`);
