package view

import (
	"sort"
	"strconv"
	"strings"
	"time"

	"odkrywajac/internal/catalog"
	"odkrywajac/internal/model"
	"odkrywajac/internal/service/bundle"
	"odkrywajac/internal/service/router"
	"odkrywajac/internal/view/template/layout"
	"odkrywajac/internal/view/template/views"
)

// interpolateSiteDesc fills the {{total_km}}/{{total_hours}}/{{bicycle_km}}/
// {{hike_km}} placeholders in the configured site.desc with live nav stats,
// mirroring Crystal's Renderer#site_desc. Used for the meta/OpenGraph
// description on pages that lack a more specific one (homepage).
func interpolateSiteDesc(desc string, ns catalog.NavStats) string {
	replacements := map[string]int{
		"{{total_km}}":    ns.SelfDistance,
		"{{total_hours}}": ns.SelfTime,
		"{{bicycle_km}}":  ns.BicycleDistance,
		"{{hike_km}}":     ns.HikeDistance,
	}
	for placeholder, value := range replacements {
		desc = strings.ReplaceAll(desc, placeholder, strconv.Itoa(value))
	}
	return desc
}

// HomepagePage creates a Renderable for the homepage.
func HomepagePage(
	data *catalog.SiteData,
	r *router.Router,
	resolver *bundle.Resolver,
) Renderable {
	url := "/index.html"

	// Homepage uses its own standalone CSS (no Bootstrap/core), matching Crystal
	cssFiles, jsFiles := resolveAssets(resolver, nil, []string{"homepage"})

	stats := navStatsFromIndex(data.NavStats, r, data.TagBySlug)

	page := layout.PageData{
		Title:        "Odkrywając Polskę",
		Desc:         interpolateSiteDesc(data.Config.Desc, data.NavStats),
		URL:          url,
		CanonicalURL: r.CanonicalURL("/"),
		SiteName:     data.Config.Title,
		CSSFiles:     cssFiles,
		JSFiles:      jsFiles,
		PageJSFiles:  []string{"/js/self/homepage.js"},
		NavStats:     stats,
	}

	return NewHTMLPage(url, page, views.HomepageContent(stats), true)
}

