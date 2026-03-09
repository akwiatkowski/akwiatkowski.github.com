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

func TestPortfolioPageURL(t *testing.T) {
	data := testSiteDataMinimal()
	rtr := router.New("https://example.com")

	page := PortfolioPage(data, rtr, nil)
	if page.URL() != "/portfolio.html" {
		t.Errorf("URL() = %q, want /portfolio.html", page.URL())
	}
	if !page.AddToSitemap() {
		t.Error("portfolio should be in sitemap")
	}
}

func TestPortfolioPageRender(t *testing.T) {
	fin := time.Date(2021, 7, 19, 0, 0, 0, 0, time.UTC)
	posts := []*model.Post{
		{
			Slug:       "2021-07-18-pagorki",
			Title:      "Pagórki",
			Date:       time.Date(2021, 7, 18, 0, 0, 0, 0, time.UTC),
			FinishedAt: &fin,
			PublishedPhotos: []*model.Photo{
				{
					ImageFilename: "best_photo.jpg",
					PostSlug:      "2021-07-18-pagorki",
					Desc:          "Best landscape",
					TagSlugs:      []string{"best"},
					Points:        10,
				},
				{
					ImageFilename: "normal_photo.jpg",
					PostSlug:      "2021-07-18-pagorki",
					Desc:          "Normal photo",
					TagSlugs:      []string{"good"},
					Points:        3,
				},
			},
		},
	}
	data := index.BuildSiteData(posts, nil, nil, nil,
		model.SiteConfig{Title: "Test", URL: "https://example.com"},
		nil, nil, nil,
	)
	rtr := router.New("https://example.com")

	page := PortfolioPage(data, rtr, nil)
	var buf bytes.Buffer
	if err := page.Render(&buf); err != nil {
		t.Fatal(err)
	}

	html := buf.String()
	// Should contain best-tagged photo
	if !strings.Contains(html, "Best landscape") {
		t.Error("portfolio should contain best-tagged photo")
	}
	// Should not contain non-best photo
	if strings.Contains(html, "Normal photo") {
		t.Error("portfolio should not contain non-best photo")
	}
}
