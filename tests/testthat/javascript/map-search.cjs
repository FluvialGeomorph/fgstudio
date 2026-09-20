// Pure JavaScript contract test; no browser, network, or study files are touched.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const {snippets, hook} = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const sent = [];
const context = vm.createContext({
  Shiny: {setInputValue: (...args) => sent.push(args)},
  L: {latLng: (lat, lng) => ({lat, lng})},
  document: {createElement: () => ({})},
  LeafletWidget: {methods: {}}
});
const [request, format, filter, tip] = snippets.map(s => vm.runInContext('(' + s + ')', context));
const render = vm.runInContext('(' + hook + ')', context);
const control = {_map: {id: 'study-boundary-map'}, _input: {}, showAlert: text => control.error = text};
const map = {searchControlOSM: control};
render.call(map);
let received;
const first = request.call(control, 'Omaha', rows => received = rows);
assert.equal(sent[0][0], 'study-boundary-map_place_query');
assert.equal(sent[0][1].text, 'Omaha');
first.abort();
request.call(control, 'Omaha Nebraska', rows => received = rows);
const reply = context.LeafletWidget.methods.fgPlaceResults;
reply.call(map, 1, ['stale'], null);
assert.equal(received, undefined);
const rows = [{label: 'Omaha', lon: -96, lat: 41}];
reply.call(map, 2, rows, null);
assert.equal(received, rows);
assert.equal(format(rows).Omaha.lat, 41);
assert.equal(format(control, rows).Omaha.lng, -96);
assert.equal(filter('query', rows), rows);
assert.equal(tip('<img src=x>').textContent, '<img src=x>');
request.call(control, 'unknown', rows => received = rows);
reply.call(map, 3, [], 'No places found');
assert.equal(received.length, 0);
assert.equal(control.error, 'No places found');
console.log('Map-search JavaScript contracts passed.');
