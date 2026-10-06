(function() {
  var timer = null;
  var pendingContext = null;

  function overlay() {
    return document.getElementById('fg-working-overlay');
  }

  function cleanText(target) {
    if (!target) return '';
    var control = target.closest('button, a, [role="tab"]');
    return control ? control.textContent.replace(/\s+/g, ' ').trim() : '';
  }

  function describe(text) {
    var actions = [
      [/Create(?: Study Area)? Flowline Points/i, 'Creating the Study Area Flowline Points and checking shared stationing...'],
      [/Save Reach Flowlines/i, 'Saving the selected Reach Flowlines...'],
      [/Extract stream network|Update stream threshold/i, 'Deriving the synthetic Stream Network from the terrain...'],
      [/Apply cutlines/i, 'Applying the saved cutlines to the terrain...'],
      [/Open study/i, 'Opening the saved Study Area and its workflow results...'],
      [/Flowline Points/i, 'Opening the saved Flowline Points and elevation profile...'],
      [/Flowline/i, 'Opening the terrain-derived Flowline review...'],
      [/Hydro Modify/i, 'Opening the hydro-modified terrain and Stream Network...'],
      [/Survey Events/i, 'Opening Survey Events and their saved terrain products...'],
      [/Collections/i, 'Opening the Study Area collection sources...'],
      [/Geometry/i, 'Opening the saved Study Area geometry...'],
      [/CRS/i, 'Opening the analysis coordinate settings...']
    ];
    for (var i=0;i<actions.length;i++) if (actions[i][0].test(text)) return actions[i][1];
    return null;
  }

  function activeContext() {
    var summary = document.getElementById('study-summary');
    if (window.location.search.indexOf('study=') >= 0 &&
        (!summary || !summary.textContent.trim())) {
      return 'Opening the saved Study Area and its workflow results...';
    }
    var active = document.querySelector('.fg-study-tabs .nav-link.active, .fg-study-tabs [role="tab"][aria-selected="true"]');
    return describe(cleanText(active)) || 'Updating the current workflow view...';
  }

  function showAfterDelay(detail) {
    clearTimeout(timer);
    timer = setTimeout(function() {
      var x = overlay();
      var message = document.getElementById('fg-working-detail');
      if (message) message.textContent = detail;
      if (x) {
        x.style.display = 'flex';
        x.setAttribute('aria-hidden','false');
      }
    },600);
  }

  document.addEventListener('click', function(event) {
    pendingContext = describe(cleanText(event.target));
  }, true);

  function connectToShiny() {
    if (!window.jQuery) {
      window.setTimeout(connectToShiny,50);
      return;
    }
    window.jQuery(document).one('shiny:connected', function() {
      if (window.location.search.indexOf('study=') >= 0)
        showAfterDelay('Opening the saved Study Area and its workflow results...');
    });
    window.jQuery(document).on('shiny:busy', function() {
      showAfterDelay(pendingContext || activeContext());
    });

    window.jQuery(document).on('shiny:idle', function() {
      clearTimeout(timer);
      timer = null;
      pendingContext = null;
      var x = overlay();
      if (x) {
        x.style.display = 'none';
        x.setAttribute('aria-hidden','true');
      }
    });
  }
  connectToShiny();
})();
