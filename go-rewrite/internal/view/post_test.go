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

func testSiteDataWithPosts() *index.SiteData {
	fin1 := time.Date(2021, 7, 19, 0, 0, 0, 0, time.UTC)
	fin2 := time.Date(2021, 8, 2, 0, 0, 0, 0, time.UTC)
	posts := []*model.Post{
		{
			Slug:          "pagorki",
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
			Slug:       "second-post",
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
	post := data.PostBySlug("pagorki")

	page := PostArticlePage(data, post, r, nil)
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
	post := data.PostBySlug("pagorki")

	page := PostArticlePage(data, post, r, nil)
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

func TestPostGalleryPageURL(t *testing.T) {
	data := testSiteDataWithPosts()
	r := router.New("https://odkrywajacpolske.pl")
	post := data.PostBySlug("pagorki")

	page := PostGalleryPage(data, post, r, nil)
	if page.URL() != "/2021/07/pagorki/galeria.html" {
		t.Errorf("URL() = %q", page.URL())
	}
}

func TestPostGalleryPageRender(t *testing.T) {
	data := testSiteDataWithPosts()
	r := router.New("https://odkrywajacpolske.pl")
	post := data.PostBySlug("pagorki")

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

func TestFindAdjacentPosts(t *testing.T) {
	data := testSiteDataWithPosts()
	post := data.PostBySlug("pagorki")

	prev, next := findAdjacentPosts(data.Posts, post)

	if prev != nil {
		t.Errorf("expected no prev post, got %q", prev.Slug)
	}
	if next == nil {
		t.Fatal("expected next post")
	}
	if next.Slug != "second-post" {
		t.Errorf("next post slug = %q, want second-post", next.Slug)
	}
}

func TestBuildRelatedPosts(t *testing.T) {
	data := testSiteDataWithPosts()
	r := router.New("https://odkrywajacpolske.pl")
	post := data.PostBySlug("pagorki")

	related := buildRelatedPosts(data, post, r, 3)
	if len(related) == 0 {
		t.Error("expected at least one related post")
	}
	if len(related) > 0 && related[0].Title != "Second Post" {
		t.Errorf("related[0].Title = %q, want Second Post", related[0].Title)
	}
}
