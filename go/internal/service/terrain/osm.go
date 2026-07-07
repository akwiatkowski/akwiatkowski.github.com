package terrain

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"github.com/paulmach/orb"
)

// osmFeature is one OSM geometry with its flattened tag set (dedicated GDAL
// columns merged with the parsed other_tags hstore).
type osmFeature struct {
	geom orb.Geometry
	tags map[string]string
}

// tag returns the value of a tag, or "" if absent.
func (f osmFeature) tag(key string) string { return f.tags[key] }

// has reports whether a tag is present (any value).
func (f osmFeature) has(key string) bool { _, ok := f.tags[key]; return ok }

// osmData holds the three OSM layers relevant to cartography, in draw-independent
// form. Multipolygons carry area features (landcover, water, buildings), lines
// carry roads/paths/waterways/railways, points carry peaks and place labels.
type osmData struct {
	polygons []osmFeature
	lines    []osmFeature
	points   []osmFeature
}

// loadOSM extracts the lat/lon bounding box (expanded by marginDeg) from the
// Poland PBF and returns the parsed OSM layers. Results are cached on disk keyed
// by the rounded bbox so repeated renders of the same post skip the ~8s
// osmium+ogr2ogr step.
func loadOSM(latMin, latMax, lonMin, lonMax float64, pbfPath string, marginDeg float64, cacheDir string) (*osmData, error) {
	west := lonMin - marginDeg
	south := latMin - marginDeg
	east := lonMax + marginDeg
	north := latMax + marginDeg

	// Cache key from the rounded extent (4dp ≈ 11m — plenty stable).
	key := fmt.Sprintf("%.4f_%.4f_%.4f_%.4f", west, south, east, north)
	sum := sha256.Sum256([]byte(key))
	dir := filepath.Join(cacheDir, fmt.Sprintf("%x", sum[:8]))
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return nil, fmt.Errorf("create osm cache dir: %w", err)
	}

	mpJSON := filepath.Join(dir, "multipolygons.geojson")
	lnJSON := filepath.Join(dir, "lines.geojson")
	ptJSON := filepath.Join(dir, "points.geojson")

	if !allExist(mpJSON, lnJSON, ptJSON) {
		if err := extractOSMLayers(pbfPath, dir, west, south, east, north, mpJSON, lnJSON, ptJSON); err != nil {
			return nil, err
		}
	}

	polygons, err := loadFeatures(mpJSON)
	if err != nil {
		return nil, err
	}
	lines, err := loadFeatures(lnJSON)
	if err != nil {
		return nil, err
	}
	points, err := loadFeatures(ptJSON)
	if err != nil {
		return nil, err
	}
	return &osmData{polygons: polygons, lines: lines, points: points}, nil
}

// extractOSMLayers clips the bbox with osmium and converts the three OSM layers
// to GeoJSON with GDAL's OSM driver (which assembles multipolygon relations —
// forests with holes, lakes — that raw node/way reading cannot).
func extractOSMLayers(pbfPath, dir string, west, south, east, north float64, mpJSON, lnJSON, ptJSON string) error {
	if _, err := os.Stat(pbfPath); err != nil {
		return fmt.Errorf("OSM source PBF not found at %s: %w", pbfPath, err)
	}
	extract := filepath.Join(dir, "extract.osm.pbf")

	// osmium bbox order is left,bottom,right,top (lon/lat).
	if err := runTool("osmium", "extract",
		"-b", fmt.Sprintf("%.5f,%.5f,%.5f,%.5f", west, south, east, north),
		pbfPath, "-o", extract, "--overwrite",
	); err != nil {
		return err
	}
	defer os.Remove(extract)

	layers := []struct {
		name, out string
	}{
		{"multipolygons", mpJSON},
		{"lines", lnJSON},
		{"points", ptJSON},
	}
	for _, l := range layers {
		// -skipfailures tolerates the occasional unclosed ring in OSM data.
		if err := runTool("ogr2ogr", "-f", "GeoJSON", "-skipfailures", l.out, extract, l.name); err != nil {
			return fmt.Errorf("ogr2ogr %s: %w", l.name, err)
		}
	}
	return nil
}

// geojsonFC is a minimal GeoJSON FeatureCollection decoder. We avoid
// orb/geojson because its BSON codec pulls in the heavy mongo-driver dependency;
// we only need the geometry and properties.
type geojsonFC struct {
	Features []struct {
		Properties map[string]any `json:"properties"`
		Geometry   *struct {
			Type        string          `json:"type"`
			Coordinates json.RawMessage `json:"coordinates"`
		} `json:"geometry"`
	} `json:"features"`
}

