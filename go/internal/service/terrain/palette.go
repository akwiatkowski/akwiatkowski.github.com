package terrain

import "time"

// palette holds the landcover colors for a map style. Classification (which OSM
// feature is forest/water/…) lives in style.go and is style-independent; only
// the colors and how strongly infrastructure shows change between palettes. This
// lets the "nature" and "seasonal" styles share all the feature logic.
type palette struct {
	bg                 string
	water              string
	forest             string
	wetland            string
	scrub              string
	heath              string
	grass              string
	orchard            string
	sand               string
	farmland           string
	farmyard           string
	cemetery           string
	builtupResidential string
	builtupIndustrial  string
	building           string
	// infraOpacity fades roads, railways and buildings (1 = full strength). The
	// seasonal style lowers it so the landscape and season lead.
	infraOpacity float64
}

// naturePalette is the default lush look. These values must stay exactly as the
// committed "nature" map uses them — that style is not to change.
func naturePalette() palette {
	return palette{
		bg: "#ECE6D4", water: "#7FBFEA", forest: "#8FC56E", wetland: "#A8D6B6",
		scrub: "#AAD182", heath: "#C6D690", grass: "#BCE092", orchard: "#B4DB84",
		sand: "#EEE0B6", farmland: "#DED2A0", farmyard: "#D8C99A", cemetery: "#CADAB2",
		builtupResidential: "#E6E0D4", builtupIndustrial: "#E0D8CA", building: "#D4C4B4",
		infraOpacity: 1.0,
	}
}

// seasonalPalette derives a nature-forward palette from the trip's month
// (meteorological seasons), with infrastructure muted so the season reads.
func seasonalPalette(month time.Month) palette {
	p := naturePalette()
	p.infraOpacity = 0.5
	switch month {
	case time.March, time.April, time.May: // spring — fresh, bright greens
		p.bg = "#EEEAD8"
		p.forest, p.wetland, p.scrub, p.heath = "#7FC25A", "#A8DCB8", "#AEDC80", "#CFE08C"
		p.grass, p.orchard = "#C6EE84", "#C2E67E"
		p.farmland, p.farmyard, p.cemetery = "#DDE6B0", "#D6CFA0", "#CFE0B4"
		p.water = "#8FCBEA"
	case time.June, time.July, time.August: // summer — lush (≈ nature)
		// keep nature colors
	case time.September, time.October, time.November: // autumn — golden
		p.bg = "#EFE6CC"
		p.forest, p.wetland, p.scrub, p.heath = "#C6A24A", "#C8CFA0", "#C6B466", "#D2C078"
		p.grass, p.orchard = "#CFC886", "#CBB45E"
		p.farmland, p.farmyard, p.cemetery = "#E2CE94", "#DCC888", "#CFC898"
		p.water = "#7FB4D4"
	default: // winter (Dec–Feb) — frosted, cold
		p.bg = "#F0EEE6"
		p.forest, p.wetland, p.scrub, p.heath = "#BCCBB6", "#CDDCD6", "#C8D2BE", "#D2D6C4"
		p.grass, p.orchard = "#E2E6D8", "#D8DCC8"
		p.farmland, p.farmyard, p.cemetery = "#E8E6DA", "#E0DCCE", "#DCE0D2"
		p.water = "#C4D6E0"
	}
	return p
}
