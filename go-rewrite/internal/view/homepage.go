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

	// Homepage uses its own standalone CSS (no Bootstrap/core), matching Crystal
	cssFiles, jsFiles := resolveAssets(resolver, nil, []string{"homepage"})

	stats := navStatsFromIndex(data.NavStats, r, data.TagBySlug)

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
		Visible    bool       `json:"visible"`
		Ready      bool       `json:"ready"`
		// Area slugs split by type — post_collection.js filters by these fields.
		TownSlugs        []string `json:"town_slugs,omitempty"`
		CountySlugs      []string `json:"county_slugs,omitempty"`
		VoivodeshipSlugs []string `json:"voivodeship_slugs,omitempty"`
		MesoRegionSlugs  []string `json:"meso_region_slugs,omitempty"`
		MacroRegionSlugs []string `json:"macro_region_slugs,omitempty"`
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
				URL:  r.AreaPostListURL(area),
				Name: area.Name,
			}
		}
	}

	// Posts
	for _, post := range data.Posts {
		if !post.IsFinished() {
			continue
		}
		// Resolve area slugs into proper types for JS filtering.
		// TownSlugs mixes towns/counties/voivodeships; we split them by looking
		// up each slug in the area index to find its actual type.
		townSlugs, countySlugs, voivSlugs := classifyTownSlugs(data, post.TownSlugs)
		mesoSlugs, macroSlugs := classifyLandSlugs(data, post.LandSlugs)

		pe := postEntry{
			URL:              r.PostURL(post),
			Title:            post.Title,
			Subtitle:         post.Subtitle,
			Date:             post.Date.Format("2006-01-02"),
			Time:             post.Date.Format(time.RFC3339),
			DistanceKm:       int(post.Distance),
			TimeSpent:        int(post.TimeSpent),
			Tags:             post.TagSlugs,
			Visible:          true,
			Ready:            true,
			TownSlugs:        townSlugs,
			CountySlugs:      countySlugs,
			VoivodeshipSlugs: voivSlugs,
			MesoRegionSlugs:  mesoSlugs,
			MacroRegionSlugs: macroSlugs,
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

// classifyTownSlugs splits post.TownSlugs into separate arrays by area type.
// A slug like "dolnoslaskie" may match as both a town and voivodeship;
// we assign it to the most specific type found in the area index.
func classifyTownSlugs(data *index.SiteData, slugs []string) (towns, counties, voivodeships []string) {
	for _, slug := range slugs {
		switch {
		case data.FindArea(model.AreaTypeTown, slug) != nil:
			towns = append(towns, slug)
		case data.FindArea(model.AreaTypeCounty, slug) != nil:
			counties = append(counties, slug)
		case data.FindArea(model.AreaTypeVoivodeship, slug) != nil:
			voivodeships = append(voivodeships, slug)
		default:
			// Unknown slug — include as town for backward compatibility.
			towns = append(towns, slug)
		}
	}
	return
}

// classifyLandSlugs splits post.LandSlugs into meso and macro region arrays.
func classifyLandSlugs(data *index.SiteData, slugs []string) (meso, macro []string) {
	for _, slug := range slugs {
		switch {
		case data.FindArea(model.AreaTypeMesoRegion, slug) != nil:
			meso = append(meso, slug)
		case data.FindArea(model.AreaTypeMacroRegion, slug) != nil:
			macro = append(macro, slug)
		default:
			// Unknown land slug — include as meso for backward compatibility.
			meso = append(meso, slug)
		}
	}
	return
}