// loadFeatures decodes a GeoJSON file into osmFeatures with a flattened tag map.
func loadFeatures(path string) ([]osmFeature, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read %s: %w", path, err)
	}
	var fc geojsonFC
	if err := json.Unmarshal(raw, &fc); err != nil {
		return nil, fmt.Errorf("parse %s: %w", path, err)
	}
	out := make([]osmFeature, 0, len(fc.Features))
	for _, f := range fc.Features {
		if f.Geometry == nil {
			continue
		}
		geom, ok := buildGeometry(f.Geometry.Type, f.Geometry.Coordinates)
		if !ok {
			continue
		}
		out = append(out, osmFeature{geom: geom, tags: flattenTags(f.Properties)})
	}
	return out, nil
}

// buildGeometry converts a GeoJSON geometry type + raw coordinates into the
// corresponding orb geometry. Only the types we render are handled.
func buildGeometry(typ string, coords json.RawMessage) (orb.Geometry, bool) {
	switch typ {
	case "Point":
		var c [2]float64
		if json.Unmarshal(coords, &c) == nil {
			return orb.Point{c[0], c[1]}, true
		}
	case "LineString":
		var c [][2]float64
		if json.Unmarshal(coords, &c) == nil {
			return toLineString(c), true
		}
	case "MultiLineString":
		var c [][][2]float64
		if json.Unmarshal(coords, &c) == nil {
			mls := make(orb.MultiLineString, len(c))
			for i, ls := range c {
				mls[i] = toLineString(ls)
			}
			return mls, true
		}
	case "Polygon":
		var c [][][2]float64
		if json.Unmarshal(coords, &c) == nil {
			return toPolygon(c), true
		}
	case "MultiPolygon":
		var c [][][][2]float64
		if json.Unmarshal(coords, &c) == nil {
			mp := make(orb.MultiPolygon, len(c))
			for i, poly := range c {
				mp[i] = toPolygon(poly)
			}
			return mp, true
		}
	}
	return nil, false
}

func toLineString(c [][2]float64) orb.LineString {
	ls := make(orb.LineString, len(c))
	for i, p := range c {
		ls[i] = orb.Point{p[0], p[1]}
	}
	return ls
}

func toPolygon(c [][][2]float64) orb.Polygon {
	poly := make(orb.Polygon, len(c))
	for i, ring := range c {
		r := make(orb.Ring, len(ring))
		for j, p := range ring {
			r[j] = orb.Point{p[0], p[1]}
		}
		poly[i] = r
	}
	return poly
}

// flattenTags merges GDAL's dedicated tag columns with the parsed other_tags
// hstore into a single map. osm_id and other_tags themselves are dropped.
func flattenTags(props map[string]any) map[string]string {
	tags := make(map[string]string)
	for k, v := range props {
		switch k {
		case "osm_id", "osm_way_id", "other_tags":
			continue
		}
		if s, ok := v.(string); ok && s != "" {
			tags[k] = s
		}
	}
	if ot, ok := props["other_tags"].(string); ok && ot != "" {
		for k, v := range parseHstore(ot) {
			if _, exists := tags[k]; !exists {
				tags[k] = v
			}
		}
	}
	return tags
}

// parseHstore parses GDAL's hstore encoding of OSM tags: `"key"=>"value",...`
// with backslash-escaped quotes inside values. It is tolerant of malformed
// input, returning whatever pairs it could read.
func parseHstore(s string) map[string]string {
	out := make(map[string]string)
	runes := []rune(s)
	i := 0
	readQuoted := func() (string, bool) {
		if i >= len(runes) || runes[i] != '"' {
			return "", false
		}
		i++ // opening quote
		var sb []rune
		for i < len(runes) {
			c := runes[i]
			if c == '\\' && i+1 < len(runes) {
				sb = append(sb, runes[i+1])
				i += 2
				continue
			}
			if c == '"' {
				i++ // closing quote
				return string(sb), true
			}
			sb = append(sb, c)
			i++
		}
		return string(sb), false
	}
	for i < len(runes) {
		for i < len(runes) && (runes[i] == ' ' || runes[i] == ',') {
			i++
		}
		key, ok := readQuoted()
		if !ok {
			break
		}
		// expect =>
		for i < len(runes) && (runes[i] == '=' || runes[i] == '>' || runes[i] == ' ') {
			i++
		}
		val, ok := readQuoted()
		if !ok {
			break
		}
		out[key] = val
	}
	return out
}

// allExist reports whether every named file exists.
func allExist(paths ...string) bool {
	for _, p := range paths {
		if _, err := os.Stat(p); err != nil {
			return false
		}
	}
	return true
}
