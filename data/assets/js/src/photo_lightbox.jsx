// Shared Photo Lightbox with ambilight glow, EXIF bar, keyboard navigation
//
// Photo object contract:
//   { src, full_src, alt, exif: { camera, lens, focal, aperture, exposure, iso }, post_url, post_title }

(function() {
    var useEffect = React.useEffect;
    var useRef = React.useRef;

    // Preload full-res images into browser cache so lightbox shows them instantly.
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

        if (!photo) return null;

        // Update backlight background directly — images are pre-cached so this is instant
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
                    <img src={photo.full_src} alt={photo.alt} />
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

    window.PhotoLightbox = { Lightbox: Lightbox, preloadImages: preloadImages };
})();
