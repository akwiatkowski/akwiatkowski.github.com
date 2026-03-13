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

func testSiteDataForTownsTimeline() *index.SiteData {
	fin1 := time.Date(2021, 7, 19, 0, 0, 0, 0, time.UTC)
	fin2 := time.Date(2021, 8, 2, 0, 0, 0, 0, time.UTC)
	fin3 := time.Date(2021, 9, 10, 0, 0, 0, 0, time.UTC)
	posts := []*model.Post{
		{
			Slug:       "2021-07-18-bike1",
			Title:      "Bike Trip",
			Date:       time.Date(2021, 7, 18, 0, 0, 0, 0, time.UTC),
			FinishedAt: &fin1,
			TagSlugs:   []string{"bicycle"},
			TownSlugs:  []string{"pobiedziska"},
		},
		{
			Slug:       "2021-08-01-train1",
			Title:      "Train Trip",
			Date:       time.Date(2021, 8, 1, 0, 0, 0, 0, time.UTC),
			FinishedAt: &fin2,
			TagSlugs:   []string{"train"},
			TownSlugs:  []string{"swarzedz"},
		},
		{
			Slug:       "2021-09-09-bike2",
			Title:      "Bike Return",
			Date:       time.Date(2021, 9, 9, 0, 0, 0, 0, time.UTC),
			FinishedAt: &fin3,
			TagSlugs:   []string{"bicycle"},
			TownSlugs:  []string{"pobiedziska"}, // revisit
		},
	}
	areas := []*model.Area{
		{Slug: "pobiedziska", Name: "Pobiedziska", Type: model.AreaTypeTown},
		{Slug: "swarzedz", Name: "Swarzędz", Type: model.AreaTypeTown},
	}
	cfg := model.SiteConfig{Title: "Test"}
	return index.BuildSiteData(posts, nil, nil, areas, cfg, nil, nil)
}

func TestTownsTimelinePageURL(t *testing.T) {
	data := testSiteDataForTownsTimeline()
	r := router.New("https://example.com")

	page := TownsTimelinePage(data, r, nil)
	if page.URL() != "/gminy/chronologicznie.html" {
		t.Errorf("URL() = %q", page.URL())
	}
}

func TestTownsTimelinePageRender(t *testing.T) {
	data := testSiteDataForTownsTimeline()
	r := router.New("https://example.com")

	page := TownsTimelinePage(data, r, nil)
	var buf bytes.Buffer
	if err := page.Render(&buf); err != nil {
		t.Fatal(err)
	}

	html := buf.String()
	checks := []string{
		"Gminy chronologicznie",
		"Pobiedziska",
		"Swarzędz",
		"2021-07",
	}
	for _, check := range checks {
		if !strings.Contains(html, check) {
			t.Errorf("HTML missing %q", check)
		}
	}
}

func TestTownsTimelineCumulativeCounts(t *testing.T) {
	data := testSiteDataForTownsTimeline()
	r := router.New("https://example.com")

	td := computeTownsTimeline(data, r)

	if len(td.Months) == 0 {
		t.Fatal("expected months")
	}

	// July 2021: pobiedziska by bicycle → self town #1
	jul := td.Months[0]
	if len(jul.SelfTowns) != 1 {
		t.Errorf("July self towns = %d, want 1", len(jul.SelfTowns))
	}
	if jul.SelfTowns[0].Name != "Pobiedziska" {
		t.Errorf("July self town name = %q", jul.SelfTowns[0].Name)
	}

	// August 2021: swarzedz by train → vehicle town
	aug := td.Months[1]
	if len(aug.VehicleTowns) != 1 {
		t.Errorf("August vehicle towns = %d, want 1", len(aug.VehicleTowns))
	}

	// September 2021: pobiedziska revisit
	sep := td.Months[2]
	if sep.RevisitCount != 1 {
		t.Errorf("September revisits = %d, want 1", sep.RevisitCount)
	}
}
