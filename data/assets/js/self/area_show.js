const { useState, useEffect, useRef } = React;
const AREA_CONFIG = JSON.parse(document.getElementById("area-config").textContent);
function loadAreaData(areaConfig) {
  var inlineData = JSON.parse(document.getElementById("area-data").textContent);
  var posts = inlineData.posts.sort((a, b) => new Date(b.date) - new Date(a.date));
  var photos = inlineData.photos;
  var routes = posts.flatMap(
    (post) => (post.coords || []).map((coord) => coord.route)
  ).filter((route) => route && route.length > 0);
  var stats = calculateStats(posts, photos);
  return { posts, photos, routes, stats };
}
function calculateStats(posts, photos) {
  const bicyclePosts = posts.filter((p) => p.tags?.includes("bicycle"));
  const hikePosts = posts.filter((p) => p.tags?.includes("hike"));
  const bicycleDistance = bicyclePosts.reduce((sum, p) => sum + (p.distace || 0), 0);
  const hikeDistance = hikePosts.reduce((sum, p) => sum + (p.distace || 0), 0);
  const totalTime = posts.reduce((sum, p) => sum + (p.time_spent || 0), 0);
  const dates = posts.map((p) => p.date).sort();
  return {
    totalDistance: Math.round(bicycleDistance + hikeDistance),
    bicycleDistance: Math.round(bicycleDistance),
    hikeDistance: Math.round(hikeDistance),
    totalTime: Math.round(totalTime),
    postsCount: posts.length,
    photosCount: photos.length,
    firstVisit: dates[0] || null,
    lastVisit: dates[dates.length - 1] || null
  };
}
function shuffleArray(array) {
  const shuffled = [...array];
  for (let i = shuffled.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
  }
  return shuffled;
}
function formatDate(dateStr) {
  return new Date(dateStr).toLocaleDateString("pl-PL", {
    day: "numeric",
    month: "long",
    year: "numeric"
  });
}
function HeroMap({ area, scrollProgress }) {
  const mapRef = useRef(null);
  const mapInstanceRef = useRef(null);
  const [polygonLoaded, setPolygonLoaded] = useState(false);
  useEffect(() => {
    if (mapInstanceRef.current)
      return;
    const { bbox } = area;
    const center = [(bbox.south + bbox.north) / 2, (bbox.west + bbox.east) / 2];
    const map = L.map(mapRef.current, {
      center,
      zoom: 12,
      zoomControl: false,
      dragging: false,
      touchZoom: false,
      scrollWheelZoom: false,
      doubleClickZoom: false,
      boxZoom: false,
      keyboard: false,
      attributionControl: false
    });
    L.tileLayer("/tiles/ump/{z}/{x}/{y}.png", {
      maxZoom: 19
    }).addTo(map);
    map.fitBounds([
      [bbox.south, bbox.west],
      [bbox.north, bbox.east]
    ], { padding: [50, 50] });
    const routeColors = ["#32b8c6", "#21808d", "#1a7480"];
    (area.routes || []).forEach((route, idx) => {
      if (route && route.length > 0) {
        L.polyline(route, {
          color: routeColors[idx % routeColors.length],
          weight: 4,
          opacity: 0.9
        }).addTo(map);
      }
    });
    const polygonUrl = `/polygons/${area.areaType}s/${area.slug}.json`;
    fetch(polygonUrl).then((response) => {
      if (!response.ok)
        throw new Error("Polygon not found");
      return response.json();
    }).then((geojson) => {
      const areaCoords = geojson.geometry.coordinates[0];
      const worldBounds = [
        [-90, -180],
        [-90, 180],
        [90, 180],
        [90, -180],
        [-90, -180]
      ];
      const areaLatLngs = areaCoords.map((coord) => [coord[1], coord[0]]);
      L.polygon([worldBounds, areaLatLngs], {
        color: "none",
        fillColor: "#000",
        fillOpacity: 0.4,
        interactive: false
      }).addTo(map);
      const polygonLayer = L.geoJSON(geojson, {
        style: {
          color: "#21808d",
          weight: 2,
          fill: false,
          dashArray: "10, 10",
          opacity: 0.9
        }
      }).addTo(map);
      map.fitBounds(polygonLayer.getBounds(), { padding: [50, 50] });
      setPolygonLoaded(true);
    }).catch((err) => {
      L.rectangle([
        [bbox.south, bbox.west],
        [bbox.north, bbox.east]
      ], {
        color: "#21808d",
        weight: 2,
        fill: false,
        dashArray: "10, 10"
      }).addTo(map);
    });
    mapInstanceRef.current = map;
  }, [area]);
  const opacity = Math.max(0.15, 1 - scrollProgress * 1.5);
  return /* @__PURE__ */ React.createElement("div", { className: "hero-map-container", style: { opacity } }, /* @__PURE__ */ React.createElement("div", { id: "map", ref: mapRef }));
}
function HeroOverlay({ area, scrollProgress }) {
  const opacity = Math.max(0, 1 - scrollProgress * 2);
  return /* @__PURE__ */ React.createElement("div", { className: "hero-overlay", style: { opacity } }, /* @__PURE__ */ React.createElement("div", { className: "hero-content" }, /* @__PURE__ */ React.createElement("span", { className: "area-type-badge" }, area.areaTypeLabel), /* @__PURE__ */ React.createElement("h1", { className: "area-name" }, area.name), /* @__PURE__ */ React.createElement("p", { className: "area-parent" }, /* @__PURE__ */ React.createElement("a", { href: area.parentUrl }, area.parentName), area.voivodeshipName && /* @__PURE__ */ React.createElement("span", null, ", ", /* @__PURE__ */ React.createElement("a", { href: area.voivodeshipUrl }, area.voivodeshipName))), /* @__PURE__ */ React.createElement("div", { className: "hero-stats-preview" }, /* @__PURE__ */ React.createElement("div", { className: "hero-stat" }, /* @__PURE__ */ React.createElement("div", { className: "hero-stat-value" }, area.stats.totalDistance), /* @__PURE__ */ React.createElement("div", { className: "hero-stat-label" }, "kilometrow")), /* @__PURE__ */ React.createElement("div", { className: "hero-stat" }, /* @__PURE__ */ React.createElement("div", { className: "hero-stat-value" }, area.stats.postsCount), /* @__PURE__ */ React.createElement("div", { className: "hero-stat-label" }, "wypraw")), /* @__PURE__ */ React.createElement("div", { className: "hero-stat" }, /* @__PURE__ */ React.createElement("div", { className: "hero-stat-value" }, area.stats.photosCount), /* @__PURE__ */ React.createElement("div", { className: "hero-stat-label" }, "zdjec")))));
}
function ScrollHint({ visible }) {
  if (!visible)
    return null;
  return /* @__PURE__ */ React.createElement("div", { className: "scroll-hint" }, /* @__PURE__ */ React.createElement("i", { className: "fa fa-chevron-down fa-2x" }));
}
function StatsSection({ stats }) {
  return /* @__PURE__ */ React.createElement("section", { className: "section" }, /* @__PURE__ */ React.createElement("h2", { className: "section-title" }, "W liczbach"), /* @__PURE__ */ React.createElement("div", { className: "stats-grid" }, /* @__PURE__ */ React.createElement("div", { className: "stat-card" }, /* @__PURE__ */ React.createElement("div", { className: "stat-icon" }, /* @__PURE__ */ React.createElement("i", { className: "fa fa-road" })), /* @__PURE__ */ React.createElement("div", { className: "stat-value" }, stats.totalDistance), /* @__PURE__ */ React.createElement("div", { className: "stat-label" }, "Kilometrow"), /* @__PURE__ */ React.createElement("div", { className: "stat-breakdown" }, /* @__PURE__ */ React.createElement("i", { className: "fa fa-bicycle" }), " ", stats.bicycleDistance, " km rowerem", /* @__PURE__ */ React.createElement("br", null), /* @__PURE__ */ React.createElement("i", { className: "fa fa-male" }), " ", stats.hikeDistance, " km pieszo")), /* @__PURE__ */ React.createElement("div", { className: "stat-card" }, /* @__PURE__ */ React.createElement("div", { className: "stat-icon" }, /* @__PURE__ */ React.createElement("i", { className: "fa fa-clock-o" })), /* @__PURE__ */ React.createElement("div", { className: "stat-value" }, stats.totalTime), /* @__PURE__ */ React.createElement("div", { className: "stat-label" }, "Godzin w terenie")), /* @__PURE__ */ React.createElement("div", { className: "stat-card" }, /* @__PURE__ */ React.createElement("div", { className: "stat-icon" }, /* @__PURE__ */ React.createElement("i", { className: "fa fa-map-marker" })), /* @__PURE__ */ React.createElement("div", { className: "stat-value" }, stats.postsCount), /* @__PURE__ */ React.createElement("div", { className: "stat-label" }, "Wypraw"), stats.firstVisit && stats.lastVisit && /* @__PURE__ */ React.createElement("div", { className: "stat-breakdown" }, "Pierwsza: ", formatDate(stats.firstVisit), /* @__PURE__ */ React.createElement("br", null), "Ostatnia: ", formatDate(stats.lastVisit))), /* @__PURE__ */ React.createElement("div", { className: "stat-card" }, /* @__PURE__ */ React.createElement("div", { className: "stat-icon" }, /* @__PURE__ */ React.createElement("i", { className: "fa fa-camera" })), /* @__PURE__ */ React.createElement("div", { className: "stat-value" }, stats.photosCount), /* @__PURE__ */ React.createElement("div", { className: "stat-label" }, "Zdjec"))), /* @__PURE__ */ React.createElement("div", { className: "nav-links" }, /* @__PURE__ */ React.createElement("a", { href: "#", className: "nav-link-btn" }, /* @__PURE__ */ React.createElement("i", { className: "fa fa-list" }), " Wszystkie wpisy"), /* @__PURE__ */ React.createElement("a", { href: "#", className: "nav-link-btn secondary" }, /* @__PURE__ */ React.createElement("i", { className: "fa fa-th" }), " Pelna galeria")));
}
function PhotosSection({ photos }) {
  const [shuffledPhotos] = useState(() => shuffleArray(photos).slice(0, 12));
  if (photos.length === 0) {
    return null;
  }
  return /* @__PURE__ */ React.createElement("section", { className: "photos-section" }, /* @__PURE__ */ React.createElement("h2", { className: "section-title" }, "Najlepsze zdjecia"), /* @__PURE__ */ React.createElement("div", { className: "photos-grid" }, shuffledPhotos.map((photo, idx) => /* @__PURE__ */ React.createElement("a", { key: idx, href: photo.post_url, className: "photo-card" }, /* @__PURE__ */ React.createElement("img", { src: photo.article_url, alt: photo.desc, loading: "lazy" }), /* @__PURE__ */ React.createElement("div", { className: "photo-overlay" }, /* @__PURE__ */ React.createElement("div", { className: "photo-title" }, photo.desc || "Zdjecie"), /* @__PURE__ */ React.createElement("div", { className: "photo-date" }, formatDate(photo.time)))))));
}
function PostsSection({ posts }) {
  if (posts.length === 0) {
    return null;
  }
  return /* @__PURE__ */ React.createElement("section", { className: "section" }, /* @__PURE__ */ React.createElement("h2", { className: "section-title" }, "Ostatnie wyprawy"), /* @__PURE__ */ React.createElement("div", { className: "posts-scroll-container" }, /* @__PURE__ */ React.createElement("div", { className: "posts-row" }, posts.map((post) => /* @__PURE__ */ React.createElement("a", { key: post.slug, href: post.url, className: "post-card-link" }, /* @__PURE__ */ React.createElement("img", { src: post.card_image_url, alt: post.title, className: "post-card-image" }), /* @__PURE__ */ React.createElement("div", { className: "post-card-content" }, /* @__PURE__ */ React.createElement("div", { className: "post-card-date" }, formatDate(post.date)), /* @__PURE__ */ React.createElement("h3", { className: "post-card-title" }, post.title), /* @__PURE__ */ React.createElement("div", { className: "post-card-stats" }, /* @__PURE__ */ React.createElement("span", null, /* @__PURE__ */ React.createElement("i", { className: "fa fa-bicycle" }), " ", post.distace || 0, " km"), /* @__PURE__ */ React.createElement("span", null, /* @__PURE__ */ React.createElement("i", { className: "fa fa-clock-o" }), " ", post.time_spent || 0, "h"))))))));
}
function AreaFooter({ area }) {
  return /* @__PURE__ */ React.createElement("footer", { className: "area-footer" }, /* @__PURE__ */ React.createElement("div", { className: "related-areas" }, /* @__PURE__ */ React.createElement("div", { className: "related-areas-title" }, "Zobacz takze"), /* @__PURE__ */ React.createElement("div", { className: "related-areas-list" }, /* @__PURE__ */ React.createElement("a", { href: area.parentUrl, className: "related-area-link" }, /* @__PURE__ */ React.createElement("i", { className: "fa fa-map-o" }), " ", area.parentName), area.voivodeshipName && /* @__PURE__ */ React.createElement("a", { href: area.voivodeshipUrl, className: "related-area-link" }, /* @__PURE__ */ React.createElement("i", { className: "fa fa-globe" }), " ", area.voivodeshipName))));
}
function AreaShowPage() {
  const [scrollProgress, setScrollProgress] = useState(0);
  const [areaData] = useState(() => {
    var data = loadAreaData(AREA_CONFIG);
    return { ...AREA_CONFIG, ...data };
  });
  useEffect(() => {
    const handleScroll = () => {
      const windowHeight = window.innerHeight;
      const progress = Math.min(1, window.scrollY / windowHeight);
      setScrollProgress(progress);
    };
    window.addEventListener("scroll", handleScroll, { passive: true });
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);
  return /* @__PURE__ */ React.createElement(React.Fragment, null, /* @__PURE__ */ React.createElement(HeroMap, { area: areaData, scrollProgress }), /* @__PURE__ */ React.createElement(HeroOverlay, { area: areaData, scrollProgress }), /* @__PURE__ */ React.createElement(ScrollHint, { visible: scrollProgress < 0.1 }), /* @__PURE__ */ React.createElement("main", { className: "main-content" }, /* @__PURE__ */ React.createElement("div", { className: "content-transition" }), /* @__PURE__ */ React.createElement(StatsSection, { stats: areaData.stats }), /* @__PURE__ */ React.createElement(PhotosSection, { photos: areaData.photos }), /* @__PURE__ */ React.createElement(PostsSection, { posts: areaData.posts }), /* @__PURE__ */ React.createElement(AreaFooter, { area: areaData })));
}
function init() {
  ReactDOM.render(/* @__PURE__ */ React.createElement(AreaShowPage, null), document.getElementById("root"));
}
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", init);
} else {
  init();
}
