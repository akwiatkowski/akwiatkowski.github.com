package terrain

// This file holds the "nature exploration" cartographic style: a muted, natural
// palette chosen so the hillshade and the route read clearly on top. Features
// are classified from their OSM tags into a fill (for areas) or a stroke (for
// lines), each with a z-index that fixes the painter's-algorithm draw order.

// roadWidthScale narrows every road (highway) line to this fraction of its
// nominal weight — roads were reading too heavy.
const roadWidthScale = 0.6

// fillStyle describes how an area feature is painted.
type fillStyle struct {
	color   string
	opacity float64
	// outlineColor/outlineWidth/outlineDash, when set, stroke the area boundary
	// (used for protected areas, which get an outline but no fill).
	outlineColor string
	outlineWidth float64
	outlineDash  string
	noFill       bool // outline-only (protected areas)
}

// lineStyle describes how a line feature is painted, optionally with a wider
// casing drawn beneath the core (roads) and/or a dash pattern (tracks/paths).
type lineStyle struct {
	color       string
	width       float64 // core width at reference (1000px) scale
	dash        string  // SVG stroke-dasharray at reference scale, "" for solid
	opacity     float64
	casingColor string
	casingWidth float64
}

// lineCategory groups line features so they render in bands (waterways lowest,
// then paths, then roads, then railways on top).
type lineCategory int

const (
	catNone lineCategory = iota
	catWaterway
	catPath
	catRoad
	catRailway
)

// polygonSpec classifies an area feature and colors it from the palette. z
// orders draws within the polygon pass (higher = on top). ok is false for
// features we don't render. Built-up land and buildings are faded by the
// palette's infraOpacity so the seasonal style can push infrastructure back.
func polygonSpec(f osmFeature, pal palette) (style fillStyle, z int, ok bool) {
	// Protected areas: outline only, so the landcover beneath stays visible.
	if f.tag("boundary") == "national_park" || f.tag("boundary") == "protected_area" ||
		f.tag("leisure") == "nature_reserve" {
		return fillStyle{noFill: true, outlineColor: "#5C8A3A", outlineWidth: 1.6, outlineDash: "6,3", opacity: 0.9}, 900, true
	}

	natural := f.tag("natural")
	landuse := f.tag("landuse")
	leisure := f.tag("leisure")

	// Water (highest of the fills).
	if natural == "water" || natural == "bay" || natural == "strait" ||
		landuse == "reservoir" || landuse == "basin" || f.tag("waterway") == "riverbank" {
		return fillStyle{color: pal.water, opacity: 1}, 800, true
	}

	if natural == "wood" || landuse == "forest" {
		return fillStyle{color: pal.forest, opacity: 1}, 500, true
	}
	if natural == "wetland" {
		return fillStyle{color: pal.wetland, opacity: 1}, 480, true
	}
	if natural == "scrub" {
		return fillStyle{color: pal.scrub, opacity: 1}, 440, true
	}
	if natural == "heath" || natural == "fell" {
		return fillStyle{color: pal.heath, opacity: 1}, 440, true
	}
	// Grass / meadow / parkland.
	if landuse == "meadow" || landuse == "grass" || natural == "grassland" ||
		landuse == "recreation_ground" || landuse == "village_green" ||
		leisure == "park" || leisure == "garden" || leisure == "pitch" || leisure == "golf_course" {
		return fillStyle{color: pal.grass, opacity: 1}, 420, true
	}
	if landuse == "orchard" || landuse == "vineyard" || landuse == "plant_nursery" {
		return fillStyle{color: pal.orchard, opacity: 1}, 410, true
	}
	if natural == "sand" || natural == "beach" {
		return fillStyle{color: pal.sand, opacity: 1}, 400, true
	}
	if landuse == "farmland" {
		return fillStyle{color: pal.farmland, opacity: 1}, 300, true
	}
	if landuse == "farmyard" {
		return fillStyle{color: pal.farmyard, opacity: 1}, 300, true
	}
	if landuse == "cemetery" || f.tag("amenity") == "grave_yard" {
		return fillStyle{color: pal.cemetery, opacity: 1}, 320, true
	}
	// Built-up land — faded by the palette so it recedes in the seasonal style.
	switch landuse {
	case "residential", "retail":
		return fillStyle{color: pal.builtupResidential, opacity: pal.infraOpacity}, 200, true
	case "industrial", "commercial", "garages", "railway":
		return fillStyle{color: pal.builtupIndustrial, opacity: pal.infraOpacity}, 200, true
	}
	// Buildings (above landcover, below roads) — also faded.
	if f.has("building") {
		return fillStyle{color: pal.building, opacity: pal.infraOpacity}, 700, true
	}
	return fillStyle{}, 0, false
}

