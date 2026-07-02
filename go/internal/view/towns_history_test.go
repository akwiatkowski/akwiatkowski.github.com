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

func testSiteDataForTownsHistory() *catalog.SiteData {
	fin1 := time.Date(2021, 7, 19, 0, 0, 0, 0, time.UTC)
	fin2 := time.Date(2021, 9, 2, 0, 0, 0, 0, time.UTC)
	posts := []*model.Post{
		{
			Slug:       "2021-07-18-trip1",
			Title:      "Trip 1",
			Date:       time.Date(2021, 7, 18, 0, 0, 0, 0, time.UTC),
			FinishedAt: &fin1,
			TagSlugs:   []string{"bicycle"},
			TownSlugs:  []string{"pobiedziska", "swarzedz"},
		},
		{
			Slug:       "2021-09-01-trip2",
			Title:      "Trip 2",
			Date:       time.Date(2021, 9, 1, 0, 0, 0, 0, time.UTC),
			FinishedAt: &fin2,
			TagSlugs:   []string{"bicycle"},
			TownSlugs:  []string{"pobiedziska"},
		},
	}
	areas := []*model.Area{
		{Slug: "pobiedziska", Name: "Pobiedziska", Type: model.AreaTypeTown, VoivodeshipSlug: "wielkopolskie"},
		{Slug: "swarzedz", Name: "Swarzędz", Type: model.AreaTypeTown, VoivodeshipSlug: "wielkopolskie"},
		{Slug: "wielkopolskie", Name: "Wielkopolskie", Type: model.AreaTypeVoivodeship},
	}
	cfg := model.SiteConfig{Title: "Test"}
	return catalog.BuildSiteData(posts, nil, nil, areas, cfg, nil, nil, nil)
}

func TestTownsHistoryPageURL(t *testing.T) {
	data := testSiteDataForTownsHistory()
	r := router.New("https://example.com")

	page := TownsHistoryPage(data, r, nil)
	if page.URL() != "/gminy/historia.html" {
		t.Errorf("URL() = %q", page.URL())
	}
}

func TestTownsHistoryPageRender(t *testing.T) {
	data := testSiteDataForTownsHistory()
	r := router.New("https://example.com")

	page := TownsHistoryPage(data, r, nil)
	var buf bytes.Buffer
	if err := page.Render(&buf); err != nil {
		t.Fatal(err)
	}

	html := buf.String()
	checks := []string{
		"Historia odwiedzonych gmin",
		"Wielkopolskie",
		"Pobiedziska",
		"Swarzędz",
		"2021-07-18",
	}
	for _, check := range checks {
		if !strings.Contains(html, check) {
			t.Errorf("HTML missing %q", check)
		}
	}
}

func TestTownsHistoryGrouping(t *testing.T) {
	data := testSiteDataForTownsHistory()
	r := router.New("https://example.com")

	hd := computeTownsHistory(data, r)

	if hd.TotalTowns != 2 {
		t.Errorf("TotalTowns = %d, want 2", hd.TotalTowns)
	}
	if len(hd.Groups) != 1 {
		t.Fatalf("Groups count = %d, want 1", len(hd.Groups))
	}
	if hd.Groups[0].VoivodeshipName != "Wielkopolskie" {
		t.Errorf("VoivodeshipName = %q", hd.Groups[0].VoivodeshipName)
	}
	if len(hd.Groups[0].Towns) != 2 {
		t.Errorf("Towns count = %d, want 2", len(hd.Groups[0].Towns))
	}
}

func TestTownsHistoryFirstVisitDate(t *testing.T) {
	data := testSiteDataForTownsHistory()
	r := router.New("https://example.com")

	hd := computeTownsHistory(data, r)

	for _, town := range hd.Groups[0].Towns {
		if town.Name == "Pobiedziska" {
			expected := "2021-07-18"
			if town.FirstVisit.Format("2006-01-02") != expected {
				t.Errorf("FirstVisit = %s, want %s", town.FirstVisit.Format("2006-01-02"), expected)
			}
		}
	}
}
