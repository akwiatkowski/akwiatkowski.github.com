package view

import (
	"bytes"
	"strings"
	"testing"
	"time"

	"odkrywajac/internal/index"
	"odkrywajac/internal/model"
	"odkrywajac/internal/service/router"
)

func testSiteDataWithPosts() *index.SiteData {
	fin1 := time.Date(2021, 7, 19, 0, 0, 0, 0, time.UTC)
	fin2 := time.Date(2021, 8, 2, 0, 0, 0, 0, time.UTC)
	posts := []*model.Post{
		{
			Slug:          "2021-07-18-pagorki",
			Title:         "Pagórki przed żniwami",
			Date:          time.Date(2021, 7, 18, 0, 0, 0, 0, time.UTC),
			FinishedAt:    &fin1,
			TagSlugs:      []string{"bicycle"},
			TownSlugs:     []string{"pobiedziska"},
			Distance:      42.0,
			Content:       "# Hello\n\nSome **bold** text.",
			ImageFilename: "header.jpg",
		},
		{
			Slug:       "2021-08-01-second-post",
			Title:      "Second Post",
			Date:       time.Date(2021, 8, 1, 0, 0, 0, 0, time.UTC),
			FinishedAt: &fin2,
			TagSlugs:   []string{"bicycle"},
			TownSlugs:  []string{"pobiedziska"},
			Distance:   30.0,
			Content:    "Second post content.",
		},
	}
	tags := []model.Tag{
		{Slug: "bicycle", SlugPl: "rowerem", Name: "Rowerem", IsNav: true},
	}
	areas := []*model.Area{
		{Slug: "pobiedziska", Name: "Pobiedziska", Type: model.AreaTypeTown},
	}
	cfg := model.SiteConfig{Title: "Odkrywając Polskę", URL: "https://odkrywajacpolske.pl"}

	return index.BuildSiteData(posts, tags, nil, areas, cfg, nil, nil, nil)
}

func TestPostArticlePageURL(t *testing.T) {
	data := testSiteDataWithPosts()
	r := router.New("https://odkrywajacpolske.pl")
	post := data.PostBySlug("2021-07-18-pagorki")

	page := PostArticlePage(data, post, r, nil, false)
	if page.URL() != "/2021/07/18-pagorki.html" {
		t.Errorf("URL() = %q", page.URL())
	}
	if !page.AddToSitemap() {
		t.Error("post article should be in sitemap")
	}
}

func TestPostArticlePageRender(t *testing.T) {
	data := testSiteDataWithPosts()
	r := router.New("https://odkrywajacpolske.pl")
	post := data.PostBySlug("2021-07-18-pagorki")

	page := PostArticlePage(data, post, r, nil, false)
	var buf bytes.Buffer
	if err := page.Render(&buf); err != nil {
		t.Fatal(err)
	}

	html := buf.String()
	checks := []string{
		"<!doctype html>",
		"<title>Pagórki przed żniwami - Odkrywając Polskę</title>",
		"<strong>bold</strong>",        // rendered markdown
		"Rowerem",                       // tag link
		"/wpisy-dla/tagu/rowerem.html", // tag URL
		"Pobiedziska",                   // area link
		"Second Post",                   // pager (next post)
		"site-nav",
		"site-footer",
	}

	for _, check := range checks {
		if !strings.Contains(html, check) {
			t.Errorf("HTML missing %q", check)
		}
	}
}

// TestPostArticleReleaseHidesDrafts verifies the release TARGET behavior:
// a not-ready (todo-tagged) post keeps its page shell but ships no body and is
// excluded from the sitemap, while in local it renders fully. Ready posts are
// unaffected by the target. Mirrors Crystal's hide_not_finished.
func TestPostArticleReleaseHidesDrafts(t *testing.T) {
	fin := time.Date(2021, 7, 19, 0, 0, 0, 0, time.UTC)
	draft := &model.Post{
		Slug:       "2021-07-18-draft",
		Title:      "Draft Post",
		Date:       time.Date(2021, 7, 18, 0, 0, 0, 0, time.UTC),
		FinishedAt: &fin,
		TagSlugs:   []string{"todo", "bicycle"},
		Content:    "# Draft heading\n\nSecret **draft** body.",
	}
	ready := &model.Post{
		Slug:       "2021-08-01-ready",
		Title:      "Ready Post",
		Date:       time.Date(2021, 8, 1, 0, 0, 0, 0, time.UTC),
		FinishedAt: &fin,
		TagSlugs:   []string{"bicycle"},
		Content:    "Ready body text.",
	}
	cfg := model.SiteConfig{Title: "Odkrywając Polskę", URL: "https://odkrywajacpolske.pl"}
	data := index.BuildSiteData([]*model.Post{draft, ready}, nil, nil, nil, cfg, nil, nil, nil)
	r := router.New("https://odkrywajacpolske.pl")

	render := func(post *model.Post, release bool) (string, bool) {
		page := PostArticlePage(data, post, r, nil, release)
		var buf bytes.Buffer
		if err := page.Render(&buf); err != nil {
			t.Fatal(err)
		}
		return buf.String(), page.AddToSitemap()
	}

	// Local: draft body present, in sitemap.
	if html, inSitemap := render(draft, false); !strings.Contains(html, "draft</strong>") || !inSitemap {
		t.Errorf("local draft: body present=%v inSitemap=%v (want both true)",
			strings.Contains(html, "draft</strong>"), inSitemap)
	}

	// Release: draft body blanked, excluded from sitemap; shell (title) stays.
	if html, inSitemap := render(draft, true); strings.Contains(html, "Secret") || inSitemap {
		t.Errorf("release draft: leaked body=%v inSitemap=%v (want both false)",
			strings.Contains(html, "Secret"), inSitemap)
	} else if !strings.Contains(html, "Draft Post") {
		t.Error("release draft: page shell (title) should remain")
	}

	// Release: ready post unaffected.
	if html, inSitemap := render(ready, true); !strings.Contains(html, "Ready body") || !inSitemap {
		t.Errorf("release ready: body present=%v inSitemap=%v (want both true)",
			strings.Contains(html, "Ready body"), inSitemap)
	}
}

