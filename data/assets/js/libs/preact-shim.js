// Preact shim - aliases preactCompat to React/ReactDOM globals
// This must be loaded AFTER preact.umd.js, preact-hooks.umd.js, preact-compat.umd.js
(function() {
  if (window.preactCompat) {
    window.React = window.preactCompat;
    window.ReactDOM = window.preactCompat;
  }
})();
