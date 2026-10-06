function(el, x) {
  var map = this;
  // Leaflet can be initialized while a workflow tab is hidden. ResizeObserver
  // corrects the map as soon as its real visible dimensions are available,
  // without exposing a workflow button for a display lifecycle detail.
  if (window.ResizeObserver) {
    if (el.fgResizeObserver) el.fgResizeObserver.disconnect();
    el.fgResizeObserver = new ResizeObserver(function() {
      if (el.offsetWidth > 0 && el.offsetHeight > 0) {
        map.invalidateSize({pan: false});
      }
    });
    el.fgResizeObserver.observe(el);
  }
  var control = L.control({position: 'bottomleft'});
  control.onAdd = function() {
    var box = L.DomUtil.create('div', 'leaflet-control hydro-opacity');
    box.style.cssText = 'background:white;color:#222;padding:8px 10px;border-radius:4px;box-shadow:0 1px 5px #777;width:190px';
    L.DomEvent.disableClickPropagation(box);
    L.DomEvent.disableScrollPropagation(box);
    [['Elevation', 'hydro-elevation'], ['Hillshade', 'hydro-hillshade']].forEach(function(layer) {
      var key = layer[1] + '-opacity';
      var row = document.createElement('label');
      row.style.cssText = 'display:block;margin:0 0 4px;font-size:12px';
      var caption = document.createElement('span');
      var slider = document.createElement('input');
      slider.type = 'range'; slider.min = '0'; slider.max = '100'; slider.step = '1';
      slider.value = el.getAttribute(key) || '50';
      slider.setAttribute('aria-label', layer[0] + ' opacity');
      slider.style.cssText = 'display:block;width:100%;cursor:pointer';
      var update = function() {
        var value = Number(slider.value);
        map.getPane(layer[1]).style.opacity = value / 100;
        el.setAttribute(key, String(value));
        caption.textContent = layer[0] + ' opacity: ' + value + '%';
      };
      slider.addEventListener('input', update);
      row.appendChild(caption); row.appendChild(slider); box.appendChild(row);
      update();
    });
    return box;
  };
  control.addTo(map);
}
