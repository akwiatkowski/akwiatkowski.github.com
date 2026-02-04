// OpenLayers Map - vanilla JS (no jQuery)
this.BlogMap = (function() {
  var throttle;

  class BlogMap {
    constructor() {}

    // run everything
    start() {
      fetch("/payload.json")
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
      var strokeWidth = 3;
      var strokeWidthLesser = 3;
      var opacityLesser = 0.4;

      var styleLineCar = new ol.style.Style({
        stroke: new ol.style.Stroke({
          color: [120, 0, 50, opacityLesser],
          width: strokeWidthLesser
        }),
        fill: new ol.style.Fill({
          color: "rgba(120, 0, 50, 0.2)"
        })
      });
      var styleLineBus = new ol.style.Style({
        stroke: new ol.style.Stroke({
          color: [50, 0, 120, opacityLesser],
          width: strokeWidthLesser
        }),
        fill: new ol.style.Fill({
          color: "rgba(50, 0, 120, 0.2)"
        })
      });
      var styleLineTrain = new ol.style.Style({
        stroke: new ol.style.Stroke({
          color: [100, 50, 180, opacityLesser],
          width: strokeWidthLesser
        }),
        fill: new ol.style.Fill({
          color: "rgba(100, 50, 180, 0.2)"
        })
      });
      var styleLineRegular = new ol.style.Style({
        stroke: new ol.style.Stroke({
          color: [50, 50, 50, opacityLesser],
          width: strokeWidthLesser
        }),
        fill: new ol.style.Fill({
          color: "rgba(50, 50, 50, 0.2)"
        })
      });
      var styleLineHike = new ol.style.Style({
        stroke: new ol.style.Stroke({
          color: [255, 100, 0],
          width: strokeWidth
        }),
        fill: new ol.style.Fill({
          color: "rgba(255, 100, 0, 0.2)"
        })
      });
      var styleLineCycle = new ol.style.Style({
        stroke: new ol.style.Stroke({
          color: [0, 70, 240],
          width: strokeWidth
        }),
        fill: new ol.style.Fill({
          color: "rgba(0, 70, 240, 0.2)"
        })
      });
      var styleLineEBike = new ol.style.Style({
        stroke: new ol.style.Stroke({
          color: [150, 60, 240],
          width: strokeWidth
        }),
        fill: new ol.style.Fill({
          color: "rgba(150, 60, 240, 0.2)"
        })
      });
      var styleLineEV = new ol.style.Style({
        stroke: new ol.style.Stroke({
          color: [220, 100, 190, opacityLesser],
          width: strokeWidth
        }),
        fill: new ol.style.Fill({
          color: "rgba(220,100,190, 0.2)"
        })
      });
      var styleLineCanoe = new ol.style.Style({
        stroke: new ol.style.Stroke({
          color: [0, 30, 150],
          width: strokeWidth
        }),
        fill: new ol.style.Fill({
          color: "rgba(0, 30, 150, 0.2)"
        })
      });
      var styleCircle = new ol.style.Style({
        stroke: new ol.style.Stroke({
          color: [255, 0, 0],
          width: strokeWidth
        }),
        fill: new ol.style.Fill({
          color: "rgba(255, 0, 0, 0.2)"
        })
      });

      var sourceCircles = new ol.source.Vector();
      var sourceLinesCanoe = new ol.source.Vector();
      var sourceLinesCycle = new ol.source.Vector();
      var sourceLinesEBike = new ol.source.Vector();
      var sourceLinesHike = new ol.source.Vector();
      var sourceLinesTrain = new ol.source.Vector();
      var sourceLinesBus = new ol.source.Vector();
      var sourceLinesEV = new ol.source.Vector();
      var sourceLinesCar = new ol.source.Vector();
      var sourceLinesRegular = new ol.source.Vector();

      for (var post of this.data["posts"]) {
        if (post["coords"]) {
          for (var route of post["coords"]) {
            if (route["route"]) {
              var coords = [];
              for (var c of route["route"]) {
                var ct = ol.proj.transform([c[1], c[0]], 'EPSG:4326', 'EPSG:3857');
                coords.push(ct);
              }
              var feature = new ol.Feature(new ol.geom.LineString(coords));
              feature.set("post-date", post["date"]);
              feature.set("post-distance", post["distace"]);
              feature.set("post-time-spent", post["time_spent"]);
              feature.set("post-url", post["url"]);
              feature.set("post-title", post["title"]);
              feature.set("post-slug", post["slug"]);
              feature.set("post-image", post["image_url"]);
              feature.set("post-small-image", post["card_image_url"]);

              if (route["type"] === "hike") {
                sourceLinesHike.addFeature(feature);
              } else if (route["type"] === "bicycle") {
                sourceLinesCycle.addFeature(feature);
              } else if (route["type"] === "e-bike") {
                sourceLinesEBike.addFeature(feature);
              } else if (route["type"] === "canoe") {
                sourceLinesCanoe.addFeature(feature);
              } else if (route["type"] === "car") {
                sourceLinesCar.addFeature(feature);
              } else if (route["type"] === "ev") {
                sourceLinesEV.addFeature(feature);
              } else if (route["type"] === "bus") {
                sourceLinesBus.addFeature(feature);
              } else if (route["type"] === "train") {
                sourceLinesTrain.addFeature(feature);
              } else {
                sourceLinesRegular.addFeature(feature);
              }
            }
          }
        }
      }

      var circleLayer = new ol.layer.Vector({
        source: sourceCircles,
        style: styleCircle
      });
      var lineLayerCanoe = new ol.layer.Vector({
        source: sourceLinesCanoe,
        style: styleLineCanoe
      });
      var lineLayerCycle = new ol.layer.Vector({
        source: sourceLinesCycle,
        style: styleLineCycle
      });
      var lineLayerEBike = new ol.layer.Vector({
        source: sourceLinesEBike,
        style: styleLineEBike
      });
      var lineLayerHike = new ol.layer.Vector({
        source: sourceLinesHike,
        style: styleLineHike
      });
      var lineLayerCar = new ol.layer.Vector({
        source: sourceLinesCar,
        style: styleLineCar
      });
      var lineLayerEV = new ol.layer.Vector({
        source: sourceLinesEV,
        style: styleLineEV
      });
      var lineLayerBus = new ol.layer.Vector({
        source: sourceLinesBus,
        style: styleLineBus
      });
      var lineLayerTrain = new ol.layer.Vector({
        source: sourceLinesTrain,
        style: styleLineTrain
      });
      var lineLayerRegular = new ol.layer.Vector({
        source: sourceLinesRegular,
        style: styleLineRegular
      });

      var map = new ol.Map({
        controls: [new ol.control.Zoom(), new ol.control.ZoomSlider()],
        pixelRatio: 1.0,
        target: "content",
        projection: "EPSG:4326",
        layers: [
          new ol.layer.Tile({
            source: new ol.source.OSM()
          }),
          circleLayer,
          lineLayerRegular,
          lineLayerCanoe,
          lineLayerCar,
          lineLayerEV,
          lineLayerBus,
          lineLayerTrain,
          lineLayerEBike,
          lineLayerHike,
          lineLayerCycle
        ],
        view: new ol.View({
          center: ol.proj.transform([19.4553, 51.7768], 'EPSG:4326', 'EPSG:3857'),
          zoom: 6
        })
      });

      // Background image change on selection
      var interaction = new ol.interaction.Select();
      interaction.getFeatures().on("add", (e) => {
        var p = e.element.U;
        var last_p = p;

        for (var post of this.data["posts"]) {
          if (post.url === last_p["post-url"]) {
            var new_image = post["header-ext-img"];
            if (new_image) {
              var img = new Image();
              img.onload = () => {
                var bg1 = document.getElementById('background1');
                var bg2 = document.getElementById('background2');
                if (bg1 && bg2) {
                  bg2.style.backgroundImage = bg1.style.backgroundImage;
                  bg2.style.display = 'block';
                  bg2.style.opacity = '1';
                  bg1.style.backgroundImage = "url(" + new_image + ")";
                  // Fade out bg2
                  bg2.style.transition = 'opacity 1.5s';
                  bg2.style.opacity = '0';
                  setTimeout(() => { bg2.style.display = 'none'; }, 1500);
                }
              };
              img.src = new_image;
            }
          }
        }
      });
      map.addInteraction(interaction);

      // Hover popup
      var popup = new ol.Overlay.Popup();
      map.addOverlay(popup);
      var lastPopupTime = +new Date();
      var poputThreshold = 1200;

      var displayFeatureInfo = (evt) => {
        var pixel = map.getEventPixel(evt.originalEvent);
        var feature = map.forEachFeatureAtPixel(pixel, (feature) => feature);

        if (feature) {
          var now = +new Date();
          if (evt.type === "click") {
            showPopup(evt, feature.U);
          } else if (evt.type === "pointermove") {
            if (lastPopupTime < now - poputThreshold) {
              lastPopupTime = now;
              showPopup(evt, feature.U);
            }
          }
        }
      };

      var showPopup = (evt, p) => {
        var div = '<div class="map-image" style="background-image: url(\'' + p["post-small-image"] + '\')">';
        div += '<div class="map-image-date">' + p["post-date"] + '</div>';
        if (p["post-distance"]) {
          div += '<div class="map-image-distance">' + p["post-distance"] + 'km</div>';
        }
        if (p["post-time-spent"]) {
          div += '<div class="map-image-time-spent">' + p["post-time-spent"] + 'h</div>';
        }
        div += '<div class="map-image-title"><a href="' + p["post-url"] + '">' + p["post-title"] + '</a></div>';
        div += '</div>';
        popup.show(evt.coordinate, div);
      };

      map.on("pointermove", throttle((evt) => {
        if (evt.dragging) return true;
        displayFeatureInfo(evt);
      }), 60);

      map.on("click", (evt) => {
        displayFeatureInfo(evt);
      });
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
