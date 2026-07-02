(function() {
  var useEffect = React.useEffect;
  var useRef = React.useRef;
  var useState = React.useState;
  function preloadAdjacent(photos, index) {
    window.__avifReady.then(function(avif) {
      [-1, 1].forEach(function(offset) {
        var idx = ((index + offset) % photos.length + photos.length) % photos.length;
        var photo = photos[idx];
        if (!photo)
          return;
        var articleSrc = avif && photo.src_avif ? photo.src_avif : photo.src;
        if (articleSrc)
          new Image().src = articleSrc;
      });
    });
  }
  function fitToViewport(naturalW, naturalH) {
    var maxW = window.innerWidth * 0.9;
    var maxH = window.innerHeight * 0.8;
    var scale = Math.min(maxW / naturalW, maxH / naturalH);
    return { width: Math.round(naturalW * scale), height: Math.round(naturalH * scale) };
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
      var cancelled = false;
      var fullTimer = null;
      var gridSrc = photo.grid_src || photo.src;
      img.src = gridSrc;
      img.className = "";
      setHiRes(false);
      var gridImg = new Image();
      gridImg.src = gridSrc;
      function applyFit(w, h) {
        if (cancelled || !imgRef.current)
          return;
        var fit = fitToViewport(w, h);
        imgRef.current.style.width = fit.width + "px";
        imgRef.current.style.height = fit.height + "px";
      }
      if (gridImg.naturalWidth > 0) {
        applyFit(gridImg.naturalWidth, gridImg.naturalHeight);
      } else {
        gridImg.onload = function() {
          applyFit(gridImg.naturalWidth, gridImg.naturalHeight);
        };
      }
      var ambilightSrc = window.__avif && photo.grid_src_avif ? photo.grid_src_avif : gridSrc;
      if (outerRef.current)
        outerRef.current.style.backgroundImage = "url(" + ambilightSrc + ")";
      if (innerRef.current)
        innerRef.current.style.backgroundImage = "url(" + ambilightSrc + ")";
      window.__avifReady.then(function(avif) {
        if (cancelled)
          return;
        var articleSrc = avif && photo.src_avif ? photo.src_avif : photo.src;
        var articleImg = new Image();
        articleImg.onload = function() {
          if (cancelled || !imgRef.current)
            return;
          imgRef.current.src = articleSrc;
          if (outerRef.current)
            outerRef.current.style.backgroundImage = "url(" + articleSrc + ")";
          if (innerRef.current)
            innerRef.current.style.backgroundImage = "url(" + articleSrc + ")";
          if (window.devicePixelRatio > 1 && photo.full_src) {
            fullTimer = setTimeout(function() {
              if (cancelled || !imgRef.current)
                return;
              var fullSrc = avif && photo.full_src_avif ? photo.full_src_avif : photo.full_src;
              var fullImg = new Image();
              fullImg.onload = function() {
                if (cancelled || !imgRef.current)
                  return;
                imgRef.current.src = fullSrc;
                setHiRes(true);
              };
              fullImg.src = fullSrc;
            }, 3e3);
          } else {
            setHiRes(true);
          }
        };
        articleImg.src = articleSrc;
      });
      preloadAdjacent(photos, index);
      return function() {
        cancelled = true;
        if (fullTimer)
          clearTimeout(fullTimer);
      };
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
    } }, /* @__PURE__ */ React.createElement("div", { ref: outerRef, className: "photo-lb-outer active" }), /* @__PURE__ */ React.createElement("div", { ref: innerRef, className: "photo-lb-inner active" }), /* @__PURE__ */ React.createElement("button", { className: "photo-lightbox-close", onClick: onClose }, "\xD7"), /* @__PURE__ */ React.createElement("span", { className: "photo-lightbox-counter" }, index + 1, " / ", photos.length), /* @__PURE__ */ React.createElement("div", { className: "photo-lightbox-img-wrap" }, /* @__PURE__ */ React.createElement("button", { className: "photo-lightbox-nav photo-lightbox-prev", onClick: onPrev }, "\u2039"), /* @__PURE__ */ React.createElement("img", { ref: imgRef, src: photo.grid_src || photo.src, alt: photo.alt, className: hiRes ? "hires" : "" }), /* @__PURE__ */ React.createElement("button", { className: "photo-lightbox-nav photo-lightbox-next", onClick: onNext }, "\u203A")), /* @__PURE__ */ React.createElement("div", { className: "photo-lightbox-exif" }, parts.length > 0 && parts.map(function(p, i) {
      return /* @__PURE__ */ React.createElement("span", { key: i }, p);
    }), photo.post_url && /* @__PURE__ */ React.createElement("a", { className: "photo-lightbox-link", href: photo.post_url }, photo.post_title || "Wpis")));
  }
  window.PhotoLightbox = { Lightbox, preloadAdjacent };
})();
