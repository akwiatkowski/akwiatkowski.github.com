package view

import (
	"odkrywajac/internal/service/bundle"
	"odkrywajac/internal/index"
	"odkrywajac/internal/service/router"
	"odkrywajac/internal/templates/layout"
	"odkrywajac/internal/templates/views"
)

// TagStatsPage creates a Renderable for the debug tag stats page.
func TagStatsPage(
	data *index.SiteData,
	r *router.Router,
	resolver *bundle.Resolver,
) Renderable {
	url := "/debug/tagged_photos.html"

	cssFiles, jsFiles := resolveAssets(resolver, []string{"core"}, nil)

	page := layout.PageData{
		Title:        "Tag Stats (Debug)",
		Desc:         "Photo tagging statistics per post",
		URL:          url,
		CanonicalURL: r.CanonicalURL(url),
		SiteName:     data.Config.Title,
		CSSFiles:     cssFiles,
		JSFiles:      jsFiles,
		NavStats:     navStatsFromIndex(data.NavStats, r, data.TagBySlug),
	}

	rows := buildTagStats(data, r)
	return NewHTMLPage(url, page, views.DebugTagStatsContent(rows), false)
}

func buildTagStats(data *index.SiteData, r *router.Router) []views.DebugTagStatsRow {
	var rows []views.DebugTagStatsRow

	for _, post := range data.Posts {
		if !post.IsFinished() {
			continue
		}

		total := len(post.PublishedPhotos)
		tagged := 0
		good := 0
		best := 0

		for _, photo := range post.PublishedPhotos {
			if len(photo.TagSlugs) > 0 {
				tagged++
			}
			for _, ts := range photo.TagSlugs {
				if ts == "good" {
					good++
				}
				if ts == "best" {
					best++
				}
			}
		}

		rows = append(rows, views.DebugTagStatsRow{
			PostTitle:    post.Title,
			PostURL:      r.PostURL(post),
			TotalPhotos:  total,
			TaggedPhotos: tagged,
			GoodPhotos:   good,
			BestPhotos:   best,
		})
	}

	return rows
}
