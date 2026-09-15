// Pure map-wiring contract test; no network or saved project access.
const assert = require('node:assert/strict'), fs = require('node:fs'), vm = require('node:vm');
const reports = [];
function group() { return {layers:new Set(), hasLayer(x){return this.layers.has(x)},
  addLayer(x){this.layers.add(x)}, removeLayer(x){this.layers.delete(x)}, clearLayers(){this.layers.clear()}} }
const context = vm.createContext({L:{layerGroup:group},
  Shiny:{setInputValue:(...x)=>reports.push(x)}, LeafletWidget:{methods:{}},
  protomaps:{LineSymbolizer:function(x){Object.assign(this,x)},
    leafletLayer:options=>({options,handlers:{},on(name,fn){this.handlers[name]=fn}})}});
const render = vm.runInContext('(' + fs.readFileSync('inst/www/network-reference.js','utf8') + ')',context);
function map(zoom) {
  const m = {zoom,shown:true,events:{},pane:{style:{}},
    createPane(){return this.pane},hasLayer(){return this.shown},getZoom(){return this.zoom},
    on(name,fn){this.events[name]=fn},off(name){delete this.events[name]}};
  m.layerManager={addLayer(holder){m.holder=holder}};return m;
}
const a=map(4);render.call(a,{id:'a'},null,{enabled:true,url:'https://example.test/{z}/{y}/{x}'});
assert.equal(a.holder.layers.size,0);assert.equal(reports.at(-1)[1],'zoom_in');
a.zoom=14;a.events.zoomend();assert.equal(a.holder.layers.size,1);
const tiles=[...a.holder.layers][0];
assert.equal(tiles.options.levelDiff,0);assert.equal(tiles.options.maxDataZoom,14);
assert.equal(tiles.options.paint_rules[0].dataLayer,'nhdflowline_network');
assert.equal(a.pane.style.pointerEvents,'none');
context.LeafletWidget.methods.fgReferenceMode.call(a,false);
assert.equal(a.holder.layers.size,0);assert.equal(reports.at(-1)[1],'off');
const b=map(14);render.call(b,{id:'b'},null,{enabled:true,url:'test'});
context.LeafletWidget.methods.fgReferenceMode.call(a,true);
assert.equal(reports.at(-1)[0],'a_reference_state');assert.equal(b.holder.layers.size,1);
a.shown=false;a.events['overlayadd overlayremove']();
assert.equal(a.holder.layers.size,0);assert.equal(reports.at(-1)[1],'hidden');
a.shown=true;a.events['overlayadd overlayremove']();
tiles.handlers.tileerror();assert.equal(reports.at(-1)[1],'error');
a.events.unload();assert.equal(a.holder.layers.size,0);
console.log('Reference-tile zoom, mode, group, map isolation, error and disposal contracts passed.');
