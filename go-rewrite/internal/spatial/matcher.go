package spatial

import (
	"fmt"
	"math"
	"sort"

	"odkrywajac/internal/model"

	geos "github.com/twpayne/go-geos"
)

// AreaWithGeom holds an area's metadata and its GEOS polygon geometry.
type AreaWithGeom struct {
	Slug  string
	Name  string
	Code  string
	BBoxS float64 // south (min lat)
	BBoxN float64 // north (max lat)
	BBoxW float64 // west (min lon)
	BBoxE float64 // east (max lon)
	geom  *geos.Geom     // GEOS polygon in lon,lat order
	prep  *geos.PrepGeom // prepared geometry for fast repeated tests
}

// Matcher performs spatial operations (route intersection, point-in-polygon)
// against a collection of area polygons using GEOS.
type Matcher struct {
	areas map[string][]*AreaWithGeom // keyed by type plural ("towns", etc.)
}

// LoadExternalAreasFunc is the function signature for loading external area data.
// It returns a map from type plural (e.g. "towns") to a slice of ExternalArea.
type LoadExternalAreasFunc func(string) (map[string][]ExternalArea, error)

// NewMatcher loads all external area polygons from YAML files in externalDir,
// builds GEOS geometries, and creates prepared geometries for fast testing.
func NewMatcher(externalDir string, loadFn LoadExternalAreasFunc) (*Matcher, error) {
	allAreas, err := loadFn(externalDir)
	if err != nil {
		return nil, fmt.Errorf("load external areas: %w", err)
	}

	matcher := &Matcher{
		areas: make(map[string][]*AreaWithGeom, len(allAreas)),
	}

	for typePlural, areaList := range allAreas {
		geomAreas := make([]*AreaWithGeom, 0, len(areaList))
		for i := range areaList {
			area := &areaList[i]
			if len(area.Polygon) < 3 {
				continue
			}

			awg := buildAreaWithGeom(area)
			if awg == nil {
				continue // skip invalid polygons
			}
			geomAreas = append(geomAreas, awg)
		}
		matcher.areas[typePlural] = geomAreas
	}

	return matcher, nil
}

// Close clears references to help GC reclaim GEOS geometry memory.
func (m *Matcher) Close() {
	for k := range m.areas {
		m.areas[k] = nil
	}
}

// MatchRoute computes which areas a route passes through, with distance metrics.
// segments is a slice of route segments, each being a slice of LatLon (lat,lon order).
// routeType is e.g. "bicycle", "hike".
func (m *Matcher) MatchRoute(segments [][]model.LatLon, routeType string) *RouteResult {
	result := &RouteResult{
		Segments: make([]SegmentResult, 0, len(segments)),
	}

	for _, seg := range segments {
		segResult := m.matchSegment(seg, routeType)
		result.Segments = append(result.Segments, segResult)
	}

	return result
}

// matchSegment matches a single route segment against all area types.
func (m *Matcher) matchSegment(points []model.LatLon, routeType string) SegmentResult {
	if len(points) < 2 {
		return SegmentResult{Type: routeType}
	}

	// Convert LatLon (lat,lon) → GEOS coords [][]float64 as [lon,lat] pairs
	geosCoords := make([][]float64, len(points))
	lons := make([]float64, len(points))
	lats := make([]float64, len(points))
	for i, pt := range points {
		geosCoords[i] = []float64{pt.Lon, pt.Lat}
		lons[i] = pt.Lon
		lats[i] = pt.Lat
	}

	routeGeom := geos.NewLineString(geosCoords)
	totalDistM := LinestringDistanceM(lons, lats)

	// Compute route bbox for pre-filtering
	routeBBox := computePointsBBox(lats, lons)

	seg := SegmentResult{
		Type:           routeType,
		TotalDistanceM: totalDistM,
		PointsCount:    len(points),
	}

	// Match each area type
	for _, areaType := range model.AllAreaTypes() {
		typePlural := areaType.EnglishPlural()
		areasForType := m.areas[typePlural]

		distances, touched := m.matchAreasForSegment(areasForType, routeGeom, points, routeBBox, totalDistM)

		switch typePlural {
		case "towns":
			seg.Towns = distances
			seg.TouchedTowns = touched
		case "counties":
			seg.Counties = distances
			seg.TouchedCounties = touched
		case "voivodeships":
			seg.Voivodeships = distances
			seg.TouchedVoivodeships = touched
		case "meso_regions":
			seg.MesoRegions = distances
			seg.TouchedMesoRegions = touched
		case "macro_regions":
			seg.MacroRegions = distances
			seg.TouchedMacroRegions = touched
		}
	}

	return seg
}

