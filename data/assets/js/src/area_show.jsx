// Area Show Page - React component for area detail pages
// Transpiled from JSX to JS via esbuild

const { useState, useEffect, useRef } = React;

// ==================== AREA CONFIG ====================
// Loaded from JSON config block in the template
const AREA_CONFIG = JSON.parse(document.getElementById('area-config').textContent);

// ==================== DATA LOADING ====================
function loadAreaData(areaConfig) {
    // Read pre-filtered data from inline JSON (generated at build time)
    // To switch to fetch: replace with fetch('/jsons/areas/' + areaConfig.slug + '.json').then(r => r.json())
    var inlineData = JSON.parse(document.getElementById('area-data').textContent);

    var posts = inlineData.posts.sort((a, b) => new Date(b.date) - new Date(a.date));
    var photos = inlineData.photos;

    // Extract routes from posts
    var routes = posts.flatMap(post =>
        (post.coords || []).map(coord => coord.route)
    ).filter(route => route && route.length > 0);

    var stats = calculateStats(posts, photos);

    return { posts, photos, routes, stats };
}

function calculateStats(posts, photos) {
    const bicyclePosts = posts.filter(p => p.tags?.includes('bicycle'));
    const hikePosts = posts.filter(p => p.tags?.includes('hike'));

    const bicycleDistance = bicyclePosts.reduce((sum, p) => sum + (p.distace || 0), 0);
    const hikeDistance = hikePosts.reduce((sum, p) => sum + (p.distace || 0), 0);
    const totalTime = posts.reduce((sum, p) => sum + (p.time_spent || 0), 0);

    const dates = posts.map(p => p.date).sort();

    return {
        totalDistance: Math.round(bicycleDistance + hikeDistance),
        bicycleDistance: Math.round(bicycleDistance),
        hikeDistance: Math.round(hikeDistance),
        totalTime: Math.round(totalTime),
        postsCount: posts.length,
        photosCount: photos.length,
        firstVisit: dates[0] || null,
        lastVisit: dates[dates.length - 1] || null
    };
}

// ==================== UTILITIES ====================
function shuffleArray(array) {
    const shuffled = [...array];
    for (let i = shuffled.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
    }
    return shuffled;
}

function formatDate(dateStr) {
    return new Date(dateStr).toLocaleDateString('pl-PL', {
        day: 'numeric',
        month: 'long',
        year: 'numeric'
    });
}

// ==================== COMPONENTS ====================

