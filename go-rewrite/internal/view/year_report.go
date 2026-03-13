package view

import (
	"encoding/json"
	"fmt"
	"math"
	"sort"
	"time"

	"odkrywajac/internal/bundle"
	"odkrywajac/internal/index"
	"odkrywajac/internal/model"
	"odkrywajac/internal/router"
	"odkrywajac/internal/templates/layout"
	"odkrywajac/internal/templates/views"
)

// YearReportPage creates a Renderable for a year report page.
func YearReportPage(
	data *index.SiteData,
	year int,
	r *router.Router,
	resolver *bundle.Resolver,
) Renderable {
	url := r.YearReportURL(year)

	rd := computeYearReport(data, year, r)

	bundles := []string{"core"}
	if rd.HasRoutes {
		bundles = append(bundles, "leaflet")
	}
	cssFiles, jsFiles := resolveAssets(resolver, bundles, []string{"year_stats"})

	page := layout.PageData{
		Title:        fmt.Sprintf("Rok %d", year),
		Desc:         fmt.Sprintf("Podsumowanie roku %d — %d wpisów, %d km", year, rd.PostCount, rd.TotalDistance),
		URL:          url,
		CanonicalURL: r.CanonicalURL(url),
		SiteName:     data.Config.Title,
		CSSFiles:     cssFiles,
		JSFiles:      jsFiles,
		NavStats:     navStatsFromIndex(data.NavStats, r, data.TagBySlug),
	}

	return NewHTMLPage(url, page, views.YearReportContent(rd), true)
}

func computeYearReport(data *index.SiteData, year int, r *router.Router) views.YearReportData {
	posts := data.PostsByYear[year]

	var allYears []int
	for y := range data.PostsByYear {
		allYears = append(allYears, y)
	}
	sort.Ints(allYears)

	rd := views.YearReportData{
		Year:     year,
		AllYears: allYears,
	}

	for _, y := range allYears {
		rd.YearReportURLs = append(rd.YearReportURLs, views.YearReportLink{
			Year:      y,
			URL:       r.YearReportURL(y),
			IsCurrent: y == year,
		})
	}

	tagCounts := make(map[string]int)
	systemTags := map[string]bool{
		"photo_of_the_year": true, "featured": true, "draft": true,
	}
	var longestTrip float64
	var longestTripPost *model.Post

	townsSeen := make(map[string]bool)
	for _, p := range data.Posts {
		if !p.IsFinished() || p.Year() >= year {
			continue
		}
		for _, t := range p.TownSlugs {
			townsSeen[t] = true
		}
	}

	newTowns := make(map[string]bool)

	for _, post := range posts {
		if !post.IsFinished() {
			continue
		}
		rd.PostCount++
		rd.TotalDistance += int(post.Distance)
		rd.TotalTime += int(post.TimeSpent)

		m := int(post.Date.Month()) - 1
		rd.Months[m].Month = int(post.Date.Month())
		rd.Months[m].Distance += post.Distance
		rd.Months[m].TimeSpent += post.TimeSpent
		rd.Months[m].PostCount++

		if post.IsBicycle() {
			rd.BicycleCount++
			rd.Months[m].BicycleDistance += post.Distance
		}
		if post.IsHike() {
			rd.HikeCount++
			rd.Months[m].HikeDistance += post.Distance
		}

		for _, tag := range post.TagSlugs {
			if !systemTags[tag] {
				tagCounts[tag]++
			}
		}

		if post.IsSelfPropelled() && post.Distance > longestTrip {
			longestTrip = post.Distance
			longestTripPost = post
		}

		for _, t := range post.TownSlugs {
			if !townsSeen[t] {
				newTowns[t] = true
				townsSeen[t] = true
			}
		}

		if post.IsPhotoOfTheYear() && rd.PhotoOfYearTitle == "" {
			setPhotoOfYear(&rd, post, r)
		}
	}

	rd.NewTownsCount = len(newTowns)

	if rd.PhotoOfYearTitle == "" && longestTripPost != nil {
		setPhotoOfYear(&rd, longestTripPost, r)
	}

	if longestTripPost != nil {
		rd.LongestTrip = longestTrip
		rd.LongestTripTitle = longestTripPost.Title
		rd.LongestTripURL = r.PostURL(longestTripPost)
	}

	for _, ms := range rd.Months {
		if ms.Distance > rd.MaxMonthDist {
			rd.MaxMonthDist = ms.Distance
		}
	}

	for tag, count := range tagCounts {
		if count >= 2 {
			name := tag
			if t := data.TagBySlug[tag]; t != nil {
				name = t.Name
			}
			rd.TagBreakdown = append(rd.TagBreakdown, views.TagCount{Name: name, Count: count})
		}
	}
	sort.Slice(rd.TagBreakdown, func(i, j int) bool {
		return rd.TagBreakdown[i].Count > rd.TagBreakdown[j].Count
	})

	now := time.Now()
	for i, ms := range rd.Months {
		if year == now.Year() && i+1 > int(now.Month()) {
			continue
		}
		if ms.Distance > rd.MostActiveMonthDist {
			rd.MostActiveMonthDist = ms.Distance
			rd.MostActiveMonth = monthName(i + 1)
		}
	}

	computeRecords(&rd, data, year)

	if prevPosts, ok := data.PostsByYear[year-1]; ok {
		for _, p := range prevPosts {
			if p.IsFinished() {
				rd.PrevYearDistance += int(p.Distance)
				rd.PrevYearTime += int(p.TimeSpent)
			}
		}
	}

	voivSeen := make(map[string]bool)
	for _, post := range posts {
		if !post.IsFinished() {
			continue
		}
		for _, slug := range post.TownSlugs {
			area := data.FindArea(model.AreaTypeTown, slug)
			if area != nil && area.VoivodeshipSlug != "" && !voivSeen[area.VoivodeshipSlug] {
				voivSeen[area.VoivodeshipSlug] = true
				voivArea := data.FindArea(model.AreaTypeVoivodeship, area.VoivodeshipSlug)
				if voivArea != nil {
					rd.Voivodeships = append(rd.Voivodeships, views.VoivodeshipLink{
						Name: voivArea.Name,
						URL:  r.AreaShowURL(voivArea),
					})
				}
			}
		}
	}
	sort.Slice(rd.Voivodeships, func(i, j int) bool {
		return rd.Voivodeships[i].Name < rd.Voivodeships[j].Name
	})

	rd.RouteJSON, rd.HasRoutes = buildYearRouteJSON(posts, data)

	// Build posts table entries sorted by date
	for _, post := range posts {
		if !post.IsFinished() {
			continue
		}
		rd.Posts = append(rd.Posts, views.YearPostEntry{
			Date:     post.Date.Format("2006-01-02"),
			Title:    post.Title,
			URL:      r.PostURL(post),
			Distance: int(post.Distance),
			Time:     int(post.TimeSpent),
			Icon:     postTypeIcon(post),
		})
	}
	sort.Slice(rd.Posts, func(i, j int) bool {
		return rd.Posts[i].Date < rd.Posts[j].Date
	})

	return rd
}

