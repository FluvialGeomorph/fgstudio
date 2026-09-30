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
global.L = {control: () => ({addTo(map) {map.control=this.onAdd();}}),
  DomUtil: {create: element}, DomEvent: {disableClickPropagation() {}, disableScrollPropagation() {}}};
const hook = eval('(' + payload.hook + ')');
const el = element();
function mount() {
  const panes = {'hydro-elevation':{style:{}},'hydro-hillshade':{style:{}}};
  const map = {getPane: name => panes[name]};
  hook.call(map,el,{});
  return {map,panes};
}
let {map,panes} = mount();
const elevation = map.control.children[0].children[1];
const hill = map.control.children[1].children[1];
elevation.value='80';elevation.events.input();
assert.strictEqual(panes['hydro-elevation'].style.opacity,.8);
assert.strictEqual(panes['hydro-hillshade'].style.opacity,.5);
hill.value='0';hill.events.input();
assert.strictEqual(panes['hydro-hillshade'].style.opacity,0);
({map,panes}=mount());
assert.strictEqual(panes['hydro-elevation'].style.opacity,.8);
assert.strictEqual(panes['hydro-hillshade'].style.opacity,0);
console.log('Hydro opacity controls passed');
