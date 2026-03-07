package view

import (
	"fmt"
	"math"
	"sort"
	"strings"
	"time"

	"odkrywajac/internal/bundle"
	"odkrywajac/internal/index"
	"odkrywajac/internal/model"
	"odkrywajac/internal/router"
	"odkrywajac/internal/templates/components"
	"odkrywajac/internal/templates/layout"
	"odkrywajac/internal/templates/views"
)

// --- Fill Algorithm ---

// galleryFillPhotos selects photos matching tags, then fills up to fillUntil
// from remaining photos using a time-weighted tag count factor.
func galleryFillPhotos(
	allPhotos []*model.Photo,
	tagSlugs []string,
	includeHeaders bool,
	fillUntil int,
) []*model.Photo {
	now := time.Now()
	matchSet := make(map[string]bool, len(tagSlugs))
	for _, s := range tagSlugs {
		matchSet[s] = true
	}

	var selected []*model.Photo
	selectedSet := make(map[*model.Photo]bool)

	// Phase 1: select photos matching tags
	for _, photo := range allPhotos {
		if photoMatchesTags(photo, matchSet) || (includeHeaders && photo.IsHeader) {
			selected = append(selected, photo)
			selectedSet[photo] = true
		}
	}

	// Phase 2: fill from remaining by factor
	if len(selected) < fillUntil {
		type scored struct {
			photo  *model.Photo
			factor float64
		}
		var remaining []scored
		for _, photo := range allPhotos {
			if selectedSet[photo] {
				continue
			}
			f := fillFactor(photo, now)
			remaining = append(remaining, scored{photo, f})
		}
		sort.Slice(remaining, func(i, j int) bool {
			return remaining[i].factor > remaining[j].factor
		})
		need := fillUntil - len(selected)
		for i := 0; i < need && i < len(remaining); i++ {
			selected = append(selected, remaining[i].photo)
		}
	}

	// Sort by capture time (newest first)
	sort.Slice(selected, func(i, j int) bool {
		ti := photoTime(selected[i])
		tj := photoTime(selected[j])
		return ti.After(tj)
	})

	return selected
}

func photoMatchesTags(photo *model.Photo, matchSet map[string]bool) bool {
	for _, s := range photo.TagSlugs {
		if matchSet[s] {
			return true
		}
	}
	return false
}

func fillFactor(photo *model.Photo, now time.Time) float64 {
	t := photoTime(photo)
	years := float64(now.Sub(t).Hours()) / (365.25 * 24)
	return float64(len(photo.TagSlugs)) / (1.0 + years)
}

func photoTime(photo *model.Photo) time.Time {
	if photo.Exif != nil && photo.Exif.Time != nil {
		return *photo.Exif.Time
	}
	return time.Time{}
}

// --- Photo Filtering Helpers ---

func photosForLens(photos []*model.Photo, lens string) []*model.Photo {
	var result []*model.Photo
	for _, p := range photos {
		if p.Exif != nil && p.Exif.LensName == lens {
			result = append(result, p)
		}
	}
	return result
}

func photosForCamera(photos []*model.Photo, camera string) []*model.Photo {
	var result []*model.Photo
	for _, p := range photos {
		if p.Exif != nil && p.Exif.CameraName == camera {
			result = append(result, p)
		}
	}
	return result
}

func photosInFocalRange(photos []*model.Photo, from, to float64) []*model.Photo {
	var result []*model.Photo
	for _, p := range photos {
		if p.Exif != nil && p.Exif.FocalLength != nil {
			fl := *p.Exif.FocalLength
			if fl >= from && fl < to {
				result = append(result, p)
			}
		}
	}
	return result
}

func photosInISORange(photos []*model.Photo, from, to int) []*model.Photo {
	var result []*model.Photo
	for _, p := range photos {
		if p.Exif != nil && p.Exif.ISO != nil {
			iso := *p.Exif.ISO
			if iso >= from && iso < to {
				result = append(result, p)
			}
		}
	}
	return result
}

func photosInExposureRange(photos []*model.Photo, from, to float64) []*model.Photo {
	var result []*model.Photo
	for _, p := range photos {
		if p.Exif != nil && p.Exif.Exposure != nil {
			exp := *p.Exif.Exposure
			if exp >= from && exp < to {
				result = append(result, p)
			}
		}
	}
	return result
}

// --- All Photos Collection ---

func allPublishedPhotos(data *index.SiteData) []*model.Photo {
	var photos []*model.Photo
	for _, post := range data.Posts {
		if !post.IsFinished() {
			continue
		}
		photos = append(photos, post.PhotoEntities...)
	}
	return photos
}

// photoToCards converts photos to PhotoCardData using a post slug lookup.
func photosToCards(photos []*model.Photo, data *index.SiteData, r *router.Router) []components.PhotoCardData {
	cards := make([]components.PhotoCardData, 0, len(photos))
	for _, photo := range photos {
		post := data.PostBySlug(photo.PostSlug)
		if post == nil {
			continue
		}
		cards = append(cards, components.PhotoCardData{
			JPEGSrc: r.ProcessedImageURL(post, photo.ImageFilename, "grid", "jpg"),
			AVIFSrc: r.ProcessedImageURL(post, photo.ImageFilename, "grid", "avif"),
			Alt:     photo.Desc,
		})
	}
	return cards
}

