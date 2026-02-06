// Leaflet Map - vanilla JS
this.BlogMap = (function() {
  var throttle;

  // Route colors by transport type
  var routeStyles = {
    hike:     { color: 'rgb(255, 100, 0)',   weight: 3, opacity: 1 },
    bicycle:  { color: 'rgb(0, 70, 240)',    weight: 3, opacity: 1 },
    'e-bike': { color: 'rgb(150, 60, 240)',  weight: 3, opacity: 1 },
    canoe:    { color: 'rgb(0, 30, 150)',    weight: 3, opacity: 1 },
    car:      { color: 'rgb(120, 0, 50)',    weight: 3, opacity: 0.4 },
    ev:       { color: 'rgb(220, 100, 190)', weight: 3, opacity: 0.4 },
    bus:      { color: 'rgb(50, 0, 120)',    weight: 3, opacity: 0.4 },
    train:    { color: 'rgb(100, 50, 180)',  weight: 3, opacity: 0.4 },
    regular:  { color: 'rgb(50, 50, 50)',    weight: 3, opacity: 0.4 }
  };

  class BlogMap {
    constructor() {
      this.map = null;
      this.data = null;
      this.lastPopupTime = 0;
      this.popupThreshold = 1200;
    }

    start() {
      fetch("/jsons/map.json")
        .then(response => response.json())
        .then(data => {
          this.data = data;
          this.initializeLayout();
          this.startMap();
        });
    }

    initializeLayout() {
      var mapDom = document.getElementById("map-container");
      var mapBoundaries = mapDom.getBoundingClientRect();
      var mapHeight = window.innerHeight - mapBoundaries.top;
      var mapWidth = window.innerWidth - mapBoundaries.left;

      console.log("map width = " + mapWidth + " height = " + mapHeight);

      mapDom.style.height = mapHeight + "px";
      mapDom.style.width = mapWidth + "px";

      var content = document.getElementById("content");
      content.style.height = mapHeight + "px";
      content.style.width = mapWidth + "px";

      var footer = document.querySelector("footer");
      if (footer) footer.style.display = "none";
    }

    startMap() {
      // Initialize map centered on Poland
      this.map = L.map('content', {
        zoomControl: true
      }).setView([51.7768, 19.4553], 6);

      // Add OSM tile layer
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; OpenStreetMap contributors',
        maxZoom: 19
      }).addTo(this.map);

      // Create layer groups for each transport type
      var layers = {
        hike: L.layerGroup().addTo(this.map),
        bicycle: L.layerGroup().addTo(this.map),
        'e-bike': L.layerGroup().addTo(this.map),
        canoe: L.layerGroup().addTo(this.map),
        car: L.layerGroup().addTo(this.map),
        ev: L.layerGroup().addTo(this.map),
        bus: L.layerGroup().addTo(this.map),
        train: L.layerGroup().addTo(this.map),
        regular: L.layerGroup().addTo(this.map)
      };

      // Add routes from posts
      for (var post of this.data["posts"]) {
        if (post["coords"]) {
          for (var route of post["coords"]) {
            if (route["route"]) {
              // Convert coords to Leaflet format [lat, lon]
              var coords = route["route"].map(c => [c[0], c[1]]);

              var routeType = route["type"] || "regular";
              var style = routeStyles[routeType] || routeStyles.regular;

              var polyline = L.polyline(coords, style);

              // Store post data on the polyline
              polyline.postData = {
                date: post["date"],
                distance: post["distance"],
                timeSpent: post["time_spent"],
                url: post["url"],
                title: post["title"],
                slug: post["slug"],
                image: post["image_url"],
                smallImage: post["card_image_url"],
                headerExtImg: post["header-ext-img"]
              };

              // Click handler
              polyline.on('click', (e) => {
                this.showPopup(e.latlng, e.target.postData);
                this.changeBackground(e.target.postData);
              });

              // Hover handler (throttled)
              polyline.on('mouseover', throttle((e) => {
                var now = +new Date();
                if (this.lastPopupTime < now - this.popupThreshold) {
                  this.lastPopupTime = now;
                  this.showPopup(e.latlng, e.target.postData);
                }
              }, 60));

              // Add to appropriate layer
              var layer = layers[routeType] || layers.regular;
              polyline.addTo(layer);
            }
          }
        }
      }
    }

    showPopup(latlng, p) {
      var div = '<div class="map-image" style="background-image: url(\'' + p.smallImage + '\')">';
      div += '<div class="map-image-date">' + p.date + '</div>';
      if (p.distance) {
        div += '<div class="map-image-distance">' + p.distance + 'km</div>';
      }
      if (p.timeSpent) {
        div += '<div class="map-image-time-spent">' + p.timeSpent + 'h</div>';
      }
      div += '<div class="map-image-title"><a href="' + p.url + '">' + p.title + '</a></div>';
      div += '</div>';

      L.popup()
        .setLatLng(latlng)
        .setContent(div)
        .openOn(this.map);
    }

    changeBackground(p) {
      var newImage = p.headerExtImg;
      if (newImage) {
        var img = new Image();
        img.onload = () => {
          var bg1 = document.getElementById('background1');
          var bg2 = document.getElementById('background2');
          if (bg1 && bg2) {
            bg2.style.backgroundImage = bg1.style.backgroundImage;
            bg2.style.display = 'block';
            bg2.style.opacity = '1';
            bg1.style.backgroundImage = "url(" + newImage + ")";
            // Fade out bg2
            bg2.style.transition = 'opacity 1.5s';
            bg2.style.opacity = '0';
            setTimeout(() => { bg2.style.display = 'none'; }, 1500);
          }
        };
        img.src = newImage;
      }
    }
  }

  // https://remysharp.com/2010/07/21/throttling-function-calls
  throttle = function(fn, threshhold, scope) {
    threshhold || (threshhold = 250);
    var last, deferTimer;
    return function() {
      var context = scope || this;
      var now = +new Date();
      var args = arguments;
      if (last && now < last + threshhold) {
        clearTimeout(deferTimer);
        deferTimer = setTimeout(function() {
          last = now;
          fn.apply(context, args);
        }, threshhold);
      } else {
        last = now;
        fn.apply(context, args);
      }
    };
  };

  return BlogMap;
}).call(this);