// matchAreasForSegment intersects a route with all areas of one type,
// returning distance-sorted results and point-based touched areas.
func (m *Matcher) matchAreasForSegment(
	areas []*AreaWithGeom,
	routeGeom *geos.Geom,
	points []model.LatLon,
	routeBBox bbox,
	totalDistM float64,
) ([]AreaDistance, []AreaRef) {
	var distances []AreaDistance
	touchedSet := make(map[string]*AreaWithGeom)

	for _, area := range areas {
		areaBBox := bbox{
			south: area.BBoxS, north: area.BBoxN,
			west: area.BBoxW, east: area.BBoxE,
		}

		// BBox pre-filter: skip areas that can't overlap the route
		if !bboxOverlaps(routeBBox, areaBBox) {
			continue
		}

		// Check point-in-polygon for touched areas using PrepGeom.ContainsXY
		for _, pt := range points {
			if pt.Lat >= area.BBoxS && pt.Lat <= area.BBoxN &&
				pt.Lon >= area.BBoxW && pt.Lon <= area.BBoxE {
				if area.prep.ContainsXY(pt.Lon, pt.Lat) {
					touchedSet[area.Slug] = area
					break
				}
			}
		}

		// Intersection for distance calculation
		if !area.prep.Intersects(routeGeom) {
			continue
		}

		intersection := area.geom.Intersection(routeGeom)
		if intersection == nil || intersection.IsEmpty() {
			continue
		}

		distM := extractIntersectionDistance(intersection)
		if distM <= 0 {
			continue
		}

		distKm := math.Round(distM/1000*1000) / 1000
		pct := 0.0
		if totalDistM > 0 {
			pct = math.Round(distM/totalDistM*100*10000) / 10000
		}

		distances = append(distances, AreaDistance{
			Slug:            area.Slug,
			Name:            area.Name,
			Code:            area.Code,
			DistanceM:       math.Round(distM*100) / 100,
			DistanceKm:      distKm,
			DistancePercent: pct,
		})
	}

	// Sort by distance descending
	sort.Slice(distances, func(i, j int) bool {
		return distances[i].DistanceM > distances[j].DistanceM
	})

	// Build touched refs from the set
	touched := make([]AreaRef, 0, len(touchedSet))
	for _, area := range touchedSet {
		touched = append(touched, AreaRef{
			Slug: area.Slug,
			Name: area.Name,
			Code: area.Code,
		})
	}
	// Sort touched by slug for deterministic output
	sort.Slice(touched, func(i, j int) bool {
		return touched[i].Slug < touched[j].Slug
	})

	return distances, touched
}

// MatchPoint tests which areas contain a given geographic point.
func (m *Matcher) MatchPoint(lat, lon float64) *PointResult {
	result := &PointResult{}

	for _, areaType := range model.AllAreaTypes() {
		typePlural := areaType.EnglishPlural()
		var refs []AreaRef

		for _, area := range m.areas[typePlural] {
			// BBox pre-filter
			if lat < area.BBoxS || lat > area.BBoxN || lon < area.BBoxW || lon > area.BBoxE {
				continue
			}

			if !area.prep.ContainsXY(lon, lat) {
				continue
			}

			refs = append(refs, AreaRef{
				Slug: area.Slug,
				Name: area.Name,
				Code: area.Code,
			})
		}

		switch typePlural {
		case "towns":
			result.Towns = refs
		case "counties":
			result.Counties = refs
		case "voivodeships":
			result.Voivodeships = refs
		case "meso_regions":
			result.MesoRegions = refs
		case "macro_regions":
			result.MacroRegions = refs
		}
	}

	return result
}

// ExternalArea is an exported version of geodata.externalArea for use by the matcher.
// It mirrors the YAML structure from data/external/*.yaml.
type ExternalArea struct {
	Slug        string      `yaml:"slug"`
	Name        string      `yaml:"name"`
	Terc        string      `yaml:"terc"`
	Kod         string      `yaml:"kod"`
	Voivodeship string      `yaml:"voivodeship"`
	Polygon     [][]float64 `yaml:"polygon"` // [lat, lon] pairs from YAML
}

// Code returns the area's identifier code (terc or kod, whichever is set).
func (a *ExternalArea) Code() string {
	if a.Terc != "" {
		return a.Terc
	}
	return a.Kod
}

