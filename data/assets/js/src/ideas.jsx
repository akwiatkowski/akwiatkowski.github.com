// Trip Ideas Planner - Preact component for bicycle trip planning
// Transpiled from JSX to JS via esbuild

const { useState, useEffect, useMemo } = React;

const getTownBySlug = (slug, towns) => {
    if (!slug || !towns) return null;
    return towns.find(t => t.slug === slug.toLowerCase()) || null;
};

const surfaceLabel = (s) => s === 'road' ? 'Szosa' : s === 'gravel' ? 'Gravel' : s === 'mtb' ? 'MTB' : s;
const surfaceIcon = (s) => s === 'road' ? '🛣️' : s === 'gravel' ? '🚵' : s === 'mtb' ? '🚵‍♂️' : '';

const trainClass = (avg) =>
    avg < 1.5 ? 'train-easy' : avg < 2.8 ? 'train-medium' : avg < 3.8 ? 'train-hard' : 'train-epic';

// Map Modal
const MapModal = ({ show, onHide, trip }) => {
    if (!show || !trip) return null;
    return (
        <>
            <div className="modal-backdrop" onClick={onHide} />
            <div className="modal-overlay">
                <div className="modal-box">
                    <div className="modal-head">
                        <span className="modal-title">{trip.start.name} → {trip.end.name}</span>
                        <button className="modal-close" onClick={onHide}>×</button>
                    </div>
                    <div className="modal-body">
                        <object data={trip.photo_map_url} />
                    </div>
                </div>
            </div>
        </>
    );
};

// Trip Card
const TripCard = ({ trip, onMapClick, towns }) => {
    const avg = (trip.start.time_distance + trip.end.time_distance) / 2;
    const tc = trainClass(avg);

    const townObjects = trip.towns.map(slug => {
        const t = getTownBySlug(slug, towns);
        return t || { slug, name: slug, url: null };
    });

    const days = trip.days_min === trip.days_normal
        ? `${trip.days_normal} dni`
        : `${trip.days_min}–${trip.days_normal} dni`;

    const stats = trip.time_cost_stats_for_new_town;

    return (
        <div className="card">
            <div className="card-head">
                <div className="card-route">{trip.start.name} → {trip.end.name}</div>
                <div className="card-meta">
                    <span>{trip.distance} km</span>
                    <span>{days}</span>
                    {trip.elevation && <span>↑{trip.elevation}m</span>}
                </div>
            </div>
            <div className="card-body">
                <div className="card-row">
                    {trip.surfaces.map((s, i) => (
                        <span key={i} className={`tag surface-${s}`}>{surfaceIcon(s)} {surfaceLabel(s)}</span>
                    ))}
                </div>

                <div className="card-row">
                    <span className={`tag ${tc}`}>🚂 {trip.start.name}: {trip.start.time_distance}h</span>
                    <span className={`tag ${tc}`}>🚂 {trip.end.name}: {trip.end.time_distance}h</span>
                </div>

                <div className="card-section">
                    <div className="card-label">Gminy ({trip.towns.length})</div>
                    <div className="towns">
                        {townObjects.map((t, i) => (
                            t.url
                                ? <a key={i} href={t.url} className="town visited">{t.name}</a>
                                : <span key={i} className="town">{t.name}</span>
                        ))}
                    </div>
                </div>

                <div className="cost-box">
                    <div className="cost-header">
                        Niezaliczonych: <strong>{trip.towns_not_visited}</strong> gmin
                        <span className="cost-direction">{trip.direction_char}</span>
                    </div>
                    <div className="cost-row">
                        <div className="cost-cell">
                            <span className="cost-num">{stats.time_cost_riding}h</span>
                            <span className="cost-desc">jazdy/gminę</span>
                        </div>
                        <div className="cost-cell">
                            <span className="cost-num">{stats.time_cost_riding_and_train}h</span>
                            <span className="cost-desc">z dojazdem</span>
                        </div>
                        <div className="cost-cell">
                            <span className="cost-num">{stats.time_cost_with_sleeping}h</span>
                            <span className="cost-desc">z noclegiem</span>
                        </div>
                    </div>
                </div>

                <div className="card-actions">
                    <a className="btn-ext" href={trip.link} target="_blank" rel="noopener noreferrer">
                        🗺️ Mapa zewnętrzna
                    </a>
                    {trip.photo_map_url && (
                        <button className="btn-map" onClick={() => onMapClick(trip)}>
                            📸 Mapa zdjęć
                        </button>
                    )}
                </div>
            </div>
        </div>
    );
};

