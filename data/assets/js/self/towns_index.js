const { useState, useMemo } = React;
function SearchBar({ query, onChange, totalCount }) {
  return /* @__PURE__ */ React.createElement("div", { className: "towns-search-wrap" }, /* @__PURE__ */ React.createElement(
    "input",
    {
      type: "text",
      className: "towns-search",
      placeholder: "Szukaj gminy...",
      value: query,
      onInput: (e) => onChange(e.target.value)
    }
  ), /* @__PURE__ */ React.createElement("div", { className: "towns-search-count" }, totalCount, " ", totalCount === 1 ? "gmina" : "gmin"));
}
function TownCard({ town }) {
  var years = town.first_year === town.last_year ? String(town.first_year) : town.first_year + "\u2013" + town.last_year;
  return /* @__PURE__ */ React.createElement("a", { href: town.show_url, className: "town-card", title: town.name }, town.photo_url ? /* @__PURE__ */ React.createElement("div", { className: "town-card-bg", style: { backgroundImage: "url(" + town.photo_url + ")" } }) : /* @__PURE__ */ React.createElement("div", { className: "town-card-bg town-card-nophoto" }, /* @__PURE__ */ React.createElement("i", { className: "fa fa-map-marker fa-2x" })), town.post_count > 1 && /* @__PURE__ */ React.createElement("span", { className: "town-card-badge" }, town.post_count), /* @__PURE__ */ React.createElement("div", { className: "town-card-overlay" }, /* @__PURE__ */ React.createElement("div", { className: "town-card-name" }, town.name), /* @__PURE__ */ React.createElement("div", { className: "town-card-meta" }, years)));
}
function VoivodeshipGroup({ group }) {
  return /* @__PURE__ */ React.createElement("div", { className: "voivodeship-group", "data-voivodeship": group.slug }, /* @__PURE__ */ React.createElement("div", { className: "voivodeship-header" }, /* @__PURE__ */ React.createElement("a", { href: group.show_url, className: "voivodeship-name" }, group.name), /* @__PURE__ */ React.createElement("span", { className: "voivodeship-count" }, group.towns.length)), /* @__PURE__ */ React.createElement("div", { className: "towns-grid" }, group.towns.map(function(town) {
    return /* @__PURE__ */ React.createElement(TownCard, { key: town.slug, town });
  })));
}
function TownsIndexApp({ data }) {
  var [query, setQuery] = useState("");
  var filtered = useMemo(function() {
    if (!query)
      return data.towns;
    var q = query.toLowerCase();
    return data.towns.filter(function(t) {
      return t.name.toLowerCase().indexOf(q) !== -1;
    });
  }, [query, data.towns]);
  var groups = useMemo(function() {
    return data.voivodeships.map(function(v) {
      var towns = filtered.filter(function(t) {
        return t.voivodeship === v.slug;
      });
      return { name: v.name, slug: v.slug, show_url: v.show_url, towns };
    }).filter(function(g) {
      return g.towns.length > 0;
    });
  }, [filtered, data.voivodeships]);
  return /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement(SearchBar, { query, onChange: setQuery, totalCount: filtered.length }), /* @__PURE__ */ React.createElement("div", { className: "towns-container" }, groups.length > 0 ? groups.map(function(g) {
    return /* @__PURE__ */ React.createElement(VoivodeshipGroup, { key: g.slug, group: g });
  }) : /* @__PURE__ */ React.createElement("div", { className: "towns-no-results" }, 'Brak wynikow dla "', query, '"')));
}
function _initTownsIndex(data) {
  ReactDOM.render(/* @__PURE__ */ React.createElement(TownsIndexApp, { data }), document.getElementById("towns-app"));
}
window.TownsIndex = { init: _initTownsIndex };