// lineSpec classifies a line feature. Waterways take the palette's water color;
// roads and railways keep their warm colors but are faded by infraOpacity so
// the seasonal style de-emphasizes them. Tracks/paths stay full strength (they
// matter for exploration).
func lineSpec(f osmFeature, pal palette) (cat lineCategory, style lineStyle, z int, ok bool) {
	if ww := f.tag("waterway"); ww != "" {
		switch ww {
		case "river", "canal":
			return catWaterway, lineStyle{color: pal.water, width: 2.2, opacity: 1}, 10, true
		case "stream", "drain", "ditch":
			return catWaterway, lineStyle{color: pal.water, width: 1.0, opacity: 0.9}, 5, true
		}
	}

	if rw := f.tag("railway"); rw == "rail" || rw == "light_rail" || rw == "narrow_gauge" {
		return catRailway, lineStyle{color: "#7A7A7A", width: 1.4, opacity: 0.9 * pal.infraOpacity,
			casingColor: "#FFFFFF", casingWidth: 0.6, dash: "5,5"}, 10, true
	}

	io := pal.infraOpacity
	hw := f.tag("highway")
	switch hw {
	case "motorway", "motorway_link":
		return catRoad, lineStyle{color: "#F0A76A", width: 3.6, casingColor: "#C8894E", casingWidth: 4.8, opacity: io}, 90, true
	case "trunk", "trunk_link":
		return catRoad, lineStyle{color: "#F4B77B", width: 3.2, casingColor: "#C99A5A", casingWidth: 4.3, opacity: io}, 85, true
	case "primary", "primary_link":
		return catRoad, lineStyle{color: "#F6C77B", width: 2.9, casingColor: "#C9A45A", casingWidth: 3.9, opacity: io}, 80, true
	case "secondary", "secondary_link":
		return catRoad, lineStyle{color: "#F7E08A", width: 2.5, casingColor: "#C9B85A", casingWidth: 3.4, opacity: io}, 70, true
	case "tertiary", "tertiary_link":
		return catRoad, lineStyle{color: "#FBF3C8", width: 2.1, casingColor: "#CFC488", casingWidth: 2.9, opacity: io}, 60, true
	case "unclassified", "residential", "living_street":
		return catRoad, lineStyle{color: "#FFFFFF", width: 1.7, casingColor: "#CFCABC", casingWidth: 2.3, opacity: io}, 50, true
	case "service":
		return catRoad, lineStyle{color: "#FFFFFF", width: 1.1, casingColor: "#D4CFC2", casingWidth: 1.6, opacity: io}, 40, true
	case "track":
		// Dirt roads: thin, soft light brown, gentle dash — present but not shouty.
		return catPath, lineStyle{color: "#B39A72", width: 0.9, dash: "3,3", opacity: 0.7}, 30, true
	case "cycleway":
		return catPath, lineStyle{color: "#6E8FC8", width: 0.9, dash: "3,3", opacity: 0.7}, 25, true
	case "path", "footway", "bridleway", "steps":
		return catPath, lineStyle{color: "#B6926A", width: 0.75, dash: "2,3", opacity: 0.65}, 20, true
	}
	return catNone, lineStyle{}, 0, false
}

// placeLabel classifies a point feature for labeling. Returns the label text,
// a font size at reference scale, whether to draw a marker dot, and ok.
func placeLabel(f osmFeature) (text string, fontPx float64, marker bool, z int, ok bool) {
	name := f.tag("name")
	if name == "" {
		return "", 0, false, 0, false
	}
	// Font sizes are fixed pixels (same on article and print): 12px default,
	// 14px for big cities. z still ranks priority for collision/LOD.
	const defaultFont, cityFont = 12.0, 14.0

	// Mountain / hill peaks — a marker plus the name and elevation.
	if f.tag("natural") == "peak" || f.tag("natural") == "hill" {
		label := name
		if ele := f.tag("ele"); ele != "" {
			label = name + " " + ele + "m"
		}
		return label, defaultFont, true, 100, true
	}
	if f.tag("tourism") == "viewpoint" {
		return name, defaultFont, true, 90, true
	}
	// Settlements, ranked by place type (all default size except big cities).
	switch f.tag("place") {
	case "city":
		return name, cityFont, false, 80, true
	case "town":
		return name, defaultFont, false, 70, true
	case "village":
		return name, defaultFont, false, 60, true
	case "hamlet", "suburb":
		return name, defaultFont, false, 50, true
	}
	return "", 0, false, 0, false
}
