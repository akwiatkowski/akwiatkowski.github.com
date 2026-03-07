// Package router provides centralized URL generation for all page types.
//
// All URL building happens here — views never construct URLs manually.
// Methods accept model instances (not raw slugs) for type safety.
package router

import (
	"fmt"

	"odkrywajac/internal/model"
)

// AreaLinkTarget controls where semantic area_link_url points.
type AreaLinkTarget int

const (
	AreaLinkShow AreaLinkTarget = iota
	AreaLinkPostList
	AreaLinkGallery
)

// TagLinkTarget controls where semantic tag_link_url points.
type TagLinkTarget int

const (
	TagLinkShow TagLinkTarget = iota
	TagLinkGallery
)

// Router generates all URLs for the site.
type Router struct {
	BaseURL        string // e.g. "https://odkrywajacpolske.pl"
	AreaLinkTarget AreaLinkTarget
	TagLinkTarget  TagLinkTarget
}

// New creates a Router with default alias targets.
func New(baseURL string) *Router {
	return &Router{
		BaseURL:        baseURL,
		AreaLinkTarget: AreaLinkShow,
		TagLinkTarget:  TagLinkShow,
	}
}

// ============================================
// Area URLs
// ============================================

// AreaShowURL returns the area show page URL: /<nominative>/<slug>.html
func (r *Router) AreaShowURL(area *model.Area) string {
	return fmt.Sprintf("/%s/%s.html", area.Type.NominativeSlug(), area.Slug)
}

// AreaPostListURL returns the area post list URL: /wpisy-dla/<genitive>/<slug>.html
func (r *Router) AreaPostListURL(area *model.Area) string {
	return fmt.Sprintf("/wpisy-dla/%s/%s.html", area.Type.GenitiveSlug(), area.Slug)
}

// AreaGalleryURL returns the area gallery URL: /galeria/<genitive>/<slug>.html
func (r *Router) AreaGalleryURL(area *model.Area) string {
	return fmt.Sprintf("/galeria/%s/%s.html", area.Type.GenitiveSlug(), area.Slug)
}

// AreaLinkURL returns the semantic area link URL (configurable target).
func (r *Router) AreaLinkURL(area *model.Area) string {
	switch r.AreaLinkTarget {
	case AreaLinkPostList:
		return r.AreaPostListURL(area)
	case AreaLinkGallery:
		return r.AreaGalleryURL(area)
	default:
		return r.AreaShowURL(area)
	}
}

// ============================================
// Tag URLs (always use SlugPl — Polish slug)
// ============================================

// TagShowURL returns the tag show page URL: /tag/<slug_pl>.html
func (r *Router) TagShowURL(tag *model.Tag) string {
	return fmt.Sprintf("/tag/%s.html", tag.SlugPl)
}

// TagPostListURL returns the tag post list URL: /wpisy-dla/tagu/<slug_pl>.html
func (r *Router) TagPostListURL(tag *model.Tag) string {
	return fmt.Sprintf("/wpisy-dla/tagu/%s.html", tag.SlugPl)
}

// TagGalleryURL returns the tag gallery URL: /galeria/tag/<slug_pl>.html
func (r *Router) TagGalleryURL(tag *model.Tag) string {
	return fmt.Sprintf("/galeria/tag/%s.html", tag.SlugPl)
}

// TagLinkURL returns the semantic tag link URL (configurable target).
func (r *Router) TagLinkURL(tag *model.Tag) string {
	switch r.TagLinkTarget {
	case TagLinkGallery:
		return r.TagGalleryURL(tag)
	default:
		return r.TagShowURL(tag)
	}
}

// ============================================
// Post URLs
// ============================================

// PostURL returns the post article URL: /<year>/<month>/<day>-<slug>.html
func (r *Router) PostURL(post *model.Post) string {
	return model.BuildPostURL(post.Date, post.Slug)
}

// PostGalleryURL returns the post gallery URL: /<year>/<month>/<slug>/galeria.html
func (r *Router) PostGalleryURL(post *model.Post) string {
	return fmt.Sprintf("/%d/%02d/%s/galeria.html",
		post.Date.Year(), post.Date.Month(), post.Slug)
}

