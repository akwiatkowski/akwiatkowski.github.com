(function() {
  var useEffect = React.useEffect;
  var useRef = React.useRef;
  function preloadImages(photos) {
    photos.forEach(function(photo) {
      var img = new Image();
      img.src = photo.full_src;
    });
  }
  function Lightbox({ photos, index, onClose, onPrev, onNext }) {
    var photo = photos[index];
    var outerRef = useRef(null);
    var innerRef = useRef(null);
    if (!photo)
      return null;
    useEffect(function() {
      var bg = "url(" + photo.src + ")";
      if (outerRef.current)
        outerRef.current.style.backgroundImage = bg;
      if (innerRef.current)
        innerRef.current.style.backgroundImage = bg;
    }, [index]);
    var exif = photo.exif || {};
    var parts = [
      exif.camera,
      exif.lens,
      exif.focal,
      exif.aperture,
      exif.exposure,
      exif.iso ? "ISO" + exif.iso : null
    ].filter(Boolean);
    return /* @__PURE__ */ React.createElement("div", { className: "photo-lightbox", onClick: function(e) {
      if (e.target === e.currentTarget)
        onClose();
    } }, /* @__PURE__ */ React.createElement("div", { ref: outerRef, className: "photo-lb-outer active" }), /* @__PURE__ */ React.createElement("div", { ref: innerRef, className: "photo-lb-inner active" }), /* @__PURE__ */ React.createElement("button", { className: "photo-lightbox-close", onClick: onClose }, "\xD7"), /* @__PURE__ */ React.createElement("span", { className: "photo-lightbox-counter" }, index + 1, " / ", photos.length), /* @__PURE__ */ React.createElement("div", { className: "photo-lightbox-img-wrap" }, /* @__PURE__ */ React.createElement("button", { className: "photo-lightbox-nav photo-lightbox-prev", onClick: onPrev }, "\u2039"), /* @__PURE__ */ React.createElement("img", { src: photo.full_src, alt: photo.alt }), /* @__PURE__ */ React.createElement("button", { className: "photo-lightbox-nav photo-lightbox-next", onClick: onNext }, "\u203A")), /* @__PURE__ */ React.createElement("div", { className: "photo-lightbox-exif" }, parts.length > 0 && parts.map(function(p, i) {
      return /* @__PURE__ */ React.createElement("span", { key: i }, p);
    }), photo.post_url && /* @__PURE__ */ React.createElement("a", { className: "photo-lightbox-link", href: photo.post_url }, photo.post_title || "Wpis")));
  }
  window.PhotoLightbox = { Lightbox, preloadImages };
})();
