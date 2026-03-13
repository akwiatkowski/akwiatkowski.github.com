package views_test

import (
	"testing"
	"time"

	"odkrywajac/internal/templates/components"
	h "odkrywajac/internal/templates/htmltest"
	"odkrywajac/internal/templates/layout"
	"odkrywajac/internal/templates/views"
)

// --- PostArticle ---

func TestPostArticle_RendersHeroHeader(t *testing.T) {
	data := views.PostArticleData{
		HeroImageURL: "/photos/hero.jpg",
		Title:        "Wycieczka po Wielkopolsce",
		Subtitle:     "Dzień pełen przygód",
		DateStr:      "2023-06-15 (czwartek)",
		Author:       "Olek",
	}
	out := h.Render(t, views.PostArticleContent(data))
	doc := h.Parse(t, out)

	headers := h.FindByClass(doc, "intro-header")
	if len(headers) == 0 {
		t.Fatal("expected .intro-header")
	}

	h1s := h.FindByTag(headers[0], "h1")
	if len(h1s) == 0 {
		t.Fatal("expected <h1>")
	}
	if text := h.InnerText(h1s[0]); text != "Wycieczka po Wielkopolsce" {
		t.Errorf("expected title, got %q", text)
	}

	h2s := h.FindByClass(doc, "subheading")
	if len(h2s) == 0 {
		t.Fatal("expected .subheading")
	}
	if text := h.InnerText(h2s[0]); text != "Dzień pełen przygód" {
		t.Errorf("expected subtitle, got %q", text)
	}

	meta := h.FindByClass(doc, "meta")
	if len(meta) == 0 {
		t.Fatal("expected .meta")
	}
	metaText := h.InnerText(meta[0])
	h.AssertContains(t, metaText, "Olek")
	h.AssertContains(t, metaText, "2023-06-15 (czwartek)")
}

func TestPostArticle_OmitsHeroWhenNoImage(t *testing.T) {
	data := views.PostArticleData{Title: "No Hero"}
	out := h.Render(t, views.PostArticleContent(data))
	h.AssertNotContains(t, out, "intro-header")
}

func TestPostArticle_RendersTagLinks(t *testing.T) {
	data := views.PostArticleData{
		Title: "Tagged",
		TagLinks: []views.PostTagLink{
			{URL: "/wpisy-dla/tagu/rowerem.html", Name: "rowerem"},
			{URL: "/wpisy-dla/tagu/najlepsze.html", Name: "najlepsze"},
		},
	}
	out := h.Render(t, views.PostArticleContent(data))
	h.AssertContains(t, out, "Tagi:")
	h.AssertContains(t, out, "/wpisy-dla/tagu/rowerem.html")
	h.AssertContains(t, out, "rowerem")
	h.AssertContains(t, out, "najlepsze")
}

func TestPostArticle_RendersAreaLinks(t *testing.T) {
	data := views.PostArticleData{
		Title: "Area",
		AreaLinks: []views.PostAreaGroup{
			{
				Label: "Gminy",
				Areas: []views.PostAreaLink{
					{URL: "/gmina/pobiedziska.html", Name: "Pobiedziska"},
				},
			},
		},
	}
	out := h.Render(t, views.PostArticleContent(data))
	h.AssertContains(t, out, "Gminy:")
	h.AssertContains(t, out, "/gmina/pobiedziska.html")
	h.AssertContains(t, out, "Pobiedziska")
}

func TestPostArticle_RendersRouteStats(t *testing.T) {
	data := views.PostArticleData{
		Title:         "Stats",
		ActivityBadge: "🚲 rowerem",
		DistanceStr:   "45 km",
		TimeStr:       "6 h",
		TemperatureStr: "🌡 22 °C",
	}
	out := h.Render(t, views.PostArticleContent(data))
	doc := h.Parse(t, out)

	statsDiv := h.FindByClass(doc, "post-route-stats")
	if len(statsDiv) == 0 {
		t.Fatal("expected .post-route-stats")
	}
	h.AssertContains(t, out, "rowerem")
	h.AssertContains(t, out, "45 km")
	h.AssertContains(t, out, "6 h")
	h.AssertContains(t, out, "22 °C")
}