// --- Gallery Page Builders ---

func galleryPage(
	data *index.SiteData,
	r *router.Router,
	resolver *bundle.Resolver,
	url, title string,
	photos []*model.Photo,
) Renderable {
	cssFiles, jsFiles := resolveAssets(resolver, []string{"core"}, []string{"gallery"})

	page := layout.PageData{
		Title:        title,
		URL:          url,
		CanonicalURL: r.CanonicalURL(url),
		SiteName:     data.Config.Title,
		CSSFiles:     cssFiles,
		JSFiles:      jsFiles,
		NavStats:     navStatsFromIndex(data.NavStats),
	}

	cards := photosToCards(photos, data, r)
	return NewHTMLPage(url, page, views.AreaGalleryContent(cards), true)
}

// --- Tag Galleries ---

// TagPhotoGalleryPage creates gallery for a photo tag (fill algorithm).
func TagPhotoGalleryPage(
	data *index.SiteData,
	tag *model.Tag,
	r *router.Router,
	resolver *bundle.Resolver,
) Renderable {
	url := r.TagGalleryURL(tag)
	allPhotos := allPublishedPhotos(data)
	photos := galleryFillPhotos(allPhotos, []string{tag.Slug}, false, 0)
	return galleryPage(data, r, resolver, url, fmt.Sprintf("Galeria: %s", tag.Name), photos)
}

// --- EXIF Galleries ---

// LensGalleryPage creates gallery for a specific lens.
func LensGalleryPage(
	data *index.SiteData,
	r *router.Router,
	resolver *bundle.Resolver,
	lens string,
) Renderable {
	url := fmt.Sprintf("/galeria/obiektyw/%s.html", sanitizeSlug(lens))
	allPhotos := allPublishedPhotos(data)
	filtered := photosForLens(allPhotos, lens)
	photos := galleryFillPhotos(filtered, []string{"good", "best"}, true, 80)
	return galleryPage(data, r, resolver, url, fmt.Sprintf("Obiektyw: %s", lens), photos)
}

// CameraGalleryPage creates gallery for a specific camera.
func CameraGalleryPage(
	data *index.SiteData,
	r *router.Router,
	resolver *bundle.Resolver,
	camera string,
) Renderable {
	url := fmt.Sprintf("/galeria/aparat/%s.html", sanitizeSlug(camera))
	allPhotos := allPublishedPhotos(data)
	filtered := photosForCamera(allPhotos, camera)
	photos := galleryFillPhotos(filtered, []string{"good", "best"}, true, 80)
	return galleryPage(data, r, resolver, url, fmt.Sprintf("Aparat: %s", camera), photos)
}

// FocalLengthGalleryPage creates gallery for a focal length range.
func FocalLengthGalleryPage(
	data *index.SiteData,
	r *router.Router,
	resolver *bundle.Resolver,
	from, to float64,
) Renderable {
	url := fmt.Sprintf("/galeria/ogniskowa/%d-%d.html", int(from), int(to))
	allPhotos := allPublishedPhotos(data)
	filtered := photosInFocalRange(allPhotos, from, to)
	photos := galleryFillPhotos(filtered, []string{"good", "best"}, true, 40)
	title := fmt.Sprintf("Ogniskowa: %d–%d mm", int(from), int(to))
	return galleryPage(data, r, resolver, url, title, photos)
}

// ISOGalleryPage creates gallery for an ISO range.
func ISOGalleryPage(
	data *index.SiteData,
	r *router.Router,
	resolver *bundle.Resolver,
	from, to int,
) Renderable {
	url := fmt.Sprintf("/galeria/czulosc/%d-%d.html", from, to)
	allPhotos := allPublishedPhotos(data)
	filtered := photosInISORange(allPhotos, from, to)
	photos := galleryFillPhotos(filtered, []string{"good", "best"}, true, 40)
	title := fmt.Sprintf("ISO: %d–%d", from, to)
	return galleryPage(data, r, resolver, url, title, photos)
}

// ExposureGalleryPage creates gallery for an exposure time range.
func ExposureGalleryPage(
	data *index.SiteData,
	r *router.Router,
	resolver *bundle.Resolver,
	from, to float64,
	label string,
) Renderable {
	fromStr := exposureLabel(from)
	toStr := exposureLabel(to)
	url := fmt.Sprintf("/galeria/ekspozycja/%s-%s.html", fromStr, toStr)
	allPhotos := allPublishedPhotos(data)
	filtered := photosInExposureRange(allPhotos, from, to)
	photos := galleryFillPhotos(filtered, []string{"good", "best"}, true, 40)
	title := fmt.Sprintf("Ekspozycja: %s", label)
	return galleryPage(data, r, resolver, url, title, photos)
}

func exposureLabel(v float64) string {
	if v >= 1 {
		return fmt.Sprintf("%.0f", v)
	}
	inv := 1.0 / v
	return fmt.Sprintf("1_%d", int(math.Round(inv)))
}

