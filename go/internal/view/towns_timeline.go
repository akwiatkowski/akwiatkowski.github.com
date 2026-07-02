package view

import (
	"fmt"
	"sort"
	"time"

	"odkrywajac/internal/bundle"
	"odkrywajac/internal/index"
	"odkrywajac/internal/model"
	"odkrywajac/internal/router"
	"odkrywajac/internal/templates/layout"
	"odkrywajac/internal/templates/views"
)

// TownsTimelinePage creates a Renderable for the towns timeline page.
func TownsTimelinePage(
	data *index.SiteData,
	r *router.Router,
	resolver *bundle.Resolver,
) Renderable {
	url := r.TownsTimelineURL()

	cssFiles, jsFiles := resolveAssets(resolver, []string{"core"}, nil)

	page := layout.PageData{
		Title:        "Gminy chronologicznie",
		URL:          url,
		CanonicalURL: r.CanonicalURL(url),
		SiteName:     data.Config.Title,
		CSSFiles:     cssFiles,
		JSFiles:      jsFiles,
		NavStats:     navStatsFromIndex(data.NavStats, r, data.TagBySlug),
	}

	td := computeTownsTimeline(data, r)

	return NewHTMLPage(url, page, views.TownsTimelineContent(td), false)
}

func computeTownsTimeline(data *index.SiteData, r *router.Router) views.TownsTimelineData {
	sorted := make([]*model.Post, 0, len(data.Posts))
	for _, p := range data.Posts {
		if p.IsFinished() {
			sorted = append(sorted, p)
		}
	}
	sort.Slice(sorted, func(i, j int) bool {
		return sorted[i].Date.Before(sorted[j].Date)
	})

	if len(sorted) == 0 {
		return views.TownsTimelineData{}
	}

	townArea := make(map[string]*model.Area)
	for _, a := range data.AreasByType[model.AreaTypeTown] {
		townArea[a.Slug] = a
	}

	type monthKey struct {
		year  int
		month int
	}

	selfSeen := make(map[string]bool)
	allSeen := make(map[string]bool)
	cumulativeSelf := 0
	cumulativeTotal := 0

	monthMap := make(map[monthKey]*views.TimelineMonth)
	var monthOrder []monthKey

	firstMonth := monthKey{sorted[0].Date.Year(), int(sorted[0].Date.Month())}
	lastMonth := monthKey{sorted[len(sorted)-1].Date.Year(), int(sorted[len(sorted)-1].Date.Month())}

	for mk := firstMonth; mk.year < lastMonth.year || (mk.year == lastMonth.year && mk.month <= lastMonth.month); {
		t := time.Date(mk.year, time.Month(mk.month), 1, 0, 0, 0, 0, time.UTC)
		tm := &views.TimelineMonth{
			Date:  t,
			Label: fmt.Sprintf("%d-%02d", mk.year, mk.month),
		}
		monthMap[mk] = tm
		monthOrder = append(monthOrder, mk)

		mk.month++
		if mk.month > 12 {
			mk.month = 1
			mk.year++
		}
	}

	for _, post := range sorted {
		mk := monthKey{post.Date.Year(), int(post.Date.Month())}
		tm := monthMap[mk]
		if tm == nil {
			continue
		}

		for _, slug := range post.TownSlugs {
			area := townArea[slug]
			if area == nil {
				continue
			}

			if post.IsSelfPropelled() {
				if !selfSeen[slug] {
					selfSeen[slug] = true
					if !allSeen[slug] {
						allSeen[slug] = true
						cumulativeTotal++
					}
					cumulativeSelf++
					tm.SelfTowns = append(tm.SelfTowns, views.TimelineTown{
						Name:    area.Name,
						URL:     r.AreaShowURL(area),
						Ordinal: cumulativeSelf,
						IsSelf:  true,
					})
				} else {
					tm.RevisitCount++
				}
			} else {
				if !allSeen[slug] {
					allSeen[slug] = true
					cumulativeTotal++
					tm.VehicleTowns = append(tm.VehicleTowns, views.TimelineTown{
						Name:    area.Name,
						URL:     r.AreaShowURL(area),
						Ordinal: cumulativeTotal,
						IsSelf:  false,
					})
				}
			}
		}
	}

	selfCount := 0
	totalCount := 0
	var months []views.TimelineMonth
	for _, mk := range monthOrder {
		tm := monthMap[mk]
		selfCount += len(tm.SelfTowns)
		totalCount += len(tm.SelfTowns) + len(tm.VehicleTowns)
		tm.CumulativeSelf = selfCount
		tm.CumulativeTotal = totalCount

		if len(tm.SelfTowns) > 0 || len(tm.VehicleTowns) > 0 || tm.RevisitCount > 0 {
			months = append(months, *tm)
		}
	}

	return views.TownsTimelineData{Months: months}
}
