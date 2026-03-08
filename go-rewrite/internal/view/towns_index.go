package view

import (
	"encoding/json"
	"sort"

	"odkrywajac/internal/bundle"
	"odkrywajac/internal/index"
	"odkrywajac/internal/model"
	"odkrywajac/internal/router"
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

	page := layout.PageData{
		Title:        "Gminy",
		URL:          url,
		CanonicalURL: rtr.CanonicalURL(url),
		SiteName:     data.Config.Title,
		CSSFiles:     cssFiles,
		JSFiles:      jsFiles,
		PageJS:       "/js/self/towns_index.js",
		NavStats:     navStatsFromIndex(data.NavStats, rtr, data.TagBySlug),
	}

	townsJSON := buildTownsJSON(data, rtr)
	rawScript := `<script id="towns-data" type="application/json">` + townsJSON + `</script>`

	return NewHTMLPage(url, page, views.TownsIndexContent(rawScript), true)
}

func buildTownsJSON(data *index.SiteData, rtr *router.Router) string {
	type townEntry struct {
		Slug             string `json:"slug"`
		Name             string `json:"name"`
		PostCount        int    `json:"post_count"`
		VoivodeshipSlug  string `json:"voivodeship_slug,omitempty"`
		PhotoURL         string `json:"photo_url,omitempty"`
		PhotoAVIF        string `json:"photo_avif,omitempty"`
		URL              string `json:"url"`
	}

	type voivodeshipEntry struct {
		Slug string `json:"slug"`
		Name string `json:"name"`
	}

	type townsData struct {
		Towns        []townEntry        `json:"towns"`
		Voivodeships []voivodeshipEntry `json:"voivodeships"`
	}

	result := townsData{}

	// Collect towns with posts
	towns := data.AreasWithPosts[model.AreaTypeTown]
	sorted := make([]*model.Area, len(towns))
	copy(sorted, towns)
	sort.Slice(sorted, func(i, j int) bool {
		return sorted[i].Name < sorted[j].Name
	})

	usedPhotos := make(map[string]bool) // track used photos for uniqueness

	for _, town := range sorted {
		posts := data.PostsForArea(model.AreaTypeTown, town.Slug)
		te := townEntry{
			Slug:            town.Slug,
			Name:            town.Name,
			PostCount:       len(posts),
			VoivodeshipSlug: town.VoivodeshipSlug,
			URL:             rtr.AreaLinkURL(town),
		}

		// Pick best unique photo for this town
		if photo, post := bestUniquePhoto(posts, usedPhotos); photo != nil {
			te.PhotoURL = rtr.ProcessedImageURL(post, photo.ImageFilename, "grid", "jpg")
			te.PhotoAVIF = rtr.ProcessedImageURL(post, photo.ImageFilename, "grid", "avif")
			usedPhotos[post.Slug+"/"+photo.ImageFilename] = true
		}

		result.Towns = append(result.Towns, te)
	}

	// Collect voivodeships
	for _, v := range data.AreasByType[model.AreaTypeVoivodeship] {
		result.Voivodeships = append(result.Voivodeships, voivodeshipEntry{
			Slug: v.Slug,
			Name: v.Name,
		})
	}

	jsonBytes, _ := json.Marshal(result)
	return string(jsonBytes)
}

// bestUniquePhoto finds the highest-scored photo not yet used.
func bestUniquePhoto(posts []*model.Post, used map[string]bool) (*model.Photo, *model.Post) {
	var bestPhoto *model.Photo
	var bestPost *model.Post
	bestScore := -1

	for _, post := range posts {
		for _, photo := range post.PhotoEntities {
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
