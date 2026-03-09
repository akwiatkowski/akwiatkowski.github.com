package polygon

import (
	"encoding/json"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"strings"

	"odkrywajac/internal/model"

	"gopkg.in/yaml.v3"
)

// DefaultTolerance is the Douglas-Peucker simplification tolerance in degrees.
// 0.001 degrees ≈ ~111m at the equator, reasonable for area outlines.
const DefaultTolerance = 0.001

// externalArea is a single area entry from data/external/*.yaml.
// Towns/counties/voivodeships use "terc" as their code field,
// while meso/macro regions use "kod".
type externalArea struct {
	Slug        string      `yaml:"slug"`
	Name        string      `yaml:"name"`
	Terc        string      `yaml:"terc"`
	Kod         string      `yaml:"kod"`
	Voivodeship string      `yaml:"voivodeship"`
	Polygon     [][]float64 `yaml:"polygon"`
}

// Code returns the area's identifier code (terc or kod, whichever is set).
func (a *externalArea) Code() string {
	if a.Terc != "" {
		return a.Terc
	}
	return a.Kod
}

// LoadExternalAreas loads all area polygons from data/external/*.yaml files.
// Returns a map keyed by area type plural name (e.g. "towns") to a slice of areas.
// Only the 5 standard area types are loaded (no external/foreign areas).
func LoadExternalAreas(externalDir string) (map[string][]externalArea, error) {
	result := make(map[string][]externalArea)
	for _, areaType := range model.AllAreaTypes() {
		typeName := areaType.EnglishPlural()
		path := filepath.Join(externalDir, typeName+".yaml")

		data, err := os.ReadFile(path)
		if err != nil {
			return nil, fmt.Errorf("read %s: %w", path, err)
		}

		var areas []externalArea
		if err := yaml.Unmarshal(data, &areas); err != nil {
			return nil, fmt.Errorf("parse %s: %w", path, err)
		}

		result[typeName] = areas
	}
	return result, nil
}

// areaCacheEntry is a single area reference inside a route segment's area list.
type areaCacheEntry struct {
	Slug string `yaml:"slug"`
}

// areaCacheSegment represents one route segment from areas_for_post/*.yml.
// It contains area lists (primary and touched) for each area type.
type areaCacheSegment struct {
	Towns              []areaCacheEntry `yaml:"towns"`
	Counties           []areaCacheEntry `yaml:"counties"`
	Voivodeships       []areaCacheEntry `yaml:"voivodeships"`
	MesoRegions        []areaCacheEntry `yaml:"meso_regions"`
	MacroRegions       []areaCacheEntry `yaml:"macro_regions"`
	TouchedTowns       []areaCacheEntry `yaml:"touched_towns"`
	TouchedCounties    []areaCacheEntry `yaml:"touched_counties"`
	TouchedVoivodeships []areaCacheEntry `yaml:"touched_voivodeships"`
	TouchedMesoRegions []areaCacheEntry `yaml:"touched_meso_regions"`
	TouchedMacroRegions []areaCacheEntry `yaml:"touched_macro_regions"`
}

// CollectVisitedSlugs gathers all area slugs that need polygon files generated.
// It merges two sources:
//  1. GPS route coverage cache (areas_for_post/*.yml) — Crystal-generated files
//     listing which areas each post's route passes through
//  2. Post frontmatter — TownSlugs and LandSlugs manually listed by the author,
//     resolved against loaded areas to determine their type
//
// Returns map[areaTypePlural]map[slug]bool (e.g. "towns" -> {"wabrzezno": true}).
func CollectVisitedSlugs(posts []*model.Post, areaCacheDir string, areas []*model.Area) map[string]map[string]bool {
	visited := make(map[string]map[string]bool)
	for _, areaType := range model.AllAreaTypes() {
		visited[areaType.EnglishPlural()] = make(map[string]bool)
	}

	// Source 1: GPS route coverage cache
	collectFromAreaCache(visited, posts, areaCacheDir)

	// Source 2: Post frontmatter slugs resolved against loaded areas
	collectFromFrontmatter(visited, posts, areas)

	return visited
}

