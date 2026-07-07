package view

import (
	"encoding/json"
	"fmt"
	"io"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"odkrywajac/internal/catalog"
	"odkrywajac/internal/geodata"
	"odkrywajac/internal/model"
	"odkrywajac/internal/service/coverage"
	"odkrywajac/internal/service/router"
	"odkrywajac/internal/service/svg"
)

// Coverage map rendering parameters. The map is a small homepage teaser, so
// aggressive simplification is fine — shapes only need to read at ~600 px.
const (
	// coverageMapWidth is the SVG viewBox width in pixels.
	coverageMapWidth = 600.0
	// coverageMapZoom is the Mercator zoom used for projection. Any zoom
	// works since we rescale to the viewBox; 7 keeps intermediate pixel
	// values in a well-conditioned range for Poland.
	coverageMapZoom = 7
	// coverageSimplifyTolerance (degrees) is applied on top of the already
	// simplified config polygons. 0.01° ≈ 1 km — invisible at teaser size,
	// but cuts the SVG payload roughly in half.
	coverageSimplifyTolerance = 0.01
)

// geoJSONFeature is the minimal subset of a GeoJSON Feature we need to read
// polygon geometry from data/config/polygons/<type>/<slug>.json files.
type geoJSONFeature struct {
	Geometry struct {
		Type        string          `json:"type"`
		Coordinates json.RawMessage `json:"coordinates"`
	} `json:"geometry"`
}

// polygonRings extracts the outer rings of a Polygon or MultiPolygon feature
// as [][]float64 lists of [lon, lat] points. Holes are ignored — at teaser
// scale they are invisible and only add payload.
func polygonRings(feature geoJSONFeature) ([][][]float64, error) {
	switch feature.Geometry.Type {
	case "Polygon":
		var rings [][][]float64
		if err := json.Unmarshal(feature.Geometry.Coordinates, &rings); err != nil {
			return nil, err
		}
		if len(rings) == 0 {
			return nil, nil
		}
		return [][][]float64{rings[0]}, nil
	case "MultiPolygon":
		var polys [][][][]float64
		if err := json.Unmarshal(feature.Geometry.Coordinates, &polys); err != nil {
			return nil, err
		}
		var outers [][][]float64
		for _, rings := range polys {
			if len(rings) > 0 {
				outers = append(outers, rings[0])
			}
		}
		return outers, nil
	default:
		return nil, fmt.Errorf("unsupported geometry type %q", feature.Geometry.Type)
	}
}

// loadPolygonRings reads one polygon config file and returns its simplified
// outer rings, or nil when the file is missing (not every area has a
// generated polygon — the caller decides whether that matters).
func loadPolygonRings(polygonConfigDir string, areaType model.AreaType, slug string) ([][][]float64, error) {
	path := filepath.Join(polygonConfigDir, areaType.EnglishPlural(), slug+".json")
	raw, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, err
	}
	var feature geoJSONFeature
	if err := json.Unmarshal(raw, &feature); err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	rings, err := polygonRings(feature)
	if err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	for i, ring := range rings {
		rings[i] = geodata.Simplify(ring, coverageSimplifyTolerance)
	}
	return rings, nil
}

// coverageProjector converts lon/lat to viewBox coordinates: Mercator pixels
// at a fixed zoom, translated and scaled so the full extent fits the width.
type coverageProjector struct {
	minPX, minPY float64
	scale        float64
	height       float64
}

func newCoverageProjector(allRings [][][]float64) coverageProjector {
	var points [][2]float64
	for _, ring := range allRings {
		for _, pt := range ring {
			points = append(points, [2]float64{pt[1], pt[0]}) // lat, lon
		}
	}
	bounds := svg.ComputeMapBounds(points, coverageMapZoom, 0)
	scale := coverageMapWidth / bounds.Width()
	return coverageProjector{
		minPX:  bounds.MinPX,
		minPY:  bounds.MinPY,
		scale:  scale,
		height: bounds.Height() * scale,
	}
}

// pathData builds an SVG path "d" attribute from rings, with coordinates
// rounded to one decimal — sub-pixel precision is wasted bytes here.
func (p coverageProjector) pathData(rings [][][]float64) string {
	var b strings.Builder
	for _, ring := range rings {
		for i, pt := range ring {
			px, py := svg.LatLonToPixel(pt[1], pt[0], coverageMapZoom)
			x := (px - p.minPX) * p.scale
			y := (py - p.minPY) * p.scale
			if i == 0 {
				fmt.Fprintf(&b, "M%.1f %.1f", x, y)
			} else {
				fmt.Fprintf(&b, "L%.1f %.1f", x, y)
			}
		}
		b.WriteString("Z")
	}
	return b.String()
}

// coverageLevelThresholds are the upper score bounds for the 5-step choropleth
// ramp. A visited county with score s gets the lowest level whose threshold it
// does not exceed (>50 falls into the top level). Because a county's score is a
// mean over its whole bounding box, most values land low — hence the compressed
// low-end steps. These are product knobs; tweak freely.
var coverageLevelThresholds = [4]float64{5, 15, 30, 50}

// coverageLevel maps an area score (0–100) to a choropleth step 1–5. Every
// drawn county is at least level 1: it is in AreasWithPosts, so it is "visited"
// even when it has no route/photo geometry to raise its score.
func coverageLevel(score float64) int {
	for level, threshold := range coverageLevelThresholds {
		if score <= threshold {
			return level + 1
		}
	}
	return len(coverageLevelThresholds) + 1
}

