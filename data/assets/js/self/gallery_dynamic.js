const { useState, useEffect, useRef, useCallback } = React;
const GALLERY_CONFIG = JSON.parse(document.getElementById("gallery-config").textContent);
function GalleryApp() {
  var PhotoLB = window.PhotoLightbox;
  const [galleryData, setGalleryData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [selectedIndex, setSelectedIndex] = useState(-1);
  const containerRef = useRef(null);
  const isOpen = selectedIndex >= 0;
  useEffect(() => {
    try {
      setGalleryData(GALLERY_CONFIG);
      setLoading(false);
    } catch (err) {
      setError(err.message);
      setLoading(false);
    }
  }, []);
  const handleImageClick = (index) => {
    setSelectedIndex(index);
  };
  const closeLightbox = useCallback(() => {
    setSelectedIndex(-1);
  }, []);
  const goPrev = useCallback(() => {
    setSelectedIndex(function(i) {
      return i > 0 ? i - 1 : galleryData.items.length - 1;
    });
  }, [galleryData]);
  const goNext = useCallback(() => {
    setSelectedIndex(function(i) {
      return i < galleryData.items.length - 1 ? i + 1 : 0;
    });
  }, [galleryData]);
  useEffect(() => {
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
    return () => window.removeEventListener("keydown", handleKey);
  }, [isOpen, closeLightbox, goPrev, goNext]);
  useEffect(() => {
    document.body.style.overflow = isOpen ? "hidden" : "";
    return () => {
      document.body.style.overflow = "";
    };
  }, [isOpen]);
  useEffect(() => {
    if (!galleryData)
      return;
    var photos = galleryData.items.map(mapToLightboxPhoto);
    PhotoLB.preloadImages(photos);
  }, [galleryData]);
  if (loading) {
    return /* @__PURE__ */ React.createElement("div", { className: "loading" }, "Loading gallery...");
  }
  if (error) {
    return /* @__PURE__ */ React.createElement("div", { className: "error" }, "Error loading gallery: ", error);
  }
  if (!galleryData || !galleryData.items.length) {
    return /* @__PURE__ */ React.createElement("div", { className: "error" }, "No images found in gallery");
  }
  var lightboxPhotos = galleryData.items.map(mapToLightboxPhoto);
  return /* @__PURE__ */ React.createElement("div", { className: "gallery-container", ref: containerRef }, /* @__PURE__ */ React.createElement("div", { className: "gallery-title" }, galleryData.galleryName), /* @__PURE__ */ React.createElement("div", { className: "masonry-grid" }, galleryData.items.map((item, index) => /* @__PURE__ */ React.createElement(
    "div",
    {
      key: index,
      className: "gallery-item",
      onClick: () => handleImageClick(index),
      role: "button",
      tabIndex: 0,
      "aria-label": `Zobacz ${item["img.alt"]}`,
      id: item["img.full_image_sanitized"]
    },
    /* @__PURE__ */ React.createElement(
      "img",
      {
        src: item["img.src"],
        alt: item["img.alt"],
        title: item["img.title"],
        loading: "lazy",
        onError: (e) => {
          e.target.src = 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg" width="100" height="100"%3E%3Crect fill="%23ddd" width="100" height="100"/%3E%3Ctext x="50" y="50" text-anchor="middle" dy=".3em" fill="%23999" font-family="sans-serif" font-size="12"%3EImage%3C/text%3E%3C/svg%3E';
        }
      }
    ),
    /* @__PURE__ */ React.createElement("div", { className: "gallery-overlay" }, /* @__PURE__ */ React.createElement("div", { className: "gallery-info" }, /* @__PURE__ */ React.createElement("div", { className: "gallery-info-title" }, item["img.title"]), /* @__PURE__ */ React.createElement("div", { className: "gallery-info-post-title hidden" }, item["post.title"]), /* @__PURE__ */ React.createElement("div", { className: "gallery-info-details" }, item["img.time_display"], " \u2022 ", parseFloat(item["img.lat"]).toFixed(2), "\xB0, ", parseFloat(item["img.lon"]).toFixed(2), "\xB0"), /* @__PURE__ */ React.createElement("div", { className: "gallery-info-exif" }, item["img.exif_string"])))
  ))), isOpen && /* @__PURE__ */ React.createElement(
    PhotoLB.Lightbox,
    {
      photos: lightboxPhotos,
      index: selectedIndex,
      onClose: closeLightbox,
      onPrev: goPrev,
      onNext: goNext
    }
  ));
}
function mapToLightboxPhoto(item) {
  var exif = {};
  if (item["img.camera"])
    exif.camera = item["img.camera"];
  if (item["img.lens"])
    exif.lens = item["img.lens"];
  if (item["img.focal"])
    exif.focal = item["img.focal"];
  if (item["img.aperture"])
    exif.aperture = item["img.aperture"];
  if (item["img.exposure"])
    exif.exposure = item["img.exposure"];
  if (item["img.iso"])
    exif.iso = item["img.iso"];
  return {
    src: item["img.src"],
    full_src: item["img.url"],
    alt: item["img.alt"] || "",
    exif,
    post_url: item["post.url"] || "",
    post_title: item["post.title"] || ""
  };
}
function init() {
  ReactDOM.render(/* @__PURE__ */ React.createElement(GalleryApp, null), document.getElementById("root"));
}
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", init);
} else {
  init();
}