// PostGalleryStatsURL returns the gallery stats URL.
func (r *Router) PostGalleryStatsURL(post *model.Post) string {
	return fmt.Sprintf("/%d/%02d/%s/galeria-statystyki.html",
		post.Date.Year(), post.Date.Month(), post.Slug)
}

// PostImageURL returns the full-size image URL.
func (r *Router) PostImageURL(post *model.Post, filename string) string {
	return fmt.Sprintf("/images/%d/%s/%s", post.Date.Year(), post.Slug, filename)
}

// ProcessedImageURL returns a processed (resized) image URL.
// size is one of: "article", "card", "grid", "thumbnail"
// format is "jpg" or "avif"
func (r *Router) ProcessedImageURL(post *model.Post, filename, size, format string) string {
	return fmt.Sprintf("/images/processed/%d/%02d/%s_%s_%s.%s",
		post.Date.Year(), post.Date.Month(), post.Slug, filename, size, format)
}

// ============================================
// Static Page URLs
// ============================================

func (r *Router) HomeURL() string           { return "/" }
func (r *Router) MapURL() string            { return "/mapa_tras.html" }
func (r *Router) PhotoMapURL() string       { return "/mapa_zdjec.html" }
func (r *Router) AboutURL() string          { return "/o-mnie.html" }
func (r *Router) EnglishURL() string        { return "/en/index.html" }
func (r *Router) MoreURL() string           { return "/wiecej.html" }
func (r *Router) GalleryURL() string        { return "/galeria.html" }
func (r *Router) PortfolioURL() string      { return "/portfolio.html" }
func (r *Router) TimelineURL() string       { return "/linia_czasu.html" }
func (r *Router) ExifStatsURL() string      { return "/statystyki_exif.html" }
func (r *Router) PhotoPlannerURL() string   { return "/pomysly_dla_zdjec.html" }
func (r *Router) TripIdeasURL() string      { return "/pomysly_tras.html" }

// YearReportURL returns the year report URL: /rok-<year>.html
func (r *Router) YearReportURL(year int) string {
	return fmt.Sprintf("/rok-%d.html", year)
}

// ============================================
// Feed URLs
// ============================================

func (r *Router) RSSURL() string     { return "/feed.rss" }
func (r *Router) AtomURL() string    { return "/feed.atom" }
func (r *Router) FeedJSON() string   { return "/feed.json" }
func (r *Router) SitemapURL() string { return "/sitemap.xml" }
func (r *Router) RobotsURL() string  { return "/robots.txt" }

// ============================================
// JSON Endpoint URLs
// ============================================

func (r *Router) HomepageJSON() string      { return "/jsons/homepage.json" }
func (r *Router) E2EJSON() string           { return "/jsons/e2e.json" }
func (r *Router) MapJSON() string           { return "/jsons/map.json" }
func (r *Router) PhotosMapJSON() string     { return "/jsons/photos_map.json" }
func (r *Router) PhotoGridJSON() string     { return "/jsons/photo_grid.json" }
func (r *Router) TrainStationsJSON() string { return "/jsons/train_stations.json" }
func (r *Router) IdeasJSON() string         { return "/jsons/ideas.json" }
func (r *Router) PhotosJSON() string        { return "/jsons/photos.json" }

// ============================================
// Index Page URLs
// ============================================

func (r *Router) TagsIndexURL() string          { return "/tagi.html" }
func (r *Router) TownsIndexURL() string         { return "/gminy.html" }
func (r *Router) VoivodeshipsIndexURL() string  { return "/wojewodztwa.html" }
func (r *Router) LandsIndexURL() string         { return "/krainy.html" }
func (r *Router) MesoRegionsIndexURL() string   { return "/regiony.html" }
func (r *Router) MacroRegionsIndexURL() string  { return "/obszary.html" }

// ============================================
// Canonical URL (full URL with base)
// ============================================

// CanonicalURL returns the full URL with base for a given path.
func (r *Router) CanonicalURL(path string) string {
	return r.BaseURL + path
}
