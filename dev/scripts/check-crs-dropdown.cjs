// Execute the shipped Selectize callbacks with a bounded DOM/control fixture.
const fs = require('node:fs');
const assert = require('node:assert/strict');
const source = fs.readFileSync('R/study_analysis_crs.R','utf8');
const callbacks = {};
for (const name of ['onInitialize','onDropdownOpen','onLoad']) {
  const text = source.match(new RegExp(name+'=I\\("([\\s\\S]*?)"\\)'))[1];
  callbacks[name] = Function('return ('+text+')')();
}
let listener, resizeListener, removed=false, resizeRemoved=false, destroyed=false, closed=false;
global.document = {addEventListener:(type,fn,capture)=>{assert.equal(capture,true);listener=fn;},
  removeEventListener:(type,fn)=>{assert.equal(fn,listener);removed=true;}};
global.window = {innerHeight:800,scrollY:20,
  addEventListener:(type,fn)=>{resizeListener=fn;},
  removeEventListener:(type,fn)=>{assert.equal(fn,resizeListener);resizeRemoved=true;}};
let rect={top:700,bottom:730}, styles={}, content={};
const inside={};
const control={isOpen:true,$control:[{getBoundingClientRect:()=>rect}],
  $dropdown:{0:{contains:target=>target===inside},css:(key,value)=>{styles[key]=value;},outerHeight:()=>270},
  $dropdown_content:{css:values=>Object.assign(content,values)},
  close:()=>{closed=true;},destroy:()=>{destroyed=true;}};
callbacks.onInitialize.call(control);
control.settings=callbacks;
assert.equal(styles['z-index'],2000);
callbacks.onDropdownOpen.call(control);
assert.equal(styles.top,'450px');
assert.equal(content['max-height'],'260px');
listener({target:inside});assert.equal(closed,false);
listener({target:{}});assert.equal(closed,true);
rect={top:100,bottom:130};callbacks.onDropdownOpen.call(control);
assert.equal(styles.top,'150px');
rect={top:700,bottom:730};callbacks.onLoad.call(control);
assert.equal(styles.top,'450px');
closed=false;resizeListener();assert.equal(closed,true);
control.destroy();assert.equal(removed,true);assert.equal(resizeRemoved,true);assert.equal(destroyed,true);
console.log('CRS dropdown: body overlay, viewport placement, internal scrolling and listener cleanup passed.');
