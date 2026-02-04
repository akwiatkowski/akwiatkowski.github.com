// Navigation stats loader + Bootstrap 5 initialization
// Fetches post counts from nav_stats.json and updates navigation elements
(function() {
  'use strict';

  function loadNavStats() {
    fetch('/nav_stats.json')
      .then(function(response) {
        return response.json();
      })
      .then(function(data) {
        data.post_counts.forEach(function(item) {
          var element = document.getElementById(item.html_id);
          if (element) {
            element.innerHTML = '(' + item.count + ')';
          }
        });
      })
      .catch(function(error) {
        console.error('Error fetching nav stats:', error);
      });
  }

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
      loadNavStats();
      initBootstrapComponents();
    });
  } else {
    loadNavStats();
    initBootstrapComponents();
  }
})();