func TestPostArticle_RendersMapLinks(t *testing.T) {
	data := views.PostArticleData{
		Title: "Maps",
		MapLinks: []views.MapLink{
			{Name: "OSM", URL: "https://osm.org/test"},
			{Name: "Google", URL: "https://google.com/maps"},
		},
	}
	out := h.Render(t, views.PostArticleContent(data))
	h.AssertContains(t, out, "Mapy:")
	h.AssertContains(t, out, "https://osm.org/test")
	h.AssertContains(t, out, "OSM")
	h.AssertContains(t, out, "Google")
}

func TestPostArticle_RendersRenderedMarkdown(t *testing.T) {
	data := views.PostArticleData{
		Title:            "Content",
		RenderedMarkdown: "<p>Hello <strong>world</strong></p>",
	}
	out := h.Render(t, views.PostArticleContent(data))
	h.AssertContains(t, out, "<p>Hello <strong>world</strong></p>")
}

func TestPostArticle_RendersPrevNextPager(t *testing.T) {
	data := views.PostArticleData{
		Title: "Pager",
		PrevPost: &views.PostPagerData{
			URL:              "/prev.html",
			Title:            "Previous Post",
			ThumbnailJPEGURL: "/prev_thumb.jpg",
		},
		NextPost: &views.PostPagerData{
			URL:              "/next.html",
			Title:            "Next Post",
			ThumbnailJPEGURL: "/next_thumb.jpg",
		},
		GalleryURL: "/gallery.html",
	}
	out := h.Render(t, views.PostArticleContent(data))
	doc := h.Parse(t, out)

	pagers := h.FindByClass(doc, "post-pager-container")
	if len(pagers) == 0 {
		t.Fatal("expected .post-pager-container")
	}

	h.AssertContains(t, out, "Poprzedni")
	h.AssertContains(t, out, "/prev.html")
	h.AssertContains(t, out, "Previous Post")
	h.AssertContains(t, out, "Następny")
	h.AssertContains(t, out, "/next.html")
	h.AssertContains(t, out, "Next Post")
	h.AssertContains(t, out, "Galeria")
	h.AssertContains(t, out, "/gallery.html")
}

func TestPostArticle_RendersRelatedPosts(t *testing.T) {
	data := views.PostArticleData{
		Title: "Related",
		RelatedPosts: []components.PostCardData{
			{URL: "/related1.html", Title: "Related 1"},
			{URL: "/related2.html", Title: "Related 2"},
		},
	}
	out := h.Render(t, views.PostArticleContent(data))
	h.AssertContains(t, out, "Powiązane wpisy")
	h.AssertContains(t, out, "Related 1")
	h.AssertContains(t, out, "Related 2")
}

func TestPostArticle_RendersFinishedAt(t *testing.T) {
	data := views.PostArticleData{
		Title:         "Finished",
		FinishedAtStr: "2023-07-01",
	}
	out := h.Render(t, views.PostArticleContent(data))
	h.AssertContains(t, out, "Wpis ukończony: 2023-07-01")
}

func TestPostArticle_RendersSvgMap(t *testing.T) {
	data := views.PostArticleData{
		Title:     "Map",
		SvgMapURL: "/mapa_zdjec/wpis/test.svg",
	}
	out := h.Render(t, views.PostArticleContent(data))
	h.AssertContains(t, out, "Mapa")
	h.AssertContains(t, out, "/mapa_zdjec/wpis/test.svg")
}

// --- Homepage ---

