// Route map (Leaflet) - vanilla JS
//
// Renders every post's GPX track on a muted basemap so the coloured routes
// read as the hero. Hovering a route shows a light tooltip; clicking opens a
// readable image card. A legend in the corner explains the colours and lets
// the reader toggle transport modes on/off.
this.BlogMap = (function() {

  // Route colours loaded from /js/self/route_colors.js (generated from
  // data/config/route_colors.yml). Maps type -> { color, weight, opacity }.
  var routeStyles = window.ROUTE_STYLES || {};

  // Polish display names per transport type (used in tooltip + legend).
  var TYPE_LABELS = {
    hike: 'Pieszo',
    bicycle: 'Rowerem',
    'e-bike': 'Rowerem elektrycznym',
    canoe: 'Kajakiem',
    car: 'Samochodem',
    ev: 'Autem elektrycznym',
    bus: 'Autobusem',
    train: 'Pociągiem',
    regular: 'Trasa'
  };

  // Motorised / public-transport modes are drawn dashed and de-emphasised so
  // the muscle-powered trips (the point of the blog) stand out.
  var MOTORISED = { car: true, ev: true, bus: true, train: true, regular: true };

  // Draw order: muscle-powered on top, motorised beneath.
  var TYPE_ORDER = ['train', 'bus', 'ev', 'car', 'regular', 'canoe', 'e-bike', 'bicycle', 'hike'];

  class BlogMap {
    constructor() {
      this.map = null;
      this.data = null;
      this.layers = {};        // type -> L.layerGroup
      this.typeActive = {};    // type -> bool (legend toggle state)
      this.routeCount = {};    // type -> number of routes
      this.lines = [];         // every coloured polyline (for tooltip control)
      this.activeLine = null;  // the route currently hovered, if any
    }

    start() {
      fetch('/jsons/map.json')
        .then(function(response) { return response.json(); })
        .then(function(data) {
          this.data = data;
          this.initializeLayout();
          this.startMap();
        }.bind(this));
    }

    // Size the map to fill the viewport below the nav; hide the footer.
    initializeLayout() {
      var mapDom = document.getElementById('map-container');
      var top = mapDom.getBoundingClientRect().top;
      mapDom.style.height = (window.innerHeight - top) + 'px';
      mapDom.style.width = '100%';

      var content = document.getElementById('content');
      content.style.height = mapDom.style.height;
      content.style.width = '100%';

      var footer = document.querySelector('footer');
      if (footer) footer.style.display = 'none';
    }

    startMap() {
      this.map = L.map('content', {
        zoomControl: true,
        minZoom: 5,
        maxZoom: 16,
        zoomSnap: 0.25
      }).setView([52.0, 19.4], 6);

      // Standard OpenStreetMap basemap — readers want the real, colourful map
      // to judge terrain and scenery. Routes pop against it thanks to their
      // white casing (see addRoute).
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
        maxZoom: 16
      }).addTo(this.map);

      this.buildRoutes();
      this.buildLegend();
      this.fitToRoutes();
      this.startTooltipSweep();
    }

    // Create one layer group per transport type and add each route as a
    // casing + coloured line pair.
    buildRoutes() {
      var self = this;
      this.lines = [];

      TYPE_ORDER.forEach(function(type) {
        self.layers[type] = L.layerGroup().addTo(self.map);
        self.typeActive[type] = true;
        self.routeCount[type] = 0;
      });

      this.data.posts.forEach(function(post) {
        if (!post.coords) return;

        post.coords.forEach(function(route) {
          if (!route.route) return;

          var type = route.type || 'regular';
          if (!self.layers[type]) {           // unknown type -> bucket as regular
            type = 'regular';
          }
          var coords = route.route.map(function(c) { return [c[0], c[1]]; });
          self.routeCount[type] = (self.routeCount[type] || 0) + 1;
          self.addRoute(coords, type, post);
        });
      });
    }

    addRoute(coords, type, post) {
      var base = routeStyles[type] || routeStyles.regular || { color: '#444' };
      var motorised = !!MOTORISED[type];
      var weight = motorised ? 3 : 4;

      var mainStyle = {
        color: base.color,
        weight: weight,
        opacity: motorised ? 0.7 : 0.95,
        lineCap: 'round',
        lineJoin: 'round',
        dashArray: motorised ? '1 8' : null
      };

      var group = this.layers[type];

      // Soft casing beneath solid (muscle-powered) routes gives them a clean
      // cartographic outline and separates overlapping tracks. Skipped for
      // dashed motorised lines (a casing would fill their gaps).
      var casing = null;
      if (!motorised) {
        casing = L.polyline(coords, {
          color: '#ffffff',
          weight: weight + 3,
          opacity: 0.9,
          lineCap: 'round',
          lineJoin: 'round',
          interactive: false
        }).addTo(group);
      }

      var line = L.polyline(coords, mainStyle).addTo(group);
      line._baseWeight = weight;
      line._baseOpacity = mainStyle.opacity;
      line._casing = casing;
      line._post = post;
      line._type = type;

      // Compact hover preview: small photo + title + stats. Follows the
      // cursor but stays small, so it's informative without taking over.
      line.bindTooltip(this.tooltipHtml(post, type), {
        sticky: true,
        direction: 'top',
        offset: [0, -6],
        className: 'rmap-tip',
        opacity: 1
      });

      this.lines.push(line);

      line.on('mouseover', function() { this.setActive(line); }.bind(this));
      line.on('mouseout', function() { this.clearActive(line); }.bind(this));
      // Click the route -> go straight to the post.
      line.on('click', function() { window.location.href = post.url; }.bind(this));
    }

    // Enforce "one tooltip at a time": when a route is hovered, close every
    // other route's tooltip and reset its highlight.
    setActive(line) {
      this.lines.forEach(function(other) {
        if (other !== line) {
          other.closeTooltip();
          this.highlight(other, false);
        }
      }.bind(this));
      this.activeLine = line;
      this.highlight(line, true);
    }

    clearActive(line) {
      line.closeTooltip();
      this.highlight(line, false);
      if (this.activeLine === line) this.activeLine = null;
    }

    // Safety net: Leaflet can leave orphaned tooltips when the cursor darts
    // across overlapping routes. Every couple of seconds, close any tooltip
    // that isn't the one currently being hovered.
    startTooltipSweep() {
      var self = this;
      setInterval(function() {
        self.lines.forEach(function(line) {
          if (line !== self.activeLine) line.closeTooltip();
        });
      }, 2000);
    }

    // Thicken + lift the hovered route to the front; restore on mouse-out.
    highlight(line, on) {
      if (on) {
        line.setStyle({ weight: line._baseWeight + 2, opacity: 1 });
        if (line._casing) { line._casing.bringToFront(); }
        line.bringToFront();
      } else {
        line.setStyle({ weight: line._baseWeight, opacity: line._baseOpacity });
      }
    }

    // Compact image preview shown on hover. Keeps the photo (readers find it
    // useful) but at a small, non-intrusive size.
    tooltipHtml(post, type) {
      var img = (window.__avif && post.card_image_url_avif)
        ? post.card_image_url_avif : post.card_image_url;
      var color = (routeStyles[type] || {}).color || '#444';

      var meta = [TYPE_LABELS[type] || 'Trasa'];
      if (post.distance) meta.push(post.distance + ' km');
      meta.push(formatDate(post.date));

      return (img
          ? '<span class="rmap-tip__img" style="background-image:url(\'' + img + '\')"></span>'
          : '') +
        '<span class="rmap-tip__cap">' +
          '<span class="rmap-tip__title">' +
            '<span class="rmap-tip__dot" style="background:' + color + '"></span>' +
            escapeHtml(post.title) +
          '</span>' +
          '<span class="rmap-tip__meta">' + meta.join(' · ') + '</span>' +
        '</span>';
    }

    // Legend / mode toggle, bottom-left. Lists only the modes present in the
    // data; clicking a row shows/hides that mode's routes.
    buildLegend() {
      var self = this;
      var present = TYPE_ORDER.filter(function(t) { return self.routeCount[t] > 0; })
        .reverse(); // muscle-powered first for the reader

      var legend = L.control({ position: 'bottomleft' });
      legend.onAdd = function() {
        var el = L.DomUtil.create('div', 'rmap-legend');
        el.innerHTML = '<div class="rmap-legend__head">Trasy</div>';

        present.forEach(function(type) {
          var color = (routeStyles[type] || {}).color || '#444';
          var motorised = !!MOTORISED[type];
          var row = L.DomUtil.create('button', 'rmap-legend__row', el);
          row.type = 'button';
          row.setAttribute('data-type', type);
          row.innerHTML =
            '<span class="rmap-legend__swatch' + (motorised ? ' is-dashed' : '') +
              '" style="--c:' + color + '"></span>' +
            '<span class="rmap-legend__label">' + (TYPE_LABELS[type] || type) + '</span>' +
            '<span class="rmap-legend__count">' + self.routeCount[type] + '</span>';

          L.DomEvent.on(row, 'click', function(ev) {
            L.DomEvent.stop(ev);
            self.toggleType(type, row);
          });
        });

        // Stop map drag/scroll when interacting with the legend.
        L.DomEvent.disableClickPropagation(el);
        L.DomEvent.disableScrollPropagation(el);
        return el;
      };
      legend.addTo(this.map);
    }

    toggleType(type, row) {
      var active = !this.typeActive[type];
      this.typeActive[type] = active;
      if (active) {
        this.layers[type].addTo(this.map);
        row.classList.remove('is-off');
      } else {
        this.map.removeLayer(this.layers[type]);
        row.classList.add('is-off');
      }
    }

    // Frame the map to the bounding box of all routes on load.
    fitToRoutes() {
      var bounds = L.latLngBounds([]);
      Object.keys(this.layers).forEach(function(type) {
        this.layers[type].eachLayer(function(l) {
          if (l.getBounds) bounds.extend(l.getBounds());
        });
      }.bind(this));

      if (bounds.isValid()) {
        this.map.fitBounds(bounds, { padding: [40, 40], maxZoom: 12 });
      }
    }
  }

  function escapeHtml(text) {
    var div = document.createElement('div');
    div.textContent = text == null ? '' : text;
    return div.innerHTML;
  }

  var PL_MONTHS = ['stycznia', 'lutego', 'marca', 'kwietnia', 'maja', 'czerwca',
    'lipca', 'sierpnia', 'września', 'października', 'listopada', 'grudnia'];

  function formatDate(dateStr) {
    if (!dateStr) return '';
    var parts = String(dateStr).split('-');
    if (parts.length !== 3) return dateStr;
    var day = parseInt(parts[2], 10);
    var monthIdx = parseInt(parts[1], 10) - 1;
    if (isNaN(day) || monthIdx < 0 || monthIdx > 11) return dateStr;
    return day + ' ' + PL_MONTHS[monthIdx] + ' ' + parts[0];
  }

  return BlogMap;
}).call(this);
