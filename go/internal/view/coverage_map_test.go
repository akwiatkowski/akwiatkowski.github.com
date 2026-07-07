package view

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"odkrywajac/internal/catalog"
	"odkrywajac/internal/model"
	"odkrywajac/internal/service/router"
)

// writeTestPolygon writes a minimal GeoJSON Feature file the way
// data/config/polygons/<type>/<slug>.json is laid out.
func writeTestPolygon(t *testing.T, dir, areaType, slug, geometry string) {
	t.Helper()
	path := filepath.Join(dir, areaType, slug+".json")
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	content := `{"type":"Feature","properties":{"slug":"` + slug + `"},"geometry":` + geometry + `}`
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

func coverageTestSiteData() *catalog.SiteData {
	finished := time.Date(2021, 7, 19, 0, 0, 0, 0, time.UTC)
	posts := []*model.Post{
		{
			Slug:       "2021-07-18-test",
			Title:      "Test",
			Date:       time.Date(2021, 7, 18, 0, 0, 0, 0, time.UTC),
			FinishedAt: &finished,
			SpatialAreaSlugs: map[model.AreaType][]string{
				model.AreaTypeCounty: {"poznanski"},
			},
		},
	}
	areas := []*model.Area{
		{Slug: "wielkopolskie", Name: "Wielkopolskie", Type: model.AreaTypeVoivodeship},
		{Slug: "poznanski", Name: "poznański", Type: model.AreaTypeCounty},
		{Slug: "gnieznienski", Name: "gnieźnieński", Type: model.AreaTypeCounty}, // unvisited
	}
	cfg := model.SiteConfig{Title: "Test", URL: "https://example.com"}
	return catalog.BuildSiteData(posts, nil, nil, areas, cfg, nil, nil, nil)
}

func TestCoverageMapSVG_RendersBaseAndVisited(t *testing.T) {
	dir := t.TempDir()
	// Rough Wielkopolska bounding shape and two county boxes inside it.
	writeTestPolygon(t, dir, "voivodeships", "wielkopolskie",
		`{"type":"Polygon","coordinates":[[[16.0,51.5],[19.0,51.5],[19.0,53.5],[16.0,53.5],[16.0,51.5]]]}`)
	writeTestPolygon(t, dir, "counties", "poznanski",
		`{"type":"Polygon","coordinates":[[[16.6,52.2],[17.3,52.2],[17.3,52.6],[16.6,52.6],[16.6,52.2]]]}`)
	writeTestPolygon(t, dir, "counties", "gnieznienski",
		`{"type":"Polygon","coordinates":[[[17.4,52.3],[17.8,52.3],[17.8,52.7],[17.4,52.7],[17.4,52.3]]]}`)

	data := coverageTestSiteData()
	r := router.New("https://example.com")
	page := CoverageMapSVG(data, r, dir)

	if page.URL() != "/maps/pokrycie_powiatow.svg" {
		t.Errorf("URL() = %q, want /maps/pokrycie_powiatow.svg", page.URL())
	}
	if page.AddToSitemap() {
		t.Error("coverage map SVG should not be in the sitemap")
	}

	var buf bytes.Buffer
	if err := page.Render(&buf); err != nil {
		t.Fatal(err)
	}
	svg := buf.String()

	if !strings.HasPrefix(svg, "<svg") || !strings.HasSuffix(svg, "</svg>") {
		t.Fatalf("output is not an SVG document: %.80s...", svg)
	}
	// One base path (voivodeship) + one visited county — the unvisited
	// county must NOT be drawn even though its polygon file exists.
	if got := strings.Count(svg, `class="w"`); got != 1 {
		t.Errorf("base paths = %d, want 1", got)
	}
	// The visited county has no route/photo geometry, so it scores 0 and lands
	// at the lowest choropleth level (still drawn, since it is "visited").
	if got := strings.Count(svg, `class="cov`); got != 1 {
		t.Errorf("scored county paths = %d, want 1", got)
	}
	if !strings.Contains(svg, `class="cov1"`) {
		t.Error("geometry-less visited county should render at level cov1")
	}
	// Dark-mode palette must ship inside the SVG (it is loaded via <img>,
	// so it cannot inherit page CSS).
	if !strings.Contains(svg, "prefers-color-scheme:dark") {
		t.Error("SVG missing embedded dark-mode style")
	}
}

func TestCoverageMapSVG_ShadesByScore(t *testing.T) {
	dir := t.TempDir()
	writeTestPolygon(t, dir, "voivodeships", "wielkopolskie",
		`{"type":"Polygon","coordinates":[[[16.0,51.5],[19.0,51.5],[19.0,53.5],[16.0,53.5],[16.0,51.5]]]}`)
	writeTestPolygon(t, dir, "counties", "poznanski",
		`{"type":"Polygon","coordinates":[[[16.6,52.2],[17.3,52.2],[17.3,52.6],[16.6,52.6],[16.6,52.2]]]}`)

	// A finished post whose hike route densely fills the poznanski bbox: many
	// scored cells → a high average → a top-tier choropleth level.
	finished := time.Date(2021, 7, 19, 0, 0, 0, 0, time.UTC)
	var seg []model.LatLon
	for lat := 52.2; lat <= 52.6; lat += 0.01 {
		for lon := 16.6; lon <= 17.3; lon += 0.01 {
			seg = append(seg, model.LatLon{Lat: lat, Lon: lon})
		}
	}
	post := &model.Post{
		Slug:       "2021-07-18-densehike",
		Date:       time.Date(2021, 7, 18, 0, 0, 0, 0, time.UTC),
		FinishedAt: &finished,
		Routes:     []model.Route{{Type: "hike", Segments: [][]model.LatLon{seg}}},
		SpatialAreaSlugs: map[model.AreaType][]string{
			model.AreaTypeCounty: {"poznanski"},
		},
	}
	areas := []*model.Area{
		{Slug: "wielkopolskie", Name: "Wielkopolskie", Type: model.AreaTypeVoivodeship},
		{Slug: "poznanski", Name: "poznański", Type: model.AreaTypeCounty},
	}
	data := catalog.BuildSiteData([]*model.Post{post}, nil, nil, areas,
		model.SiteConfig{Title: "Test", URL: "https://example.com"}, nil, nil, nil)

	var buf bytes.Buffer
	if err := CoverageMapSVG(data, router.New("https://example.com"), dir).Render(&buf); err != nil {
		t.Fatal(err)
	}
	// The route covers essentially the whole county bbox with hike (base 80),
	// so the average clears the top threshold → cov5.
	if got := buf.String(); !strings.Contains(got, `class="cov5"`) {
		t.Errorf("densely hiked county should render at level cov5; got %s", got)
	}
}

func TestCoverageMapSVG_SkipsMissingCountyPolygons(t *testing.T) {
	dir := t.TempDir()
	writeTestPolygon(t, dir, "voivodeships", "wielkopolskie",
		`{"type":"Polygon","coordinates":[[[16.0,51.5],[19.0,51.5],[19.0,53.5],[16.0,53.5],[16.0,51.5]]]}`)
	// No county polygon file for the visited county — must render without error.

	data := coverageTestSiteData()
	r := router.New("https://example.com")

	var buf bytes.Buffer
	if err := CoverageMapSVG(data, r, dir).Render(&buf); err != nil {
		t.Fatal(err)
	}
	if got := strings.Count(buf.String(), `class="cov`); got != 0 {
		t.Errorf("visited county paths = %d, want 0 (polygon file missing)", got)
	}
}

func TestCoverageMapSVG_FailsWithoutVoivodeships(t *testing.T) {
	data := coverageTestSiteData()
	r := router.New("https://example.com")

	var buf bytes.Buffer
	if err := CoverageMapSVG(data, r, t.TempDir()).Render(&buf); err == nil {
		t.Error("expected error when no voivodeship polygons exist")
	}
}

func TestPolygonRings_MultiPolygon(t *testing.T) {
	// polygonRings must handle MultiPolygon geometries (coastal voivodeships).
	feature := geoJSONFeature{}
	feature.Geometry.Type = "MultiPolygon"
	feature.Geometry.Coordinates = []byte(`[[[[16.0,51.5],[17.0,51.5],[17.0,52.5],[16.0,51.5]]],[[[18.0,53.0],[18.5,53.0],[18.5,53.5],[18.0,53.0]]]]`)
	rings, err := polygonRings(feature)
	if err != nil {
		t.Fatal(err)
	}
	if len(rings) != 2 {
		t.Errorf("MultiPolygon outer rings = %d, want 2", len(rings))
	}
}
