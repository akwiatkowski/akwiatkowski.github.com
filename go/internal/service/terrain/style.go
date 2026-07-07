package terrain

// This file holds the "nature exploration" cartographic style: a muted, natural
// palette chosen so the hillshade and the route read clearly on top. Features
// are classified from their OSM tags into a fill (for areas) or a stroke (for
// lines), each with a z-index that fixes the painter's-algorithm draw order.

// mapBackground is the paper color drawn under everything (unmapped land).
const mapBackground = "#F4F1E8"

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

// polygonSpec classifies an area feature. z orders draws within the polygon
// pass (higher = on top). ok is false for features we don't render.
func polygonSpec(f osmFeature) (style fillStyle, z int, ok bool) {
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
		return fillStyle{color: "#A5C9E3", opacity: 1}, 800, true
	}

	// Forest / wood.
	if natural == "wood" || landuse == "forest" {
		return fillStyle{color: "#BCD5A2", opacity: 1}, 500, true
	}
	// Wetland.
	if natural == "wetland" {
		return fillStyle{color: "#CFE0D6", opacity: 1}, 480, true
	}
	// Scrub / heath.
	if natural == "scrub" {
		return fillStyle{color: "#D2DEB2", opacity: 1}, 440, true
	}
	if natural == "heath" || natural == "fell" {
		return fillStyle{color: "#DAD8A6", opacity: 1}, 440, true
	}
	// Grass / meadow / parkland.
	if landuse == "meadow" || landuse == "grass" || natural == "grassland" ||
		landuse == "recreation_ground" || landuse == "village_green" ||
		leisure == "park" || leisure == "garden" || leisure == "pitch" || leisure == "golf_course" {
		return fillStyle{color: "#E1EBC6", opacity: 1}, 420, true
	}
	// Orchard / vineyard.
	if landuse == "orchard" || landuse == "vineyard" || landuse == "plant_nursery" {
		return fillStyle{color: "#D8E4A8", opacity: 1}, 410, true
	}
	// Sand / beach.
	if natural == "sand" || natural == "beach" {
		return fillStyle{color: "#EFE6C8", opacity: 1}, 400, true
	}
	// Farmland.
	if landuse == "farmland" {
		return fillStyle{color: "#F2EAD6", opacity: 1}, 300, true
	}
	if landuse == "farmyard" {
		return fillStyle{color: "#EBDCC0", opacity: 1}, 300, true
	}
	// Cemetery.
	if landuse == "cemetery" || f.tag("amenity") == "grave_yard" {
		return fillStyle{color: "#D8DECB", opacity: 1}, 320, true
	}
	// Built-up land (subtle, low).
	switch landuse {
	case "residential", "retail":
		return fillStyle{color: "#E9E4DB", opacity: 1}, 200, true
	case "industrial", "commercial", "garages", "railway":
		return fillStyle{color: "#E5DDD3", opacity: 1}, 200, true
	}
	// Buildings (above landcover, below roads).
	if f.has("building") {
		return fillStyle{color: "#D9C9BB", opacity: 1}, 700, true
	}
	return fillStyle{}, 0, false
}

// lineSpec classifies a line feature into a category + style + z-order.
func lineSpec(f osmFeature) (cat lineCategory, style lineStyle, z int, ok bool) {
	if ww := f.tag("waterway"); ww != "" {
		switch ww {
		case "river", "canal":
			return catWaterway, lineStyle{color: "#A5C9E3", width: 2.2, opacity: 1}, 10, true
		case "stream", "drain", "ditch":
			return catWaterway, lineStyle{color: "#A5C9E3", width: 1.0, opacity: 0.9}, 5, true
		}
	}

	if rw := f.tag("railway"); rw == "rail" || rw == "light_rail" || rw == "narrow_gauge" {
		return catRailway, lineStyle{color: "#7A7A7A", width: 1.4, opacity: 0.9,
			casingColor: "#FFFFFF", casingWidth: 0.6, dash: "5,5"}, 10, true
	}

	hw := f.tag("highway")
	switch hw {
	case "motorway", "motorway_link":
		return catRoad, lineStyle{color: "#F0A76A", width: 3.6, casingColor: "#C8894E", casingWidth: 4.8, opacity: 1}, 90, true
	case "trunk", "trunk_link":
		return catRoad, lineStyle{color: "#F4B77B", width: 3.2, casingColor: "#C99A5A", casingWidth: 4.3, opacity: 1}, 85, true
	case "primary", "primary_link":
		return catRoad, lineStyle{color: "#F6C77B", width: 2.9, casingColor: "#C9A45A", casingWidth: 3.9, opacity: 1}, 80, true
	case "secondary", "secondary_link":
		return catRoad, lineStyle{color: "#F7E08A", width: 2.5, casingColor: "#C9B85A", casingWidth: 3.4, opacity: 1}, 70, true
	case "tertiary", "tertiary_link":
		return catRoad, lineStyle{color: "#FBF3C8", width: 2.1, casingColor: "#CFC488", casingWidth: 2.9, opacity: 1}, 60, true
	case "unclassified", "residential", "living_street":
		return catRoad, lineStyle{color: "#FFFFFF", width: 1.7, casingColor: "#CFCABC", casingWidth: 2.3, opacity: 1}, 50, true
	case "service":
		return catRoad, lineStyle{color: "#FFFFFF", width: 1.1, casingColor: "#D4CFC2", casingWidth: 1.6, opacity: 1}, 40, true
	case "track":
		return catPath, lineStyle{color: "#9C7A50", width: 1.3, dash: "3.5,2", opacity: 0.95}, 30, true
	case "cycleway":
		return catPath, lineStyle{color: "#3F6FD0", width: 1.2, dash: "3,2", opacity: 0.9}, 25, true
	case "path", "footway", "bridleway", "steps":
		return catPath, lineStyle{color: "#A2683E", width: 1.0, dash: "2,2", opacity: 0.9}, 20, true
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
	// Mountain / hill peaks — a marker plus the name and elevation.
	if f.tag("natural") == "peak" || f.tag("natural") == "hill" {
		label := name
		if ele := f.tag("ele"); ele != "" {
			label = name + " " + ele + "m"
		}
		return label, 9, true, 100, true
	}
	if f.tag("tourism") == "viewpoint" {
		return name, 8.5, true, 90, true
	}
	// Settlements, sized by rank.
	switch f.tag("place") {
	case "city":
		return name, 15, false, 80, true
	case "town":
		return name, 12.5, false, 70, true
	case "village":
		return name, 10, false, 60, true
	case "hamlet", "suburb":
		return name, 8.5, false, 50, true
	}
	return "", 0, false, 0, false
}