// --- Gallery Index Pages ---

// GalleryIndexPage creates the main gallery index page.
func GalleryIndexPage(
	data *index.SiteData,
	r *router.Router,
	resolver *bundle.Resolver,
) Renderable {
	url := r.GalleryIndexURL()
	cssFiles, jsFiles := resolveAssets(resolver, []string{"core"}, nil)

	page := layout.PageData{
		Title:        "Galeria",
		URL:          url,
		CanonicalURL: r.CanonicalURL(url),
		SiteName:     data.Config.Title,
		CSSFiles:     cssFiles,
		JSFiles:      jsFiles,
		NavStats:     navStatsFromIndex(data.NavStats),
	}

	links := buildGalleryIndexLinks(data, r)
	return NewHTMLPage(url, page, views.GalleryIndexContent(links), true)
}

func buildGalleryIndexLinks(data *index.SiteData, r *router.Router) []views.GalleryIndexLink {
	var links []views.GalleryIndexLink

	// Photo tag galleries
	for _, pt := range data.PhotoTags {
		tag := &model.Tag{Slug: pt.Slug, SlugPl: pt.SlugPl, Name: pt.Title}
		links = append(links, views.GalleryIndexLink{
			URL:      r.TagGalleryURL(tag),
			Name:     pt.Title,
			Category: "Tagi",
		})
	}

	// Unique lenses/cameras from photos
	lenses := collectUniqueLenses(data)
	for _, lens := range lenses {
		links = append(links, views.GalleryIndexLink{
			URL:      fmt.Sprintf("/galeria/obiektyw/%s.html", sanitizeSlug(lens)),
			Name:     lens,
			Category: "Obiektywy",
		})
	}

	cameras := collectUniqueCameras(data)
	for _, camera := range cameras {
		links = append(links, views.GalleryIndexLink{
			URL:      fmt.Sprintf("/galeria/aparat/%s.html", sanitizeSlug(camera)),
			Name:     camera,
			Category: "Aparaty",
		})
	}

	return links
}

// --- Unique EXIF values ---

func collectUniqueLenses(data *index.SiteData) []string {
	seen := make(map[string]bool)
	var result []string
	for _, post := range data.Posts {
		if !post.IsFinished() {
			continue
		}
		for _, photo := range post.PhotoEntities {
			if photo.Exif != nil && photo.Exif.LensName != "" && !seen[photo.Exif.LensName] {
				seen[photo.Exif.LensName] = true
				result = append(result, photo.Exif.LensName)
			}
		}
	}
	sort.Strings(result)
	return result
}

func collectUniqueCameras(data *index.SiteData) []string {
	seen := make(map[string]bool)
	var result []string
	for _, post := range data.Posts {
		if !post.IsFinished() {
			continue
		}
		for _, photo := range post.PhotoEntities {
			if photo.Exif != nil && photo.Exif.CameraName != "" && !seen[photo.Exif.CameraName] {
				seen[photo.Exif.CameraName] = true
				result = append(result, photo.Exif.CameraName)
			}
		}
	}
	sort.Strings(result)
	return result
}

// --- Focal Length Ranges ---

// FocalLengthRanges returns exponential ranges starting at 16mm with ×1.2 steps.
func FocalLengthRanges() [][2]float64 {
	var ranges [][2]float64
	from := 16.0
	for from < 600 {
		to := math.Round(from * 1.2)
		if to <= from {
			to = from + 1
		}
		ranges = append(ranges, [2]float64{from, to})
		from = to
	}
	return ranges
}

// ISODoubleRanges returns standard ISO doubling ranges.
func ISODoubleRanges() [][2]int {
	return [][2]int{
		{50, 100}, {100, 200}, {200, 400}, {400, 800},
		{800, 1600}, {1600, 3200}, {3200, 6400}, {6400, 12800},
		{12800, 25600}, {25600, 51200},
	}
}

// ExposureRanges returns photography-meaningful shutter speed groups.
type ExposureRange struct {
	From  float64
	To    float64
	Label string
}

func ExposureRanges() []ExposureRange {
	return []ExposureRange{
		{1.0 / 8000, 1.0 / 2000, "1/8000–1/2000s"},
		{1.0 / 2000, 1.0 / 500, "1/2000–1/500s"},
		{1.0 / 500, 1.0 / 125, "1/500–1/125s"},
		{1.0 / 125, 1.0 / 30, "1/125–1/30s"},
		{1.0 / 30, 1.0 / 8, "1/30–1/8s"},
		{1.0 / 8, 1.0, "1/8–1s"},
		{1.0, 30.0, "1–30s"},
		{30.0, 3600.0, "30s+"},
	}
}

// --- Slug Sanitization ---

func sanitizeSlug(s string) string {
	s = strings.ToLower(s)
	s = strings.Map(func(r rune) rune {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == '-' || r == '_' || r == '.' {
			return r
		}
		if r == ' ' || r == '/' {
			return '-'
		}
		return -1
	}, s)
	// Collapse multiple dashes
	for strings.Contains(s, "--") {
		s = strings.ReplaceAll(s, "--", "-")
	}
	return strings.Trim(s, "-")
}
