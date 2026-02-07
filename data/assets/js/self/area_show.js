var AreaShow = (() => {
  // data/assets/js/src/area_show.jsx
  var { useState, useEffect, useRef } = React;
  var AREA_CONFIG = JSON.parse(document.getElementById("area-config").textContent);
  function loadAreaData(areaConfig) {
    var inlineData = JSON.parse(document.getElementById("area-data").textContent);
    var posts = inlineData.posts.sort((a, b) => new Date(b.date) - new Date(a.date));
    var photos = inlineData.photos;
    var relatedAreas = inlineData.related_areas || [];
    var routes = posts.flatMap(
      (post) => (post.coords || []).map((coord) => coord.route)
    ).filter((route) => route && route.length > 0);
    var stats = calculateStats(posts, photos);
    return { posts, photos, routes, stats, relatedAreas };
  }
  function calculateStats(posts, photos) {
    const bicyclePosts = posts.filter((p) => p.tags?.includes("bicycle"));
    const hikePosts = posts.filter((p) => p.tags?.includes("hike"));
    const bicycleDistance = bicyclePosts.reduce((sum, p) => sum + (p.distace || 0), 0);
    const hikeDistance = hikePosts.reduce((sum, p) => sum + (p.distace || 0), 0);
    const totalTime = posts.reduce((sum, p) => sum + (p.time_spent || 0), 0);
    const dates = posts.map((p) => p.date).sort();
    const firstYear = dates[0] ? new Date(dates[0]).getFullYear() : null;
    const lastYear = dates.length > 0 ? new Date(dates[dates.length - 1]).getFullYear() : null;
    return {
      totalDistance: Math.round(bicycleDistance + hikeDistance),
      bicycleDistance: Math.round(bicycleDistance),
      hikeDistance: Math.round(hikeDistance),
      totalTime: Math.round(totalTime),
      postsCount: posts.length,
      photosCount: photos.length,
      firstYear,
      lastYear
    };
  }
  function formatDate(dateStr) {
    return new Date(dateStr).toLocaleDateString("pl-PL", {
      day: "numeric",
      month: "long",
      year: "numeric"
    });
  }
  function initLeafletMap(container, area, options = {}) {
    const { bbox } = area;
    const interactive = options.interactive || false;
    const map = L.map(container, {
      center: [(bbox.south + bbox.north) / 2, (bbox.west + bbox.east) / 2],
      zoom: 12,
      zoomControl: interactive,
      dragging: interactive,
      touchZoom: interactive,
      scrollWheelZoom: false,
      doubleClickZoom: interactive,
      boxZoom: interactive,
      keyboard: interactive,
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
      if (options.onReady)
        options.onReady();
    }).catch(() => {
      L.rectangle([
        [bbox.south, bbox.west],
        [bbox.north, bbox.east]
      ], {
        color: "#21808d",
        weight: 2,
        fill: false,
        dashArray: "10, 10"
      }).addTo(map);
      if (options.onReady)
        options.onReady();
    });
    return map;
  }
  function HeroPhotoBg({ url, scrollProgress }) {
    if (!url)
      return null;
    const opacity = Math.max(0.15, 1 - scrollProgress * 1.5);
    return /* @__PURE__ */ React.createElement(
      "div",
      {
        className: "hero-photo-bg",
        style: {
          backgroundImage: `url(${url})`,
          opacity
        }
      }
    );
  }
  function HeroMap({ area, hasPhoto, scrollProgress }) {
    const mapRef = useRef(null);
    const mapInstanceRef = useRef(null);
    const [mapReady, setMapReady] = useState(false);
    useEffect(() => {
      if (mapInstanceRef.current)
        return;
      const onReady = () => {
        setTimeout(() => setMapReady(true), 600);
      };
      mapInstanceRef.current = initLeafletMap(mapRef.current, area, {
        interactive: false,
        onReady
      });
    }, [area]);
    const fadeOpacity = mapReady ? 1 : 0;
    const scrollOpacity = hasPhoto ? void 0 : Math.max(0.15, 1 - scrollProgress * 1.5);
    return /* @__PURE__ */ React.createElement(
      "div",
      {
        className: `hero-map-container${hasPhoto ? " has-photo" : ""}`,
        style: hasPhoto ? { opacity: fadeOpacity } : { opacity: mapReady ? scrollOpacity : 0 }
      },
      /* @__PURE__ */ React.createElement("div", { id: "map", ref: mapRef })
    );
  }
  function HeroOverlay({ area, scrollProgress }) {
    const opacity = Math.max(0, 1 - scrollProgress * 2);
    const { stats } = area;
    const yearRange = stats.firstYear && stats.lastYear ? stats.firstYear === stats.lastYear ? `${stats.firstYear}` : `${stats.firstYear}\u2013${stats.lastYear}` : null;
    return /* @__PURE__ */ React.createElement("div", { className: "hero-overlay", style: { opacity } }, /* @__PURE__ */ React.createElement("div", { className: "hero-content" }, /* @__PURE__ */ React.createElement("span", { className: "area-type-badge" }, area.areaTypeLabel), /* @__PURE__ */ React.createElement("h1", { className: "area-name" }, area.name), yearRange && /* @__PURE__ */ React.createElement("div", { className: "area-year-range" }, yearRange), /* @__PURE__ */ React.createElement("p", { className: "area-parent" }, area.parentName && /* @__PURE__ */ React.createElement("a", { href: area.parentUrl }, area.parentName), area.voivodeshipName && /* @__PURE__ */ React.createElement("span", null, area.parentName ? ", " : "", /* @__PURE__ */ React.createElement("a", { href: area.voivodeshipUrl }, area.voivodeshipName)))));
  }
  function ScrollHint({ visible }) {
    if (!visible)
      return null;
    return /* @__PURE__ */ React.createElement("div", { className: "scroll-hint" }, /* @__PURE__ */ React.createElement("i", { className: "fa fa-chevron-down fa-2x" }));
  }
  function StatsBar({ stats, postListUrl, galleryUrl }) {
    return /* @__PURE__ */ React.createElement("div", { className: "stats-bar" }, /* @__PURE__ */ React.createElement("div", { className: "stats-inline" }, /* @__PURE__ */ React.createElement("span", { className: "stat-value" }, stats.postsCount), " wypraw", /* @__PURE__ */ React.createElement("span", { className: "stat-sep" }, "\xB7"), /* @__PURE__ */ React.createElement("span", { className: "stat-value" }, stats.totalDistance), " km", /* @__PURE__ */ React.createElement("span", { className: "stat-sep" }, "\xB7"), /* @__PURE__ */ React.createElement("span", { className: "stat-value" }, stats.totalTime), " h", /* @__PURE__ */ React.createElement("span", { className: "stat-sep" }, "\xB7"), /* @__PURE__ */ React.createElement("span", { className: "stat-value" }, stats.photosCount), " zdjec"), /* @__PURE__ */ React.createElement("div", { className: "stats-links" }, /* @__PURE__ */ React.createElement("a", { href: postListUrl, className: "stats-link-btn" }, /* @__PURE__ */ React.createElement("i", { className: "fa fa-list" }), " Wszystkie wpisy"), /* @__PURE__ */ React.createElement("a", { href: galleryUrl, className: "stats-link-btn secondary" }, /* @__PURE__ */ React.createElement("i", { className: "fa fa-th" }), " Pelna galeria")));
  }
  function MapSection({ area }) {
    const mapRef = useRef(null);
    const mapInstanceRef = useRef(null);
    useEffect(() => {
      if (mapInstanceRef.current)
        return;
      mapInstanceRef.current = initLeafletMap(mapRef.current, area, {
        interactive: true
      });
    }, [area]);
    return /* @__PURE__ */ React.createElement("section", { className: "section map-section" }, /* @__PURE__ */ React.createElement("h2", { className: "section-title" }, "Mapa"), /* @__PURE__ */ React.createElement("div", { className: "map-container", ref: mapRef }));
  }
  function PhotosSection({ photos }) {
    const [displayPhotos] = useState(
      () => [...photos].sort((a, b) => b.points - a.points).slice(0, 16)
    );
    if (photos.length === 0)
      return null;
    return /* @__PURE__ */ React.createElement("section", { className: "photos-section" }, /* @__PURE__ */ React.createElement("h2", { className: "section-title" }, "Najlepsze zdjecia"), /* @__PURE__ */ React.createElement("div", { className: "photos-grid" }, displayPhotos.map((photo, idx) => /* @__PURE__ */ React.createElement("a", { key: idx, href: photo.post_url, className: "photo-card" }, /* @__PURE__ */ React.createElement("img", { src: photo.article_url, alt: photo.desc, loading: "lazy" }), /* @__PURE__ */ React.createElement("div", { className: "photo-overlay" }, /* @__PURE__ */ React.createElement("div", { className: "photo-title" }, photo.desc || "Zdjecie"), /* @__PURE__ */ React.createElement("div", { className: "photo-date" }, formatDate(photo.time)))))));
  }
  function PostsSection({ posts }) {
    const [displayPosts] = useState(() => {
      if (posts.length <= 5)
        return posts;
      const scored = posts.map((post, idx) => {
        const recencyScore = 1 - idx / posts.length * 0.9;
        const randomFactor = 0.8 + Math.random() * 0.4;
        return { post, score: recencyScore * randomFactor };
      });
      scored.sort((a, b) => b.score - a.score);
      return scored.slice(0, 5).map((s) => s.post).sort((a, b) => new Date(b.date) - new Date(a.date));
    });
    if (posts.length === 0)
      return null;
    return /* @__PURE__ */ React.createElement("section", { className: "section" }, /* @__PURE__ */ React.createElement("h2", { className: "section-title" }, "Wyprawy"), /* @__PURE__ */ React.createElement("div", { className: "posts-list" }, displayPosts.map((post) => /* @__PURE__ */ React.createElement("a", { key: post.slug, href: post.url, className: "post-card-link" }, /* @__PURE__ */ React.createElement("div", { className: "post-card-image-wrap" }, /* @__PURE__ */ React.createElement("img", { src: post.card_image_url, alt: post.title, className: "post-card-image", loading: "lazy" })), /* @__PURE__ */ React.createElement("div", { className: "post-card-content" }, /* @__PURE__ */ React.createElement("div", { className: "post-card-date" }, formatDate(post.date)), /* @__PURE__ */ React.createElement("h3", { className: "post-card-title" }, post.title), /* @__PURE__ */ React.createElement("div", { className: "post-card-stats" }, post.distace > 0 && /* @__PURE__ */ React.createElement("span", null, /* @__PURE__ */ React.createElement("i", { className: "fa fa-road" }), " ", post.distace, " km"), post.time_spent > 0 && /* @__PURE__ */ React.createElement("span", null, /* @__PURE__ */ React.createElement("i", { className: "fa fa-clock-o" }), " ", post.time_spent, "h")))))));
  }
  function RelatedAreasSection({ relatedAreas }) {
    if (!relatedAreas || relatedAreas.length === 0)
      return null;
    return /* @__PURE__ */ React.createElement("section", { className: "related-section" }, /* @__PURE__ */ React.createElement("h2", { className: "section-title" }, "Zobacz takze"), /* @__PURE__ */ React.createElement("div", { className: "related-grid" }, relatedAreas.map((area, idx) => /* @__PURE__ */ React.createElement("a", { key: idx, href: area.show_url, className: "related-card" }, area.best_photo_url && /* @__PURE__ */ React.createElement(
      "div",
      {
        className: "related-card-bg",
        style: { backgroundImage: `url(${area.best_photo_url})` }
      }
    ), /* @__PURE__ */ React.createElement("div", { className: "related-card-overlay" }, /* @__PURE__ */ React.createElement("div", { className: "related-card-name" }, area.name), /* @__PURE__ */ React.createElement("div", { className: "related-card-type" }, area.area_type))))));
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
    const hasPhoto = !!areaData.bestPhotoUrl;
    return /* @__PURE__ */ React.createElement(React.Fragment, null, hasPhoto && /* @__PURE__ */ React.createElement(HeroPhotoBg, { url: areaData.bestPhotoUrl, scrollProgress }), /* @__PURE__ */ React.createElement(HeroMap, { area: areaData, hasPhoto, scrollProgress }), /* @__PURE__ */ React.createElement(HeroOverlay, { area: areaData, scrollProgress }), /* @__PURE__ */ React.createElement(ScrollHint, { visible: scrollProgress < 0.1 }), /* @__PURE__ */ React.createElement("main", { className: "main-content" }, /* @__PURE__ */ React.createElement("div", { className: "content-transition" }), /* @__PURE__ */ React.createElement(
      StatsBar,
      {
        stats: areaData.stats,
        postListUrl: areaData.postListUrl,
        galleryUrl: areaData.galleryUrl
      }
    ), /* @__PURE__ */ React.createElement(MapSection, { area: areaData }), /* @__PURE__ */ React.createElement(PhotosSection, { photos: areaData.photos }), /* @__PURE__ */ React.createElement(PostsSection, { posts: areaData.posts }), /* @__PURE__ */ React.createElement(RelatedAreasSection, { relatedAreas: areaData.relatedAreas })));
  }
  function init() {
    ReactDOM.render(/* @__PURE__ */ React.createElement(AreaShowPage, null), document.getElementById("root"));
  }
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
