package view

import (
	"bytes"
	"strings"
	"testing"
	"time"

	"odkrywajac/internal/index"
	"odkrywajac/internal/model"
	"odkrywajac/internal/router"
	"odkrywajac/internal/templates/layout"
)

func testSiteDataForFeeds() *index.SiteData {
	fin := time.Date(2021, 7, 19, 0, 0, 0, 0, time.UTC)
	posts := []*model.Post{
		{
			Slug:       "pagorki",
			Title:      "Pagórki przed żniwami",
			Subtitle:   "Krótka wycieczka rowerowa",
			Date:       time.Date(2021, 7, 18, 0, 0, 0, 0, time.UTC),
			FinishedAt: &fin,
			TagSlugs:   []string{"bicycle"},
			TownSlugs:  []string{"pobiedziska"},
			Distance:   42.0,
		},
	}
	cfg := model.SiteConfig{
		Title:  "Odkrywając Polskę",
		URL:    "https://odkrywajacpolske.pl",
		Author: "Olek",
		Desc:   "Blog podróżniczy",
	}

	return index.BuildSiteData(posts, nil, nil, nil, cfg, nil, nil, nil)
}

func TestRSSFeed(t *testing.T) {
	data := testSiteDataForFeeds()
	rtr := router.New("https://odkrywajacpolske.pl")

	feed := RSSFeed(data, rtr)

	if feed.URL() != "/feed.rss" {
		t.Errorf("URL() = %q, want /feed.rss", feed.URL())
	}
	if feed.AddToSitemap() {
		t.Error("RSS feed should not be in sitemap")
	}

	var buf bytes.Buffer
	if err := feed.Render(&buf); err != nil {
		t.Fatal(err)
	}

	xml := buf.String()
	checks := []string{
		`<?xml version="1.0"`,
		`<rss version="2.0"`,
		"<title>Odkrywając Polskę</title>",
		"<title>Pagórki przed żniwami</title>",
		"https://odkrywajacpolske.pl/2021/07/18-pagorki.html",
		"<description>Krótka wycieczka rowerowa</description>",
	}
	for _, check := range checks {
		if !strings.Contains(xml, check) {
			t.Errorf("RSS missing %q", check)
		}
	}
}

func TestAtomFeed(t *testing.T) {
	data := testSiteDataForFeeds()
	rtr := router.New("https://odkrywajacpolske.pl")

	feed := AtomFeed(data, rtr)

	if feed.URL() != "/feed.atom" {
		t.Errorf("URL() = %q, want /feed.atom", feed.URL())
	}
	if feed.AddToSitemap() {
		t.Error("Atom feed should not be in sitemap")
	}

	var buf bytes.Buffer
	if err := feed.Render(&buf); err != nil {
		t.Fatal(err)
	}

	xml := buf.String()
	checks := []string{
		`<?xml version="1.0"`,
		`xmlns="http://www.w3.org/2005/Atom"`,
		"<title>Odkrywając Polskę</title>",
		"<title>Pagórki przed żniwami</title>",
		`rel="alternate"`,
		"<name>Olek</name>",
	}
	for _, check := range checks {
		if !strings.Contains(xml, check) {
			t.Errorf("Atom missing %q", check)
		}
	}
}

func TestSitemap(t *testing.T) {
	rtr := router.New("https://odkrywajacpolske.pl")

	views := []Renderable{
		NewHTMLPage("/page1.html", layout.PageData{}, nil, true),
		NewHTMLPage("/page2.html", layout.PageData{}, nil, true),
		NewJSONEndpoint("/jsons/data.json", nil),   // not in sitemap
		NewRedirectPage("/old.html", "/new.html", 302), // not in sitemap
	}

	sm := Sitemap(views, rtr)

	if sm.URL() != "/sitemap.xml" {
		t.Errorf("URL() = %q, want /sitemap.xml", sm.URL())
	}
	if sm.AddToSitemap() {
		t.Error("sitemap should not be in sitemap")
	}

	var buf bytes.Buffer
	if err := sm.Render(&buf); err != nil {
		t.Fatal(err)
	}

	xml := buf.String()
	if !strings.Contains(xml, "https://odkrywajacpolske.pl/page1.html") {
		t.Error("sitemap should contain page1")
	}
	if !strings.Contains(xml, "https://odkrywajacpolske.pl/page2.html") {
		t.Error("sitemap should contain page2")
	}
	if strings.Contains(xml, "/jsons/data.json") {
		t.Error("sitemap should not contain JSON endpoint")
	}
	if strings.Contains(xml, "/old.html") {
		t.Error("sitemap should not contain redirect")
	}
}

func TestRobotsTxt(t *testing.T) {
	rtr := router.New("https://odkrywajacpolske.pl")

	robots := RobotsTxt(rtr)

	if robots.URL() != "/robots.txt" {
		t.Errorf("URL() = %q, want /robots.txt", robots.URL())
	}

	var buf bytes.Buffer
	if err := robots.Render(&buf); err != nil {
		t.Fatal(err)
	}

	content := buf.String()
	if !strings.Contains(content, "User-agent: *") {
		t.Error("robots.txt should contain User-agent")
	}
	if !strings.Contains(content, "Sitemap: https://odkrywajacpolske.pl/sitemap.xml") {
		t.Error("robots.txt should contain sitemap URL")
	}
}

func TestRecentFinishedPosts(t *testing.T) {
	fin := time.Date(2021, 1, 1, 0, 0, 0, 0, time.UTC)
	posts := make([]*model.Post, 25)
	for i := range posts {
		posts[i] = &model.Post{
			Slug:       "post",
			Date:       time.Date(2021, 1, i+1, 0, 0, 0, 0, time.UTC),
			FinishedAt: &fin,
		}
	}
	// Add one unfinished
	posts = append(posts, &model.Post{
		Slug: "unfinished",
		Date: time.Date(2099, 1, 1, 0, 0, 0, 0, time.UTC),
	})

	result := recentFinishedPosts(posts, 20)
	if len(result) != 20 {
		t.Errorf("expected 20 posts, got %d", len(result))
	}
	// Should be sorted by date desc
	if !result[0].Date.After(result[1].Date) {
		t.Error("posts should be sorted by date desc")
	}
}
