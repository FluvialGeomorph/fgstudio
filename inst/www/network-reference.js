function(el, x, config) {
  var map = this;
  var group = 'NHDPlusV2 reference channels';
  var enabled = config.enabled;
  var pane = map.createPane('fg-network-reference');
  pane.style.zIndex = 350;
  pane.style.pointerEvents = 'none';
  var holder = L.layerGroup();
  var tiles = protomaps.leafletLayer({
    url: config.url,
    maxDataZoom: 14,
    levelDiff: 0,
    pane: 'fg-network-reference',
    updateWhenIdle: true,
    keepBuffer: 1,
    paint_rules: [{dataLayer: 'nhdflowline_network',
      symbolizer: new protomaps.LineSymbolizer({color: '#2389b8', width: 2.5, opacity: 0.85})}],
    label_rules: [],
    attribution: 'USGS / EPA NHDPlusV2'
  });
  var report = function(state) {
    Shiny.setInputValue(el.id + '_reference_state', state, {priority: 'event'});
  };
  var sync = function() {
    var visible = enabled && map.hasLayer(holder) && map.getZoom() >= 12;
    if (visible && !holder.hasLayer(tiles)) holder.addLayer(tiles);
    if (!visible && holder.hasLayer(tiles)) holder.removeLayer(tiles);
    report(!enabled ? 'off' : !map.hasLayer(holder) ? 'hidden' : map.getZoom() < 12 ? 'zoom_in' : 'visible');
  };
  map.layerManager.addLayer(holder, 'tile', 'fg-network-reference', group);
  // Each map owns its state; the shared Leaflet method must not close over a later map.
  map.fgSetReferenceMode = function(value) { enabled = !!value; sync(); };
  LeafletWidget.methods.fgReferenceMode = function(value) { this.fgSetReferenceMode(value); };
  map.on('zoomend', sync);
  map.on('overlayadd overlayremove', sync);
  tiles.on('tileerror', function() { if (enabled && map.hasLayer(holder)) report('error'); });
  map.on('unload', function() {
    map.off('zoomend', sync);
    map.off('overlayadd overlayremove', sync);
    holder.clearLayers();
  });
  sync();
}
