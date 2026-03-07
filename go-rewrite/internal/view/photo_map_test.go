package view

import (
	"bytes"
	"strings"
	"testing"
	"time"

	"odkrywajac/internal/index"
	"odkrywajac/internal/model"
	svgpkg "odkrywajac/internal/svg"
)

func testSiteDataForPhotoMaps() *index.SiteData {
	fin := time.Date(2021, 7, 19, 0, 0, 0, 0, time.UTC)
	photoTime := time.Date(2021, 7, 18, 10, 0, 0, 0, time.UTC)
	lat, lon := 52.4, 16.9
	posts := []*model.Post{
		{
			Slug:       "pagorki",
			Title:      "Pagórki",
			Date:       time.Date(2021, 7, 18, 0, 0, 0, 0, time.UTC),
			FinishedAt: &fin,
			TagSlugs:   []string{"bicycle"},
			TownSlugs:  []string{"pobiedziska"},
			Routes: []model.Route{
				{
					Type: "bicycle",
					Segments: [][]model.LatLon{
						{{Lat: 52.4, Lon: 16.9}, {Lat: 52.41, Lon: 16.91}, {Lat: 52.42, Lon: 16.92}},
					},
				},
			},
			PhotoEntities: []*model.Photo{
				{
					ImageFilename: "photo1.jpg",
					PostSlug:      "pagorki",
					Desc:          "Test photo",
					IsTimeline:    true,
					Exif: &model.ExifData{
						Lat:  &lat,
						Lon:  &lon,
						Time: &photoTime,
					},
				},
			},
		},
	}
	areas := []*model.Area{
		{Slug: "wielkopolskie", Name: "Wielkopolskie", Type: model.AreaTypeVoivodeship,
			BBox: &model.BBox{South: 51.0, North: 53.0, West: 15.5, East: 18.5}},
	}
	cfg := model.SiteConfig{Title: "Test"}
	return index.BuildSiteData(posts, nil, nil, areas, cfg, nil, nil, nil)
}

func TestGlobalMapSVGs(t *testing.T) {
	data := testSiteDataForPhotoMaps()
	svgs := GlobalMapSVGs(data)

	if len(svgs) != len(globalMapVariants) {
		t.Errorf("got %d SVGs, want %d", len(svgs), len(globalMapVariants))
	}

	// Check first variant renders
	var buf bytes.Buffer
	if err := svgs[0].Render(&buf); err != nil {
		t.Fatal(err)
	}
	output := buf.String()
	if !strings.Contains(output, "<svg") {
		t.Error("output should contain <svg element")
	}
	if !strings.Contains(output, "UMP-pcPL") {
		t.Error("output should contain UMP attribution")
	}
}

func TestVoivodeshipMapSVGs(t *testing.T) {
	data := testSiteDataForPhotoMaps()
	svgs := VoivodeshipMapSVGs(data)

	// Should not create maps for voivodeships without posts
	// Wielkopolskie has posts via town slug matching
	// At minimum, check it doesn't panic
	_ = svgs
}

func TestPostMapSVGs(t *testing.T) {
	data := testSiteDataForPhotoMaps()

	svgs := PostMapSVGs(data, nil)

	if len(svgs) != 2 { // big + small per post with routes
		t.Errorf("got %d SVGs, want 2", len(svgs))
	}

	// Render big map
	var buf bytes.Buffer
	if err := svgs[0].Render(&buf); err != nil {
		t.Fatal(err)
	}

	output := buf.String()
	if !strings.Contains(output, "photo-map-route") {
		t.Error("big map should contain route elements")
	}
}

func TestTagMapSVGs(t *testing.T) {
	data := testSiteDataForPhotoMaps()
	svgs := TagMapSVGs(data)

	// "bicycle" tag has posts
	found := false
	for _, s := range svgs {
		if s.URL() == "/mapa_zdjec/tagu/bicycle.svg" {
			found = true
			break
		}
	}
	if !found {
		t.Error("expected bicycle tag map")
	}
}

func TestSvgMapViewInputHash(t *testing.T) {
	data := testSiteDataForPhotoMaps()
	svgs := GlobalMapSVGs(data)

	// All views should implement InputHasher
	for _, s := range svgs {
		ih, ok := s.(InputHasher)
		if !ok {
			t.Fatalf("SvgMapView should implement InputHasher")
		}
		hash := ih.InputHash()
		if hash == "" {
			t.Error("InputHash should not be empty")
		}
		// Same inputs should produce same hash
		if ih.InputHash() != hash {
			t.Error("InputHash should be deterministic")
		}
	}

	// Different configs should produce different hashes
	if len(svgs) >= 2 {
		h1 := svgs[0].(*svgpkg.SvgMapView).InputHash()
		h2 := svgs[1].(*svgpkg.SvgMapView).InputHash()
		if h1 == h2 {
			t.Error("different map variants should have different hashes")
		}
	}
}
