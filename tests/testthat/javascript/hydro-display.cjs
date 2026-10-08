const fs = require('fs');
const assert = require('assert');
const payload = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
function element() {
  return {style: {}, children: [], attributes: {}, events: {},
    appendChild(x) {this.children.push(x);},
    setAttribute(k,v) {this.attributes[k]=v;},
    getAttribute(k) {return this.attributes[k];},
    addEventListener(k,v) {this.events[k]=v;}};
}
global.document = {createElement: element};
global.window = {setTimeout(callback) {callback();return 1;},clearTimeout() {}};
global.ResizeObserver = class {
  constructor(callback) {this.callback=callback;}
  observe(el) {this.el=el;el.resizeObserver=this;}
  disconnect() {this.disconnected=true;}
};
global.window.ResizeObserver = global.ResizeObserver;
global.L = {control: () => ({addTo(map) {map.control=this.onAdd();}}),
  DomUtil: {create: element}, DomEvent: {disableClickPropagation() {}, disableScrollPropagation() {}}};
const hook = eval('(' + payload.hook + ')');
const el = element();
function mount(bounds=[-93,40,-92.99,40.01],visible=true) {
  const panes = {'hydro-elevation':{style:{}},'hydro-hillshade':{style:{}}};
  const map = {getPane: name => panes[name],invalidateSize(options) {
    this.invalidated=options;
  },fitBounds(bounds,options) {this.fitCalls=(this.fitCalls || []).concat([{bounds,options}]);}};
  el.offsetWidth=visible ? 800 : 0;el.offsetHeight=visible ? 600 : 0;
  hook.call(map,el,{}, {bounds});
  el.resizeObserver.callback();
  return {map,panes};
}
let {map,panes} = mount(undefined,false);
assert.strictEqual(map.fitCalls,undefined);
el.offsetWidth=800;el.offsetHeight=600;el.resizeObserver.callback();
assert.deepStrictEqual(map.invalidated,{pan:false});
assert.deepStrictEqual(map.fitCalls,[{bounds:[[40,-93],[40.01,-92.99]],
  options:{animate:false,padding:[16,16]}}]);
el.resizeObserver.callback();
assert.strictEqual(map.fitCalls.length,1);
el.offsetWidth=0;el.offsetHeight=0;el.resizeObserver.callback();
el.offsetWidth=800;el.offsetHeight=600;el.resizeObserver.callback();
assert.strictEqual(map.fitCalls.length,2);
const elevation = map.control.children[0].children[1];
const hill = map.control.children[1].children[1];
elevation.value='80';elevation.events.input();
assert.strictEqual(panes['hydro-elevation'].style.opacity,.8);
assert.strictEqual(panes['hydro-hillshade'].style.opacity,.5);
hill.value='0';hill.events.input();
assert.strictEqual(panes['hydro-hillshade'].style.opacity,0);
({map,panes}=mount([-94,41,-93.5,41.5]));
assert.deepStrictEqual(map.fitCalls,[{bounds:[[41,-94],[41.5,-93.5]],
  options:{animate:false,padding:[16,16]}}]);
assert.strictEqual(panes['hydro-elevation'].style.opacity,.8);
assert.strictEqual(panes['hydro-hillshade'].style.opacity,0);
console.log('Hydro opacity controls passed');