// collectFromAreaCache reads Crystal-generated areas_for_post/*.yml files and
// extracts all area slugs from both primary and touched lists.
func collectFromAreaCache(visited map[string]map[string]bool, posts []*model.Post, areaCacheDir string) {
	if areaCacheDir == "" {
		return
	}
	if _, err := os.Stat(areaCacheDir); err != nil {
		return
	}

	for _, post := range posts {
		path := filepath.Join(areaCacheDir, post.Slug+".yml")
		data, err := os.ReadFile(path)
		if err != nil {
			continue
		}

		var segments []areaCacheSegment
		if err := yaml.Unmarshal(data, &segments); err != nil {
			continue
		}

		for _, seg := range segments {
			addSlugs(visited["towns"], seg.Towns)
			addSlugs(visited["towns"], seg.TouchedTowns)
			addSlugs(visited["counties"], seg.Counties)
			addSlugs(visited["counties"], seg.TouchedCounties)
			addSlugs(visited["voivodeships"], seg.Voivodeships)
			addSlugs(visited["voivodeships"], seg.TouchedVoivodeships)
			addSlugs(visited["meso_regions"], seg.MesoRegions)
			addSlugs(visited["meso_regions"], seg.TouchedMesoRegions)
			addSlugs(visited["macro_regions"], seg.MacroRegions)
			addSlugs(visited["macro_regions"], seg.TouchedMacroRegions)
		}
	}
}

// addSlugs adds all slugs from entries into the target set.
func addSlugs(target map[string]bool, entries []areaCacheEntry) {
	for _, entry := range entries {
		if entry.Slug != "" {
			target[entry.Slug] = true
		}
	}
}

// collectFromFrontmatter resolves post frontmatter TownSlugs and LandSlugs
// against loaded area data to determine each slug's area type, then adds them
// to the visited map. This catches areas that aren't in the GPS cache
// (e.g. small towns the route didn't intersect but the author listed manually).
func collectFromFrontmatter(visited map[string]map[string]bool, posts []*model.Post, areas []*model.Area) {
	// Build slug -> area type lookup from loaded areas
	slugToType := make(map[string]model.AreaType)
	for _, area := range areas {
		slugToType[area.Slug] = area.Type
	}

	for _, post := range posts {
		// TownSlugs can reference towns, counties, or voivodeships
		for _, slug := range post.TownSlugs {
			if areaType, ok := slugToType[slug]; ok {
				visited[areaType.EnglishPlural()][slug] = true
			}
		}
		// LandSlugs reference meso_regions or macro_regions
		for _, slug := range post.LandSlugs {
			if areaType, ok := slugToType[slug]; ok {
				visited[areaType.EnglishPlural()][slug] = true
			}
		}
	}
}

// GenerateResult contains statistics about a polygon generation run.
type GenerateResult struct {
	Generated int // number of new polygon files written
	Skipped   int // number of existing files skipped
	Missing   int // number of visited slugs not found in external data
}

