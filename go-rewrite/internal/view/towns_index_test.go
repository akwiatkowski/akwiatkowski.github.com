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

func TestTownsIndexPageURL(t *testing.T) {
	data := testSiteData()
	rtr := router.New("https://example.com")

	page := TownsIndexPage(data, rtr, nil)
	if page.URL() != "/gminy.html" {
		t.Errorf("URL() = %q, want /gminy.html", page.URL())
	}
	if !page.AddToSitemap() {
		t.Error("towns index should be in sitemap")
	}
}

func TestTownsIndexPageRender(t *testing.T) {
	fin := time.Date(2021, 7, 19, 0, 0, 0, 0, time.UTC)
	posts := []*model.Post{
		{
			Slug:       "2021-07-18-pagorki",
			Title:      "Pagórki",
			Date:       time.Date(2021, 7, 18, 0, 0, 0, 0, time.UTC),
			FinishedAt: &fin,
			TownSlugs:  []string{"pobiedziska"},
		},
	}
	areas := []*model.Area{
		{Slug: "pobiedziska", Name: "Pobiedziska", Type: model.AreaTypeTown, VoivodeshipSlug: "wielkopolskie"},
		{Slug: "wielkopolskie", Name: "Wielkopolskie", Type: model.AreaTypeVoivodeship},
	}
	data := index.BuildSiteData(posts, nil, nil, areas,
		model.SiteConfig{Title: "Test", URL: "https://example.com"},
		nil, nil, nil,
	)
	rtr := router.New("https://example.com")

	page := TownsIndexPage(data, rtr, nil)
	var buf bytes.Buffer
	if err := page.Render(&buf); err != nil {
		t.Fatal(err)
	}

	html := buf.String()
	checks := []string{
		`id="towns-data"`,
		"Pobiedziska",
		"pobiedziska",
		"wielkopolskie",
		`id="towns-app"`,
	}
	for _, check := range checks {
		if !strings.Contains(html, check) {
			t.Errorf("towns index missing %q", check)
		}
	}
}