func TestHomepage_RendersHeroSection(t *testing.T) {
	stats := layout.NavStats{BicycleDistance: 1234, HikeDistance: 567, SelfTime: 89}
	out := h.Render(t, views.HomepageContent(stats))
	doc := h.Parse(t, out)

	heroes := h.FindByClass(doc, "hero")
	if len(heroes) == 0 {
		t.Fatal("expected .hero section")
	}
	h.AssertContains(t, out, "Polska, której nie zobaczysz")
	h.AssertContains(t, out, "z autostrady")
}

func TestHomepage_RendersStats(t *testing.T) {
	stats := layout.NavStats{BicycleDistance: 1234, HikeDistance: 567, SelfTime: 89}
	out := h.Render(t, views.HomepageContent(stats))
	h.AssertContains(t, out, "1234")
	h.AssertContains(t, out, "567")
	h.AssertContains(t, out, "89")
	h.AssertContains(t, out, "rowerem")
	h.AssertContains(t, out, "pieszo")
	h.AssertContains(t, out, "w terenie")
}

func TestHomepage_RendersRecentPostsSection(t *testing.T) {
	stats := layout.NavStats{}
	out := h.Render(t, views.HomepageContent(stats))
	h.AssertContains(t, out, "Ostatnie wpisy")
	h.AssertContains(t, out, "posts-grid")
}

func TestHomepage_RendersCategoriesSection(t *testing.T) {
	stats := layout.NavStats{}
	out := h.Render(t, views.HomepageContent(stats))
	h.AssertContains(t, out, "Odkrywaj")
	h.AssertContains(t, out, "section-categories")
}

func TestHomepageStats_RendersStatUnits(t *testing.T) {
	stats := layout.NavStats{BicycleDistance: 100, HikeDistance: 50, SelfTime: 20}
	out := h.Render(t, views.HomepageStats(stats))
	doc := h.Parse(t, out)

	units := h.FindByClass(doc, "stat-unit")
	if len(units) < 3 {
		t.Errorf("expected at least 3 stat-unit spans, got %d", len(units))
	}

	// Check km and h units
	h.AssertContains(t, out, "km")
	h.AssertContains(t, out, "h")
}

// --- Burnout ---

func TestBurnout_RendersTitle(t *testing.T) {
	bd := views.BurnoutData{}
	out := h.Render(t, views.BurnoutContent(bd))
	h.AssertContains(t, out, "Burnout")
	h.AssertContains(t, out, "aktywność miesięczna")
}

func TestBurnout_RendersTableHeaders(t *testing.T) {
	bd := views.BurnoutData{}
	out := h.Render(t, views.BurnoutContent(bd))
	h.AssertContains(t, out, "Miesiąc")
	h.AssertContains(t, out, "Dystans (km)")
	h.AssertContains(t, out, "Czas (h)")
}

func TestBurnout_RendersMonthRow(t *testing.T) {
	lastYear := 80
	avg := 90
	changePct := 25
	bd := views.BurnoutData{
		Months: []views.BurnoutMonth{
			{
				Date:                  time.Date(2023, 6, 1, 0, 0, 0, 0, time.UTC),
				Distance:              100,
				DistanceLastYear:      &lastYear,
				DistanceAvg:           &avg,
				DistanceChangePercent: &changePct,
				TimeSpent:             15,
			},
		},
		MaxDistance: 200,
		MaxTime:    30,
	}
	out := h.Render(t, views.BurnoutContent(bd))
	h.AssertContains(t, out, "2023-06")
	h.AssertContains(t, out, "100")
	h.AssertContains(t, out, "80")
	h.AssertContains(t, out, "90")
	h.AssertContains(t, out, "+25%")
}

// --- TownsHistory ---

func TestTownsHistory_RendersTitle(t *testing.T) {
	hd := views.TownsHistoryData{TotalTowns: 42}
	out := h.Render(t, views.TownsHistoryContent(hd))
	h.AssertContains(t, out, "Historia odwiedzonych gmin")
	h.AssertContains(t, out, "Odwiedzono 42 gmin.")
}

