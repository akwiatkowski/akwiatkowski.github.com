package view

import (
	"bytes"
	"strings"
	"testing"

	"odkrywajac/internal/router"
)

func TestHomepagePageURL(t *testing.T) {
	data := testSiteDataWithPosts()
	r := router.New("https://odkrywajacpolske.pl")

	page := HomepagePage(data, r, nil)
	if page.URL() != "/index.html" {
		t.Errorf("URL() = %q, want /index.html", page.URL())
	}
	if !page.AddToSitemap() {
		t.Error("homepage should be in sitemap")
	}
}

func TestHomepagePageRender(t *testing.T) {
	data := testSiteDataWithPosts()
	r := router.New("https://odkrywajacpolske.pl")

	page := HomepagePage(data, r, nil)
	var buf bytes.Buffer
	if err := page.Render(&buf); err != nil {
		t.Fatal(err)
	}

	html := buf.String()
	checks := []string{
		"<!doctype html>",
		"Odkrywając Polskę",
		"home-page",
		"hero-image hero-loading",
		"hero-stats",
		"posts-grid",
		"categories",
		"stat-value",
		"stat-unit",
		"stat-label",
		"/js/self/homepage.js",
	}

	for _, check := range checks {
		if !strings.Contains(html, check) {
			t.Errorf("HTML missing %q", check)
		}
	}
}

func TestHomepageJSONURL(t *testing.T) {
	data := testSiteDataWithPosts()
	r := router.New("https://odkrywajacpolske.pl")

	ep := HomepageJSON(data, r)
	if ep.URL() != "/jsons/homepage.json" {
		t.Errorf("URL() = %q, want /jsons/homepage.json", ep.URL())
	}
	if ep.AddToSitemap() {
		t.Error("JSON endpoint should not be in sitemap")
	}
}

func TestHomepageJSONRender(t *testing.T) {
	data := testSiteDataWithPosts()
	r := router.New("https://odkrywajacpolske.pl")

	ep := HomepageJSON(data, r)
	var buf bytes.Buffer
	if err := ep.Render(&buf); err != nil {
		t.Fatal(err)
	}

	json := buf.String()
	checks := []string{
		`"posts"`,
		`"tags"`,
		`"areas"`,
		`"pobiedziska"`,  // town slug in post towns
		`"Rowerem"`,      // tag name
		`"/wpisy-dla/tagu/rowerem.html"`, // tag URL
		`"distance_km"`,  // renamed from distance
		`"time"`,         // RFC3339 timestamp
	}

	for _, check := range checks {
		if !strings.Contains(json, check) {
			t.Errorf("JSON missing %q", check)
		}
	}
}