function HeroMap({ area, scrollProgress }) {
    const mapRef = useRef(null);
    const mapInstanceRef = useRef(null);
    const [polygonLoaded, setPolygonLoaded] = useState(false);

    useEffect(() => {
        if (mapInstanceRef.current) return;

        const { bbox } = area;
        const center = [(bbox.south + bbox.north) / 2, (bbox.west + bbox.east) / 2];

        const map = L.map(mapRef.current, {
            center: center,
            zoom: 12,
            zoomControl: false,
            dragging: false,
            touchZoom: false,
            scrollWheelZoom: false,
            doubleClickZoom: false,
            boxZoom: false,
            keyboard: false,
            attributionControl: false
        });

        // Local tiles
        L.tileLayer('/tiles/ump/{z}/{x}/{y}.png', {
            maxZoom: 19,
        }).addTo(map);

        // Fit to bbox initially
        map.fitBounds([
            [bbox.south, bbox.west],
            [bbox.north, bbox.east]
        ], { padding: [50, 50] });

        // Draw routes with teal color scheme
        // Routes come as arrays of [lat, lng] from payload.json coords
        const routeColors = ['#32b8c6', '#21808d', '#1a7480'];
        (area.routes || []).forEach((route, idx) => {
            if (route && route.length > 0) {
                L.polyline(route, {
                    color: routeColors[idx % routeColors.length],
                    weight: 4,
                    opacity: 0.9
                }).addTo(map);
            }
        });

        // Try to load polygon, fall back to bbox rectangle
        const polygonUrl = `/polygons/${area.areaType}s/${area.slug}.json`;
        fetch(polygonUrl)
            .then(response => {
                if (!response.ok) throw new Error('Polygon not found');
                return response.json();
            })
            .then(geojson => {
                // Get the polygon coordinates
                const areaCoords = geojson.geometry.coordinates[0];

                // Create inverted polygon mask: world bounds with area cut out
                const worldBounds = [
                    [-90, -180],
                    [-90, 180],
                    [90, 180],
                    [90, -180],
                    [-90, -180]
                ];

                // Note: Leaflet expects [lat, lng], GeoJSON uses [lng, lat]
                const areaLatLngs = areaCoords.map(coord => [coord[1], coord[0]]);

                // Add gray mask outside the area
                L.polygon([worldBounds, areaLatLngs], {
                    color: 'none',
                    fillColor: '#000',
                    fillOpacity: 0.4,
                    interactive: false
                }).addTo(map);

                // Draw polygon outline on top
                const polygonLayer = L.geoJSON(geojson, {
                    style: {
                        color: '#21808d',
                        weight: 2,
                        fill: false,
                        dashArray: '10, 10',
                        opacity: 0.9
                    }
                }).addTo(map);

                // Fit map to polygon bounds
                map.fitBounds(polygonLayer.getBounds(), { padding: [50, 50] });
                setPolygonLoaded(true);
            })
            .catch(err => {
                // Fallback: draw bbox rectangle
                L.rectangle([
                    [bbox.south, bbox.west],
                    [bbox.north, bbox.east]
                ], {
                    color: '#21808d',
                    weight: 2,
                    fill: false,
                    dashArray: '10, 10'
                }).addTo(map);
            });

        mapInstanceRef.current = map;
    }, [area]);

    const opacity = Math.max(0.15, 1 - scrollProgress * 1.5);

    return (
        <div className="hero-map-container" style={{ opacity }}>
            <div id="map" ref={mapRef}></div>
        </div>
    );
}