func TestTownsHistory_RendersVoivodeshipGroups(t *testing.T) {
	hd := views.TownsHistoryData{
		TotalTowns: 2,
		Groups: []views.TownsHistoryGroup{
			{
				VoivodeshipName: "wielkopolskie",
				VoivodeshipURL:  "/wojewodztwo/wielkopolskie.html",
				Towns: []views.TownHistoryEntry{
					{
						Name:       "Pobiedziska",
						URL:        "/gmina/pobiedziska.html",
						FirstVisit: time.Date(2020, 3, 15, 0, 0, 0, 0, time.UTC),
					},
				},
			},
		},
	}
	out := h.Render(t, views.TownsHistoryContent(hd))
	doc := h.Parse(t, out)

	h.AssertContains(t, out, "wielkopolskie")
	h.AssertContains(t, out, "/wojewodztwo/wielkopolskie.html")
	h.AssertContains(t, out, "Pobiedziska")
	h.AssertContains(t, out, "/gmina/pobiedziska.html")
	h.AssertContains(t, out, "2020-03-15")

	// Check count is shown
	h.AssertContains(t, out, "(1)")

	// Check it's an ordered list
	ols := h.FindByTag(doc, "ol")
	if len(ols) == 0 {
		t.Error("expected <ol> for town list")
	}
}

// --- TownsTimeline ---

func TestTownsTimeline_RendersTitle(t *testing.T) {
	td := views.TownsTimelineData{}
	out := h.Render(t, views.TownsTimelineContent(td))
	h.AssertContains(t, out, "Gminy chronologicznie")
}

func TestTownsTimeline_RendersMonthWithTowns(t *testing.T) {
	td := views.TownsTimelineData{
		Months: []views.TimelineMonth{
			{
				Label:           "Czerwiec 2023",
				CumulativeSelf:  10,
				CumulativeTotal: 15,
				RevisitCount:    2,
				SelfTowns: []views.TimelineTown{
					{Name: "Pobiedziska", URL: "/gmina/pobiedziska.html", Ordinal: 11, IsSelf: true},
				},
				VehicleTowns: []views.TimelineTown{
					{Name: "Gniezno", URL: "/gmina/gniezno.html", Ordinal: 16, IsSelf: false},
				},
			},
		},
	}
	out := h.Render(t, views.TownsTimelineContent(td))

	h.AssertContains(t, out, "Czerwiec 2023")
	h.AssertContains(t, out, "Łącznie własnym napędem: 10")
	h.AssertContains(t, out, "Wszystkie: 15")
	h.AssertContains(t, out, "Powtórne: 2")

	// Self town with green badge
	h.AssertContains(t, out, "#11")
	h.AssertContains(t, out, "Pobiedziska")
	h.AssertContains(t, out, "bg-success")

	// Vehicle town with gray badge
	h.AssertContains(t, out, "#16")
	h.AssertContains(t, out, "Gniezno")
	h.AssertContains(t, out, "bg-secondary")
}

// --- YearReport ---

func TestYearReport_RendersTitle(t *testing.T) {
	rd := views.YearReportData{Year: 2023}
	out := h.Render(t, views.YearReportContent(rd))
	h.AssertContains(t, out, "Rok 2023")
}

func TestYearReport_RendersYearNavigation(t *testing.T) {
	rd := views.YearReportData{
		Year: 2023,
		YearReportURLs: []views.YearReportLink{
			{Year: 2022, URL: "/rok-2022.html", IsCurrent: false},
			{Year: 2023, URL: "/rok-2023.html", IsCurrent: true},
		},
	}
	out := h.Render(t, views.YearReportContent(rd))
	doc := h.Parse(t, out)

	yearNav := h.FindByClass(doc, "year-nav")
	if len(yearNav) == 0 {
		t.Fatal("expected .year-nav")
	}

	// Current year should be bold
	strongs := h.FindByTag(yearNav[0], "strong")
	if len(strongs) == 0 {
		t.Error("expected <strong> for current year")
	}
	if text := h.InnerText(strongs[0]); text != "2023" {
		t.Errorf("expected 2023 as current, got %q", text)
	}

	// Other year should be a link
	h.AssertContains(t, out, "/rok-2022.html")
}

