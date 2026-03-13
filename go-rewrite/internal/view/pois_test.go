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

func testSiteDataForPOIs() *index.SiteData {
	fin := time.Date(2021, 7, 19, 0, 0, 0, 0, time.UTC)
	lat1, lon1 := 52.4, 16.9
	lat2, lon2 := 50.0, 19.9 // ~300km away
	posts := []*model.Post{
		{
			Slug:       "2021-07-18-trip1",
			Title:      "Trip One",
			Date:       time.Date(2021, 7, 18, 0, 0, 0, 0, time.UTC),
			FinishedAt: &fin,
			TagSlugs:   []string{"bicycle"},
			TownSlugs:  []string{"pobiedziska"},
			PublishedPhotos: []*model.Photo{
				{
					ImageFilename: "photo1.jpg",
					PostSlug:      "2021-07-18-trip1",
					Desc:          "Nice view",
					Points:        10,
					Exif: &model.ExifData{
						Lat: &lat1,
						Lon: &lon1,
					},
				},
				{
					ImageFilename: "photo2.jpg",
					PostSlug:      "2021-07-18-trip1",
					Desc:          "Mountain view",
					Points:        8,
					Exif: &model.ExifData{
						Lat: &lat2,
						Lon: &lon2,
					},
				},
			},
		},
	}

	stations := []model.TrainStation{
		{Name: "Castle", Lat: 52.41, Lon: 16.91},
	}

	cfg := model.SiteConfig{Title: "Test"}
	return index.BuildSiteData(posts, nil, nil, nil, cfg, nil, stations)
}

func TestPOIsPageURL(t *testing.T) {
	data := testSiteDataForPOIs()
	rtr := router.New("https://example.com")

	page := POIsPage(data, rtr, nil)
	if page.URL() != "/pois.html" {
		t.Errorf("got URL %q, want /pois.html", page.URL())
	}
}

func TestPOIsPageRenders(t *testing.T) {
	data := testSiteDataForPOIs()
	rtr := router.New("https://example.com")

	page := POIsPage(data, rtr, nil)
	var buf bytes.Buffer
	if err := page.Render(&buf); err != nil {
		t.Fatal(err)
	}
	output := buf.String()

	if !strings.Contains(output, "pois-data") {
		t.Error("output should contain pois-data script tag")
	}
	if !strings.Contains(output, "pois-root") {
		t.Error("output should contain pois-root div")
	}
}

func TestPOIsPageContainsManualPOI(t *testing.T) {
	data := testSiteDataForPOIs()
	rtr := router.New("https://example.com")

	page := POIsPage(data, rtr, nil)
	var buf bytes.Buffer
	if err := page.Render(&buf); err != nil {
		t.Fatal(err)
	}
	output := buf.String()

	if !strings.Contains(output, "Castle") {
		t.Error("output should contain manual POI name")
	}
	if !strings.Contains(output, `"type":"visited"`) {
		t.Error("output should contain visited type for manual POI")
	}
}

func TestBuildAutoPOIsMaxCount(t *testing.T) {
	data := testSiteDataForPOIs()
	rtr := router.New("https://example.com")

	pois := buildPOIs(data, rtr)

	hasManual := false
	hasAuto := false
	for _, p := range pois {
		if p.Type == "visited" {
			hasManual = true
		}
		if p.Type == "auto" {
			hasAuto = true
		}
	}
	if !hasManual {
		t.Error("should have manual POIs")
	}
	if !hasAuto {
		t.Error("should have auto POIs from geotagged photos")
	}
}

func TestHaversineM(t *testing.T) {
	// Poznan to Krakow is ~300km
	d := haversineM(52.4, 16.9, 50.0, 19.9)
	if d < 250000 || d > 400000 {
		t.Errorf("Poznan-Krakow distance %f out of expected range", d)
	}

	// Same point should be ~0
	d = haversineM(52.4, 16.9, 52.4, 16.9)
	if d > 1 {
		t.Errorf("same point distance should be ~0, got %f", d)
	}
}
