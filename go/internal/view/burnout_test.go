package view

import (
	"bytes"
	"strings"
	"testing"
	"time"

	"odkrywajac/internal/index"
	"odkrywajac/internal/model"
	"odkrywajac/internal/service/router"
	"odkrywajac/internal/templates/views"
)

func testSiteDataForBurnout() *index.SiteData {
	fin1 := time.Date(2021, 7, 19, 0, 0, 0, 0, time.UTC)
	fin2 := time.Date(2022, 7, 15, 0, 0, 0, 0, time.UTC)
	posts := []*model.Post{
		{
			Slug:       "2021-07-18-trip-jul-2021",
			Title:      "July 2021",
			Date:       time.Date(2021, 7, 18, 0, 0, 0, 0, time.UTC),
			FinishedAt: &fin1,
			TagSlugs:   []string{"bicycle"},
			Distance:   40.0,
			TimeSpent:  3.0,
		},
		{
			Slug:       "2022-07-14-trip-jul-2022",
			Title:      "July 2022",
			Date:       time.Date(2022, 7, 14, 0, 0, 0, 0, time.UTC),
			FinishedAt: &fin2,
			TagSlugs:   []string{"bicycle"},
			Distance:   60.0,
			TimeSpent:  5.0,
		},
	}
	cfg := model.SiteConfig{Title: "Test"}
	return index.BuildSiteData(posts, nil, nil, nil, cfg, nil, nil, nil)
}

func TestBurnoutPageURL(t *testing.T) {
	data := testSiteDataForBurnout()
	r := router.New("https://example.com")

	page := BurnoutPage(data, r, nil)
	if page.URL() != "/debug/burnout.html" {
		t.Errorf("URL() = %q, want /debug/burnout.html", page.URL())
	}
	if page.AddToSitemap() {
		t.Error("burnout should not be in sitemap")
	}
}

func TestBurnoutPageRender(t *testing.T) {
	data := testSiteDataForBurnout()
	r := router.New("https://example.com")

	page := BurnoutPage(data, r, nil)
	var buf bytes.Buffer
	if err := page.Render(&buf); err != nil {
		t.Fatal(err)
	}

	html := buf.String()
	checks := []string{
		"Burnout",
		"burnout-table",
		"Dystans",
		"Czas",
	}

	for _, check := range checks {
		if !strings.Contains(html, check) {
			t.Errorf("HTML missing %q", check)
		}
	}
}

func TestBurnoutMonthlyAggregation(t *testing.T) {
	data := testSiteDataForBurnout()
	bd := computeBurnout(data)

	if len(bd.Months) == 0 {
		t.Fatal("expected months")
	}
	if bd.MaxDistance != 60 {
		t.Errorf("MaxDistance = %d, want 60", bd.MaxDistance)
	}
}

func TestBurnoutYearOverYearDelta(t *testing.T) {
	data := testSiteDataForBurnout()
	bd := computeBurnout(data)

	var jul2022 *views.BurnoutMonth
	for i := range bd.Months {
		if bd.Months[i].Date.Year() == 2022 && bd.Months[i].Date.Month() == 7 {
			jul2022 = &bd.Months[i]
			break
		}
	}

	if jul2022 == nil {
		t.Fatal("could not find July 2022")
	}
	if jul2022.Distance != 60 {
		t.Errorf("Distance = %d, want 60", jul2022.Distance)
	}
	if jul2022.DistanceLastYear == nil {
		t.Fatal("expected DistanceLastYear")
	}
	if *jul2022.DistanceLastYear != 40 {
		t.Errorf("DistanceLastYear = %d, want 40", *jul2022.DistanceLastYear)
	}
	if jul2022.DistanceChangePercent == nil {
		t.Fatal("expected DistanceChangePercent")
	}
	if *jul2022.DistanceChangePercent != 50 {
		t.Errorf("DistanceChangePercent = %d, want 50", *jul2022.DistanceChangePercent)
	}
}
