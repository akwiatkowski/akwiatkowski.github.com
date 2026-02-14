(function() {
  var useEffect = React.useEffect;
  var useRef = React.useRef;
  var useState = React.useState;
  function preloadAdjacent(photos, index) {
    var indices = [index, index + 1, index + 2, index - 1];
    indices.forEach(function(i) {
      var idx = (i % photos.length + photos.length) % photos.length;
      var photo = photos[idx];
      if (photo && photo.full_src) {
        var img = new Image();
        img.src = photo.full_src;
      }
    });
  }
  function Lightbox({ photos, index, onClose, onPrev, onNext }) {
    var photo = photos[index];
    var outerRef = useRef(null);
    var innerRef = useRef(null);
    var imgRef = useRef(null);
    var [hiRes, setHiRes] = useState(false);
    if (!photo)
      return null;
    useEffect(function() {
      if (!photo)
        return;
      var img = imgRef.current;
      if (!img)
        return;
      setHiRes(false);
      img.src = photo.src;
      var fullImg = new Image();
      fullImg.onload = function() {
        if (imgRef.current) {
          imgRef.current.src = photo.full_src;
          setHiRes(true);
        }
      };
      fullImg.src = photo.full_src;
      preloadAdjacent(photos, index);
    }, [index]);
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
    } }, /* @__PURE__ */ React.createElement("div", { ref: outerRef, className: "photo-lb-outer active" }), /* @__PURE__ */ React.createElement("div", { ref: innerRef, className: "photo-lb-inner active" }), /* @__PURE__ */ React.createElement("button", { className: "photo-lightbox-close", onClick: onClose }, "\xD7"), /* @__PURE__ */ React.createElement("span", { className: "photo-lightbox-counter" }, index + 1, " / ", photos.length), /* @__PURE__ */ React.createElement("div", { className: "photo-lightbox-img-wrap" }, /* @__PURE__ */ React.createElement("button", { className: "photo-lightbox-nav photo-lightbox-prev", onClick: onPrev }, "\u2039"), /* @__PURE__ */ React.createElement("img", { ref: imgRef, src: photo.src, alt: photo.alt, className: hiRes ? "hires" : "" }), /* @__PURE__ */ React.createElement("button", { className: "photo-lightbox-nav photo-lightbox-next", onClick: onNext }, "\u203A")), /* @__PURE__ */ React.createElement("div", { className: "photo-lightbox-exif" }, parts.length > 0 && parts.map(function(p, i) {
      return /* @__PURE__ */ React.createElement("span", { key: i }, p);
    }), photo.post_url && /* @__PURE__ */ React.createElement("a", { className: "photo-lightbox-link", href: photo.post_url }, photo.post_title || "Wpis")));
  }
  window.PhotoLightbox = { Lightbox, preloadAdjacent };
})();
