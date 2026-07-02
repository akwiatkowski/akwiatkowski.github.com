package spatial

// RouteResult holds the spatial matching results for an entire route (all segments).
type RouteResult struct {
	Segments []SegmentResult
}

// SegmentResult holds the area-matching results for a single route segment.
type SegmentResult struct {
	Type           string  // route type: "bicycle", "hike", etc.
	TotalDistanceM float64 // total Haversine distance of this segment in meters
	PointsCount    int     // number of coordinate points in this segment

	// Distance-based intersections (route passes through area polygon)
	Towns        []AreaDistance
	Counties     []AreaDistance
	Voivodeships []AreaDistance
	MesoRegions  []AreaDistance
	MacroRegions []AreaDistance

	// Point-in-polygon touches (at least one route vertex inside area)
	TouchedTowns        []AreaRef
	TouchedCounties     []AreaRef
	TouchedVoivodeships []AreaRef
	TouchedMesoRegions  []AreaRef
	TouchedMacroRegions []AreaRef
}

// AreaDistance records how much of a route passes through an area.
type AreaDistance struct {
	Slug           string
	Name           string
	Code           string
	DistanceM      float64 // meters
	DistanceKm     float64 // kilometers (rounded to 3 decimal places)
	DistancePercent float64 // percentage of segment total
}

// AreaRef is a lightweight area reference (no distance info), used for touched areas.
type AreaRef struct {
	Slug string
	Name string
	Code string
}

// PointResult holds the areas containing a single geographic point.
type PointResult struct {
	Towns        []AreaRef
	Counties     []AreaRef
	Voivodeships []AreaRef
	MesoRegions  []AreaRef
	MacroRegions []AreaRef
}

// AreaKey uniquely identifies an area by type and slug, used as a map key.
type AreaKey struct {
	TypePlural string // "towns", "counties", etc.
	Slug       string
}

// PhotoRef identifies a single photo within a post.
type PhotoRef struct {
	Filename string `yaml:"filename"`
	PostSlug string `yaml:"post_slug"`
}