// Generate creates simplified GeoJSON polygon files for all visited areas.
// It loads external area data from externalDir, determines which areas need
// polygons based on posts and area cache, simplifies the polygons, and writes
// GeoJSON files to outputDir/{type}/{slug}.json.
func Generate(externalDir, outputDir, areaCacheDir string, posts []*model.Post, areas []*model.Area, tolerance float64, force bool) (GenerateResult, error) {
	var result GenerateResult

	// Load all external area data (with full polygons)
	external, err := LoadExternalAreas(externalDir)
	if err != nil {
		return result, fmt.Errorf("load external areas: %w", err)
	}

	// Build slug -> externalArea index for each type
	externalIndex := buildExternalIndex(external)

	// Collect visited area slugs from GPS cache + frontmatter
	visited := CollectVisitedSlugs(posts, areaCacheDir, areas)

	// Generate polygon files for each visited area
	for _, areaType := range model.AllAreaTypes() {
		typePlural := areaType.EnglishPlural()
		typeSingular := areaType.String()
		typeDir := filepath.Join(outputDir, typePlural)

		slugs := visited[typePlural]
		if len(slugs) == 0 {
			continue
		}

		if err := os.MkdirAll(typeDir, 0o755); err != nil {
			return result, fmt.Errorf("create dir %s: %w", typeDir, err)
		}

		idx := externalIndex[typePlural]
		for slug := range slugs {
			outPath := filepath.Join(typeDir, slug+".json")

			// Skip existing files unless force is set
			if !force {
				if _, err := os.Stat(outPath); err == nil {
					result.Skipped++
					continue
				}
			}

			area, ok := idx[slug]
			if !ok {
				result.Missing++
				continue
			}

			if len(area.Polygon) < 3 {
				result.Missing++
				continue
			}

			data, err := buildGeoJSON(area, typeSingular, tolerance)
			if err != nil {
				return result, fmt.Errorf("build geojson for %s/%s: %w", typePlural, slug, err)
			}

			if err := os.WriteFile(outPath, data, 0o644); err != nil {
				return result, fmt.Errorf("write %s: %w", outPath, err)
			}
			result.Generated++
		}
	}

	return result, nil
}

// buildExternalIndex creates a slug-to-area lookup for each area type.
func buildExternalIndex(external map[string][]externalArea) map[string]map[string]*externalArea {
	index := make(map[string]map[string]*externalArea)
	for typeName, areas := range external {
		m := make(map[string]*externalArea, len(areas))
		for i := range areas {
			m[areas[i].Slug] = &areas[i]
		}
		index[typeName] = m
	}
	return index
}

// geoJSONFeature is the GeoJSON Feature output structure.
type geoJSONFeature struct {
	Type       string            `json:"type"`
	Properties geoJSONProperties `json:"properties"`
	Geometry   geoJSONGeometry   `json:"geometry"`
}

// geoJSONProperties holds metadata about the simplified polygon.
type geoJSONProperties struct {
	Slug             string  `json:"slug"`
	Name             string  `json:"name"`
	Type             string  `json:"type"`
	OriginalPoints   int     `json:"original_points"`
	SimplifiedPoints int     `json:"simplified_points"`
	ReductionPercent float64 `json:"reduction_percent"`
}

// geoJSONGeometry is a GeoJSON Polygon geometry.
type geoJSONGeometry struct {
	Type        string        `json:"type"`
	Coordinates [][][2]float64 `json:"coordinates"`
}

// buildGeoJSON creates a compact GeoJSON Feature for the given external area.
// It simplifies the polygon using Douglas-Peucker, swaps coordinates from
// [lat,lon] (YAML input) to [lon,lat] (GeoJSON standard), closes the ring,
// and rounds coordinates to 6 decimal places.
func buildGeoJSON(area *externalArea, typeSingular string, tolerance float64) ([]byte, error) {
	originalPoints := len(area.Polygon)

	// Simplify
	simplified := Simplify(area.Polygon, tolerance)

	// Convert to GeoJSON coordinates: swap [lat,lon] → [lon,lat], round, close ring
	coords := make([][2]float64, 0, len(simplified)+1)
	for _, point := range simplified {
		coords = append(coords, [2]float64{
			roundTo6(point[1]), // lon
			roundTo6(point[0]), // lat
		})
	}

	// Ensure the ring is closed (first point == last point)
	if len(coords) > 0 && (coords[0] != coords[len(coords)-1]) {
		coords = append(coords, coords[0])
	}

	simplifiedPoints := len(coords)
	reductionPct := 0.0
	if originalPoints > 0 {
		reductionPct = roundTo1((1.0 - float64(simplifiedPoints)/float64(originalPoints)) * 100.0)
	}

	feature := geoJSONFeature{
		Type: "Feature",
		Properties: geoJSONProperties{
			Slug:             area.Slug,
			Name:             area.Name,
			Type:             typeSingular,
			OriginalPoints:   originalPoints,
			SimplifiedPoints: simplifiedPoints,
			ReductionPercent: reductionPct,
		},
		Geometry: geoJSONGeometry{
			Type:        "Polygon",
			Coordinates: [][][2]float64{coords},
		},
	}

	return json.Marshal(feature)
}

