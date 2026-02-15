// Towns Index Page - Preact component for interactive town listing
// Transpiled from JSX to JS via esbuild

const { useState, useMemo } = React;

// ==================== COMPONENTS ====================

function SearchBar({ query, onChange, totalCount }) {
    return (
        <div className="towns-search-wrap">
            <input
                type="text"
                className="towns-search"
                placeholder="Szukaj gminy..."
                value={query}
                onInput={(e) => onChange(e.target.value)}
            />
            <div className="towns-search-count">
                {totalCount} {totalCount === 1 ? 'gmina' : 'gmin'}
            </div>
        </div>
    );
}

function TownCard({ town }) {
    var years = town.first_year === town.last_year
        ? String(town.first_year)
        : town.first_year + '\u2013' + town.last_year;
    var bgUrl = (window.__avif && town.photo_url_avif) ? town.photo_url_avif : town.photo_url;

    return (
        <a href={town.show_url} className="town-card" title={town.name}>
            {bgUrl ? (
                <div className="town-card-bg" style={{ backgroundImage: 'url(' + bgUrl + ')' }}></div>
            ) : (
                <div className="town-card-bg town-card-nophoto">
                    <i className="fa fa-map-marker fa-2x"></i>
                </div>
            )}
            {town.post_count > 1 && (
                <span className="town-card-badge">{town.post_count}</span>
            )}
            <div className="town-card-overlay">
                <div className="town-card-name">{town.name}</div>
                <div className="town-card-meta">{years}</div>
            </div>
        </a>
    );
}

function VoivodeshipGroup({ group }) {
    return (
        <div className="voivodeship-group" data-voivodeship={group.slug}>
            <div className="voivodeship-header">
                <a href={group.show_url} className="voivodeship-name">{group.name}</a>
                <span className="voivodeship-count">{group.towns.length}</span>
            </div>
            <div className="towns-grid">
                {group.towns.map(function(town) {
                    return <TownCard key={town.slug} town={town} />;
                })}
            </div>
        </div>
    );
}

function TownsIndexApp({ data }) {
    var [query, setQuery] = useState('');

    var filtered = useMemo(function() {
        if (!query) return data.towns;
        var q = query.toLowerCase();
        return data.towns.filter(function(t) {
            return t.name.toLowerCase().indexOf(q) !== -1;
        });
    }, [query, data.towns]);

    var groups = useMemo(function() {
        return data.voivodeships
            .map(function(v) {
                var towns = filtered.filter(function(t) { return t.voivodeship === v.slug; });
                return { name: v.name, slug: v.slug, show_url: v.show_url, towns: towns };
            })
            .filter(function(g) { return g.towns.length > 0; });
    }, [filtered, data.voivodeships]);

    return (
        <div>
            <SearchBar query={query} onChange={setQuery} totalCount={filtered.length} />
            <div className="towns-container">
                {groups.length > 0 ? (
                    groups.map(function(g) {
                        return <VoivodeshipGroup key={g.slug} group={g} />;
                    })
                ) : (
                    <div className="towns-no-results">
                        Brak wynikow dla "{query}"
                    </div>
                )}
            </div>
        </div>
    );
}

// ==================== INIT ====================
function _initTownsIndex(data) {
    ReactDOM.render(<TownsIndexApp data={data} />, document.getElementById('towns-app'));
}

window.TownsIndex = { init: _initTownsIndex };
