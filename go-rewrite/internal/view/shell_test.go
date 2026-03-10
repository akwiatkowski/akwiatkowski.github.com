package view

import (
	"bytes"
	"strings"
	"testing"

	"odkrywajac/internal/index"
	"odkrywajac/internal/model"
	"odkrywajac/internal/router"
)

func testSiteDataMinimal() *index.SiteData {
	return index.BuildSiteData(nil, nil, nil, nil,
		model.SiteConfig{Title: "Test Site", URL: "https://example.com"},
		nil, nil, nil,
	)
}

func TestShellPageURLs(t *testing.T) {
	data := testSiteDataMinimal()
	rtr := router.New("https://example.com")

	tests := []struct {
		name    string
		page    Renderable
		wantURL string
	}{
		{"RouteMap", RouteMapPage(data, rtr, nil), "/mapa_tras.html"},
		{"PhotoMap", PhotoMapPage(data, rtr, nil), "/mapa_zdjec.html"},
		{"Timeline", TimelinePage(data, rtr, nil), "/linia_czasu.html"},
		{"ExifStats", ExifStatsPage(data, rtr, nil), "/statystyki_exif.html"},
		{"PhotoPlanner", PhotoPlannerPage(data, rtr, nil), "/pomysly_dla_zdjec.html"},
		{"TripIdeas", TripIdeasPage(data, rtr, nil), "/pomysly_tras.html"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.page.URL() != tt.wantURL {
				t.Errorf("URL() = %q, want %q", tt.page.URL(), tt.wantURL)
			}
			if !tt.page.AddToSitemap() {
				t.Error("shell page should be in sitemap")
			}
		})
	}
}

func TestShellPageRender(t *testing.T) {
	data := testSiteDataMinimal()
	rtr := router.New("https://example.com")

	page := RouteMapPage(data, rtr, nil)

	var buf bytes.Buffer
	if err := page.Render(&buf); err != nil {
		t.Fatal(err)
	}

	html := buf.String()
	checks := []string{
		"<!doctype html>",
		`id="root"`,
		"/js/self/map_leaflet.js",
		"Mapa tras",
	}
	for _, check := range checks {
		if !strings.Contains(html, check) {
			t.Errorf("shell page HTML missing %q", check)
		}
	}
}