// roundTo6 rounds a float to 6 decimal places.
func roundTo6(f float64) float64 {
	return math.Round(f*1e6) / 1e6
}

// roundTo1 rounds a float to 1 decimal place.
func roundTo1(f float64) float64 {
	return math.Round(f*10) / 10
}

// BuildSlugIndex creates a slug-to-externalArea index from a flat slice.
// Exported for testing convenience.
func BuildSlugIndex(areas []externalArea) map[string]*externalArea {
	m := make(map[string]*externalArea, len(areas))
	for i := range areas {
		m[areas[i].Slug] = &areas[i]
	}
	return m
}

// ExternalAreaFilenameParts returns the YAML filename (without extension)
// for each area type. Matches data/external/{name}.yaml.
func ExternalAreaFilenameParts() []string {
	parts := make([]string, 0, 5)
	for _, at := range model.AllAreaTypes() {
		parts = append(parts, at.EnglishPlural())
	}
	return parts
}

// FormatTypeName converts an AreaType to the singular string used in GeoJSON
// properties. This is the same as AreaType.String() but documented here for
// clarity about the output contract.
func FormatTypeName(areaType model.AreaType) string {
	return areaType.String()
}

// SplitTownSlugsIntoTypes is exposed for testing. Given a list of town slugs
// from post frontmatter, it resolves each against the area index and returns
// which type each belongs to. Slugs not found in the index are ignored.
func SplitTownSlugsIntoTypes(slugs []string, areaIndex map[string]model.AreaType) map[string][]string {
	result := make(map[string][]string)
	for _, slug := range slugs {
		if at, ok := areaIndex[slug]; ok {
			typeName := at.EnglishPlural()
			result[typeName] = append(result[typeName], slug)
		}
	}
	return result
}

// ValidateGeoJSONOutput checks that a GeoJSON byte slice has the expected
// Feature structure. Returns an error if validation fails. Used in tests.
func ValidateGeoJSONOutput(data []byte) error {
	var feature geoJSONFeature
	if err := json.Unmarshal(data, &feature); err != nil {
		return fmt.Errorf("invalid JSON: %w", err)
	}
	if feature.Type != "Feature" {
		return fmt.Errorf("expected type 'Feature', got %q", feature.Type)
	}
	if feature.Geometry.Type != "Polygon" {
		return fmt.Errorf("expected geometry type 'Polygon', got %q", feature.Geometry.Type)
	}
	if len(feature.Geometry.Coordinates) == 0 {
		return fmt.Errorf("no coordinate rings")
	}
	ring := feature.Geometry.Coordinates[0]
	if len(ring) < 4 {
		return fmt.Errorf("polygon ring has %d points, need at least 4", len(ring))
	}
	// Check ring is closed
	if ring[0] != ring[len(ring)-1] {
		return fmt.Errorf("polygon ring is not closed")
	}
	// Check type field exists
	validTypes := map[string]bool{
		"town": true, "county": true, "voivodeship": true,
		"meso_region": true, "macro_region": true,
	}
	if !validTypes[feature.Properties.Type] {
		return fmt.Errorf("invalid type %q", feature.Properties.Type)
	}
	// Check slug is non-empty
	if feature.Properties.Slug == "" {
		return fmt.Errorf("empty slug")
	}
	if strings.Contains(feature.Properties.Slug, "/") {
		return fmt.Errorf("slug contains slash: %q", feature.Properties.Slug)
	}
	return nil
}