function HeroOverlay({ area, scrollProgress }) {
    const opacity = Math.max(0, 1 - scrollProgress * 2);

    return (
        <div className="hero-overlay" style={{ opacity }}>
            <div className="hero-content">
                <span className="area-type-badge">{area.areaTypeLabel}</span>
                <h1 className="area-name">{area.name}</h1>
                <p className="area-parent">
                    <a href={area.parentUrl}>{area.parentName}</a>
                    {area.voivodeshipName && (
                        <span>, <a href={area.voivodeshipUrl}>{area.voivodeshipName}</a></span>
                    )}
                </p>

                <div className="hero-stats-preview">
                    <div className="hero-stat">
                        <div className="hero-stat-value">{area.stats.totalDistance}</div>
                        <div className="hero-stat-label">kilometrow</div>
                    </div>
                    <div className="hero-stat">
                        <div className="hero-stat-value">{area.stats.postsCount}</div>
                        <div className="hero-stat-label">wypraw</div>
                    </div>
                    <div className="hero-stat">
                        <div className="hero-stat-value">{area.stats.photosCount}</div>
                        <div className="hero-stat-label">zdjec</div>
                    </div>
                </div>
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

function StatsSection({ stats }) {
    return (
        <section className="section">
            <h2 className="section-title">W liczbach</h2>

            <div className="stats-grid">
                <div className="stat-card">
                    <div className="stat-icon">
                        <i className="fa fa-road"></i>
                    </div>
                    <div className="stat-value">{stats.totalDistance}</div>
                    <div className="stat-label">Kilometrow</div>
                    <div className="stat-breakdown">
                        <i className="fa fa-bicycle"></i> {stats.bicycleDistance} km rowerem<br/>
                        <i className="fa fa-male"></i> {stats.hikeDistance} km pieszo
                    </div>
                </div>

                <div className="stat-card">
                    <div className="stat-icon">
                        <i className="fa fa-clock-o"></i>
                    </div>
                    <div className="stat-value">{stats.totalTime}</div>
                    <div className="stat-label">Godzin w terenie</div>
                </div>

                <div className="stat-card">
                    <div className="stat-icon">
                        <i className="fa fa-map-marker"></i>
                    </div>
                    <div className="stat-value">{stats.postsCount}</div>
                    <div className="stat-label">Wypraw</div>
                    {stats.firstVisit && stats.lastVisit && (
                        <div className="stat-breakdown">
                            Pierwsza: {formatDate(stats.firstVisit)}<br/>
                            Ostatnia: {formatDate(stats.lastVisit)}
                        </div>
                    )}
                </div>

                <div className="stat-card">
                    <div className="stat-icon">
                        <i className="fa fa-camera"></i>
                    </div>
                    <div className="stat-value">{stats.photosCount}</div>
                    <div className="stat-label">Zdjec</div>
                </div>
            </div>

            <div className="nav-links">
                <a href="#" className="nav-link-btn">
                    <i className="fa fa-list"></i> Wszystkie wpisy
                </a>
                <a href="#" className="nav-link-btn secondary">
                    <i className="fa fa-th"></i> Pelna galeria
                </a>
            </div>
        </section>
    );
}

function PhotosSection({ photos }) {
    const [shuffledPhotos] = useState(() => shuffleArray(photos).slice(0, 12));

    if (photos.length === 0) {
        return null;
    }

    return (
        <section className="photos-section">
            <h2 className="section-title">Najlepsze zdjecia</h2>

            <div className="photos-grid">
                {shuffledPhotos.map((photo, idx) => (
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
    if (posts.length === 0) {
        return null;
    }

    return (
        <section className="section">
            <h2 className="section-title">Ostatnie wyprawy</h2>

            <div className="posts-scroll-container">
                <div className="posts-row">
                    {posts.map(post => (
                        <a key={post.slug} href={post.url} className="post-card-link">
                            <img src={post.card_image_url} alt={post.title} className="post-card-image" />
                            <div className="post-card-content">
                                <div className="post-card-date">{formatDate(post.date)}</div>
                                <h3 className="post-card-title">{post.title}</h3>
                                <div className="post-card-stats">
                                    <span><i className="fa fa-bicycle"></i> {post.distace || 0} km</span>
                                    <span><i className="fa fa-clock-o"></i> {post.time_spent || 0}h</span>
                                </div>
                            </div>
                        </a>
                    ))}
                </div>
            </div>
        </section>
    );
}

function AreaFooter({ area }) {
    return (
        <footer className="area-footer">
            <div className="related-areas">
                <div className="related-areas-title">Zobacz takze</div>
                <div className="related-areas-list">
                    <a href={area.parentUrl} className="related-area-link">
                        <i className="fa fa-map-o"></i> {area.parentName}
                    </a>
                    {area.voivodeshipName && (
                        <a href={area.voivodeshipUrl} className="related-area-link">
                            <i className="fa fa-globe"></i> {area.voivodeshipName}
                        </a>
                    )}
                </div>
            </div>
        </footer>
    );
}

// ==================== MAIN APP ====================
function AreaShowPage() {
    const [scrollProgress, setScrollProgress] = useState(0);
    const [areaData] = useState(() => {
        var data = loadAreaData(AREA_CONFIG);
        return { ...AREA_CONFIG, ...data };
    });

    // Handle scroll
    useEffect(() => {
        const handleScroll = () => {
            const windowHeight = window.innerHeight;
            const progress = Math.min(1, window.scrollY / windowHeight);
            setScrollProgress(progress);
        };

        window.addEventListener('scroll', handleScroll, { passive: true });
        return () => window.removeEventListener('scroll', handleScroll);
    }, []);

    return (
        <>
            <HeroMap area={areaData} scrollProgress={scrollProgress} />
            <HeroOverlay area={areaData} scrollProgress={scrollProgress} />
            <ScrollHint visible={scrollProgress < 0.1} />

            <main className="main-content">
                <div className="content-transition"></div>
                <StatsSection stats={areaData.stats} />
                <PhotosSection photos={areaData.photos} />
                <PostsSection posts={areaData.posts} />
                <AreaFooter area={areaData} />
            </main>
        </>
    );
}

// ==================== RENDER ====================
function init() {
    // Using React 17 API for Preact compatibility
    ReactDOM.render(<AreaShowPage />, document.getElementById('root'));
}

// Wait for DOM to be ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else {
    init();
}
