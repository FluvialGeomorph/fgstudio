# Use the same collapsed Leaflet Search control as ohwm2, with our Photon backend.
add_place_search <- function(map) {
  options <- leaflet.extras::searchOptions(
    collapsed = TRUE, autoCollapse = TRUE, autoCollapseTime = 20000,
    minLength = 3, delayType = 1200, autoType = FALSE,
    hideMarkerOnCollapse = TRUE, zoom = 14,
    textPlaceholder = "Find a place...",
    sourceData = htmlwidgets::JS("function(text, done) {
      var control = this;
      var token = (control.fgToken || 0) + 1;
      control.fgToken = token;
      control.fgDone = done;
      Shiny.setInputValue(control._map.id + '_place_query',
        {text: text, token: token}, {priority: 'event'});
      return {abort: function() { control.fgDone = null; }};
    }"),
    formatData = htmlwidgets::JS("function(controlOrRows, response) {
      var rows = Array.isArray(response) ? response : controlOrRows;
      var records = Object.create(null);
      if (!Array.isArray(rows)) return records;
      rows.forEach(function(row) {
        if (typeof row.label !== 'string' || !Number.isFinite(row.lon) ||
            !Number.isFinite(row.lat)) return;
        records[row.label] = L.latLng(row.lat, row.lon);
      });
      return records;
    }"),
    filterData = htmlwidgets::JS("function(text, records) { return records; }"),
    buildTip = htmlwidgets::JS("function(text) {
      var tip = document.createElement('a'); tip.textContent = text;
      return tip;
    }")
  )
  map <- leaflet.extras::addSearchOSM(map, options = options)
  htmlwidgets::onRender(map, "function(el, x) {
    LeafletWidget.methods.fgPlaceResults = function(token, rows, error) {
      var control = this.searchControlOSM;
      if (!control || control.fgToken !== token || !control.fgDone) return;
      var done = control.fgDone; control.fgDone = null;
      done(rows || []);
      if (error) control.showAlert(error);
    };
    var control = this.searchControlOSM;
    control._input.title = 'Public place names only. Search text goes to Photon / OpenStreetMap.';
  }")
}
