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

// HomepagePage creates a Renderable for the homepage.
func HomepagePage(
	data *index.SiteData,
	r *router.Router,
	resolver *bundle.Resolver,
) Renderable {
	url := "/index.html"

	cssFiles, jsFiles := resolveAssets(resolver, []string{"core"}, []string{"homepage"})

	stats := navStatsFromIndex(data.NavStats)

	page := layout.PageData{
		Title:        "Odkrywając Polskę",
		URL:          url,
		CanonicalURL: r.CanonicalURL("/"),
		SiteName:     data.Config.Title,
		CSSFiles:     cssFiles,
		JSFiles:      jsFiles,
		PageJS:       "/js/self/homepage.js",
		NavStats:     stats,
	}

	return NewHTMLPage(url, page, views.HomepageContent(stats), true)
}

// HomepageJSON creates a JSON endpoint for homepage JavaScript.
func HomepageJSON(data *index.SiteData, r *router.Router) Renderable {
	type topPhoto struct {
		URL    string `json:"url"`
		AVIF   string `json:"avif"`
		Points int    `json:"points"`
	}

	type postEntry struct {
		URL        string     `json:"url"`
		Title      string     `json:"title"`
		Subtitle   string     `json:"subtitle,omitempty"`
		Date       string     `json:"date"`
		Time       string     `json:"time"`
		DistanceKm int        `json:"distance_km,omitempty"`
		TimeSpent  int        `json:"time_spent,omitempty"`
		CardImage  string     `json:"card_image_url,omitempty"`
		CardAVIF   string     `json:"card_image_url_avif,omitempty"`
		Tags       []string   `json:"tags"`
		TopPhotos  []topPhoto `json:"top_photos,omitempty"`
		Towns      []string   `json:"towns,omitempty"`
		Counties   []string   `json:"counties,omitempty"`
		Voivodeships []string `json:"voivodeships,omitempty"`
		MesoRegions  []string `json:"meso_regions,omitempty"`
	}

	type tagInfo struct {
		URL  string `json:"url"`
		Name string `json:"name"`
	}

	type areaInfo struct {
		URL  string `json:"url"`
		Name string `json:"name"`
	}

	type homepageData struct {
		Posts []postEntry             `json:"posts"`
		Tags  map[string]tagInfo     `json:"tags"`
		Areas map[string]map[string]areaInfo `json:"areas"`
	}

	result := homepageData{
		Tags:  make(map[string]tagInfo),
		Areas: make(map[string]map[string]areaInfo),
	}

	// Tags
	for _, tag := range data.Tags {
		result.Tags[tag.Slug] = tagInfo{
			URL:  r.TagPostListURL(&tag),
			Name: tag.Name,
		}
	}

	// Area lookup maps
	for _, areaType := range model.AllAreaTypes() {
		typeName := areaType.EnglishPlural()
		result.Areas[typeName] = make(map[string]areaInfo)
		for _, area := range data.AreasByType[areaType] {
			result.Areas[typeName][area.Slug] = areaInfo{
				URL:  r.AreaLinkURL(area),
				Name: area.Name,
			}
		}
	}

	// Posts
	for _, post := range data.Posts {
		if !post.IsFinished() {
			continue
		}
		pe := postEntry{
			URL:        r.PostURL(post),
			Title:      post.Title,
			Subtitle:   post.Subtitle,
			Date:       post.Date.Format("2006-01-02"),
			Time:       post.Date.Format(time.RFC3339),
			DistanceKm: int(post.Distance),
			TimeSpent:  int(post.TimeSpent),
			Tags:       post.TagSlugs,
			Towns:      post.TownSlugs,
			MesoRegions: post.LandSlugs,
		}

		if post.ImageFilename != "" {
			pe.CardImage = r.ProcessedImageURL(post, post.ImageFilename, "card", "jpg")
			pe.CardAVIF = r.ProcessedImageURL(post, post.ImageFilename, "card", "avif")
		}

		// Top 4 photos by points
		if len(post.PhotoEntities) > 0 {
			sorted := make([]*model.Photo, len(post.PhotoEntities))
			copy(sorted, post.PhotoEntities)
			sort.Slice(sorted, func(i, j int) bool {
				return sorted[i].Points > sorted[j].Points
			})
			for i, photo := range sorted {
				if i >= 4 {
					break
				}
				pe.TopPhotos = append(pe.TopPhotos, topPhoto{
					URL:    r.ProcessedImageURL(post, photo.ImageFilename, "card", "jpg"),
					AVIF:   r.ProcessedImageURL(post, photo.ImageFilename, "card", "avif"),
					Points: photo.Points,
				})
			}
		}

		result.Posts = append(result.Posts, pe)
	}

	return NewJSONEndpoint(r.HomepageJSON(), result)
}
