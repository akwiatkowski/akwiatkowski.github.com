// Navigation stats loader
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

  // Run when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', loadNavStats);
  } else {
    loadNavStats();
  }
})();
