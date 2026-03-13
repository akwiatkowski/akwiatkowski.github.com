package view

import (
	"bytes"
	"strings"
	"testing"
	"time"

	"odkrywajac/internal/index"
	"odkrywajac/internal/model"
	"odkrywajac/internal/router"
)

func testSiteDataWithPhotos() *index.SiteData {
	fin := time.Date(2021, 7, 19, 0, 0, 0, 0, time.UTC)
	lat, lon := 52.4, 16.9
	posts := []*model.Post{
		{
			Slug:       "2021-07-18-pagorki",
			Title:      "Pagórki przed żniwami",
			Date:       time.Date(2021, 7, 18, 0, 0, 0, 0, time.UTC),
			FinishedAt: &fin,
			TagSlugs:   []string{"bicycle"},
			Distance:   42.0,
			Routes: []model.Route{
				{Type: "bicycle", Segments: [][]model.LatLon{{{Lat: 52.4, Lon: 16.9}, {Lat: 52.5, Lon: 17.0}}}},
			},
			PublishedPhotos: []*model.Photo{
				{
					ImageFilename: "photo1.jpg",
					PostSlug:      "2021-07-18-pagorki",
					Desc:          "Beautiful sunset over fields",
					Points:        5,
					TagSlugs:      []string{"best"},
					Exif: &model.ExifData{
						Lat:           &lat,
						Lon:           &lon,
						CameraName:    "Sony A7III",
						LensName:      "24-70mm f/2.8",
						FocalLength35: func() *float64 { f := 50.0; return &f }(),
					},
				},
				{
					ImageFilename: "photo2.jpg",
					PostSlug:      "2021-07-18-pagorki",
					Desc:          "Road through wheat",
					Points:        3,
				},
			},
		},
	}
	stations := []model.TrainStation{
		{Name: "Pobiedziska", Lat: 52.47, Lon: 17.28, TimeDistance: map[string]float64{"Poznań": 0.5}},
	}

	return index.BuildSiteData(posts, nil, nil, nil,
		model.SiteConfig{Title: "Test", URL: "https://example.com"},
		nil, stations,
	)
}

func TestMapJSON(t *testing.T) {
	data := testSiteDataWithPhotos()
	rtr := router.New("https://example.com")

	endpoint := MapJSON(data, rtr)
	if endpoint.URL() != "/jsons/map.json" {
		t.Errorf("URL() = %q", endpoint.URL())
	}

	var buf bytes.Buffer
	if err := endpoint.Render(&buf); err != nil {
		t.Fatal(err)
	}

	json := buf.String()
	checks := []string{"pagorki", "52.4", "16.9", "bicycle"}
	for _, check := range checks {
		if !strings.Contains(json, check) {
			t.Errorf("map JSON missing %q", check)
		}
	}
}

func TestPhotosJSON(t *testing.T) {
	data := testSiteDataWithPhotos()
	rtr := router.New("https://example.com")

	endpoint := PhotosJSON(data, rtr)
	if endpoint.URL() != "/jsons/photos.json" {
		t.Errorf("URL() = %q", endpoint.URL())
	}

	var buf bytes.Buffer
	if err := endpoint.Render(&buf); err != nil {
		t.Fatal(err)
	}

	json := buf.String()
	// Should contain photo with GPS and EXIF
	checks := []string{
		"Beautiful sunset over fields",
		"Sony A7III",
		"24-70mm f/2.8",
		"photo1.jpg",
	}
	for _, check := range checks {
		if !strings.Contains(json, check) {
			t.Errorf("photos JSON missing %q", check)
		}
	}
	// photo2 has short desc but 18 chars - should be included
	if !strings.Contains(json, "Road through wheat") {
		t.Error("photos JSON missing photo2")
	}
}

func TestPhotosMapJSON(t *testing.T) {
	data := testSiteDataWithPhotos()
	rtr := router.New("https://example.com")

	endpoint := PhotosMapJSON(data, rtr)
	if endpoint.URL() != "/jsons/photos_map.json" {
		t.Errorf("URL() = %q", endpoint.URL())
	}

	var buf bytes.Buffer
	if err := endpoint.Render(&buf); err != nil {
		t.Fatal(err)
	}

	json := buf.String()
	// Should contain photo1 (has GPS) but not photo2 (no GPS)
	if !strings.Contains(json, "photo1.jpg") {
		t.Error("photos map should contain GPS-tagged photo")
	}
	if strings.Contains(json, "photo2.jpg") {
		t.Error("photos map should not contain non-GPS photo")
	}
}

func TestTrainStationsJSON(t *testing.T) {
	data := testSiteDataWithPhotos()
	rtr := router.New("https://example.com")

	endpoint := TrainStationsJSON(data, rtr)
	if endpoint.URL() != "/jsons/train_stations.json" {
		t.Errorf("URL() = %q", endpoint.URL())
	}

	var buf bytes.Buffer
	if err := endpoint.Render(&buf); err != nil {
		t.Fatal(err)
	}

	json := buf.String()
	if !strings.Contains(json, "Pobiedziska") {
		t.Error("train stations JSON should contain station name")
	}
	if !strings.Contains(json, "0.5") {
		t.Error("train stations JSON should contain time distance")
	}
}

func TestPhotoGridJSON(t *testing.T) {
	data := testSiteDataWithPhotos()
	rtr := router.New("https://example.com")

	endpoint := PhotoGridJSON(data, rtr)
	if endpoint.URL() != "/jsons/photo_grid.json" {
		t.Errorf("URL() = %q", endpoint.URL())
	}

	var buf bytes.Buffer
	if err := endpoint.Render(&buf); err != nil {
		t.Fatal(err)
	}

	json := buf.String()
	if !strings.Contains(json, "52.4") {
		t.Error("photo grid should contain lat coordinate")
	}
	if !strings.Contains(json, "16.9") {
		t.Error("photo grid should contain lon coordinate")
	}
}

func TestIdeasJSON(t *testing.T) {
	rtr := router.New("https://example.com")

	endpoint := IdeasJSON(rtr)
	if endpoint.URL() != "/jsons/ideas.json" {
		t.Errorf("URL() = %q", endpoint.URL())
	}
	if endpoint.AddToSitemap() {
		t.Error("JSON endpoint should not be in sitemap")
	}

	var buf bytes.Buffer
	if err := endpoint.Render(&buf); err != nil {
		t.Fatal(err)
	}

	json := buf.String()
	if !strings.Contains(json, `"towns"`) {
		t.Error("ideas JSON should contain towns key")
	}
	if !strings.Contains(json, `"ideas"`) {
		t.Error("ideas JSON should contain ideas key")
	}
}
