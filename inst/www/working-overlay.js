(function() {
  var timer = null;
  var pendingOpen = false;
  var initialRestore = window.location.search.indexOf('study=') >= 0;

  function overlay() {
    return document.getElementById('fg-working-overlay');
  }

  function showAfterDelay() {
    clearTimeout(timer);
    timer = setTimeout(function() {
      var x = overlay();
      var message = document.getElementById('fg-working-detail');
      if (message) message.textContent = 'Opening the saved Study Area and its workflow results...';
      if (x) {
        x.style.display = 'flex';
        x.setAttribute('aria-hidden','false');
      }
    },600);
  }

  document.addEventListener('click', function(event) {
    pendingOpen = !!(event.target && event.target.closest('.fg-open-study'));
  }, true);

  function connectToShiny() {
    if (!window.jQuery) {
      window.setTimeout(connectToShiny,50);
      return;
    }
    window.jQuery(document).one('shiny:connected', function() {
      if (initialRestore) showAfterDelay();
    });
    window.jQuery(document).on('shiny:busy', function() {
      if (pendingOpen || initialRestore) showAfterDelay();
    });

    window.jQuery(document).on('shiny:idle', function() {
      if (!pendingOpen && !initialRestore) return;
      clearTimeout(timer);
      timer = null;
      pendingOpen = false;
      initialRestore = false;
      var x = overlay();
      if (x) {
        x.style.display = 'none';
        x.setAttribute('aria-hidden','true');
      }
    });
  }
  connectToShiny();
})();