func TestYearReport_RendersSummaryCards(t *testing.T) {
	rd := views.YearReportData{
		Year:          2023,
		PostCount:     15,
		TotalDistance:  800,
		TotalTime:     120,
		BicycleCount:  10,
		HikeCount:     5,
		NewTownsCount: 20,
	}
	out := h.Render(t, views.YearReportContent(rd))
	h.AssertContains(t, out, "15")
	h.AssertContains(t, out, "wpisów")
	h.AssertContains(t, out, "800 km")
	h.AssertContains(t, out, "dystans")
	h.AssertContains(t, out, "120 h")
	h.AssertContains(t, out, "czas")
	h.AssertContains(t, out, "rowerem")
	h.AssertContains(t, out, "pieszo")
	h.AssertContains(t, out, "nowe gminy") //nolint:misspell // Polish word
}

func TestYearReport_RendersPhotoOfYear(t *testing.T) {
	rd := views.YearReportData{
		Year:               2023,
		PhotoOfYearURL:     "/photos/best.jpg",
		PhotoOfYearAVIF:    "/photos/best.avif",
		PhotoOfYearTitle:   "Best Photo 2023",
		PhotoOfYearPostURL: "/post/best.html",
	}
	out := h.Render(t, views.YearReportContent(rd))
	doc := h.Parse(t, out)

	photoDiv := h.FindByClass(doc, "photo-of-year")
	if len(photoDiv) == 0 {
		t.Fatal("expected .photo-of-year")
	}
	h.AssertContains(t, out, "/photos/best.jpg")
	h.AssertContains(t, out, "/photos/best.avif")
	h.AssertContains(t, out, "Best Photo 2023")
}

func TestYearReport_RendersTagBreakdown(t *testing.T) {
	rd := views.YearReportData{
		Year: 2023,
		TagBreakdown: []views.TagCount{
			{Name: "rowerem", Count: 10},
			{Name: "pieszo", Count: 5},
		},
	}
	out := h.Render(t, views.YearReportContent(rd))
	doc := h.Parse(t, out)

	chips := h.FindByClass(doc, "tag-chips")
	if len(chips) == 0 {
		t.Fatal("expected .tag-chips")
	}
	h.AssertContains(t, out, "rowerem")
	h.AssertContains(t, out, "10")
	h.AssertContains(t, out, "pieszo")
}

func TestYearReport_RendersVoivodeships(t *testing.T) {
	rd := views.YearReportData{
		Year: 2023,
		Voivodeships: []views.VoivodeshipLink{
			{Name: "wielkopolskie", URL: "/wojewodztwo/wielkopolskie.html"},
			{Name: "lubuskie", URL: "/wojewodztwo/lubuskie.html"},
		},
	}
	out := h.Render(t, views.YearReportContent(rd))
	h.AssertContains(t, out, "Województwa:")
	h.AssertContains(t, out, "wielkopolskie")
	h.AssertContains(t, out, "/wojewodztwo/wielkopolskie.html")
	h.AssertContains(t, out, "lubuskie")
}

func TestYearReport_RendersLongestTripRecord(t *testing.T) {
	rd := views.YearReportData{
		Year:             2023,
		LongestTrip:      120,
		LongestTripTitle: "Epic Ride",
		LongestTripURL:   "/post/epic.html",
		IsLongestAllTime: true,
	}
	out := h.Render(t, views.YearReportContent(rd))
	h.AssertContains(t, out, "Rekord!")
	h.AssertContains(t, out, "120 km")
	h.AssertContains(t, out, "Epic Ride")
	h.AssertContains(t, out, "border-success")
}

