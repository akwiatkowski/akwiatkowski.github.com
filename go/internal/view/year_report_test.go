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

func testSiteDataForYearReport() *index.SiteData {
	fin1 := time.Date(2021, 7, 19, 0, 0, 0, 0, time.UTC)
	fin2 := time.Date(2021, 8, 2, 0, 0, 0, 0, time.UTC)
	fin3 := time.Date(2022, 5, 10, 0, 0, 0, 0, time.UTC)
	posts := []*model.Post{
		{
			Slug:       "2021-07-18-pagorki",
			Title:      "Pagórki przed żniwami",
			Date:       time.Date(2021, 7, 18, 0, 0, 0, 0, time.UTC),
			FinishedAt: &fin1,
			TagSlugs:   []string{"bicycle"},
			TownSlugs:  []string{"pobiedziska"},
			Distance:   42.0,
			TimeSpent:  3.0,
			ImageFilename: "header.jpg",
		},
		{
			Slug:       "2021-08-01-second-trip",
			Title:      "Druga wycieczka",
			Date:       time.Date(2021, 8, 1, 0, 0, 0, 0, time.UTC),
			FinishedAt: &fin2,
			TagSlugs:   []string{"bicycle", "hike"},
			TownSlugs:  []string{"swarzedz"},
			Distance:   30.0,
			TimeSpent:  2.5,
		},
		{
			Slug:       "2022-05-09-next-year",
			Title:      "Następny rok",
			Date:       time.Date(2022, 5, 9, 0, 0, 0, 0, time.UTC),
			FinishedAt: &fin3,
			TagSlugs:   []string{"bicycle"},
			TownSlugs:  []string{"pobiedziska"},
			Distance:   55.0,
			TimeSpent:  4.0,
		},
	}
	tags := []model.Tag{
		{Slug: "bicycle", SlugPl: "rowerem", Name: "Rowerem", IsNav: true},
		{Slug: "hike", SlugPl: "pieszo", Name: "Pieszo"},
	}
	areas := []*model.Area{
		{Slug: "pobiedziska", Name: "Pobiedziska", Type: model.AreaTypeTown, VoivodeshipSlug: "wielkopolskie"},
		{Slug: "swarzedz", Name: "Swarzędz", Type: model.AreaTypeTown, VoivodeshipSlug: "wielkopolskie"},
		{Slug: "wielkopolskie", Name: "Wielkopolskie", Type: model.AreaTypeVoivodeship},
	}
	cfg := model.SiteConfig{Title: "Odkrywając Polskę", URL: "https://odkrywajacpolske.pl"}

	return index.BuildSiteData(posts, tags, nil, areas, cfg, nil, nil, nil)
}

func TestYearReportPageURL(t *testing.T) {
	data := testSiteDataForYearReport()
	r := router.New("https://odkrywajacpolske.pl")

	page := YearReportPage(data, 2021, r, nil)
	if page.URL() != "/rok/2021.html" {
		t.Errorf("URL() = %q, want /rok/2021.html", page.URL())
	}
	if !page.AddToSitemap() {
		t.Error("year report should be in sitemap")
	}
}

func TestYearReportPageRender(t *testing.T) {
	data := testSiteDataForYearReport()
	r := router.New("https://odkrywajacpolske.pl")

	page := YearReportPage(data, 2021, r, nil)
	var buf bytes.Buffer
	if err := page.Render(&buf); err != nil {
		t.Fatal(err)
	}

	html := buf.String()
	checks := []string{
		"Rok 2021",
		"72 km",       // total distance (42+30)
		"wpisów",
		"rowerem",
		"Rowerem",    // tag breakdown
		"rok/2022",   // year navigation
	}

	for _, check := range checks {
		if !strings.Contains(html, check) {
			t.Errorf("HTML missing %q", check)
		}
	}
}

func TestYearReportAggregation(t *testing.T) {
	data := testSiteDataForYearReport()
	r := router.New("https://odkrywajacpolske.pl")

	rd := computeYearReport(data, 2021, r)

	if rd.PostCount != 2 {
		t.Errorf("PostCount = %d, want 2", rd.PostCount)
	}
	if rd.TotalDistance != 72 {
		t.Errorf("TotalDistance = %d, want 72", rd.TotalDistance)
	}
	if rd.BicycleCount != 2 {
		t.Errorf("BicycleCount = %d, want 2", rd.BicycleCount)
	}
	if rd.HikeCount != 1 {
		t.Errorf("HikeCount = %d, want 1", rd.HikeCount)
	}
	if rd.LongestTrip != 42.0 {
		t.Errorf("LongestTrip = %f, want 42.0", rd.LongestTrip)
	}
	if rd.NewTownsCount != 2 {
		t.Errorf("NewTownsCount = %d, want 2", rd.NewTownsCount)
	}
}

func TestYearReportNewTownsExcludesPriorYears(t *testing.T) {
	data := testSiteDataForYearReport()
	r := router.New("https://odkrywajacpolske.pl")

	rd := computeYearReport(data, 2022, r)

	// pobiedziska was already visited in 2021, so no new towns
	if rd.NewTownsCount != 0 {
		t.Errorf("NewTownsCount for 2022 = %d, want 0 (pobiedziska was in 2021)", rd.NewTownsCount)
	}
}

func TestYearReportSparklineData(t *testing.T) {
	data := testSiteDataForYearReport()
	r := router.New("https://odkrywajacpolske.pl")

	rd := computeYearReport(data, 2021, r)

	// July = month 7, index 6
	if rd.Months[6].Distance != 42.0 {
		t.Errorf("July distance = %f, want 42.0", rd.Months[6].Distance)
	}
	// August = month 8, index 7
	if rd.Months[7].Distance != 30.0 {
		t.Errorf("August distance = %f, want 30.0", rd.Months[7].Distance)
	}
	if rd.MaxMonthDist != 42.0 {
		t.Errorf("MaxMonthDist = %f, want 42.0", rd.MaxMonthDist)
	}
}

func TestPostHelperMethods(t *testing.T) {
	p := &model.Post{
		TagSlugs: []string{"bicycle", "hike"},
		Routes: []model.Route{
			{Type: "bicycle", Segments: [][]model.LatLon{{{Lat: 1, Lon: 2}}}},
		},
	}

	if !p.HasTag("bicycle") {
		t.Error("HasTag bicycle should be true")
	}
	if p.HasTag("train") {
		t.Error("HasTag train should be false")
	}
	if !p.IsBicycle() {
		t.Error("IsBicycle should be true")
	}
	if !p.IsHike() {
		t.Error("IsHike should be true")
	}
	if !p.IsSelfPropelled() {
		t.Error("IsSelfPropelled should be true")
	}
	if !p.HasRoutes() {
		t.Error("HasRoutes should be true")
	}
	if p.IsPhotoOfTheYear() {
		t.Error("IsPhotoOfTheYear should be false")
	}
}