// buildAreaWithGeom creates a GEOS polygon from an external area's coordinates.
// Input polygon coords are in [lat, lon] order; they're converted to [lon, lat] for GEOS.
// Returns nil if the polygon can't be created (e.g. invalid geometry).
func buildAreaWithGeom(area *ExternalArea) *AreaWithGeom {
	// Detect coordinate order and convert to [lon, lat]
	normalized := normalizeToLonLat(area.Polygon)

	// Build [][]float64 coords for GEOS and compute bbox
	geosCoords := make([][]float64, 0, len(normalized)+1)
	var minLat, maxLat, minLon, maxLon float64
	minLat, maxLat = math.Inf(1), math.Inf(-1)
	minLon, maxLon = math.Inf(1), math.Inf(-1)

	for _, point := range normalized {
		lon, lat := point[0], point[1]
		geosCoords = append(geosCoords, []float64{lon, lat})
		if lat < minLat {
			minLat = lat
		}
		if lat > maxLat {
			maxLat = lat
		}
		if lon < minLon {
			minLon = lon
		}
		if lon > maxLon {
			maxLon = lon
		}
	}

	// Close the ring if needed
	if len(geosCoords) > 0 {
		first := geosCoords[0]
		last := geosCoords[len(geosCoords)-1]
		if first[0] != last[0] || first[1] != last[1] {
			geosCoords = append(geosCoords, first)
		}
	}

	// Create GEOS polygon: [][][]float64{outerRing}
	polygon := geos.NewPolygon([][][]float64{geosCoords})
	if polygon == nil || !polygon.IsValid() {
		if polygon != nil {
			polygon = polygon.MakeValid()
			if polygon == nil || polygon.IsEmpty() {
				return nil
			}
		} else {
			return nil
		}
	}

	prep := polygon.Prepare()

	return &AreaWithGeom{
		Slug:  area.Slug,
		Name:  area.Name,
		Code:  area.Code(),
		BBoxS: minLat,
		BBoxN: maxLat,
		BBoxW: minLon,
		BBoxE: maxLon,
		geom:  polygon,
		prep:  prep,
	}
}

// normalizeToLonLat detects coordinate order and converts to [lon, lat] if needed.
// Uses the same heuristic as geodata.normalizeCoordOrder: for Poland,
// if first coord's first value > 40, it's latitude → needs swap.
func normalizeToLonLat(coords [][]float64) [][]float64 {
	if len(coords) == 0 || len(coords[0]) < 2 {
		return coords
	}

	if coords[0][0] > 40 {
		// First value is latitude — swap to [lon, lat]
		result := make([][]float64, len(coords))
		for i, pt := range coords {
			result[i] = []float64{pt[1], pt[0]}
		}
		return result
	}

	return coords
}

// extractIntersectionDistance extracts the total Haversine distance from a GEOS
// intersection result, which may be a LineString, MultiLineString, or GeometryCollection.
func extractIntersectionDistance(geom *geos.Geom) float64 {
	typeID := geom.TypeID()

	switch typeID {
	case geos.TypeIDLineString:
		return geomLinestringDistance(geom)

	case geos.TypeIDMultiLineString, geos.TypeIDGeometryCollection:
		nGeoms := geom.NumGeometries()
		var total float64
		for i := 0; i < nGeoms; i++ {
			sub := geom.Geometry(i)
			total += extractIntersectionDistance(sub)
		}
		return total

	default:
		// Points and other types don't contribute distance
		return 0
	}
}

// geomLinestringDistance computes the Haversine distance of a GEOS linestring.
func geomLinestringDistance(geom *geos.Geom) float64 {
	coordSeq := geom.CoordSeq()
	if coordSeq == nil {
		return 0
	}
	size := coordSeq.Size()
	if size < 2 {
		return 0
	}

	lons := make([]float64, size)
	lats := make([]float64, size)
	for i := 0; i < size; i++ {
		lons[i] = coordSeq.X(i)
		lats[i] = coordSeq.Y(i)
	}

	return LinestringDistanceM(lons, lats)
}

// bbox is a simple axis-aligned bounding box for pre-filtering.
type bbox struct {
	south, north, west, east float64
}

// bboxOverlaps returns true if two bounding boxes overlap.
func bboxOverlaps(a, b bbox) bool {
	return a.south <= b.north && a.north >= b.south &&
		a.west <= b.east && a.east >= b.west
}

// computePointsBBox computes the bounding box of a set of lat/lon coordinates.
func computePointsBBox(lats, lons []float64) bbox {
	if len(lats) == 0 {
		return bbox{}
	}

	b := bbox{
		south: lats[0], north: lats[0],
		west: lons[0], east: lons[0],
	}
	for i := 1; i < len(lats); i++ {
		if lats[i] < b.south {
			b.south = lats[i]
		}
		if lats[i] > b.north {
			b.north = lats[i]
		}
		if lons[i] < b.west {
			b.west = lons[i]
		}
		if lons[i] > b.east {
			b.east = lons[i]
		}
	}
	return b
}
