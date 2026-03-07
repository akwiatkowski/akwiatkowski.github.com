package view

import (
	"sort"
	"time"

	"odkrywajac/internal/bundle"
	"odkrywajac/internal/index"
	"odkrywajac/internal/model"
	"odkrywajac/internal/router"
	"odkrywajac/internal/templates/layout"
	"odkrywajac/internal/templates/views"
)

// TownsHistoryPage creates a Renderable for the towns history page.
func TownsHistoryPage(
	data *index.SiteData,
	r *router.Router,
	resolver *bundle.Resolver,
) Renderable {
	url := r.TownsHistoryURL()

	cssFiles, jsFiles := resolveAssets(resolver, []string{"core"}, nil)

	page := layout.PageData{
		Title:        "Historia odwiedzonych gmin",
		URL:          url,
		CanonicalURL: r.CanonicalURL(url),
		SiteName:     data.Config.Title,
		CSSFiles:     cssFiles,
		JSFiles:      jsFiles,
		NavStats:     navStatsFromIndex(data.NavStats),
	}

	hd := computeTownsHistory(data, r)

	return NewHTMLPage(url, page, views.TownsHistoryContent(hd), false)
}

func computeTownsHistory(data *index.SiteData, r *router.Router) views.TownsHistoryData {
	townFirstVisit := make(map[string]time.Time)
	for _, post := range data.Posts {
		if !post.IsFinished() {
			continue
		}
		for _, slug := range post.TownSlugs {
			if existing, ok := townFirstVisit[slug]; !ok || post.Date.Before(existing) {
				townFirstVisit[slug] = post.Date
			}
		}
	}

	voivGroups := make(map[string][]views.TownHistoryEntry)
	voivNames := make(map[string]string)
	voivURLs := make(map[string]string)

	towns := data.AreasByType[model.AreaTypeTown]
	for _, town := range towns {
		firstVisit, ok := townFirstVisit[town.Slug]
		if !ok {
			continue
		}

		voivSlug := town.VoivodeshipSlug
		if voivSlug == "" {
			voivSlug = "inne"
		}

		entry := views.TownHistoryEntry{
			Name:       town.Name,
			URL:        r.AreaShowURL(town),
			FirstVisit: firstVisit,
		}
		voivGroups[voivSlug] = append(voivGroups[voivSlug], entry)

		if _, exists := voivNames[voivSlug]; !exists {
			voivArea := data.FindArea(model.AreaTypeVoivodeship, voivSlug)
			if voivArea != nil {
				voivNames[voivSlug] = voivArea.Name
				voivURLs[voivSlug] = r.AreaShowURL(voivArea)
			} else {
				voivNames[voivSlug] = voivSlug
			}
		}
	}

	for slug := range voivGroups {
		group := voivGroups[slug]
		sort.Slice(group, func(i, j int) bool {
			return group[i].FirstVisit.Before(group[j].FirstVisit)
		})
		voivGroups[slug] = group
	}

	var sortedSlugs []string
	for slug := range voivGroups {
		sortedSlugs = append(sortedSlugs, slug)
	}
	sort.Slice(sortedSlugs, func(i, j int) bool {
		return voivNames[sortedSlugs[i]] < voivNames[sortedSlugs[j]]
	})

	var groups []views.TownsHistoryGroup
	totalTowns := 0
	for _, slug := range sortedSlugs {
		groups = append(groups, views.TownsHistoryGroup{
			VoivodeshipName: voivNames[slug],
			VoivodeshipURL:  voivURLs[slug],
			Towns:           voivGroups[slug],
		})
		totalTowns += len(voivGroups[slug])
	}

	return views.TownsHistoryData{
		Groups:     groups,
		TotalTowns: totalTowns,
	}
}
