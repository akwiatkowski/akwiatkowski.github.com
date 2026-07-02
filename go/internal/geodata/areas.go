package geodata

import (
	"fmt"
	"math"
	"os"
	"path/filepath"
	"strings"

	"odkrywajac/internal/model"

	"gopkg.in/yaml.v3"
)

// areaConfigEntry is the output YAML structure for a single area in data/cache-go/areas/.
// It mirrors the Crystal-generated format in data/config/areas/.
type areaConfigEntry struct {
	Slug        string   `yaml:"slug"`
	Name        string   `yaml:"name"`
	Code        string   `yaml:"code"`
	Voivodeship string   `yaml:"voivodeship,omitempty"`
	BBox        *bboxOut `yaml:"bbox,omitempty"`
}

// bboxOut is the bounding box in the output YAML.
type bboxOut struct {
	South float64 `yaml:"south"`
	North float64 `yaml:"north"`
	West  float64 `yaml:"west"`
	East  float64 `yaml:"east"`
}

// AreaConfigResult contains statistics about area config generation.
type AreaConfigResult struct {
	TotalAreas int
	TypeCounts map[string]int
}

// GenerateAreaConfigs reads all 5 external YAML files from externalDir and writes
// bbox-only area config YAMLs to outputDir/areas/{type}.yml. This replaces the
// Crystal-generated data/config/areas/ with a Go-native equivalent.
//
// The transformation per area:
//   - Computes bbox from polygon coordinates (with coordinate order normalization)
//   - Maps terc/kod → code
//   - Disambiguates duplicate slugs for towns and counties (voivodeship + type suffixes)
//   - Lowercases voivodeship names
//   - Drops polygon, id, type fields
func GenerateAreaConfigs(externalDir, outputDir string, force bool) (AreaConfigResult, error) {
	var result AreaConfigResult
	result.TypeCounts = make(map[string]int)

	areasDir := filepath.Join(outputDir, "areas")

	// Quick check: if all 5 output files exist and force=false, skip entirely
	if !force && allAreaConfigsExist(areasDir) {
		for _, areaType := range model.AllAreaTypes() {
			result.TypeCounts[areaType.EnglishPlural()] = -1 // indicates skipped
		}
		return result, nil
	}

	// Load all external areas
	external, err := LoadExternalAreas(externalDir)
	if err != nil {
		return result, err
	}

	// Disambiguate town and county slugs (mutates the slices)
	disambiguateSlugs(external["towns"], external["counties"])
	disambiguateSlugs(external["counties"], nil)

	if err := os.MkdirAll(areasDir, 0o755); err != nil {
		return result, fmt.Errorf("create areas dir: %w", err)
	}

	for _, areaType := range model.AllAreaTypes() {
		typeName := areaType.EnglishPlural()
		areas := external[typeName]
		isAdmin := areaType == model.AreaTypeTown || areaType == model.AreaTypeCounty || areaType == model.AreaTypeVoivodeship

		entries := make([]areaConfigEntry, 0, len(areas))
		for i := range areas {
			area := &areas[i]
			entry := areaConfigEntry{
				Slug: area.Slug,
				Name: area.Name,
				Code: area.Code(),
			}

			// Voivodeship names are UPPERCASE in external YAML — lowercase them
			if areaType == model.AreaTypeVoivodeship {
				entry.Name = strings.ToLower(entry.Name)
			}

			// Lowercase voivodeship slug reference for admin areas
			if isAdmin && area.Voivodeship != "" {
				entry.Voivodeship = strings.ToLower(area.Voivodeship)
			}

			// Compute bbox from polygon
			if len(area.Polygon) > 0 {
				normalized := normalizeCoordOrder(area.Polygon)
				entry.BBox = computeBBox(normalized)
			}

			entries = append(entries, entry)
		}

		outPath := filepath.Join(areasDir, typeName+".yml")
		data, err := yaml.Marshal(entries)
		if err != nil {
			return result, fmt.Errorf("marshal %s: %w", typeName, err)
		}
		if err := os.WriteFile(outPath, data, 0o644); err != nil {
			return result, fmt.Errorf("write %s: %w", outPath, err)
		}

		result.TypeCounts[typeName] = len(entries)
		result.TotalAreas += len(entries)
	}

	return result, nil
}

// allAreaConfigsExist checks if all 5 area config files exist in the given directory.
func allAreaConfigsExist(areasDir string) bool {
	for _, areaType := range model.AllAreaTypes() {
		path := filepath.Join(areasDir, areaType.EnglishPlural()+".yml")
		if _, err := os.Stat(path); err != nil {
			return false
		}
	}
	return true
}