// HomepageJSON creates the /jsons/homepage.json endpoint consumed by
// homepage.js (hero + category chips) and post_collection.js (post list
// filtering). The shape mirrors Crystal's HomePageJsonGenerator exactly:
// flat {slug, url, name} arrays for tags and each area type, and post
// entries with per-type *_slugs arrays plus a top-photos `photos` list of
// {src, src_avif, alt, points}. Both JS consumers and the e2e suite encode
// this contract — do not rename fields here without updating them.
func HomepageJSON(data *catalog.SiteData, r *router.Router) Renderable {
	type photoEntry struct {
		Src     string `json:"src"`
		SrcAVIF string `json:"src_avif"`
		Alt     string `json:"alt"`
		Points  int    `json:"points"`
	}

	type postEntry struct {
		URL        string       `json:"url"`
		Title      string       `json:"title"`
		Subtitle   string       `json:"subtitle,omitempty"`
		Date       string       `json:"date"`
		Time       string       `json:"time"`
		DistanceKm float64      `json:"distance_km,omitempty"`
		TimeSpent  float64      `json:"time_spent,omitempty"`
		CardImage  string       `json:"card_image_url,omitempty"`
		CardAVIF   string       `json:"card_image_url_avif,omitempty"`
		Tags       []string     `json:"tags"`
		Photos     []photoEntry `json:"photos,omitempty"`
		Visible    bool         `json:"visible"`
		Ready      bool         `json:"ready"`
		// Area slugs split by type — post_collection.js filters by these fields.
		TownSlugs        []string `json:"town_slugs,omitempty"`
		CountySlugs      []string `json:"county_slugs,omitempty"`
		VoivodeshipSlugs []string `json:"voivodeship_slugs,omitempty"`
		MesoRegionSlugs  []string `json:"meso_region_slugs,omitempty"`
		MacroRegionSlugs []string `json:"macro_region_slugs,omitempty"`
	}

	// areaRef is one lookup-table row; the JS finds entries by slug to render
	// linked chips/tags, so slug must be part of each element (not a map key).
	type areaRef struct {
		Slug string `json:"slug"`
		URL  string `json:"url"`
		Name string `json:"name"`
	}

	type homepageData struct {
		Posts        []postEntry `json:"posts"`
		Tags         []areaRef   `json:"tags"`
		Towns        []areaRef   `json:"towns"`
		Counties     []areaRef   `json:"counties"`
		Voivodeships []areaRef   `json:"voivodeships"`
		MesoRegions  []areaRef   `json:"meso_regions"`
		MacroRegions []areaRef   `json:"macro_regions"`
	}

	result := homepageData{}

	// All tags, in config order (homepage.js finds chips by slug).
	for _, tag := range data.Tags {
		result.Tags = append(result.Tags, areaRef{
			Slug: tag.Slug,
			URL:  r.TagPostListURL(&tag),
			Name: tag.Name,
		})
	}

	// Posts + collection of every area slug the posts reference, per type.
	// The lookup tables below only list referenced areas (Crystal parity) —
	// shipping all 2477 towns would bloat the payload for no reader.
	referenced := make(map[model.AreaType][]string)
	addReferenced := func(areaType model.AreaType, slugs []string) {
		for _, slug := range slugs {
			if !containsSlug(referenced[areaType], slug) {
				referenced[areaType] = append(referenced[areaType], slug)
			}
		}
	}

	for _, post := range data.Posts {
		if !post.IsFinished() {
			continue
		}
		pe := postEntry{
			URL:              r.PostURL(post),
			Title:            post.Title,
			Subtitle:         post.Subtitle,
			Date:             post.Date.Format("2006-01-02"),
			Time:             post.Date.Format(time.RFC3339),
			DistanceKm:       post.Distance,
			TimeSpent:        post.TimeSpent,
			Tags:             post.TagSlugs,
			Visible:          true,
			Ready:            true,
			TownSlugs:        postAreaSlugs(data, post, model.AreaTypeTown),
			CountySlugs:      postAreaSlugs(data, post, model.AreaTypeCounty),
			VoivodeshipSlugs: postAreaSlugs(data, post, model.AreaTypeVoivodeship),
			MesoRegionSlugs:  postAreaSlugs(data, post, model.AreaTypeMesoRegion),
			MacroRegionSlugs: postAreaSlugs(data, post, model.AreaTypeMacroRegion),
		}
		addReferenced(model.AreaTypeTown, pe.TownSlugs)
		addReferenced(model.AreaTypeCounty, pe.CountySlugs)
		addReferenced(model.AreaTypeVoivodeship, pe.VoivodeshipSlugs)
		addReferenced(model.AreaTypeMesoRegion, pe.MesoRegionSlugs)
		addReferenced(model.AreaTypeMacroRegion, pe.MacroRegionSlugs)

		if post.ImageFilename != "" {
			pe.CardImage = r.ProcessedImageURL(post, post.ImageFilename, "card", "jpg")
			pe.CardAVIF = r.ProcessedImageURL(post, post.ImageFilename, "card", "avif")
		}

		// Top 4 photos by points — homepage.js picks the hero from these,
		// weighting by `points`, and uses `src`/`src_avif` directly.
		if len(post.PublishedPhotos) > 0 {
			sorted := make([]*model.Photo, len(post.PublishedPhotos))
			copy(sorted, post.PublishedPhotos)
			sort.Slice(sorted, func(i, j int) bool {
				return sorted[i].Points > sorted[j].Points
			})
			for i, photo := range sorted {
				if i >= 4 {
					break
				}
				pe.Photos = append(pe.Photos, photoEntry{
					Src:     r.ProcessedImageURL(post, photo.ImageFilename, "card", "jpg"),
					SrcAVIF: r.ProcessedImageURL(post, photo.ImageFilename, "card", "avif"),
					Alt:     photo.Desc,
					Points:  photo.Points,
				})
			}
		}

		result.Posts = append(result.Posts, pe)
	}

	// Area lookup tables for the referenced slugs only.
	areaTable := func(areaType model.AreaType) []areaRef {
		refs := make([]areaRef, 0, len(referenced[areaType]))
		for _, slug := range referenced[areaType] {
			area := data.FindArea(areaType, slug)
			if area == nil {
				continue // slug without a config entry — nothing to link to
			}
			refs = append(refs, areaRef{
				Slug: area.Slug,
				URL:  r.AreaPostListURL(area),
				Name: area.Name,
			})
		}
		return refs
	}
	result.Towns = areaTable(model.AreaTypeTown)
	result.Counties = areaTable(model.AreaTypeCounty)
	result.Voivodeships = areaTable(model.AreaTypeVoivodeship)
	result.MesoRegions = areaTable(model.AreaTypeMesoRegion)
	result.MacroRegions = areaTable(model.AreaTypeMacroRegion)

	return NewJSONEndpoint(r.HomepageJSON(), result)
}

// postAreaSlugs returns the slugs of the given area type a post belongs to:
// the union of spatial route coverage (precise, per-type) and frontmatter
// slugs classified by the area index (covers route-less posts and areas the
// author tagged beyond the GPS line).
func postAreaSlugs(data *catalog.SiteData, post *model.Post, areaType model.AreaType) []string {
	slugs := append([]string(nil), post.SpatialAreaSlugs[areaType]...)

	var fromFrontmatter []string
	switch areaType {
	case model.AreaTypeTown, model.AreaTypeCounty, model.AreaTypeVoivodeship:
		towns, counties, voivodeships := classifyTownSlugs(data, post.TownSlugs)
		switch areaType {
		case model.AreaTypeTown:
			fromFrontmatter = towns
		case model.AreaTypeCounty:
			fromFrontmatter = counties
		default:
			fromFrontmatter = voivodeships
		}
	case model.AreaTypeMesoRegion, model.AreaTypeMacroRegion:
		meso, macro := classifyLandSlugs(data, post.LandSlugs)
		if areaType == model.AreaTypeMesoRegion {
			fromFrontmatter = meso
		} else {
			fromFrontmatter = macro
		}
	}
	for _, slug := range fromFrontmatter {
		if !containsSlug(slugs, slug) {
			slugs = append(slugs, slug)
		}
	}
	return slugs
}

// containsSlug reports whether list already holds slug (tiny lists, linear scan).
func containsSlug(list []string, slug string) bool {
	for _, item := range list {
		if item == slug {
			return true
		}
	}
	return false
}

// classifyTownSlugs splits post.TownSlugs into separate arrays by area type.
// A slug like "dolnoslaskie" may match as both a town and voivodeship;
// we assign it to the most specific type found in the area index.
func classifyTownSlugs(data *catalog.SiteData, slugs []string) (towns, counties, voivodeships []string) {
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
func classifyLandSlugs(data *catalog.SiteData, slugs []string) (meso, macro []string) {
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