func TestPostGalleryPageURL(t *testing.T) {
	data := testSiteDataWithPosts()
	r := router.New("https://odkrywajacpolske.pl")
	post := data.PostBySlug("2021-07-18-pagorki")

	page := PostGalleryPage(data, post, r, nil)
	if page.URL() != "/galeria/2021/07/18-pagorki.html" {
		t.Errorf("URL() = %q", page.URL())
	}
}

func TestPostGalleryPageRender(t *testing.T) {
	data := testSiteDataWithPosts()
	r := router.New("https://odkrywajacpolske.pl")
	post := data.PostBySlug("2021-07-18-pagorki")

	page := PostGalleryPage(data, post, r, nil)
	var buf bytes.Buffer
	if err := page.Render(&buf); err != nil {
		t.Fatal(err)
	}

	html := buf.String()
	if !strings.Contains(html, "gallery-config") {
		t.Error("HTML should contain gallery-config script")
	}
	if !strings.Contains(html, `id="root"`) {
		t.Error("HTML should contain root div")
	}
}

func TestPostArticleSvgMapRendered(t *testing.T) {
	data := testSiteDataWithPosts()
	r := router.New("https://odkrywajacpolske.pl")

	// Add routes to the first post so SVG map section appears.
	post := data.PostBySlug("2021-07-18-pagorki")
	post.Routes = []model.Route{{
		Type: "bicycle",
		Segments: [][]model.LatLon{
			{{Lat: 52.3, Lon: 16.8}, {Lat: 52.5, Lon: 17.0}},
		},
	}}

	page := PostArticlePage(data, post, r, nil, false)
	var buf bytes.Buffer
	if err := page.Render(&buf); err != nil {
		t.Fatal(err)
	}
	html := buf.String()

	checks := []struct {
		desc, substr string
	}{
		{"SVG object embed", `post_small_photo_map`},
		{"SVG data URL", `/mapa_zdjec/wpis/2021-07-18-pagorki.svg`},
		{"Mapa heading", `<h2>Mapa</h2>`},
		{"UMP map link", `mapa.ump.waw.pl`},
		{"OSM map link", `openstreetmap.org`},
		{"Mapy.cz link", `mapy.cz`},
		{"Google map link", `google.pl/maps`},
		{"route stats", `post-route-stats`},
		{"distance", `42 km`},
	}
	for _, check := range checks {
		if !strings.Contains(html, check.substr) {
			t.Errorf("HTML missing %s (%q)", check.desc, check.substr)
		}
	}
}

func TestPostArticleNoSvgMapWithoutRoutes(t *testing.T) {
	data := testSiteDataWithPosts()
	r := router.New("https://odkrywajacpolske.pl")

	// Second post has no routes — should not have SVG map.
	post := data.PostBySlug("2021-08-01-second-post")

	page := PostArticlePage(data, post, r, nil, false)
	var buf bytes.Buffer
	if err := page.Render(&buf); err != nil {
		t.Fatal(err)
	}
	html := buf.String()

	if strings.Contains(html, "post_small_photo_map") {
		t.Error("post without routes should not have SVG map")
	}
	if strings.Contains(html, "mapa_zdjec") {
		t.Error("post without routes should not have mapa_zdjec URL")
	}
}

func TestFindAdjacentPosts(t *testing.T) {
	data := testSiteDataWithPosts()
	post := data.PostBySlug("2021-07-18-pagorki")

	prev, next := findAdjacentPosts(data.Posts, post)

	if prev != nil {
		t.Errorf("expected no prev post, got %q", prev.Slug)
	}
	if next == nil {
		t.Fatal("expected next post")
	}
	if next.Slug != "2021-08-01-second-post" {
		t.Errorf("next post slug = %q, want 2021-08-01-second-post", next.Slug)
	}
}

func TestBuildRelatedPosts(t *testing.T) {
	data := testSiteDataWithPosts()
	r := router.New("https://odkrywajacpolske.pl")
	post := data.PostBySlug("2021-07-18-pagorki")

	related := buildRelatedPosts(data, post, r, 3)
	if len(related) == 0 {
		t.Error("expected at least one related post")
	}
	if len(related) > 0 && related[0].Title != "Second Post" {
		t.Errorf("related[0].Title = %q, want Second Post", related[0].Title)
	}
}
