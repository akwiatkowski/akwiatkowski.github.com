// Portfolio Page - Preact components
// Hero, Bio, Masonry grid with ambilight, Lightbox with EXIF

const { useState, useEffect, useRef, useCallback } = React;

// ==================== LAZY IMAGE ====================

function LazyImage({ src, alt, onLoad, className }) {
    var imgRef = useRef(null);
    var [loaded, setLoaded] = useState(false);

    useEffect(function() {
        var img = imgRef.current;
        if (!img) return;

        var observer = new IntersectionObserver(function(entries) {
            entries.forEach(function(entry) {
                if (entry.isIntersecting) {
                    img.src = img.dataset.src;
                    observer.unobserve(img);
                }
            });
        }, { rootMargin: '300px' });

        observer.observe(img);
        return function() { observer.disconnect(); };
    }, []);

    function handleLoad() {
        setLoaded(true);
        if (onLoad) onLoad();
    }

    return (
        <img
            ref={imgRef}
            data-src={src}
            alt={alt}
            className={(className || '') + (loaded ? ' visible' : '')}
            onLoad={handleLoad}
        />
    );
}

// ==================== HERO ====================

function Hero({ photo }) {
    var style = photo ? { backgroundImage: 'url(' + photo.src + ')' } : {};
    return (
        <section className="portfolio-hero">
            <div className="portfolio-hero-bg" style={style}></div>
            <div className="portfolio-hero-overlay">
                <h1 className="portfolio-hero-name">Aleksander Kwiatkowski</h1>
                <p className="portfolio-hero-tagline">
                    Rowerem i pieszo przez Polsk&#281;
                </p>
            </div>
            <div className="portfolio-scroll-hint" onClick={function() {
                var bio = document.querySelector('.portfolio-bio');
                if (bio) bio.scrollIntoView({ behavior: 'smooth' });
            }}>&#8964;</div>
        </section>
    );
}

// ==================== BIO ====================

function Bio({ stats }) {
    return (
        <section className="portfolio-bio">
            <p>
                Od <span className="stat-value">{stats.years_active}</span> dokumentuj&#281;
                polsk&#261; wie&#347; i krajobraz.{' '}
                <span className="stat-value">{stats.bicycle_distance_km.toLocaleString()}km</span> na rowerze,{' '}
                <span className="stat-value">{stats.hike_distance_km.toLocaleString()}km</span> pieszo,{' '}
                <span className="stat-value">{stats.total_hours}h</span> w terenie.{' '}
                <span className="stat-value">{stats.photo_count.toLocaleString()}</span> zdj&#281;&#263;{' '}
                z <span className="stat-value">{stats.post_count}</span> wypraw{' '}
                przez <span className="stat-value">{stats.towns_visited}</span> gmin.
            </p>
        </section>
    );
}

// ==================== MASONRY GRID ====================

function MasonryGrid({ photos, onPhotoClick }) {
    return (
        <div className="portfolio-grid">
            {photos.map(function(photo, i) {
                return (
                    <GridItem key={i} photo={photo} index={i} onClick={onPhotoClick} />
                );
            })}
        </div>
    );
}

function GridItem({ photo, index, onClick }) {
    var [itemLoaded, setItemLoaded] = useState(false);
    var style = { '--photo-url': 'url(' + photo.src + ')' };

    return (
        <div
            className={'portfolio-grid-item' + (itemLoaded ? ' loaded' : '')}
            style={style}
            onClick={function() { onClick(index); }}
        >
            <LazyImage
                src={photo.src}
                alt={photo.alt}
                onLoad={function() { setItemLoaded(true); }}
            />
        </div>
    );
}

// ==================== APP ====================

function PortfolioApp({ data }) {
    var PhotoLB = window.PhotoLightbox;
    var [lightboxIndex, setLightboxIndex] = useState(-1);
    var isOpen = lightboxIndex >= 0;

    // Preload all full-res images once on mount
    useEffect(function() {
        PhotoLB.preloadImages(data.photos);
    }, []);

    var goPrev = useCallback(function() {
        setLightboxIndex(function(i) { return i > 0 ? i - 1 : data.photos.length - 1; });
    }, [data.photos.length]);

    var goNext = useCallback(function() {
        setLightboxIndex(function(i) { return i < data.photos.length - 1 ? i + 1 : 0; });
    }, [data.photos.length]);

    var closeLightbox = useCallback(function() {
        setLightboxIndex(-1);
    }, []);

    // Keyboard navigation
    useEffect(function() {
        if (!isOpen) return;
        function handleKey(e) {
            if (e.key === 'Escape') closeLightbox();
            else if (e.key === 'ArrowLeft') goPrev();
            else if (e.key === 'ArrowRight') goNext();
        }
        window.addEventListener('keydown', handleKey);
        return function() { window.removeEventListener('keydown', handleKey); };
    }, [isOpen, closeLightbox, goPrev, goNext]);

    // Lock body scroll when lightbox open
    useEffect(function() {
        document.body.style.overflow = isOpen ? 'hidden' : '';
        return function() { document.body.style.overflow = ''; };
    }, [isOpen]);

    return (
        <React.Fragment>
            <Hero photo={data.hero_photo} />
            <Bio stats={data.stats} />
            <MasonryGrid photos={data.photos} onPhotoClick={setLightboxIndex} />
            {isOpen && (
                <PhotoLB.Lightbox
                    photos={data.photos}
                    index={lightboxIndex}
                    onClose={closeLightbox}
                    onPrev={goPrev}
                    onNext={goNext}
                />
            )}
        </React.Fragment>
    );
}

// ==================== INIT ====================

function _initPortfolio() {
    var el = document.getElementById('portfolio-data');
    if (!el) return;
    var data = JSON.parse(el.textContent);
    ReactDOM.render(<PortfolioApp data={data} />, document.getElementById('portfolio-root'));
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', _initPortfolio);
} else {
    _initPortfolio();
}
