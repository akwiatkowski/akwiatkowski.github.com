// Shared Photo Lightbox with ambilight glow, EXIF bar, keyboard navigation
//
// Photo object contract:
//   { src, full_src, alt, exif: { camera, lens, focal, aperture, exposure, iso }, post_url, post_title }

(function() {
    var useEffect = React.useEffect;
    var useRef = React.useRef;
    var useState = React.useState;

    // Preload adjacent images (current + next 2 + prev 1) instead of all at once
    function preloadAdjacent(photos, index) {
        var indices = [index, index + 1, index + 2, index - 1];
        indices.forEach(function(i) {
            var idx = ((i % photos.length) + photos.length) % photos.length;
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

        if (!photo) return null;

        // Progressive: show article size immediately, swap to full when loaded
        useEffect(function() {
            if (!photo) return;
            var img = imgRef.current;
            if (!img) return;

            setHiRes(false);

            // Show article size immediately
            img.src = photo.src;

            // Load full-res in background
            var fullImg = new Image();
            fullImg.onload = function() {
                if (imgRef.current) {
                    imgRef.current.src = photo.full_src;
                    setHiRes(true);
                }
            };
            fullImg.src = photo.full_src;

            // Preload adjacent images
            preloadAdjacent(photos, index);
        }, [index]);

        // Update backlight background
        useEffect(function() {
            var bg = 'url(' + photo.src + ')';
            if (outerRef.current) outerRef.current.style.backgroundImage = bg;
            if (innerRef.current) innerRef.current.style.backgroundImage = bg;
        }, [index]);

        var exif = photo.exif || {};
        var parts = [exif.camera, exif.lens, exif.focal, exif.aperture, exif.exposure,
                     exif.iso ? 'ISO' + exif.iso : null].filter(Boolean);

        return (
            <div className="photo-lightbox" onClick={function(e) {
                if (e.target === e.currentTarget) onClose();
            }}>
                <div ref={outerRef} className="photo-lb-outer active"></div>
                <div ref={innerRef} className="photo-lb-inner active"></div>

                <button className="photo-lightbox-close" onClick={onClose}>&times;</button>
                <span className="photo-lightbox-counter">{index + 1} / {photos.length}</span>

                <div className="photo-lightbox-img-wrap">
                    <button className="photo-lightbox-nav photo-lightbox-prev" onClick={onPrev}>&#8249;</button>
                    <img ref={imgRef} src={photo.src} alt={photo.alt} className={hiRes ? 'hires' : ''} />
                    <button className="photo-lightbox-nav photo-lightbox-next" onClick={onNext}>&#8250;</button>
                </div>

                <div className="photo-lightbox-exif">
                    {parts.length > 0 && parts.map(function(p, i) {
                        return <span key={i}>{p}</span>;
                    })}
                    {photo.post_url && (
                        <a className="photo-lightbox-link" href={photo.post_url}>
                            {photo.post_title || 'Wpis'}
                        </a>
                    )}
                </div>
            </div>
        );
    }

    window.PhotoLightbox = { Lightbox: Lightbox, preloadAdjacent: preloadAdjacent };
})();