func TestYearReport_RendersMonthlyTable(t *testing.T) {
	var months [12]views.MonthStats
	months[5] = views.MonthStats{Month: 6, Distance: 150, BicycleDistance: 100, HikeDistance: 50, TimeSpent: 20, PostCount: 3}
	rd := views.YearReportData{
		Year:         2023,
		Months:       months,
		MaxMonthDist: 150,
	}
	out := h.Render(t, views.YearReportContent(rd))
	h.AssertContains(t, out, "Miesiące")
	h.AssertContains(t, out, "Czerwiec")
	h.AssertContains(t, out, "150 km")
	h.AssertContains(t, out, "100 km")
	h.AssertContains(t, out, "50 km")
	h.AssertContains(t, out, "20 h")
}

func TestYearReport_RendersSparklineWhenData(t *testing.T) {
	var months [12]views.MonthStats
	months[0] = views.MonthStats{Distance: 100}
	months[1] = views.MonthStats{Distance: 50}
	rd := views.YearReportData{
		Year:         2023,
		Months:       months,
		MaxMonthDist: 100,
	}
	out := h.Render(t, views.YearReportContent(rd))
	doc := h.Parse(t, out)

	svgs := h.FindByClass(doc, "sparkline")
	if len(svgs) == 0 {
		t.Error("expected sparkline SVG")
	}

	circles := h.FindByTag(doc, "circle")
	if len(circles) != 12 {
		t.Errorf("expected 12 sparkline circles, got %d", len(circles))
	}
}

func TestYearReport_RendersRouteMap(t *testing.T) {
	rd := views.YearReportData{
		Year:      2023,
		HasRoutes: true,
		RouteJSON: `{"routes":[]}`,
	}
	out := h.Render(t, views.YearReportContent(rd))
	doc := h.Parse(t, out)

	yearMap := h.FindAll(doc, func(n *h.Node) bool {
		return h.IsElement(n, "div") && h.HasAttr(n, "id", "year-map")
	})
	if len(yearMap) == 0 {
		t.Error("expected #year-map div")
	}

	// templ.Raw renders JSON inside a <script> tag; check the map div exists
	// and the script tag with year-routes ID is present
	scripts := h.FindAll(doc, func(n *h.Node) bool {
		return h.IsElement(n, "script") && h.HasAttr(n, "id", "year-routes")
	})
	if len(scripts) == 0 {
		t.Error("expected #year-routes script tag")
	}
}

func TestYearReport_OmitsRouteMapWhenNoRoutes(t *testing.T) {
	rd := views.YearReportData{Year: 2023, HasRoutes: false}
	out := h.Render(t, views.YearReportContent(rd))
	h.AssertNotContains(t, out, "year-map")
}

func TestYearReport_YearOverYearComparison(t *testing.T) {
	rd := views.YearReportData{
		Year:             2023,
		TotalDistance:     900,
		PrevYearDistance:  800,
		PrevYearTime:     100,
	}
	out := h.Render(t, views.YearReportContent(rd))
	h.AssertContains(t, out, "Rok wcześniej: 800 km, 100 h")
	h.AssertContains(t, out, "+100 km")
}

// --- GalleryIndex ---

func TestGalleryIndex_RendersTitle(t *testing.T) {
	out := h.Render(t, views.GalleryIndexContent(nil))
	h.AssertContains(t, out, "Galeria")
}

