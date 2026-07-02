// Bootstrap 5 initialization
(function() {
  'use strict';

  function initBootstrapComponents() {
    // Initialize Bootstrap 5 tooltips
    var tooltipTriggerList = document.querySelectorAll('[data-bs-toggle="tooltip"]');
    tooltipTriggerList.forEach(function(tooltipTriggerEl) {
      new bootstrap.Tooltip(tooltipTriggerEl);
    });
  }

  // Run when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function() {
      initBootstrapComponents();
    });
  } else {
    initBootstrapComponents();
  }
})();