// postTypeIcon returns a CSS icon class based on the post's transport tag.
func postTypeIcon(post *model.Post) string {
	switch {
	case post.IsBicycle():
		return "icon-bicycle"
	case post.IsHike():
		return "icon-hike"
	case post.IsWalk():
		return "icon-walk"
	case post.IsTrain():
		return "icon-train"
	case post.HasTag("bus"):
		return "icon-bus"
	case post.HasTag("car"):
		return "icon-car"
	default:
		return ""
	}
}

func setPhotoOfYear(rd *views.YearReportData, post *model.Post, r *router.Router) {
	rd.PhotoOfYearTitle = post.Title
	rd.PhotoOfYearPostURL = r.PostURL(post)
	if post.ImageFilename != "" {
		rd.PhotoOfYearURL = r.ProcessedImageURL(post, post.ImageFilename, "card", "jpg")
		rd.PhotoOfYearAVIF = r.ProcessedImageURL(post, post.ImageFilename, "card", "avif")
	}
}

func computeRecords(rd *views.YearReportData, data *index.SiteData, year int) {
	var allTimeLongest float64
	for _, p := range data.Posts {
		if p.IsFinished() && p.IsSelfPropelled() && p.Distance > allTimeLongest {
			allTimeLongest = p.Distance
		}
	}
	rd.IsLongestAllTime = rd.LongestTrip >= allTimeLongest && rd.LongestTrip > 0

	type monthDist struct {
		dist float64
	}
	var allMonths []monthDist
	for _, posts := range data.PostsByYear {
		var monthly [12]float64
		for _, p := range posts {
			if p.IsFinished() {
				monthly[int(p.Date.Month())-1] += p.Distance
			}
		}
		for _, d := range monthly {
			if d > 0 {
				allMonths = append(allMonths, monthDist{d})
			}
		}
	}
	sort.Slice(allMonths, func(i, j int) bool { return allMonths[i].dist > allMonths[j].dist })
	if len(allMonths) > 0 && rd.MostActiveMonthDist >= allMonths[0].dist {
		rd.IsMostActiveAllTime = true
	}

	maxPostsYear := 0
	maxPostsCount := 0
	for y, posts := range data.PostsByYear {
		count := 0
		for _, p := range posts {
			if p.IsFinished() {
				count++
			}
		}
		if count > maxPostsCount {
			maxPostsCount = count
			maxPostsYear = y
		}
	}
	rd.MostPostsYear = maxPostsYear
	rd.MostPostsCount = maxPostsCount
	rd.IsPostRecordYear = year == maxPostsYear
}

func buildYearRouteJSON(posts []*model.Post, data *index.SiteData) (string, bool) {
	type routeSegment struct {
		Points [][]float64 `json:"points"`
		Color  string      `json:"color"`
		Weight int         `json:"weight"`
	}

	var segments []routeSegment
	for _, post := range posts {
		if !post.IsFinished() || !post.HasRoutes() {
			continue
		}
		for _, route := range post.Routes {
			color := "#3388ff"
			weight := 3
			if rc, ok := data.RouteColors[route.Type]; ok {
				color = rc.Color
				weight = rc.Weight
			}
			for _, seg := range route.Segments {
				points := make([][]float64, len(seg))
				for i, ll := range seg {
					points[i] = []float64{math.Round(ll.Lat*100000) / 100000, math.Round(ll.Lon*100000) / 100000}
				}
				segments = append(segments, routeSegment{
					Points: points,
					Color:  color,
					Weight: weight,
				})
			}
		}
	}

	if len(segments) == 0 {
		return "[]", false
	}

	b, _ := json.Marshal(segments)
	return string(b), true
}

func monthName(m int) string {
	names := [12]string{
		"Styczeń", "Luty", "Marzec", "Kwiecień", "Maj", "Czerwiec",
		"Lipiec", "Sierpień", "Wrzesień", "Październik", "Listopad", "Grudzień",
	}
	if m >= 1 && m <= 12 {
		return names[m-1]
	}
	return ""
}
