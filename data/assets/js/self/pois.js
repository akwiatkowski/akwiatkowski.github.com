const { useState, useEffect, useRef, useMemo } = React;
var POLAND_BOUNDS = [[49, 14.1], [54.9, 24.2]];
var TILE_URL = "/tiles/ump/{z}/{x}/{y}.png";
function visitedSvg() {
  return '<svg width="32" height="32" viewBox="0 0 32 32" xmlns="http://www.w3.org/2000/svg"><circle cx="16" cy="16" r="14" fill="currentColor"/><path d="M10 16l4 4 8-8" stroke="#fff" stroke-width="2.5" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>';
}
function todoSvg() {
  return '<svg width="32" height="32" viewBox="0 0 32 32" xmlns="http://www.w3.org/2000/svg"><circle cx="16" cy="16" r="14" fill="currentColor"/><text x="16" y="21" text-anchor="middle" fill="#fff" font-size="16" font-weight="700">?</text></svg>';
}
function autoSvg() {
  return '<svg width="32" height="32" viewBox="0 0 32 32" xmlns="http://www.w3.org/2000/svg"><circle cx="16" cy="16" r="14" fill="currentColor"/><path d="M10 13h12v8H10z" fill="none" stroke="#fff" stroke-width="1.5"/><circle cx="16" cy="17" r="2.5" fill="none" stroke="#fff" stroke-width="1.5"/><rect x="12" y="11" width="8" height="2" rx="1" fill="#fff"/></svg>';
}
function markerSvgFor(type) {
  if (type === "visited")
    return visitedSvg();
  if (type === "auto")
    return autoSvg();
  return todoSvg();
}
function createMarkerIcon(type, isActive) {
  var cls = "poi-marker poi-marker--" + type + (isActive ? " poi-marker--active" : "") + " poi-marker-enter";
  return L.divIcon({
    className: "",
    html: '<div class="' + cls + '">' + markerSvgFor(type) + "</div>",
    iconSize: [32, 32],
    iconAnchor: [16, 16]
  });
}
function formatHours(h) {
  if (h < 1)
    return Math.round(h * 60) + "min";
  var hrs = Math.floor(h);
  var mins = Math.round((h - hrs) * 60);
  return mins > 0 ? hrs + "h " + mins + "min" : hrs + "h";
}
function VisitedCard({ poi, onClose }) {
  return /* @__PURE__ */ React.createElement("div", { className: "poi-card" }, poi.photo_url && /* @__PURE__ */ React.createElement("picture", null, poi.photo_url_avif && /* @__PURE__ */ React.createElement("source", { type: "image/avif", srcSet: poi.photo_url_avif }), /* @__PURE__ */ React.createElement("img", { className: "poi-card-photo", src: poi.photo_url, alt: poi.photo_desc || poi.name, loading: "lazy" })), /* @__PURE__ */ React.createElement("div", { className: "poi-card-body" }, /* @__PURE__ */ React.createElement("div", { className: "poi-card-name" }, poi.name), /* @__PURE__ */ React.createElement("div", { className: "poi-card-post-title" }, poi.post_title), /* @__PURE__ */ React.createElement("div", { className: "poi-card-meta" }, /* @__PURE__ */ React.createElement("span", null, poi.post_date), poi.post_distance > 0 && /* @__PURE__ */ React.createElement("span", null, poi.post_distance, "km"), poi.post_time_spent > 0 && /* @__PURE__ */ React.createElement("span", null, poi.post_time_spent, "h")), /* @__PURE__ */ React.createElement("a", { href: poi.post_url, className: "poi-card-link" }, "Otworz wpis ", /* @__PURE__ */ React.createElement("span", null, "\u2192"))));
}
function AutoCard({ poi, onClose }) {
  return /* @__PURE__ */ React.createElement("div", { className: "poi-card" }, poi.photo_url && /* @__PURE__ */ React.createElement("picture", null, poi.photo_url_avif && /* @__PURE__ */ React.createElement("source", { type: "image/avif", srcSet: poi.photo_url_avif }), /* @__PURE__ */ React.createElement("img", { className: "poi-card-photo", src: poi.photo_url, alt: poi.photo_desc || poi.name, loading: "lazy" })), /* @__PURE__ */ React.createElement("div", { className: "poi-card-body" }, /* @__PURE__ */ React.createElement("div", { className: "poi-card-name" }, poi.name), /* @__PURE__ */ React.createElement("div", { className: "poi-card-post-title" }, poi.post_title), /* @__PURE__ */ React.createElement("div", { className: "poi-card-meta" }, /* @__PURE__ */ React.createElement("span", null, poi.post_date)), /* @__PURE__ */ React.createElement("a", { href: poi.post_url, className: "poi-card-link" }, "Otworz wpis ", /* @__PURE__ */ React.createElement("span", null, "\u2192"))));
}
function TodoMiniMap({ poi }) {
  var mapRef = useRef(null);
  var mapContainerRef = useRef(null);
  useEffect(function() {
    if (!mapContainerRef.current || mapRef.current)
      return;
    var map = L.map(mapContainerRef.current, {
      zoomControl: false,
      dragging: false,
      scrollWheelZoom: false,
      doubleClickZoom: false,
      touchZoom: false,
      keyboard: false,
      attributionControl: false
    });
    L.tileLayer(TILE_URL, { maxZoom: 14 }).addTo(map);
    var poiLatLng = [poi.lat, poi.lon];
    var bounds = [poiLatLng];
    L.marker(poiLatLng, {
      icon: createMarkerIcon("todo", false)
    }).addTo(map);
    if (poi.station_lat && poi.station_lon) {
      var stationLatLng = [poi.station_lat, poi.station_lon];
      bounds.push(stationLatLng);
      L.marker(stationLatLng, {
        icon: L.divIcon({
          className: "",
          html: '<div style="width:24px;height:24px;background:#6366f1;border-radius:50%;display:flex;align-items:center;justify-content:center;color:#fff;font-size:14px;box-shadow:0 2px 6px rgba(0,0,0,0.3);">&#x1f6c8;</div>',
          iconSize: [24, 24],
          iconAnchor: [12, 12]
        })
      }).addTo(map);
      L.polyline([poiLatLng, stationLatLng], {
        color: "#6366f1",
        weight: 2,
        dashArray: "6, 8",
        opacity: 0.7
      }).addTo(map);
    }
    map.fitBounds(bounds, { padding: [30, 30], maxZoom: 11 });
    mapRef.current = map;
    return function() {
      if (mapRef.current) {
        mapRef.current.remove();
        mapRef.current = null;
      }
    };
  }, [poi.lat, poi.lon, poi.station_lat, poi.station_lon]);
  return /* @__PURE__ */ React.createElement("div", { className: "poi-card-minimap", ref: mapContainerRef });
}
function TodoCard({ poi, onClose }) {
  return /* @__PURE__ */ React.createElement("div", { className: "poi-card" }, /* @__PURE__ */ React.createElement(TodoMiniMap, { poi }), /* @__PURE__ */ React.createElement("div", { className: "poi-card-body" }, /* @__PURE__ */ React.createElement("div", { className: "poi-card-name" }, poi.name), poi.station_name && /* @__PURE__ */ React.createElement("div", { className: "poi-card-station" }, /* @__PURE__ */ React.createElement("div", { className: "poi-card-station-icon" }, "\u{1F682}"), /* @__PURE__ */ React.createElement("div", { className: "poi-card-station-info" }, /* @__PURE__ */ React.createElement("div", { className: "poi-card-station-name" }, poi.station_name), /* @__PURE__ */ React.createElement("div", { className: "poi-card-station-time" }, poi.station_distance_km, "km od POI \xB7 ", formatHours(poi.station_time), " z Poznania"))), poi.idea_start && /* @__PURE__ */ React.createElement("div", { className: "poi-card-idea" }, /* @__PURE__ */ React.createElement("div", { className: "poi-card-idea-label" }, "Pomysl na trase"), /* @__PURE__ */ React.createElement("div", { className: "poi-card-idea-route" }, poi.idea_start, " \u2192 ", poi.idea_finish), /* @__PURE__ */ React.createElement("div", { className: "poi-card-idea-meta" }, poi.idea_distance, "km, ", poi.idea_days, " dni"))));
}
function DetailPanel({ poi, onClose }) {
  if (!poi)
    return null;
  var card;
  if (poi.type === "visited")
    card = /* @__PURE__ */ React.createElement(VisitedCard, { poi, onClose });
  else if (poi.type === "auto")
    card = /* @__PURE__ */ React.createElement(AutoCard, { poi, onClose });
  else
    card = /* @__PURE__ */ React.createElement(TodoCard, { poi, onClose });
  return /* @__PURE__ */ React.createElement("div", { className: "poi-panel" + (poi ? " poi-panel--open" : ""), "data-testid": "poi-panel" }, /* @__PURE__ */ React.createElement("div", { className: "poi-panel-handle" }), /* @__PURE__ */ React.createElement("button", { className: "poi-panel-close", onClick: onClose, "aria-label": "Zamknij" }, "\xD7"), card);
}
function Legend({ visited, todo, auto: autoCount }) {
  return /* @__PURE__ */ React.createElement("div", { className: "poi-legend", "data-testid": "poi-legend" }, /* @__PURE__ */ React.createElement("div", { className: "poi-legend-item" }, /* @__PURE__ */ React.createElement("div", { className: "poi-legend-dot poi-legend-dot--visited" }), /* @__PURE__ */ React.createElement("span", null, "Odwiedzone (", visited, ")")), /* @__PURE__ */ React.createElement("div", { className: "poi-legend-item" }, /* @__PURE__ */ React.createElement("div", { className: "poi-legend-dot poi-legend-dot--todo" }), /* @__PURE__ */ React.createElement("span", null, "Do odwiedzenia (", todo, ")")), autoCount > 0 && /* @__PURE__ */ React.createElement("div", { className: "poi-legend-item" }, /* @__PURE__ */ React.createElement("div", { className: "poi-legend-dot poi-legend-dot--auto" }), /* @__PURE__ */ React.createElement("span", null, "Najlepsze zdjecia (", autoCount, ")")));
}
function PoisApp({ data }) {
  var [selectedPoi, setSelectedPoi] = useState(null);
  var mapRef = useRef(null);
  var mapContainerRef = useRef(null);
  var markersRef = useRef([]);
  var counts = useMemo(function() {
    var v = 0, t = 0, a = 0;
    data.pois.forEach(function(p) {
      if (p.type === "visited")
        v++;
      else if (p.type === "auto")
        a++;
      else
        t++;
    });
    return { visited: v, todo: t, auto: a };
  }, [data.pois]);
  useEffect(function() {
    if (!mapContainerRef.current || mapRef.current)
      return;
    var map = L.map(mapContainerRef.current, {
      zoomControl: true
    });
    L.tileLayer(TILE_URL, { maxZoom: 16 }).addTo(map);
    map.fitBounds(POLAND_BOUNDS);
    map.on("click", function() {
      setSelectedPoi(null);
    });
    mapRef.current = map;
    return function() {
      if (mapRef.current) {
        mapRef.current.remove();
        mapRef.current = null;
      }
    };
  }, []);
  useEffect(function() {
    var map = mapRef.current;
    if (!map)
      return;
    markersRef.current.forEach(function(m) {
      map.removeLayer(m);
    });
    markersRef.current = [];
    data.pois.forEach(function(poi, i) {
      var marker = L.marker([poi.lat, poi.lon], {
        icon: createMarkerIcon(poi.type, false)
      });
      marker.on("click", function(e) {
        L.DomEvent.stopPropagation(e);
        setSelectedPoi(poi);
      });
      setTimeout(function() {
        marker.addTo(map);
      }, i * 30);
      markersRef.current.push(marker);
    });
  }, [data.pois]);
  useEffect(function() {
    var map = mapRef.current;
    if (!map)
      return;
    markersRef.current.forEach(function(marker, i) {
      var poi = data.pois[i];
      if (!poi)
        return;
      var isActive = selectedPoi && selectedPoi.lat === poi.lat && selectedPoi.lon === poi.lon && selectedPoi.name === poi.name;
      marker.setIcon(createMarkerIcon(poi.type, isActive));
    });
    if (selectedPoi) {
      map.panTo([selectedPoi.lat, selectedPoi.lon], { animate: true, duration: 0.3 });
    }
  }, [selectedPoi, data.pois]);
  var handleClose = function() {
    setSelectedPoi(null);
  };
  return /* @__PURE__ */ React.createElement("div", { className: "pois-layout" }, /* @__PURE__ */ React.createElement("div", { className: "poi-map", ref: mapContainerRef, "data-testid": "poi-map" }), /* @__PURE__ */ React.createElement(Legend, { visited: counts.visited, todo: counts.todo, auto: counts.auto }), /* @__PURE__ */ React.createElement(DetailPanel, { poi: selectedPoi, onClose: handleClose }));
}
function init() {
  var el = document.getElementById("pois-data");
  if (!el)
    return;
  var data = JSON.parse(el.textContent);
  ReactDOM.render(/* @__PURE__ */ React.createElement(PoisApp, { data }), document.getElementById("pois-root"));
}
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", init);
} else {
  init();
}
