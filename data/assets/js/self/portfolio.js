const { useState, useEffect, useRef, useCallback } = React;
function LazyImage({ src, alt, onLoad, className }) {
  var imgRef = useRef(null);
  var [loaded, setLoaded] = useState(false);
  useEffect(function() {
    var img = imgRef.current;
    if (!img)
      return;
    var observer = new IntersectionObserver(function(entries) {
      entries.forEach(function(entry) {
        if (entry.isIntersecting) {
          img.src = img.dataset.src;
          observer.unobserve(img);
        }
      });
    }, { rootMargin: "300px" });
    observer.observe(img);
    return function() {
      observer.disconnect();
    };
  }, []);
  function handleLoad() {
    setLoaded(true);
    if (onLoad)
      onLoad();
  }
  return /* @__PURE__ */ React.createElement(
    "img",
    {
      ref: imgRef,
      "data-src": src,
      alt,
      className: (className || "") + (loaded ? " visible" : ""),
      onLoad: handleLoad
    }
  );
}
function Hero({ photo }) {
  var style = photo ? { backgroundImage: "url(" + photo.src + ")" } : {};
  return /* @__PURE__ */ React.createElement("section", { className: "portfolio-hero" }, /* @__PURE__ */ React.createElement("div", { className: "portfolio-hero-bg", style }), /* @__PURE__ */ React.createElement("div", { className: "portfolio-hero-overlay" }, /* @__PURE__ */ React.createElement("h1", { className: "portfolio-hero-name" }, "Aleksander Kwiatkowski"), /* @__PURE__ */ React.createElement("p", { className: "portfolio-hero-tagline" }, "Rowerem i pieszo przez Polsk\u0119")), /* @__PURE__ */ React.createElement("div", { className: "portfolio-scroll-hint", onClick: function() {
    var bio = document.querySelector(".portfolio-bio");
    if (bio)
      bio.scrollIntoView({ behavior: "smooth" });
  } }, "\u2304"));
}
function Bio({ stats }) {
  return /* @__PURE__ */ React.createElement("section", { className: "portfolio-bio" }, /* @__PURE__ */ React.createElement("p", null, "Od ", /* @__PURE__ */ React.createElement("span", { className: "stat-value" }, stats.years_active), " dokumentuj\u0119 polsk\u0105 wie\u015B i krajobraz.", " ", /* @__PURE__ */ React.createElement("span", { className: "stat-value" }, stats.bicycle_distance_km.toLocaleString(), "km"), " na rowerze,", " ", /* @__PURE__ */ React.createElement("span", { className: "stat-value" }, stats.hike_distance_km.toLocaleString(), "km"), " pieszo,", " ", /* @__PURE__ */ React.createElement("span", { className: "stat-value" }, stats.total_hours, "h"), " w terenie.", " ", /* @__PURE__ */ React.createElement("span", { className: "stat-value" }, stats.photo_count.toLocaleString()), " zdj\u0119\u0107", " ", "z ", /* @__PURE__ */ React.createElement("span", { className: "stat-value" }, stats.post_count), " wypraw", " ", "przez ", /* @__PURE__ */ React.createElement("span", { className: "stat-value" }, stats.towns_visited), " gmin."));
}
function MasonryGrid({ photos, onPhotoClick }) {
  return /* @__PURE__ */ React.createElement("div", { className: "portfolio-grid" }, photos.map(function(photo, i) {
    return /* @__PURE__ */ React.createElement(GridItem, { key: i, photo, index: i, onClick: onPhotoClick });
  }));
}
function GridItem({ photo, index, onClick }) {
  var [itemLoaded, setItemLoaded] = useState(false);
  var gridSrc = photo.grid_src || photo.src;
  var style = { "--photo-url": "url(" + gridSrc + ")" };
  return /* @__PURE__ */ React.createElement(
    "div",
    {
      className: "portfolio-grid-item" + (itemLoaded ? " loaded" : ""),
      style,
      onClick: function() {
        onClick(index);
      }
    },
    /* @__PURE__ */ React.createElement(
      LazyImage,
      {
        src: gridSrc,
        alt: photo.alt,
        onLoad: function() {
          setItemLoaded(true);
        }
      }
    )
  );
}
function PortfolioApp({ data }) {
  var PhotoLB = window.PhotoLightbox;
  var [lightboxIndex, setLightboxIndex] = useState(-1);
  var isOpen = lightboxIndex >= 0;
  useEffect(function() {
    if (lightboxIndex < 0)
      return;
    PhotoLB.preloadAdjacent(data.photos, lightboxIndex);
  }, [lightboxIndex]);
  var goPrev = useCallback(function() {
    setLightboxIndex(function(i) {
      return i > 0 ? i - 1 : data.photos.length - 1;
    });
  }, [data.photos.length]);
  var goNext = useCallback(function() {
    setLightboxIndex(function(i) {
      return i < data.photos.length - 1 ? i + 1 : 0;
    });
  }, [data.photos.length]);
  var closeLightbox = useCallback(function() {
    setLightboxIndex(-1);
  }, []);
  useEffect(function() {
    if (!isOpen)
      return;
    function handleKey(e) {
      if (e.key === "Escape")
        closeLightbox();
      else if (e.key === "ArrowLeft")
        goPrev();
      else if (e.key === "ArrowRight")
        goNext();
    }
    window.addEventListener("keydown", handleKey);
    return function() {
      window.removeEventListener("keydown", handleKey);
    };
  }, [isOpen, closeLightbox, goPrev, goNext]);
  useEffect(function() {
    document.body.style.overflow = isOpen ? "hidden" : "";
    return function() {
      document.body.style.overflow = "";
    };
  }, [isOpen]);
  return /* @__PURE__ */ React.createElement(React.Fragment, null, /* @__PURE__ */ React.createElement(Hero, { photo: data.hero_photo }), /* @__PURE__ */ React.createElement(Bio, { stats: data.stats }), /* @__PURE__ */ React.createElement(MasonryGrid, { photos: data.photos, onPhotoClick: setLightboxIndex }), isOpen && /* @__PURE__ */ React.createElement(
    PhotoLB.Lightbox,
    {
      photos: data.photos,
      index: lightboxIndex,
      onClose: closeLightbox,
      onPrev: goPrev,
      onNext: goNext
    }
  ));
}
function _initPortfolio() {
  var el = document.getElementById("portfolio-data");
  if (!el)
    return;
  var data = JSON.parse(el.textContent);
  ReactDOM.render(/* @__PURE__ */ React.createElement(PortfolioApp, { data }), document.getElementById("portfolio-root"));
}
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", _initPortfolio);
} else {
  _initPortfolio();
}
