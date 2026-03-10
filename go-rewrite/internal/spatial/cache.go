package spatial

import (
	"fmt"
	"math"
	"os"
	"path/filepath"
	"sort"

	"gopkg.in/yaml.v3"
)

// cacheSegment is the YAML structure for one route segment in areas_for_post/*.yml.
// It matches the Crystal-generated format for backward compatibility.
type cacheSegment struct {
	Type           string             `yaml:"type"`
	TotalDistanceM float64           `yaml:"total_distance_meters"`
	TotalDistanceKm float64          `yaml:"total_distance_km"`
	PointsCount    float64           `yaml:"points_count"` // Crystal writes as float
	Towns          []cacheAreaDist   `yaml:"towns,omitempty"`
	Counties       []cacheAreaDist   `yaml:"counties,omitempty"`
	Voivodeships   []cacheAreaDist   `yaml:"voivodeships,omitempty"`
	MesoRegions    []cacheAreaDist   `yaml:"meso_regions,omitempty"`
	MacroRegions   []cacheAreaDist   `yaml:"macro_regions,omitempty"`
	TouchedTowns       []cacheAreaRef `yaml:"touched_towns,omitempty"`
	TouchedCounties    []cacheAreaRef `yaml:"touched_counties,omitempty"`
	TouchedVoivodeships []cacheAreaRef `yaml:"touched_voivodeships,omitempty"`
	TouchedMesoRegions []cacheAreaRef `yaml:"touched_meso_regions,omitempty"`
	TouchedMacroRegions []cacheAreaRef `yaml:"touched_macro_regions,omitempty"`
}

// cacheAreaDist is the YAML structure for an area with distance info.
type cacheAreaDist struct {
	Slug           string  `yaml:"slug"`
	Name           string  `yaml:"name"`
	Code           string  `yaml:"code"`
	DistanceM      float64 `yaml:"distance_meters"`
	DistanceKm     float64 `yaml:"distance_km"`
	DistancePercent float64 `yaml:"distance_percent"`
}

// cacheAreaRef is the YAML structure for an area reference (no distance).
type cacheAreaRef struct {
	Slug string `yaml:"slug"`
	Name string `yaml:"name"`
	Code string `yaml:"code"`
}

// WriteRouteCoverage writes a route matching result to cache as YAML in Crystal-compatible format.
// File path: {cacheDir}/{postSlug}.yml
func WriteRouteCoverage(cacheDir, postSlug string, result *RouteResult) error {
	if err := os.MkdirAll(cacheDir, 0o755); err != nil {
		return fmt.Errorf("create cache dir: %w", err)
	}

	segments := make([]cacheSegment, 0, len(result.Segments))
	for _, seg := range result.Segments {
		cs := cacheSegment{
			Type:            seg.Type,
			TotalDistanceM:  roundM(seg.TotalDistanceM),
			TotalDistanceKm: roundKm(seg.TotalDistanceM),
			PointsCount:     float64(seg.PointsCount),
			Towns:           toAreaDists(seg.Towns),
			Counties:        toAreaDists(seg.Counties),
			Voivodeships:    toAreaDists(seg.Voivodeships),
			MesoRegions:     toAreaDists(seg.MesoRegions),
			MacroRegions:    toAreaDists(seg.MacroRegions),
			TouchedTowns:       toAreaRefs(seg.TouchedTowns),
			TouchedCounties:    toAreaRefs(seg.TouchedCounties),
			TouchedVoivodeships: toAreaRefs(seg.TouchedVoivodeships),
			TouchedMesoRegions: toAreaRefs(seg.TouchedMesoRegions),
			TouchedMacroRegions: toAreaRefs(seg.TouchedMacroRegions),
		}
		segments = append(segments, cs)
	}

	data, err := yaml.Marshal(segments)
	if err != nil {
		return fmt.Errorf("marshal YAML: %w", err)
	}

	// Prepend YAML document separator like Crystal does
	content := append([]byte("---\n"), data...)

	path := filepath.Join(cacheDir, postSlug+".yml")
	return os.WriteFile(path, content, 0o644)
}

// WritePhotosInArea writes photo→area assignments to per-area YAML cache files.
// Each file is at {cacheDir}/{typePlural}/{slug}.yml containing a list of PhotoRefs.
func WritePhotosInArea(cacheDir string, assignments map[AreaKey][]PhotoRef) error {
	for areaKey, photos := range assignments {
		typeDir := filepath.Join(cacheDir, areaKey.TypePlural)
		if err := os.MkdirAll(typeDir, 0o755); err != nil {
			return fmt.Errorf("create dir %s: %w", typeDir, err)
		}

		// Sort photos by filename for deterministic output
		sort.Slice(photos, func(i, j int) bool {
			if photos[i].PostSlug != photos[j].PostSlug {
				return photos[i].PostSlug < photos[j].PostSlug
			}
			return photos[i].Filename < photos[j].Filename
		})

		data, err := yaml.Marshal(photos)
		if err != nil {
			return fmt.Errorf("marshal YAML for %s/%s: %w", areaKey.TypePlural, areaKey.Slug, err)
		}

		content := append([]byte("---\n"), data...)
		path := filepath.Join(typeDir, areaKey.Slug+".yml")
		if err := os.WriteFile(path, content, 0o644); err != nil {
			return fmt.Errorf("write %s: %w", path, err)
		}
	}

	return nil
}

// IsRouteCoverageStale checks if the cached route coverage for a post needs regeneration.
// Returns true if the cache file is missing or older than any of the route source files.
func IsRouteCoverageStale(cacheDir, postSlug string, routePaths []string) bool {
	cachePath := filepath.Join(cacheDir, postSlug+".yml")
	cacheInfo, err := os.Stat(cachePath)
	if err != nil {
		return true // cache file doesn't exist
	}

	cacheMtime := cacheInfo.ModTime()
	for _, routePath := range routePaths {
		routeInfo, err := os.Stat(routePath)
		if err != nil {
			continue
		}
		if routeInfo.ModTime().After(cacheMtime) {
			return true // route file is newer than cache
		}
	}

	return false
}

// toAreaDists converts AreaDistance slice to cache-compatible format.
func toAreaDists(ads []AreaDistance) []cacheAreaDist {
	if len(ads) == 0 {
		return nil
	}
	result := make([]cacheAreaDist, len(ads))
	for i, ad := range ads {
		result[i] = cacheAreaDist(ad)
	}
	return result
}

// toAreaRefs converts AreaRef slice to cache-compatible format.
func toAreaRefs(refs []AreaRef) []cacheAreaRef {
	if len(refs) == 0 {
		return nil
	}
	result := make([]cacheAreaRef, len(refs))
	for i, ref := range refs {
		result[i] = cacheAreaRef(ref)
	}
	return result
}

// roundM rounds meters to 2 decimal places.
func roundM(m float64) float64 {
	return math.Round(m*100) / 100
}

// roundKm converts meters to km rounded to 3 decimal places.
func roundKm(m float64) float64 {
	return math.Round(m/1000*1000) / 1000
}
