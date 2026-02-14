// Gallery Dynamic - Preact component for dynamic photo galleries
// Uses shared PhotoLightbox for image viewing

const { useState, useEffect, useRef, useCallback } = React;

// Load gallery data from JSON config block
const GALLERY_CONFIG = JSON.parse(document.getElementById('gallery-config').textContent);

function GalleryApp() {
    var PhotoLB = window.PhotoLightbox;
    const [galleryData, setGalleryData] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [selectedIndex, setSelectedIndex] = useState(-1);
    const containerRef = useRef(null);
    const isOpen = selectedIndex >= 0;

    // Load gallery data from config
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
        setSelectedIndex(function(i) { return i > 0 ? i - 1 : galleryData.items.length - 1; });
    }, [galleryData]);

    const goNext = useCallback(() => {
        setSelectedIndex(function(i) { return i < galleryData.items.length - 1 ? i + 1 : 0; });
    }, [galleryData]);

    // Keyboard navigation
    useEffect(() => {
        if (!isOpen) return;
        function handleKey(e) {
            if (e.key === 'Escape') closeLightbox();
            else if (e.key === 'ArrowLeft') goPrev();
            else if (e.key === 'ArrowRight') goNext();
        }
        window.addEventListener('keydown', handleKey);
        return () => window.removeEventListener('keydown', handleKey);
    }, [isOpen, closeLightbox, goPrev, goNext]);

    // Lock body scroll when lightbox open
    useEffect(() => {
        document.body.style.overflow = isOpen ? 'hidden' : '';
        return () => { document.body.style.overflow = ''; };
    }, [isOpen]);

    // Preload adjacent images when lightbox opens or navigates
    useEffect(() => {
        if (!galleryData || selectedIndex < 0) return;
        var photos = galleryData.items.map(mapToLightboxPhoto);
        PhotoLB.preloadAdjacent(photos, selectedIndex);
    }, [galleryData, selectedIndex]);

    if (loading) {
        return <div className="loading">Loading gallery...</div>;
    }

    if (error) {
        return <div className="error">Error loading gallery: {error}</div>;
    }

    if (!galleryData || !galleryData.items.length) {
        return <div className="error">No images found in gallery</div>;
    }

    var lightboxPhotos = galleryData.items.map(mapToLightboxPhoto);

    return (
        <div className="gallery-container" ref={containerRef}>
            <div className="gallery-title">{galleryData.galleryName}</div>

            <div className="masonry-grid">
                {galleryData.items.map((item, index) => (
                    <div
                        key={index}
                        className="gallery-item"
                        onClick={() => handleImageClick(index)}
                        role="button"
                        tabIndex={0}
                        aria-label={`Zobacz ${item['img.alt']}`}
                        id={item['img.full_image_sanitized']}
                    >
                        <picture>
                            <source type="image/avif"
                                srcSet={(item['img.grid_src.avif'] || '') + ' 560w, ' + (item['img.src.avif'] || '') + ' 1000w'}
                                sizes="(max-width: 400px) 100vw, (max-width: 900px) 50vw, 280px" />
                            <img
                                src={item['img.grid_src'] || item['img.src']}
                                srcSet={(item['img.grid_src'] || '') + ' 560w, ' + (item['img.src'] || '') + ' 1000w'}
                                sizes="(max-width: 400px) 100vw, (max-width: 900px) 50vw, 280px"
                                alt={item['img.alt']}
                                title={item['img.title']}
                                loading="lazy"
                                onError={(e) => {
                                    e.target.src = 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg" width="100" height="100"%3E%3Crect fill="%23ddd" width="100" height="100"/%3E%3Ctext x="50" y="50" text-anchor="middle" dy=".3em" fill="%23999" font-family="sans-serif" font-size="12"%3EImage%3C/text%3E%3C/svg%3E';
                                }}
                            />
                        </picture>
                        <div className="gallery-overlay">
                            <div className="gallery-info">
                                <div className="gallery-info-title">{item['img.title']}</div>
                                <div className="gallery-info-post-title hidden">{item['post.title']}</div>
                                <div className="gallery-info-details">
                                    {item['img.time_display']} • {parseFloat(item['img.lat']).toFixed(2)}°, {parseFloat(item['img.lon']).toFixed(2)}°
                                </div>
                                <div className="gallery-info-exif">{item['img.exif_string']}</div>
                            </div>
                        </div>
                    </div>
                ))}
            </div>

            {isOpen && (
                <PhotoLB.Lightbox
                    photos={lightboxPhotos}
                    index={selectedIndex}
                    onClose={closeLightbox}
                    onPrev={goPrev}
                    onNext={goNext}
                />
            )}
        </div>
    );
}

// Map gallery item to shared lightbox photo contract
function mapToLightboxPhoto(item) {
    var exif = {};
    if (item['img.camera']) exif.camera = item['img.camera'];
    if (item['img.lens']) exif.lens = item['img.lens'];
    if (item['img.focal']) exif.focal = item['img.focal'];
    if (item['img.aperture']) exif.aperture = item['img.aperture'];
    if (item['img.exposure']) exif.exposure = item['img.exposure'];
    if (item['img.iso']) exif.iso = item['img.iso'];
    return {
        grid_src: item['img.grid_src'] || '',
        grid_src_avif: item['img.grid_src.avif'] || '',
        src: item['img.src'],
        src_avif: item['img.src.avif'] || '',
        full_src: item['img.url'],
        full_src_avif: item['img.url.avif'] || '',
        alt: item['img.alt'] || '',
        exif: exif,
        post_url: item['post.url'] || '',
        post_title: item['post.title'] || ''
    };
}

// ==================== RENDER ====================
function init() {
    ReactDOM.render(<GalleryApp />, document.getElementById('root'));
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else {
    init();
}
