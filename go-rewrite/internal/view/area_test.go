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

func testSiteData() *index.SiteData {
	posts := []*model.Post{
		{
			Slug:      "pagorki",
			Title:     "Pagórki przed żniwami",
			Date:      time.Date(2021, 7, 18, 0, 0, 0, 0, time.UTC),
			TagSlugs:  []string{"bicycle"},
			TownSlugs: []string{"pobiedziska"},
			Distance:  42.0,
			FinishedAt: func() *time.Time { t := time.Date(2021, 7, 19, 0, 0, 0, 0, time.UTC); return &t }(),
		},
	}
	tags := []model.Tag{
		{Slug: "bicycle", SlugPl: "rowerem", Name: "Rowerem", IsNav: true},
		{Slug: "hike", SlugPl: "pieszo", Name: "Pieszo", IsNav: true},
	}
	areas := []*model.Area{
		{Slug: "pobiedziska", Name: "Pobiedziska", Type: model.AreaTypeTown},
	}
	cfg := model.SiteConfig{Title: "Odkrywając Polskę", URL: "https://odkrywajacpolske.pl"}

	return index.BuildSiteData(posts, tags, nil, areas, cfg, nil, nil, nil)
}

func TestAreaShowPageURL(t *testing.T) {
	data := testSiteData()
	r := router.New("https://odkrywajacpolske.pl")
	area := data.FindArea(model.AreaTypeTown, "pobiedziska")
	if area == nil {
		t.Fatal("area not found")
	}

	page := AreaShowPage(data, area, r, nil, "")
	if page.URL() != "/gmina/pobiedziska.html" {
		t.Errorf("URL() = %q, want /gmina/pobiedziska.html", page.URL())
	}
	if !page.AddToSitemap() {
		t.Error("area show should be in sitemap")
	}
}

func TestAreaShowPageRender(t *testing.T) {
	data := testSiteData()
	r := router.New("https://odkrywajacpolske.pl")
	area := data.FindArea(model.AreaTypeTown, "pobiedziska")

	page := AreaShowPage(data, area, r, nil, "")
	var buf bytes.Buffer
	if err := page.Render(&buf); err != nil {
		t.Fatal(err)
	}

	html := buf.String()
	checks := []string{
		"<!doctype html>",
		`<html lang="pl">`,
		"<title>Pobiedziska - Odkrywając Polskę</title>",
		`id="area-data"`,
		`id="root"`,
		"site-nav",
		"site-footer",
		"/js/self/area_show.js",
	}
	for _, check := range checks {
		if !strings.Contains(html, check) {
			t.Errorf("HTML missing %q", check)
		}
	}
}

func TestAreaPostListPageURL(t *testing.T) {
	data := testSiteData()
	r := router.New("https://odkrywajacpolske.pl")
	area := data.FindArea(model.AreaTypeTown, "pobiedziska")

	page := AreaPostListPage(data, area, r, nil)
	if page.URL() != "/wpisy-dla/gminy/pobiedziska.html" {
		t.Errorf("URL() = %q", page.URL())
	}
}

func TestAreaGalleryPageURL(t *testing.T) {
	data := testSiteData()
	r := router.New("https://odkrywajacpolske.pl")
	area := data.FindArea(model.AreaTypeTown, "pobiedziska")

	page := AreaGalleryPage(data, area, r, nil)
	if page.URL() != "/galeria/gminy/pobiedziska.html" {
		t.Errorf("URL() = %q", page.URL())
	}
}

func TestE2EJSONRender(t *testing.T) {
	data := testSiteData()
	r := router.New("https://odkrywajacpolske.pl")

	ep := E2EJSON(data, r)
	if ep.URL() != "/jsons/e2e.json" {
		t.Errorf("URL() = %q", ep.URL())
	}

	var buf bytes.Buffer
	if err := ep.Render(&buf); err != nil {
		t.Fatal(err)
	}

	json := buf.String()
	if !strings.Contains(json, "pagorki") {
		t.Error("JSON should contain post slug")
	}
	if !strings.Contains(json, "Pagórki przed żniwami") {
		t.Error("JSON should contain post title")
	}
}

func TestRedirectPageRender(t *testing.T) {
	rp := NewRedirectPage("/tag/rowerem.html", "/wpisy-dla/tagu/rowerem.html", 302)

	if rp.URL() != "/tag/rowerem.html" {
		t.Errorf("URL() = %q", rp.URL())
	}
	if rp.AddToSitemap() {
		t.Error("redirect should not be in sitemap")
	}

	var buf bytes.Buffer
	if err := rp.Render(&buf); err != nil {
		t.Fatal(err)
	}

	html := buf.String()
	if !strings.Contains(html, "/wpisy-dla/tagu/rowerem.html") {
		t.Error("redirect HTML should contain target URL")
	}
}

func TestGenerateAllViews(t *testing.T) {
	data := testSiteData()
	r := router.New("https://odkrywajacpolske.pl")

	all := GenerateAllViews(data, r, nil, "")

	// 1 area with posts → 3 pages (show, post list, gallery)
	// + 1 JSON endpoint (e2e.json)
	// + 2 tag redirects (bicycle, hike)
	expectedMin := 6
	if len(all) < expectedMin {
		t.Errorf("expected at least %d views, got %d", expectedMin, len(all))
	}

	// Check all views have unique URLs
	urls := make(map[string]bool)
	for _, v := range all {
		if urls[v.URL()] {
			t.Errorf("duplicate URL: %s", v.URL())
		}
		urls[v.URL()] = true
	}
}
