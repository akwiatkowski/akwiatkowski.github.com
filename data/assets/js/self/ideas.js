const { useState, useEffect, useMemo } = React;
const getTownBySlug = (slug, towns) => {
  if (!slug || !towns)
    return null;
  return towns.find((t) => t.slug === slug.toLowerCase()) || null;
};
const surfaceLabel = (s) => s === "road" ? "Szosa" : s === "gravel" ? "Gravel" : s === "mtb" ? "MTB" : s;
const surfaceIcon = (s) => s === "road" ? "\u{1F6E3}\uFE0F" : s === "gravel" ? "\u{1F6B5}" : s === "mtb" ? "\u{1F6B5}\u200D\u2642\uFE0F" : "";
const trainClass = (avg) => avg < 1.5 ? "train-easy" : avg < 2.8 ? "train-medium" : avg < 3.8 ? "train-hard" : "train-epic";
const MapModal = ({ show, onHide, trip }) => {
  if (!show || !trip)
    return null;
  return /* @__PURE__ */ React.createElement(React.Fragment, null, /* @__PURE__ */ React.createElement("div", { className: "modal-backdrop", onClick: onHide }), /* @__PURE__ */ React.createElement("div", { className: "modal-overlay" }, /* @__PURE__ */ React.createElement("div", { className: "modal-box" }, /* @__PURE__ */ React.createElement("div", { className: "modal-head" }, /* @__PURE__ */ React.createElement("span", { className: "modal-title" }, trip.start.name, " \u2192 ", trip.end.name), /* @__PURE__ */ React.createElement("button", { className: "modal-close", onClick: onHide }, "\xD7")), /* @__PURE__ */ React.createElement("div", { className: "modal-body" }, /* @__PURE__ */ React.createElement("object", { data: trip.photo_map_url })))));
};
const TripCard = ({ trip, onMapClick, towns }) => {
  const avg = (trip.start.time_distance + trip.end.time_distance) / 2;
  const tc = trainClass(avg);
  const townObjects = trip.towns.map((slug) => {
    const t = getTownBySlug(slug, towns);
    return t || { slug, name: slug, url: null };
  });
  const days = trip.days_min === trip.days_normal ? `${trip.days_normal} dni` : `${trip.days_min}\u2013${trip.days_normal} dni`;
  const stats = trip.time_cost_stats_for_new_town;
  return /* @__PURE__ */ React.createElement("div", { className: "card" }, /* @__PURE__ */ React.createElement("div", { className: "card-head" }, /* @__PURE__ */ React.createElement("div", { className: "card-route" }, trip.start.name, " \u2192 ", trip.end.name), /* @__PURE__ */ React.createElement("div", { className: "card-meta" }, /* @__PURE__ */ React.createElement("span", null, trip.distance, " km"), /* @__PURE__ */ React.createElement("span", null, days), trip.elevation && /* @__PURE__ */ React.createElement("span", null, "\u2191", trip.elevation, "m"))), /* @__PURE__ */ React.createElement("div", { className: "card-body" }, /* @__PURE__ */ React.createElement("div", { className: "card-row" }, trip.surfaces.map((s, i) => /* @__PURE__ */ React.createElement("span", { key: i, className: `tag surface-${s}` }, surfaceIcon(s), " ", surfaceLabel(s)))), /* @__PURE__ */ React.createElement("div", { className: "card-row" }, /* @__PURE__ */ React.createElement("span", { className: `tag ${tc}` }, "\u{1F682} ", trip.start.name, ": ", trip.start.time_distance, "h"), /* @__PURE__ */ React.createElement("span", { className: `tag ${tc}` }, "\u{1F682} ", trip.end.name, ": ", trip.end.time_distance, "h")), /* @__PURE__ */ React.createElement("div", { className: "card-section" }, /* @__PURE__ */ React.createElement("div", { className: "card-label" }, "Gminy (", trip.towns.length, ")"), /* @__PURE__ */ React.createElement("div", { className: "towns" }, townObjects.map((t, i) => t.url ? /* @__PURE__ */ React.createElement("a", { key: i, href: t.url, className: "town visited" }, t.name) : /* @__PURE__ */ React.createElement("span", { key: i, className: "town" }, t.name)))), /* @__PURE__ */ React.createElement("div", { className: "cost-box" }, /* @__PURE__ */ React.createElement("div", { className: "cost-header" }, "Niezaliczonych: ", /* @__PURE__ */ React.createElement("strong", null, trip.towns_not_visited), " gmin", /* @__PURE__ */ React.createElement("span", { className: "cost-direction" }, trip.direction_char)), /* @__PURE__ */ React.createElement("div", { className: "cost-row" }, /* @__PURE__ */ React.createElement("div", { className: "cost-cell" }, /* @__PURE__ */ React.createElement("span", { className: "cost-num" }, stats.time_cost_riding, "h"), /* @__PURE__ */ React.createElement("span", { className: "cost-desc" }, "jazdy/gmin\u0119")), /* @__PURE__ */ React.createElement("div", { className: "cost-cell" }, /* @__PURE__ */ React.createElement("span", { className: "cost-num" }, stats.time_cost_riding_and_train, "h"), /* @__PURE__ */ React.createElement("span", { className: "cost-desc" }, "z dojazdem")), /* @__PURE__ */ React.createElement("div", { className: "cost-cell" }, /* @__PURE__ */ React.createElement("span", { className: "cost-num" }, stats.time_cost_with_sleeping, "h"), /* @__PURE__ */ React.createElement("span", { className: "cost-desc" }, "z noclegiem")))), /* @__PURE__ */ React.createElement("div", { className: "card-actions" }, /* @__PURE__ */ React.createElement("a", { className: "btn-ext", href: trip.link, target: "_blank", rel: "noopener noreferrer" }, "\u{1F5FA}\uFE0F Mapa zewn\u0119trzna"), trip.photo_map_url && /* @__PURE__ */ React.createElement("button", { className: "btn-map", onClick: () => onMapClick(trip) }, "\u{1F4F8} Mapa zdj\u0119\u0107"))));
};
const Filters = ({ filters, onChange, surfaces, directions }) => {
  const DurationCheck = ({ val, label }) => /* @__PURE__ */ React.createElement("label", { className: "check" }, /* @__PURE__ */ React.createElement(
    "input",
    {
      type: "checkbox",
      checked: filters.duration.includes(val),
      onChange: (e) => onChange("duration", e.target.checked ? [...filters.duration, val] : filters.duration.filter((d) => d !== val))
    }
  ), label);
  return /* @__PURE__ */ React.createElement("div", { className: "filters" }, /* @__PURE__ */ React.createElement("div", { className: "filter-group" }, /* @__PURE__ */ React.createElement("div", { className: "filter-label" }, "Szukaj"), /* @__PURE__ */ React.createElement(
    "input",
    {
      type: "text",
      className: "filter-input",
      placeholder: "Gmina...",
      value: filters.searchText,
      onChange: (e) => onChange("searchText", e.target.value)
    }
  )), /* @__PURE__ */ React.createElement("div", { className: "filter-group" }, /* @__PURE__ */ React.createElement("div", { className: "filter-label" }, "Dystans: ", filters.distanceRange[0], "\u2013", filters.distanceRange[1], " km"), /* @__PURE__ */ React.createElement(
    "input",
    {
      type: "range",
      min: "50",
      max: "300",
      step: "10",
      value: filters.distanceRange[0],
      onChange: (e) => onChange("distanceRange", [parseInt(e.target.value), filters.distanceRange[1]])
    }
  ), /* @__PURE__ */ React.createElement(
    "input",
    {
      type: "range",
      min: "50",
      max: "300",
      step: "10",
      value: filters.distanceRange[1],
      onChange: (e) => onChange("distanceRange", [filters.distanceRange[0], parseInt(e.target.value)])
    }
  )), /* @__PURE__ */ React.createElement("div", { className: "filter-group" }, /* @__PURE__ */ React.createElement("div", { className: "filter-label" }, "Kierunek"), /* @__PURE__ */ React.createElement(
    "select",
    {
      className: "filter-select",
      value: filters.direction,
      onChange: (e) => onChange("direction", e.target.value)
    },
    /* @__PURE__ */ React.createElement("option", { value: "" }, "Wszystkie"),
    directions.map((d) => /* @__PURE__ */ React.createElement("option", { key: d, value: d }, d))
  )), /* @__PURE__ */ React.createElement("div", { className: "filter-group" }, /* @__PURE__ */ React.createElement("div", { className: "filter-label" }, "Min. niezaliczonych: ", filters.notVisited), /* @__PURE__ */ React.createElement(
    "input",
    {
      type: "range",
      min: "0",
      max: "10",
      step: "1",
      value: filters.notVisited,
      onChange: (e) => onChange("notVisited", parseInt(e.target.value))
    }
  )), /* @__PURE__ */ React.createElement("div", { className: "filter-group" }, /* @__PURE__ */ React.createElement("div", { className: "filter-label" }, "Czas trwania"), /* @__PURE__ */ React.createElement("div", { className: "checks" }, /* @__PURE__ */ React.createElement(DurationCheck, { val: "1", label: "1 dzie\u0144" }), /* @__PURE__ */ React.createElement(DurationCheck, { val: "2", label: "2 dni" }), /* @__PURE__ */ React.createElement(DurationCheck, { val: "3", label: "3 dni" }), /* @__PURE__ */ React.createElement(DurationCheck, { val: "4", label: "4 dni" }), /* @__PURE__ */ React.createElement(DurationCheck, { val: "5+", label: "5+ dni" }))), /* @__PURE__ */ React.createElement("div", { className: "filter-group" }, /* @__PURE__ */ React.createElement("div", { className: "filter-label" }, "Nawierzchnia"), /* @__PURE__ */ React.createElement("div", { className: "filter-btns" }, surfaces.map((s) => /* @__PURE__ */ React.createElement(
    "button",
    {
      key: s,
      className: `filter-btn ${filters.surface.includes(s) ? "active" : ""}`,
      onClick: () => onChange("surface", filters.surface.includes(s) ? filters.surface.filter((x) => x !== s) : [...filters.surface, s])
    },
    surfaceIcon(s),
    " ",
    surfaceLabel(s)
  )))), /* @__PURE__ */ React.createElement("div", { className: "filter-group" }, /* @__PURE__ */ React.createElement("div", { className: "filter-label" }, "Dojazd poci\u0105giem"), /* @__PURE__ */ React.createElement(
    "select",
    {
      className: "filter-select",
      value: filters.trainAccessibility,
      onChange: (e) => onChange("trainAccessibility", e.target.value)
    },
    /* @__PURE__ */ React.createElement("option", { value: "all" }, "Wszystkie"),
    /* @__PURE__ */ React.createElement("option", { value: "easy" }, "Szybki (<2h)"),
    /* @__PURE__ */ React.createElement("option", { value: "medium" }, "\u015Aredni (<4h)"),
    /* @__PURE__ */ React.createElement("option", { value: "hard" }, "Ci\u0119\u017Cki (<6h)"),
    /* @__PURE__ */ React.createElement("option", { value: "epic" }, "Grube (<8h)")
  )), /* @__PURE__ */ React.createElement("button", { className: "filter-reset", onClick: () => onChange("reset", null) }, "Resetuj filtry"));
};
const App = () => {
  const [trips, setTrips] = useState([]);
  const [towns, setTowns] = useState([]);
  const [loading, setLoading] = useState(true);
  const [mapTrip, setMapTrip] = useState(null);
  const [filters, setFilters] = useState({
    searchText: "",
    distanceRange: [50, 300],
    notVisited: 0,
    direction: "",
    duration: [],
    surface: [],
    trainAccessibility: "all"
  });
  useEffect(() => {
    fetch("/jsons/ideas.json").then((r) => r.json()).then((data) => {
      const ideas = data.ideas || data;
      const mapped = (Array.isArray(ideas) ? ideas : []).map((t) => ({
        ...t,
        days_min: t.days_min || t.lindays_mink,
        end: t.end || t.finish,
        direction: t.direction_char
      }));
      setTrips(mapped);
      setTowns(data.towns || []);
    }).catch(() => {
      setTrips([]);
      setTowns([]);
    }).finally(() => setLoading(false));
  }, []);
  const surfaces = useMemo(() => {
    const s = /* @__PURE__ */ new Set();
    trips.forEach((t) => (t.surfaces || []).forEach((x) => s.add(x)));
    return Array.from(s).sort();
  }, [trips]);
  const directions = useMemo(() => {
    return Array.from(new Set(trips.map((t) => t.direction))).sort();
  }, [trips]);
  const filtered = useMemo(() => trips.filter((t) => {
    if (filters.direction && t.direction !== filters.direction)
      return false;
    if (t.distance < filters.distanceRange[0] || t.distance > filters.distanceRange[1])
      return false;
    if (t.towns_not_visited < filters.notVisited)
      return false;
    if (filters.duration.length > 0) {
      const d = t.days_normal;
      if (!filters.duration.some(
        (v) => v === "5+" && d > 4 || v !== "5+" && d == parseInt(v)
      ))
        return false;
    }
    if (filters.surface.length > 0 && !t.surfaces.some((s) => filters.surface.includes(s)))
      return false;
    if (filters.searchText) {
      const q = filters.searchText.toLowerCase();
      if (![t.start.name, t.end.name, t.slug, ...t.towns].join(" ").toLowerCase().includes(q))
        return false;
    }
    if (filters.trainAccessibility !== "all") {
      const avg = (t.start.time_distance + t.end.time_distance) / 2;
      const limits = { easy: 2, medium: 4, hard: 6, epic: 8 };
      if (avg > limits[filters.trainAccessibility])
        return false;
    }
    return true;
  }), [trips, filters]);
  const handleFilter = (key, val) => {
    if (key === "reset") {
      setFilters({
        searchText: "",
        distanceRange: [50, 300],
        notVisited: 0,
        direction: "",
        duration: [],
        surface: [],
        trainAccessibility: "all"
      });
    } else {
      setFilters((prev) => ({ ...prev, [key]: val }));
    }
  };
  return /* @__PURE__ */ React.createElement(React.Fragment, null, /* @__PURE__ */ React.createElement("div", { className: "ideas-page" }, /* @__PURE__ */ React.createElement("header", { className: "ideas-hero" }, /* @__PURE__ */ React.createElement("h1", null, "Pomys\u0142y na trasy"), /* @__PURE__ */ React.createElement("p", null, loading ? "\u0141adowanie..." : `${filtered.length} ${filtered.length === 1 ? "trasa" : "tras"}`)), /* @__PURE__ */ React.createElement("div", { className: "ideas-grid" }, /* @__PURE__ */ React.createElement("aside", { className: "ideas-aside" }, /* @__PURE__ */ React.createElement(
    Filters,
    {
      filters,
      onChange: handleFilter,
      surfaces,
      directions
    }
  )), /* @__PURE__ */ React.createElement("main", { className: "ideas-main" }, loading ? /* @__PURE__ */ React.createElement("div", { className: "ideas-loading" }, "\u0141adowanie...") : filtered.length === 0 ? /* @__PURE__ */ React.createElement("div", { className: "ideas-empty" }, /* @__PURE__ */ React.createElement("div", { className: "ideas-empty-icon" }, "\u{1F6AB}"), /* @__PURE__ */ React.createElement("h3", null, "Brak pomys\u0142\xF3w na wycieczk\u0119"), /* @__PURE__ */ React.createElement("p", null, "Zmie\u0144 filtry aby zobaczy\u0107 jakie\u015B pomys\u0142y")) : /* @__PURE__ */ React.createElement("div", { className: "cards" }, filtered.map((t, i) => /* @__PURE__ */ React.createElement(TripCard, { key: t.slug || i, trip: t, onMapClick: setMapTrip, towns })))))), /* @__PURE__ */ React.createElement(MapModal, { show: !!mapTrip, onHide: () => setMapTrip(null), trip: mapTrip }));
};
function init() {
  ReactDOM.render(/* @__PURE__ */ React.createElement(App, null), document.getElementById("root"));
}
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", init);
} else {
  init();
}
