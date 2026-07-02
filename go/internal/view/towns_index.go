package view

import (
	"encoding/json"
	"sort"

	"odkrywajac/internal/service/bundle"
	"odkrywajac/internal/index"
	"odkrywajac/internal/model"
	"odkrywajac/internal/service/router"
	"odkrywajac/internal/templates/layout"
	"odkrywajac/internal/templates/views"
)

// TownsIndexPage creates a Renderable for the towns index page.
// It embeds JSON with town data for the Preact client-side app.
func TownsIndexPage(
	data *index.SiteData,
	rtr *router.Router,
	resolver *bundle.Resolver,
) Renderable {
	url := rtr.TownsIndexURL()
	cssFiles, jsFiles := resolveAssets(resolver, []string{"core", "react-runtime"}, nil)
	// towns_index.js must load synchronously (JSFiles, not the deferred
	// PageJSFiles): it only registers window.TownsIndex, and the page content
	// contains an inline bootstrap that calls TownsIndex.init() during parse.
	jsFiles = append(jsFiles, bundle.AssetFile{Path: "/js/self/towns_index.js"})

	page := layout.PageData{
		Title:        "Gminy",
		URL:          url,
		CanonicalURL: rtr.CanonicalURL(url),
		SiteName:     data.Config.Title,
		CSSFiles:     cssFiles,
		JSFiles:      jsFiles,
		NavStats:     navStatsFromIndex(data.NavStats, rtr, data.TagBySlug),
	}

	townsJSON := buildTownsJSON(data, rtr)
	rawScript := `<script id="towns-data" type="application/json">` + townsJSON + `</script>`

	return NewHTMLPage(url, page, views.TownsIndexContent(rawScript), true)
}

// buildTownsJSON serializes the #towns-data payload consumed by towns_index.js.
// Field names mirror Crystal's TownsIndexView#generate_towns_json exactly —
// the Preact app reads show_url / voivodeship / photo_url_avif / first_year /
// last_year, so renaming any of them silently breaks the page.
func buildTownsJSON(data *index.SiteData, rtr *router.Router) string {
	type townEntry struct {
		Name        string `json:"name"`
		Slug        string `json:"slug"`
		Voivodeship string `json:"voivodeship"` // voivodeship slug, groups towns client-side
		ShowURL     string `json:"show_url"`
		PostCount   int    `json:"post_count"`
		PhotoURL    string `json:"photo_url"`      // empty string when no photo (Crystal parity)
		PhotoAVIF   string `json:"photo_url_avif"` // AVIF variant, picked when window.__avif
		FirstYear   int    `json:"first_year"`
		LastYear    int    `json:"last_year"`
	}

	type voivodeshipEntry struct {
		Name    string `json:"name"`
		Slug    string `json:"slug"`
		ShowURL string `json:"show_url"`
	}

	type townsData struct {
		Voivodeships []voivodeshipEntry `json:"voivodeships"`
		Towns        []townEntry        `json:"towns"`
	}

	result := townsData{}

	// Collect towns with posts, sorted by display name like Crystal.
	towns := data.AreasWithPosts[model.AreaTypeTown]
	sorted := make([]*model.Area, len(towns))
	copy(sorted, towns)
	sort.Slice(sorted, func(i, j int) bool {
		return sorted[i].Name < sorted[j].Name
	})

	usedPhotos := make(map[string]bool) // track used photos for uniqueness
	townVoivodeships := make(map[string]bool)

	for _, town := range sorted {
		posts := data.PostsForArea(model.AreaTypeTown, town.Slug)
		if len(posts) == 0 {
			continue
		}
		firstYear, lastYear := postYearRange(posts)
		te := townEntry{
			Name:        town.Name,
			Slug:        town.Slug,
			Voivodeship: town.VoivodeshipSlug,
			ShowURL:     rtr.AreaShowURL(town),
			PostCount:   len(posts),
			FirstYear:   firstYear,
			LastYear:    lastYear,
		}
		townVoivodeships[town.VoivodeshipSlug] = true

		// Pick best unique photo for this town
		if photo, post := bestUniquePhoto(posts, usedPhotos); photo != nil {
			te.PhotoURL = rtr.ProcessedImageURL(post, photo.ImageFilename, "grid", "jpg")
			te.PhotoAVIF = rtr.ProcessedImageURL(post, photo.ImageFilename, "grid", "avif")
			usedPhotos[post.Slug+"/"+photo.ImageFilename] = true
		}

		result.Towns = append(result.Towns, te)
	}

	// Only voivodeships that actually group a listed town, sorted by name
	// (Crystal filters the same way, so empty groups never reach the client).
	voivs := make([]*model.Area, 0)
	for _, v := range data.AreasByType[model.AreaTypeVoivodeship] {
		if townVoivodeships[v.Slug] {
			voivs = append(voivs, v)
		}
	}
	sort.Slice(voivs, func(i, j int) bool { return voivs[i].Name < voivs[j].Name })
	for _, v := range voivs {
		result.Voivodeships = append(result.Voivodeships, voivodeshipEntry{
			Name:    v.Name,
			Slug:    v.Slug,
			ShowURL: rtr.AreaShowURL(v),
		})
	}

	jsonBytes, _ := json.Marshal(result)
	return string(jsonBytes)
}

// postYearRange returns the earliest and latest post year, feeding the
// "2019–2024" range shown on town cards.
func postYearRange(posts []*model.Post) (int, int) {
	first, last := posts[0].Date.Year(), posts[0].Date.Year()
	for _, post := range posts[1:] {
		year := post.Date.Year()
		if year < first {
			first = year
		}
		if year > last {
			last = year
		}
	}
	return first, last
}

// bestUniquePhoto finds the highest-scored photo not yet used.
func bestUniquePhoto(posts []*model.Post, used map[string]bool) (*model.Photo, *model.Post) {
	var bestPhoto *model.Photo
	var bestPost *model.Post
	bestScore := -1

	for _, post := range posts {
		for _, photo := range post.PublishedPhotos {
			key := post.Slug + "/" + photo.ImageFilename
			if used[key] {
				continue
			}
			if photo.Points > bestScore {
				bestScore = photo.Points
				bestPhoto = photo
				bestPost = post
			}
		}
	}

	return bestPhoto, bestPost
}
