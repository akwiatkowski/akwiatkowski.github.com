// Area Show Page - React component for area detail pages
// Transpiled from JSX to JS via esbuild

const { useState, useEffect, useRef } = React;

// ==================== AREA CONFIG ====================
const AREA_CONFIG = JSON.parse(document.getElementById('area-config').textContent);

// ==================== DATA LOADING ====================
// Route colors loaded from /js/self/route_colors.js (generated from data/config/route_colors.yml)

function loadAreaData(areaConfig) {
    var inlineData = JSON.parse(document.getElementById('area-data').textContent);

    var posts = inlineData.posts.sort((a, b) => new Date(b.date) - new Date(a.date));
    var photos = inlineData.photos;
    var relatedAreas = inlineData.related_areas || [];

    // Preserve tag→route association for coloring
    var routes = posts.flatMap(post => {
        var style = window.getRouteStyle(post.tags);
        return (post.coords || []).map(coord => coord.route)
            .filter(route => route && route.length > 0)
            .map(route => ({ points: route, style }));
    });

    var stats = calculateStats(posts, photos);

    return { posts, photos, routes, stats, relatedAreas };
}

function calculateStats(posts, photos) {
    const bicyclePosts = posts.filter(p => p.tags?.includes('bicycle'));
    const hikePosts = posts.filter(p => p.tags?.includes('hike'));

    const bicycleDistance = bicyclePosts.reduce((sum, p) => sum + (p.distace || 0), 0);
    const hikeDistance = hikePosts.reduce((sum, p) => sum + (p.distace || 0), 0);
    const totalTime = posts.reduce((sum, p) => sum + (p.time_spent || 0), 0);

    const dates = posts.map(p => p.date).sort();
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

// ==================== UTILITIES ====================
function formatDate(dateStr) {
    return new Date(dateStr).toLocaleDateString('pl-PL', {
        day: 'numeric',
        month: 'long',
        year: 'numeric'
    });
}

// ==================== SHARED MAP LOGIC ====================
function initLeafletMap(container, area, options = {}) {
    const { bbox } = area;
    const interactive = options.interactive || false;

    const map = L.map(container, {
        center: [(bbox.south + bbox.north) / 2, (bbox.west + bbox.east) / 2],
        zoom: 12,
        minZoom: 6,
        maxZoom: 16,
        zoomControl: interactive,
        dragging: interactive,
        touchZoom: interactive,
        scrollWheelZoom: false,
        doubleClickZoom: interactive,
        boxZoom: interactive,
        keyboard: interactive,
        attributionControl: false
    });

    L.tileLayer('/tiles/ump/{z}/{x}/{y}.png', {
        maxZoom: 16,
    }).addTo(map);

    map.fitBounds([
        [bbox.south, bbox.west],
        [bbox.north, bbox.east]
    ], { padding: [50, 50] });

    (area.routes || []).forEach((route) => {
        var points = route.points || route;
        var style = route.style || window.ROUTE_STYLES.regular;
        if (points && points.length > 0) {
            L.polyline(points, {
                color: style.color,
                weight: style.weight,
                opacity: style.opacity
            }).addTo(map);
        }
    });

    const polygonUrl = `/polygons/${area.areaType}s/${area.slug}.json`;
    fetch(polygonUrl)
        .then(response => {
            if (!response.ok) throw new Error('Polygon not found');
            return response.json();
        })
        .then(geojson => {
            const areaCoords = geojson.geometry.coordinates[0];
            const worldBounds = [
                [-90, -180], [-90, 180], [90, 180], [90, -180], [-90, -180]
            ];
            const areaLatLngs = areaCoords.map(coord => [coord[1], coord[0]]);

            L.polygon([worldBounds, areaLatLngs], {
                color: 'none',
                fillColor: '#000',
                fillOpacity: 0.4,
                interactive: false
            }).addTo(map);

            const polygonLayer = L.geoJSON(geojson, {
                style: {
                    color: '#21808d',
                    weight: 2,
                    fill: false,
                    dashArray: '10, 10',
                    opacity: 0.9
                }
            }).addTo(map);

            map.fitBounds(polygonLayer.getBounds(), { padding: [50, 50] });

            if (options.onReady) options.onReady();
        })
        .catch(() => {
            L.rectangle([
                [bbox.south, bbox.west],
                [bbox.north, bbox.east]
            ], {
                color: '#21808d',
                weight: 2,
                fill: false,
                dashArray: '10, 10'
            }).addTo(map);

            if (options.onReady) options.onReady();
        });

    return map;
}

// ==================== COMPONENTS ====================

function HeroPhotoBg({ url, scrollProgress }) {
    if (!url) return null;

    const opacity = Math.max(0.15, 1 - scrollProgress * 1.5);

    return (
        <div
            className="hero-photo-bg"
            style={{
                backgroundImage: `url(${url})`,
                opacity
            }}
        />
    );
}

function HeroMap({ area, hasPhoto, scrollProgress }) {
    const mapRef = useRef(null);
    const mapInstanceRef = useRef(null);
    const [mapReady, setMapReady] = useState(false);

    useEffect(() => {
        if (mapInstanceRef.current) return;

        const onReady = () => {
            setTimeout(() => setMapReady(true), 600);
        };

        mapInstanceRef.current = initLeafletMap(mapRef.current, area, {
            interactive: false,
            onReady
        });
    }, [area]);

    const fadeOpacity = mapReady ? 1 : 0;
    const scrollOpacity = hasPhoto ? undefined : Math.max(0.15, 1 - scrollProgress * 1.5);

    return (
        <div
            className={`hero-map-container${hasPhoto ? ' has-photo' : ''}`}
            style={hasPhoto ? { opacity: fadeOpacity } : { opacity: mapReady ? scrollOpacity : 0 }}
        >
            <div id="map" ref={mapRef}></div>
        </div>
    );
}

function HeroOverlay({ area, scrollProgress }) {
    const opacity = Math.max(0, 1 - scrollProgress * 2);
    const { stats } = area;

    const yearRange = stats.firstYear && stats.lastYear
        ? (stats.firstYear === stats.lastYear ? `${stats.firstYear}` : `${stats.firstYear}\u2013${stats.lastYear}`)
        : null;

    return (
        <div className="hero-overlay" style={{ opacity }}>
            <div className="hero-content">
                <span className="area-type-badge">{area.areaTypeLabel}</span>
                <h1 className="area-name">{area.name}</h1>
                {yearRange && <div className="area-year-range">{yearRange}</div>}
                <p className="area-parent">
                    {area.parentName && <a href={area.parentUrl}>{area.parentName}</a>}
                    {area.voivodeshipName && (
                        <span>{area.parentName ? ', ' : ''}<a href={area.voivodeshipUrl}>{area.voivodeshipName}</a></span>
                    )}
                </p>
            </div>
        </div>
    );
}

function ScrollHint({ visible }) {
    if (!visible) return null;
    return (
        <div className="scroll-hint">
            <i className="fa fa-chevron-down fa-2x"></i>
        </div>
    );
}

function StatsBar({ stats, postListUrl, galleryUrl }) {
    return (
        <div className="stats-bar">
            <div className="stats-inline">
                <span className="stat-value">{stats.postsCount}</span> wypraw
                <span className="stat-sep">&middot;</span>
                <span className="stat-value">{stats.totalDistance}</span> km
                <span className="stat-sep">&middot;</span>
                <span className="stat-value">{stats.totalTime}</span> h
                <span className="stat-sep">&middot;</span>
                <span className="stat-value">{stats.photosCount}</span> zdjec
            </div>
            <div className="stats-links">
                <a href={postListUrl} className="stats-link-btn">
                    <i className="fa fa-list"></i> Wszystkie wpisy
                </a>
                <a href={galleryUrl} className="stats-link-btn secondary">
                    <i className="fa fa-th"></i> Pelna galeria
                </a>
            </div>
        </div>
    );
}

function MapSection({ area }) {
    const mapRef = useRef(null);
    const mapInstanceRef = useRef(null);

    useEffect(() => {
        if (mapInstanceRef.current) return;

        mapInstanceRef.current = initLeafletMap(mapRef.current, area, {
            interactive: true
        });
    }, [area]);

    return (
        <section className="section map-section">
            <h2 className="section-title">Mapa</h2>
            <div className="map-container" ref={mapRef}></div>
        </section>
    );
}

function PhotosSection({ photos }) {
    const [displayPhotos] = useState(() =>
        [...photos].sort((a, b) => b.points - a.points).slice(0, 16)
    );

    if (photos.length === 0) return null;

    return (
        <section className="photos-section">
            <h2 className="section-title">Najlepsze zdjecia</h2>
            <div className="photos-grid">
                {displayPhotos.map((photo, idx) => (
                    <a key={idx} href={photo.post_url} className="photo-card">
                        <img src={photo.article_url} alt={photo.desc} loading="lazy" />
                        <div className="photo-overlay">
                            <div className="photo-title">{photo.desc || 'Zdjecie'}</div>
                            <div className="photo-date">{formatDate(photo.time)}</div>
                        </div>
                    </a>
                ))}
            </div>
        </section>
    );
}

function PostsSection({ posts }) {
    const [displayPosts] = useState(() => {
        if (posts.length <= 5) return posts;

        // Fuzzy selection preferring latest posts
        // Posts are already sorted by date descending
        const scored = posts.map((post, idx) => {
            // Recency score: latest=1.0, oldest≈0.1
            const recencyScore = 1.0 - (idx / posts.length) * 0.9;
            const randomFactor = 0.8 + Math.random() * 0.4;
            return { post, score: recencyScore * randomFactor };
        });

        scored.sort((a, b) => b.score - a.score);
        // Select top 5, re-sort by date for display
        return scored.slice(0, 5)
            .map(s => s.post)
            .sort((a, b) => new Date(b.date) - new Date(a.date));
    });

    if (posts.length === 0) return null;

    return (
        <section className="section">
            <h2 className="section-title">Wyprawy</h2>
            <div className="posts-list">
                {displayPosts.map(post => (
                    <a key={post.slug} href={post.url} className="post-card-link">
                        <div className="post-card-image-wrap">
                            <img src={post.card_image_url} alt={post.title} className="post-card-image" loading="lazy" />
                        </div>
                        <div className="post-card-content">
                            <div className="post-card-date">{formatDate(post.date)}</div>
                            <h3 className="post-card-title">{post.title}</h3>
                            <div className="post-card-stats">
                                {post.distace > 0 && <span><i className="fa fa-road"></i> {post.distace} km</span>}
                                {post.time_spent > 0 && <span><i className="fa fa-clock-o"></i> {post.time_spent}h</span>}
                            </div>
                        </div>
                    </a>
                ))}
            </div>
        </section>
    );
}

function RelatedAreasSection({ relatedAreas }) {
    if (!relatedAreas || relatedAreas.length === 0) return null;

    return (
        <section className="related-section">
            <h2 className="section-title">Zobacz takze</h2>
            <div className="related-grid">
                {relatedAreas.map((area, idx) => (
                    <a key={idx} href={area.show_url} className="related-card">
                        {area.best_photo_url && (
                            <div
                                className="related-card-bg"
                                style={{ backgroundImage: `url(${area.best_photo_url})` }}
                            />
                        )}
                        <div className="related-card-overlay">
                            <div className="related-card-name">{area.name}</div>
                            <div className="related-card-type">{area.area_type}</div>
                        </div>
                    </a>
                ))}
            </div>
        </section>
    );
}

// ==================== MAIN APP ====================
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

        window.addEventListener('scroll', handleScroll, { passive: true });
        return () => window.removeEventListener('scroll', handleScroll);
    }, []);

    const hasPhoto = !!areaData.bestPhotoUrl;

    return (
        <>
            {hasPhoto && <HeroPhotoBg url={areaData.bestPhotoUrl} scrollProgress={scrollProgress} />}
            <HeroMap area={areaData} hasPhoto={hasPhoto} scrollProgress={scrollProgress} />
            <HeroOverlay area={areaData} scrollProgress={scrollProgress} />
            <ScrollHint visible={scrollProgress < 0.1} />

            <main className="main-content">
                <div className="content-transition"></div>
                <StatsBar
                    stats={areaData.stats}
                    postListUrl={areaData.postListUrl}
                    galleryUrl={areaData.galleryUrl}
                />
                <MapSection area={areaData} />
                <PhotosSection photos={areaData.photos} />
                <PostsSection posts={areaData.posts} />
                <RelatedAreasSection relatedAreas={areaData.relatedAreas} />
            </main>
        </>
    );
}

// ==================== RENDER ====================
function init() {
    ReactDOM.render(<AreaShowPage />, document.getElementById('root'));
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else {
    init();
}
