package view

import (
	"bytes"
	"strings"
	"testing"
	"time"

	"odkrywajac/internal/catalog"
	"odkrywajac/internal/model"
	"odkrywajac/internal/service/router"
)

func testSiteData() *catalog.SiteData {
	posts := []*model.Post{
		{
			Slug:       "2021-07-18-pagorki",
			Title:      "Pagórki przed żniwami",
			Date:       time.Date(2021, 7, 18, 0, 0, 0, 0, time.UTC),
			TagSlugs:   []string{"bicycle"},
			TownSlugs:  []string{"pobiedziska"},
			Distance:   42.0,
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

	return catalog.BuildSiteData(posts, tags, nil, areas, cfg, nil, nil, nil)
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

	out := buf.String()
	if !strings.Contains(out, "/2021/07/18-pagorki.html") {
		t.Error("JSON should contain post URL")
	}
	if !strings.Contains(out, `"ready": true`) {
		t.Error("JSON should contain ready field")
	}
	if !strings.Contains(out, `"photos_count":`) {
		t.Error("JSON should contain photos_count field")
	}
	if !strings.Contains(out, `"tags":`) {
		t.Error("JSON should contain tags array")
	}
	if !strings.Contains(out, `"voivodeships":`) {
		t.Error("JSON should contain voivodeships array at top level")
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

	all := GenerateAllViews(data, r, nil, "", "", "", false)

	// 1 homepage + 2 posts (article+gallery) + 3 area pages
	// + 2 tag post lists + 2 tag redirects + 8 JSON endpoints
	// + 3 feeds (rss, atom, robots) + 1 sitemap
	// + 6 shell pages + 3 static pages + 1 towns index + 1 portfolio
	expectedMin := 33
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

	// Verify key URLs are present
	expectedURLs := []string{
		"/index.html",                      // homepage
		"/2021/07/18-pagorki.html",         // post article
		"/galeria/2021/07/18-pagorki.html", // post gallery
		"/gmina/pobiedziska.html",          // area show
		"/wpisy-dla/tagu/rowerem.html",     // tag post list
		"/jsons/homepage.json",             // homepage JSON
		"/jsons/e2e.json",                  // e2e JSON
		"/jsons/map.json",                  // map JSON
		"/jsons/photos.json",               // photos JSON
		"/jsons/photos_map.json",           // photos map JSON
		"/jsons/train_stations.json",       // train stations JSON
		"/jsons/photo_grid.json",           // photo grid JSON
		"/jsons/ideas.json",                // ideas JSON
		"/feed.xml",                        // RSS feed
		"/feed_atom.xml",                   // Atom feed
		"/sitemap.xml",                     // sitemap
		"/robots.txt",                      // robots
		"/mapa_tras.html",                  // route map
		"/mapa_zdjec.html",                 // photo map
		"/linia_czasu.html",                // timeline
		"/statystyki_exif.html",            // exif stats
		"/pomysly_dla_zdjec.html",          // photo planner
		"/pomysly_tras.html",               // trip ideas
		"/o-mnie.html",                     // about
		"/en/index.html",                   // english
		"/wiecej.html",                     // more
		"/gminy.html",                      // towns index
		"/portfolio.html",                  // portfolio
	}
	for _, url := range expectedURLs {
		if !urls[url] {
			t.Errorf("missing URL: %s", url)
		}
	}
}