// Filters
const Filters = ({ filters, onChange, surfaces, directions }) => {
    const DurationCheck = ({ val, label }) => (
        <label className="check">
            <input type="checkbox" checked={filters.duration.includes(val)}
                onChange={e => onChange('duration', e.target.checked
                    ? [...filters.duration, val]
                    : filters.duration.filter(d => d !== val))} />
            {label}
        </label>
    );

    return (
        <div className="filters">
            <div className="filter-group">
                <div className="filter-label">Szukaj</div>
                <input type="text" className="filter-input" placeholder="Gmina..."
                    value={filters.searchText}
                    onChange={e => onChange('searchText', e.target.value)} />
            </div>

            <div className="filter-group">
                <div className="filter-label">Dystans: {filters.distanceRange[0]}–{filters.distanceRange[1]} km</div>
                <input type="range" min="50" max="300" step="10"
                    value={filters.distanceRange[0]}
                    onChange={e => onChange('distanceRange', [parseInt(e.target.value), filters.distanceRange[1]])} />
                <input type="range" min="50" max="300" step="10"
                    value={filters.distanceRange[1]}
                    onChange={e => onChange('distanceRange', [filters.distanceRange[0], parseInt(e.target.value)])} />
            </div>

            <div className="filter-group">
                <div className="filter-label">Kierunek</div>
                <select className="filter-select" value={filters.direction}
                    onChange={e => onChange('direction', e.target.value)}>
                    <option value="">Wszystkie</option>
                    {directions.map(d => <option key={d} value={d}>{d}</option>)}
                </select>
            </div>

            <div className="filter-group">
                <div className="filter-label">Min. niezaliczonych: {filters.notVisited}</div>
                <input type="range" min="0" max="10" step="1"
                    value={filters.notVisited}
                    onChange={e => onChange('notVisited', parseInt(e.target.value))} />
            </div>

            <div className="filter-group">
                <div className="filter-label">Czas trwania</div>
                <div className="checks">
                    <DurationCheck val="1" label="1 dzień" />
                    <DurationCheck val="2" label="2 dni" />
                    <DurationCheck val="3" label="3 dni" />
                    <DurationCheck val="4" label="4 dni" />
                    <DurationCheck val="5+" label="5+ dni" />
                </div>
            </div>

            <div className="filter-group">
                <div className="filter-label">Nawierzchnia</div>
                <div className="filter-btns">
                    {surfaces.map(s => (
                        <button key={s}
                            className={`filter-btn ${filters.surface.includes(s) ? 'active' : ''}`}
                            onClick={() => onChange('surface', filters.surface.includes(s)
                                ? filters.surface.filter(x => x !== s)
                                : [...filters.surface, s])}>
                            {surfaceIcon(s)} {surfaceLabel(s)}
                        </button>
                    ))}
                </div>
            </div>

            <div className="filter-group">
                <div className="filter-label">Dojazd pociągiem</div>
                <select className="filter-select" value={filters.trainAccessibility}
                    onChange={e => onChange('trainAccessibility', e.target.value)}>
                    <option value="all">Wszystkie</option>
                    <option value="easy">Szybki (&lt;2h)</option>
                    <option value="medium">Średni (&lt;4h)</option>
                    <option value="hard">Ciężki (&lt;6h)</option>
                    <option value="epic">Grube (&lt;8h)</option>
                </select>
            </div>

            <button className="filter-reset" onClick={() => onChange('reset', null)}>
                Resetuj filtry
            </button>
        </div>
    );
};

