function(el, x, data) {
  var map = this;
  var targetBounds = data && data.bounds;
  var fittedTarget = false;
  var wasVisible = false;
  var fitTimer = null;
  function fitTarget() {
    var visible = el.offsetWidth > 0 && el.offsetHeight > 0;
    if (!visible) {
      wasVisible = false;
      if (fitTimer !== null) window.clearTimeout(fitTimer);
      fitTimer = null;
      return;
    }
    map.invalidateSize({pan: false});
    if ((!wasVisible || !fittedTarget) && Array.isArray(targetBounds) &&
        targetBounds.length === 4 && targetBounds.every(Number.isFinite)) {
      if (fitTimer !== null) window.clearTimeout(fitTimer);
      fitTimer = window.setTimeout(function() {
        fitTimer = null;
        if (el.offsetWidth <= 0 || el.offsetHeight <= 0) return;
        map.invalidateSize({pan: false});
        map.fitBounds([[targetBounds[1], targetBounds[0]],
          [targetBounds[3], targetBounds[2]]],
          {animate: false, padding: [16, 16]});
        fittedTarget = true;
      }, 60);
    }
    wasVisible = true;
  }
  // Leaflet can be initialized while a workflow tab is hidden. ResizeObserver
  // corrects its dimensions and applies the newly selected Stream extent once
  // the map is visible. Later resizes do not override the analyst's own zoom.
  if (window.ResizeObserver) {
    if (el.fgResizeObserver) el.fgResizeObserver.disconnect();
    el.fgResizeObserver = new ResizeObserver(function() {
      fitTarget();
    });
    el.fgResizeObserver.observe(el);
  }
  fitTarget();
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