// boundsFromRings computes the lat/lon bounding box of polygon rings, whose
// points are [lon, lat] pairs (GeoJSON order).
func boundsFromRings(rings [][][]float64) coverage.Bounds {
	b := coverage.Bounds{
		MinLat: math.Inf(1), MaxLat: math.Inf(-1),
		MinLon: math.Inf(1), MaxLon: math.Inf(-1),
	}
	for _, ring := range rings {
		for _, pt := range ring {
			lon, lat := pt[0], pt[1]
			if lat < b.MinLat {
				b.MinLat = lat
			}
			if lat > b.MaxLat {
				b.MaxLat = lat
			}
			if lon < b.MinLon {
				b.MinLon = lon
			}
			if lon > b.MaxLon {
				b.MaxLon = lon
			}
		}
	}
	return b
}

// CoverageMapSVG bakes the homepage coverage teaser: all 16 voivodeship
// outlines as a base layer, with every visited county (powiat with at least
// one post) shaded on top by how thoroughly it has been explored. The shade
// comes from coverage.ScoreGrid — a 5×5 km grid scored from routes and photos,
// averaged over each county's bounding box (see the coverage package). Rendered
// once at build time to a static SVG the homepage embeds via <img> — no JS, no
// tiles, instant paint. Colors adapt to dark mode via a media query inside the
// SVG (which works even in <img> context).
//
// Polygons are read from polygonConfigDir (data/config/polygons): it holds all
// voivodeships plus exactly the counties that have posts — which is the set we
// shade, so missing county files are skipped without harm.
func CoverageMapSVG(
	data *catalog.SiteData,
	r *router.Router,
	polygonConfigDir string,
) Renderable {
	url := r.CoverageMapSVGURL()

	return NewRawEndpoint(url, false, func(w io.Writer) error {
		voivodeships := data.AreasByType[model.AreaTypeVoivodeship]
		visited := data.AreasWithPosts[model.AreaTypeCounty]

		// Score once from finished posts only: keeps drafts off the public map
		// and makes "published photo" mean a photo actually on the blog.
		var finishedPosts []*model.Post
		for _, post := range data.Posts {
			if post.IsFinished() {
				finishedPosts = append(finishedPosts, post)
			}
		}
		scores := coverage.ScoreGrid(finishedPosts)

		// Deterministic output: render areas in slug order.
		sortAreasBySlug := func(areas []*model.Area) []*model.Area {
			sorted := make([]*model.Area, len(areas))
			copy(sorted, areas)
			sort.Slice(sorted, func(i, j int) bool { return sorted[i].Slug < sorted[j].Slug })
			return sorted
		}

		type shape struct {
			slug  string
			rings [][][]float64
			level int // choropleth step 1–5; 0 for the voivodeship base layer
		}

		loadShapes := func(areaType model.AreaType, areas []*model.Area, scored bool) ([]shape, error) {
			var shapes []shape
			for _, area := range sortAreasBySlug(areas) {
				rings, err := loadPolygonRings(polygonConfigDir, areaType, area.Slug)
				if err != nil {
					return nil, err
				}
				if rings == nil {
					continue
				}
				s := shape{slug: area.Slug, rings: rings}
				if scored {
					s.level = coverageLevel(scores.AreaScore(boundsFromRings(rings)))
				}
				shapes = append(shapes, s)
			}
			return shapes, nil
		}

		base, err := loadShapes(model.AreaTypeVoivodeship, voivodeships, false)
		if err != nil {
			return err
		}
		counties, err := loadShapes(model.AreaTypeCounty, visited, true)
		if err != nil {
			return err
		}
		if len(base) == 0 {
			return fmt.Errorf("coverage map: no voivodeship polygons in %s", polygonConfigDir)
		}

		// Project everything against the voivodeship extent (all of Poland),
		// so counties land in the same coordinate space.
		var allRings [][][]float64
		for _, s := range base {
			allRings = append(allRings, s.rings...)
		}
		projector := newCoverageProjector(allRings)

		fmt.Fprintf(w,
			`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %.0f %.0f" role="img" aria-label="Mapa Polski z powiatami pokolorowanymi według stopnia poznania">`,
			coverageMapWidth, projector.height)
		// 5-step teal ramp (light→dark = less→more explored), plus the gray
		// voivodeship base. The SVG is loaded via <img> and cannot see page CSS
		// variables, so colors and the dark-mode override live here.
		io.WriteString(w, `<style>`+
			`.w{fill:#eceeec;stroke:#fff;stroke-width:1}`+
			`.cov1{fill:#d3ebee}.cov2{fill:#a5d7dd}.cov3{fill:#66b8c2}.cov4{fill:#3d97a3}.cov5{fill:#1f6b76}`+
			`path[class^=cov]{stroke:#fff;stroke-width:.5}`+
			`@media (prefers-color-scheme:dark){`+
			`.w{fill:#242626;stroke:#141414}`+
			`.cov1{fill:#1e3b3f}.cov2{fill:#275a61}.cov3{fill:#357f89}.cov4{fill:#48a5b3}.cov5{fill:#63d0df}`+
			`path[class^=cov]{stroke:#141414}}`+
			`</style>`)
		for _, s := range base {
			fmt.Fprintf(w, `<path class="w" d="%s"/>`, projector.pathData(s.rings))
		}
		for _, s := range counties {
			fmt.Fprintf(w, `<path class="cov%d" d="%s"/>`, s.level, projector.pathData(s.rings))
		}
		_, err = io.WriteString(w, `</svg>`)
		return err
	})
}
