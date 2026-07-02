package view

import (
	"sort"
	"time"

	"odkrywajac/internal/catalog"
	"odkrywajac/internal/service/bundle"
	"odkrywajac/internal/service/router"
	"odkrywajac/internal/view/template/layout"
	"odkrywajac/internal/view/template/views"
)

// BurnoutPage creates a Renderable for the burnout stats page.
func BurnoutPage(
	data *catalog.SiteData,
	r *router.Router,
	resolver *bundle.Resolver,
) Renderable {
	url := r.BurnoutURL()

	cssFiles, jsFiles := resolveAssets(resolver, []string{"core"}, []string{"burnout"})

	page := layout.PageData{
		Title:        "Burnout",
		Desc:         "Miesięczna aktywność — porównanie rok do roku",
		URL:          url,
		CanonicalURL: r.CanonicalURL(url),
		SiteName:     data.Config.Title,
		CSSFiles:     cssFiles,
		JSFiles:      jsFiles,
		NavStats:     navStatsFromIndex(data.NavStats, r, data.TagBySlug),
	}

	bd := computeBurnout(data)

	return NewHTMLPage(url, page, views.BurnoutContent(bd), false)
}

func computeBurnout(data *catalog.SiteData) views.BurnoutData {
	type monthKey struct {
		year  int
		month int
	}
	type monthData struct {
		distance  int
		timeSpent int
	}

	monthly := make(map[monthKey]monthData)
	var firstDate, lastDate time.Time

	for _, post := range data.Posts {
		if !post.IsFinished() || (post.Distance == 0 && post.TimeSpent == 0) || !post.IsSelfPropelled() {
			continue
		}

		mk := monthKey{post.Date.Year(), int(post.Date.Month())}
		md := monthly[mk]
		md.distance += int(post.Distance)
		md.timeSpent += int(post.TimeSpent)
		monthly[mk] = md

		if firstDate.IsZero() || post.Date.Before(firstDate) {
			firstDate = post.Date
		}
		if lastDate.IsZero() || post.Date.After(lastDate) {
			lastDate = post.Date
		}
	}

	if firstDate.IsZero() {
		return views.BurnoutData{}
	}

	var months []views.BurnoutMonth
	maxDist := 0
	maxTime := 0

	current := time.Date(firstDate.Year(), firstDate.Month(), 1, 0, 0, 0, 0, time.UTC)
	end := time.Date(lastDate.Year(), lastDate.Month(), 1, 0, 0, 0, 0, time.UTC)

	for !current.After(end) {
		mk := monthKey{current.Year(), int(current.Month())}
		md := monthly[mk]

		bm := views.BurnoutMonth{
			Date:      current,
			Distance:  md.distance,
			TimeSpent: md.timeSpent,
		}

		prevMK := monthKey{current.Year() - 1, int(current.Month())}
		if prev, ok := monthly[prevMK]; ok {
			bm.DistanceLastYear = intPtr(prev.distance)
			bm.TimeSpentLastYear = intPtr(prev.timeSpent)
			if prev.distance > 0 {
				change := md.distance - prev.distance
				pct := int(float64(change) / float64(prev.distance) * 100)
				bm.DistanceChange = intPtr(change)
				bm.DistanceChangePercent = intPtr(pct)
			}
			if prev.timeSpent > 0 {
				change := md.timeSpent - prev.timeSpent
				pct := int(float64(change) / float64(prev.timeSpent) * 100)
				bm.TimeSpentChange = intPtr(change)
				bm.TimeSpentChangePercent = intPtr(pct)
			}
		}

		var distSum, timeSum, count int
		for y := firstDate.Year(); y < current.Year(); y++ {
			amk := monthKey{y, int(current.Month())}
			if am, ok := monthly[amk]; ok {
				distSum += am.distance
				timeSum += am.timeSpent
				count++
			}
		}
		if count > 0 {
			avgDist := distSum / count
			avgTime := timeSum / count
			bm.DistanceAvg = intPtr(avgDist)
			bm.TimeSpentAvg = intPtr(avgTime)
			if avgDist > 0 {
				change := md.distance - avgDist
				bm.DistanceAvgChange = intPtr(change)
				bm.DistanceAvgChangePercent = intPtr(int(float64(change) / float64(avgDist) * 100))
			}
			if avgTime > 0 {
				change := md.timeSpent - avgTime
				bm.TimeSpentAvgChange = intPtr(change)
				bm.TimeSpentAvgChangePercent = intPtr(int(float64(change) / float64(avgTime) * 100))
			}
		}

		if md.distance > maxDist {
			maxDist = md.distance
		}
		if md.timeSpent > maxTime {
			maxTime = md.timeSpent
		}

		months = append(months, bm)
		current = current.AddDate(0, 1, 0)
	}

	sort.Slice(months, func(i, j int) bool {
		return months[i].Date.After(months[j].Date)
	})

	return views.BurnoutData{
		Months:      months,
		MaxDistance: maxDist,
		MaxTime:     maxTime,
	}
}

func intPtr(v int) *int {
	return &v
}