// App
const App = () => {
    const [trips, setTrips] = useState([]);
    const [towns, setTowns] = useState([]);
    const [loading, setLoading] = useState(true);
    const [mapTrip, setMapTrip] = useState(null);
    const [filters, setFilters] = useState({
        searchText: '', distanceRange: [50, 300], notVisited: 0,
        direction: '', duration: [], surface: [], trainAccessibility: 'all'
    });

    useEffect(() => {
        fetch('/jsons/ideas.json').then(r => r.json()).then(data => {
            const ideas = data.ideas || data;
            const mapped = (Array.isArray(ideas) ? ideas : []).map(t => ({
                ...t, days_min: t.days_min || t.lindays_mink,
                end: t.end || t.finish, direction: t.direction_char
            }));
            setTrips(mapped);
            setTowns(data.towns || []);
        }).catch(() => { setTrips([]); setTowns([]); }).finally(() => setLoading(false));
    }, []);

    const surfaces = useMemo(() => {
        const s = new Set();
        trips.forEach(t => (t.surfaces || []).forEach(x => s.add(x)));
        return Array.from(s).sort();
    }, [trips]);

    const directions = useMemo(() => {
        return Array.from(new Set(trips.map(t => t.direction))).sort();
    }, [trips]);

    const filtered = useMemo(() => trips.filter(t => {
        if (filters.direction && t.direction !== filters.direction) return false;
        if (t.distance < filters.distanceRange[0] || t.distance > filters.distanceRange[1]) return false;
        if (t.towns_not_visited < filters.notVisited) return false;
        if (filters.duration.length > 0) {
            const d = t.days_normal;
            if (!filters.duration.some(v =>
                (v === '5+' && d > 4) || (v !== '5+' && d == parseInt(v))
            )) return false;
        }
        if (filters.surface.length > 0 && !t.surfaces.some(s => filters.surface.includes(s))) return false;
        if (filters.searchText) {
            const q = filters.searchText.toLowerCase();
            if (![t.start.name, t.end.name, t.slug, ...t.towns].join(' ').toLowerCase().includes(q)) return false;
        }
        if (filters.trainAccessibility !== 'all') {
            const avg = (t.start.time_distance + t.end.time_distance) / 2;
            const limits = { easy: 2, medium: 4, hard: 6, epic: 8 };
            if (avg > limits[filters.trainAccessibility]) return false;
        }
        return true;
    }), [trips, filters]);

    const handleFilter = (key, val) => {
        if (key === 'reset') {
            setFilters({
                searchText: '', distanceRange: [50, 300], notVisited: 0,
                direction: '', duration: [], surface: [], trainAccessibility: 'all'
            });
        } else {
            setFilters(prev => ({ ...prev, [key]: val }));
        }
    };

    return (
        <>
            <div className="ideas-page">
                <header className="ideas-hero">
                    <h1>Pomysły na trasy</h1>
                    <p>{loading ? 'Ładowanie...' : `${filtered.length} ${filtered.length === 1 ? 'trasa' : 'tras'}`}</p>
                </header>
                <div className="ideas-grid">
                    <aside className="ideas-aside">
                        <Filters filters={filters} onChange={handleFilter}
                            surfaces={surfaces} directions={directions} />
                    </aside>
                    <main className="ideas-main">
                        {loading ? (
                            <div className="ideas-loading">Ładowanie...</div>
                        ) : filtered.length === 0 ? (
                            <div className="ideas-empty">
                                <div className="ideas-empty-icon">🚫</div>
                                <h3>Brak pomysłów na wycieczkę</h3>
                                <p>Zmień filtry aby zobaczyć jakieś pomysły</p>
                            </div>
                        ) : (
                            <div className="cards">
                                {filtered.map((t, i) => (
                                    <TripCard key={t.slug || i} trip={t} onMapClick={setMapTrip} towns={towns} />
                                ))}
                            </div>
                        )}
                    </main>
                </div>
            </div>
            <MapModal show={!!mapTrip} onHide={() => setMapTrip(null)} trip={mapTrip} />
        </>
    );
};

function init() {
    ReactDOM.render(<App />, document.getElementById('root'));
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else {
    init();
}