func TestGalleryIndex_RendersGroupedLinks(t *testing.T) {
	links := []views.GalleryIndexLink{
		{URL: "/galeria/tagu/rowerem.html", Name: "Rowerem", Category: "Tagi"},
		{URL: "/galeria/tagu/pieszo.html", Name: "Pieszo", Category: "Tagi"},
		{URL: "/galeria/gminy/pobiedziska.html", Name: "Pobiedziska", Category: "Gminy"},
	}
	out := h.Render(t, views.GalleryIndexContent(links))
	doc := h.Parse(t, out)

	// Check categories rendered as h3
	h3s := h.FindByTag(doc, "h3")
	catTexts := make(map[string]bool)
	for _, heading := range h3s {
		catTexts[h.InnerText(heading)] = true
	}
	if !catTexts["Tagi"] {
		t.Error("expected 'Tagi' category heading")
	}
	if !catTexts["Gminy"] {
		t.Error("expected 'Gminy' category heading")
	}

	// Check links
	h.AssertContains(t, out, "Rowerem")
	h.AssertContains(t, out, "/galeria/tagu/rowerem.html")
	h.AssertContains(t, out, "Pobiedziska")
}

// --- DebugTagStats ---

func TestDebugTagStats_RendersTable(t *testing.T) {
	rows := []views.DebugTagStatsRow{
		{
			PostTitle:    "Wycieczka",
			PostURL:      "/post.html",
			TotalPhotos:  20,
			TaggedPhotos: 15,
			GoodPhotos:   5,
			BestPhotos:   2,
		},
	}
	out := h.Render(t, views.DebugTagStatsContent(rows))
	doc := h.Parse(t, out)

	h.AssertContains(t, out, "Photo Tag Stats")

	tables := h.FindByTag(doc, "table")
	if len(tables) == 0 {
		t.Fatal("expected <table>")
	}

	h.AssertContains(t, out, "Wycieczka")
	h.AssertContains(t, out, "/post.html")
	h.AssertContains(t, out, "20")
	h.AssertContains(t, out, "15")
	h.AssertContains(t, out, "75%")
}

// --- StaticAbout ---

func TestStaticAbout_RendersHeading(t *testing.T) {
	out := h.Render(t, views.StaticAboutContent("<p>About content</p>"))
	h.AssertContains(t, out, "O mnie")
	h.AssertContains(t, out, "I o tej stronie")
}

func TestStaticAbout_RendersContent(t *testing.T) {
	out := h.Render(t, views.StaticAboutContent("<p>About content</p>"))
	h.AssertContains(t, out, "<p>About content</p>")
}

// --- StaticEnglish ---

func TestStaticEnglish_RendersHeading(t *testing.T) {
	out := h.Render(t, views.StaticEnglishContent("<p>English text</p>"))
	h.AssertContains(t, out, "Welcome")
	h.AssertContains(t, out, "a few words for English only speaking visitors")
}

func TestStaticEnglish_RendersContent(t *testing.T) {
	out := h.Render(t, views.StaticEnglishContent("<p>English text</p>"))
	h.AssertContains(t, out, "<p>English text</p>")
}

// --- StaticMore ---

func TestStaticMore_RendersTitle(t *testing.T) {
	out := h.Render(t, views.StaticMoreContent(nil))
	h.AssertContains(t, out, "Więcej")
}

func TestStaticMore_RendersLinks(t *testing.T) {
	links := []views.MoreLink{
		{URL: "/galeria.html", Name: "Galeria", Desc: "Wszystkie zdjęcia", Icon: "photos"},
		{URL: "/o-mnie.html", Name: "O mnie", Desc: "Kim jestem", Icon: "stats"},
	}
	out := h.Render(t, views.StaticMoreContent(links))
	doc := h.Parse(t, out)

	moreLinks := h.FindByClass(doc, "more-link")
	if len(moreLinks) != 2 {
		t.Errorf("expected 2 more-link items, got %d", len(moreLinks))
	}
	h.AssertContains(t, out, "Galeria")
	h.AssertContains(t, out, "Wszystkie zdjęcia")
	h.AssertContains(t, out, "/galeria.html")
	h.AssertContains(t, out, "O mnie")
}

// --- Simple script-injecting views ---

