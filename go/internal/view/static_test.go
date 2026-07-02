package view

import (
	"bytes"
	"strings"
	"testing"

	"odkrywajac/internal/catalog"
	"odkrywajac/internal/model"
	"odkrywajac/internal/service/router"
)

func TestAboutPageURL(t *testing.T) {
	data := testSiteDataMinimal()
	rtr := router.New("https://example.com")

	page := AboutPage(data, rtr, nil, "")
	if page.URL() != "/o-mnie.html" {
		t.Errorf("URL() = %q, want /o-mnie.html", page.URL())
	}
	if !page.AddToSitemap() {
		t.Error("about page should be in sitemap")
	}
}

func TestAboutPageRender(t *testing.T) {
	data := testSiteDataMinimal()
	rtr := router.New("https://example.com")

	page := AboutPage(data, rtr, nil, "")
	var buf bytes.Buffer
	if err := page.Render(&buf); err != nil {
		t.Fatal(err)
	}

	html := buf.String()
	checks := []string{
		"<!doctype html>",
		"O mnie",
	}
	for _, check := range checks {
		if !strings.Contains(html, check) {
			t.Errorf("about page missing %q", check)
		}
	}
}

func TestEnglishPageURL(t *testing.T) {
	data := testSiteDataMinimal()
	rtr := router.New("https://example.com")

	page := EnglishPage(data, rtr, nil, "")
	if page.URL() != "/en/index.html" {
		t.Errorf("URL() = %q, want /en/index.html", page.URL())
	}
}

func TestMorePageURL(t *testing.T) {
	data := testSiteDataMinimal()
	rtr := router.New("https://example.com")

	page := MorePage(data, rtr, nil)
	if page.URL() != "/wiecej.html" {
		t.Errorf("URL() = %q, want /wiecej.html", page.URL())
	}
}

func TestMorePageRender(t *testing.T) {
	data := catalog.BuildSiteData(nil, nil, nil, nil,
		model.SiteConfig{Title: "Test", URL: "https://example.com"},
		nil, nil, nil,
	)
	rtr := router.New("https://example.com")

	page := MorePage(data, rtr, nil)
	var buf bytes.Buffer
	if err := page.Render(&buf); err != nil {
		t.Fatal(err)
	}

	html := buf.String()
	checks := []string{
		"Więcej",
		"/portfolio.html",
		"/mapa_tras.html",
		"/linia_czasu.html",
		"/mapa_zdjec.html",
		"/statystyki_exif.html",
		"/pomysly_tras.html",
		"/pomysly_dla_zdjec.html",
	}
	for _, check := range checks {
		if !strings.Contains(html, check) {
			t.Errorf("more page missing %q", check)
		}
	}
}