// normalizeCoordOrder detects whether polygon coordinates are in [lat, lon] or
// [lon, lat] order and normalizes to [lon, lat] (GeoJSON/GEOS convention).
//
// Detection heuristic for Poland: if the first coordinate's first value is in
// the latitude range for Poland (roughly 49-56), the order is [lat, lon] and
// needs swapping. If it's in the longitude range (14-25), it's already [lon, lat].
func normalizeCoordOrder(coords [][]float64) [][]float64 {
	if len(coords) == 0 {
		return coords
	}

	first := coords[0]
	if len(first) < 2 {
		return coords
	}

	// Poland's latitude range: ~49-55, longitude range: ~14-25
	// If first value > 40, it's likely latitude → needs swap
	if first[0] > 40 {
		result := make([][]float64, len(coords))
		for i, point := range coords {
			result[i] = []float64{point[1], point[0]} // swap to [lon, lat]
		}
		return result
	}

	return coords
}

// computeBBox computes an axis-aligned bounding box from [lon, lat] coordinates.
func computeBBox(coords [][]float64) *bboxOut {
	if len(coords) == 0 {
		return nil
	}

	minLon := math.Inf(1)
	maxLon := math.Inf(-1)
	minLat := math.Inf(1)
	maxLat := math.Inf(-1)

	for _, point := range coords {
		lon, lat := point[0], point[1]
		if lon < minLon {
			minLon = lon
		}
		if lon > maxLon {
			maxLon = lon
		}
		if lat < minLat {
			minLat = lat
		}
		if lat > maxLat {
			maxLat = lat
		}
	}

	return &bboxOut{
		South: minLat,
		North: maxLat,
		West:  minLon,
		East:  maxLon,
	}
}

// tercTypeLabels maps the last digit of a TERC code to a Polish gmina type label.
// Used during slug disambiguation for towns with the same name in the same voivodeship.
var tercTypeLabels = map[byte]string{
	'1': "miejska",         // urban municipality
	'2': "wiejska",         // rural municipality
	'3': "miejsko-wiejska", // urban-rural municipality
}

// disambiguateSlugs resolves slug collisions for areas (towns or counties) using
// a two-pass algorithm matching the Crystal implementation:
//
// Pass 1: For duplicate slugs across voivodeships, append "-{voivodeship}" to ALL
// entries sharing that slug (no first-wins behavior).
//
// Pass 2: For still-colliding slugs (same name + same voivodeship), check if TERC
// last digits are unique in the group. If so, append the type label (-miejska, -wiejska,
// -miejsko-wiejska). If not, fall back to the county slug derived from the TERC prefix.
//
// The counties parameter is used for the county-slug fallback in Pass 2. It can be nil
// if no fallback is needed (e.g., when disambiguating counties themselves).
func disambiguateSlugs(areas []externalArea, counties []externalArea) {
	if len(areas) == 0 {
		return
	}

	// Pass 1: voivodeship disambiguation
	bySlug := groupBySlug(areas)
	for slug, indices := range bySlug {
		if len(indices) <= 1 {
			continue
		}
		for _, idx := range indices {
			voiv := strings.ToLower(areas[idx].Voivodeship)
			if voiv != "" {
				areas[idx].Slug = slug + "-" + voiv
			}
		}
	}

	// Pass 2: type/county disambiguation for remaining collisions
	bySlug2 := groupBySlug(areas)
	for slug, indices := range bySlug2 {
		if len(indices) <= 1 {
			continue
		}

		// Check if TERC last digits are unique within this group
		typeDigits := make(map[byte]bool)
		allHaveTerc := true
		for _, idx := range indices {
			terc := areas[idx].Terc
			if terc == "" {
				allHaveTerc = false
				break
			}
			typeDigits[terc[len(terc)-1]] = true
		}
		typesUnique := allHaveTerc && len(typeDigits) == len(indices)

		for _, idx := range indices {
			terc := areas[idx].Terc
			if terc == "" {
				continue
			}
			if typesUnique {
				lastDigit := terc[len(terc)-1]
				label, ok := tercTypeLabels[lastDigit]
				if !ok {
					label = terc
				}
				areas[idx].Slug = slug + "-" + label
			} else {
				// Fall back to county slug from TERC prefix
				countySlug := countySlugForTerc(terc, counties)
				if countySlug != "" {
					areas[idx].Slug = slug + "-" + countySlug
				} else {
					areas[idx].Slug = slug + "-" + terc
				}
			}
		}
	}
}

// groupBySlug groups area indices by their current slug.
func groupBySlug(areas []externalArea) map[string][]int {
	result := make(map[string][]int)
	for i := range areas {
		result[areas[i].Slug] = append(result[areas[i].Slug], i)
	}
	return result
}

// countySlugForTerc finds the county slug matching the first 4 digits of a town's
// TERC code. County TERC codes are 4 digits that prefix their town's 7-digit codes.
func countySlugForTerc(terc string, counties []externalArea) string {
	if len(terc) < 4 || len(counties) == 0 {
		return ""
	}
	prefix := terc[:4]
	for i := range counties {
		if strings.HasPrefix(counties[i].Terc, prefix) {
			return counties[i].Slug
		}
	}
	return ""
}