func TestGalleryDynamic_RendersRawHTML(t *testing.T) {
	rawHTML := `<script id="gallery-config" type="application/json">{"test":1}</script>` +
		"\n" + `<div id="root"></div>`
	out := h.Render(t, views.GalleryDynamicContent(rawHTML))
	h.AssertContains(t, out, `{"test":1}`)
	doc := h.Parse(t, out)
	root := h.FindAll(doc, func(n *h.Node) bool {
		return h.IsElement(n, "div") && h.HasAttr(n, "id", "root")
	})
	if len(root) == 0 {
		t.Error("expected #root div")
	}
}

func TestAreaShow_RendersScriptAndRoot(t *testing.T) {
	out := h.Render(t, views.AreaShowContent(`<script id="area-data">{"name":"test"}</script>`))
	h.AssertContains(t, out, `{"name":"test"}`)
	doc := h.Parse(t, out)
	root := h.FindAll(doc, func(n *h.Node) bool {
		return h.IsElement(n, "div") && h.HasAttr(n, "id", "root")
	})
	if len(root) == 0 {
		t.Error("expected #root div")
	}
}

func TestAreaPostList_RendersScriptAndContainer(t *testing.T) {
	out := h.Render(t, views.AreaPostListContent(`<script>config()</script>`))
	h.AssertContains(t, out, "config()")
	doc := h.Parse(t, out)
	container := h.FindAll(doc, func(n *h.Node) bool {
		return h.IsElement(n, "div") && h.HasAttr(n, "id", "posts-container")
	})
	if len(container) == 0 {
		t.Error("expected #posts-container div")
	}
	h.AssertContains(t, out, "Wczytywanie wpisów")
}

func TestAreaGallery_RendersPhotoGrid(t *testing.T) {
	photos := []components.PhotoCardData{
		{JPEGSrc: "/1.jpg", Alt: "one"},
		{JPEGSrc: "/2.jpg", Alt: "two"},
	}
	out := h.Render(t, views.AreaGalleryContent(photos))
	doc := h.Parse(t, out)

	galleryContainer := h.FindByClass(doc, "gallery-container")
	if len(galleryContainer) == 0 {
		t.Fatal("expected .gallery-container")
	}
	grid := h.FindByClass(doc, "photo-grid")
	if len(grid) == 0 {
		t.Fatal("expected .photo-grid")
	}
	if !h.HasClass(grid[0], "cols-3") {
		t.Error("expected cols-3 for area gallery")
	}
	cards := h.FindByClass(doc, "photo-card")
	if len(cards) != 2 {
		t.Errorf("expected 2 photo cards, got %d", len(cards))
	}
}

func TestPOIs_RendersScriptAndRoot(t *testing.T) {
	out := h.Render(t, views.POIsContent(`<script id="pois-data">[]</script>`))
	h.AssertContains(t, out, "pois-data")
	doc := h.Parse(t, out)
	root := h.FindAll(doc, func(n *h.Node) bool {
		return h.IsElement(n, "div") && h.HasAttr(n, "id", "pois-root")
	})
	if len(root) == 0 {
		t.Error("expected #pois-root div")
	}
}

func TestTownsIndex_RendersScriptAndRoot(t *testing.T) {
	out := h.Render(t, views.TownsIndexContent(`<script id="towns-data">{"towns":[]}</script>`))
	h.AssertContains(t, out, `{"towns":[]}`)
	doc := h.Parse(t, out)
	root := h.FindAll(doc, func(n *h.Node) bool {
		return h.IsElement(n, "div") && h.HasAttr(n, "id", "root")
	})
	if len(root) == 0 {
		t.Error("expected #root div")
	}
}

func TestShell_RendersRootDiv(t *testing.T) {
	out := h.Render(t, views.ShellContent())
	doc := h.Parse(t, out)
	root := h.FindAll(doc, func(n *h.Node) bool {
		return h.IsElement(n, "div") && h.HasAttr(n, "id", "root")
	})
	if len(root) == 0 {
		t.Error("expected #root div")
	}
}
