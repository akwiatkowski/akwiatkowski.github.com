package view

import (
	"fmt"

	"odkrywajac/internal/bundle"
	"odkrywajac/internal/index"
	"odkrywajac/internal/model"
	"odkrywajac/internal/router"
	"odkrywajac/internal/templates/components"
	"odkrywajac/internal/templates/layout"
	"odkrywajac/internal/templates/views"
)

// TagPostListPage creates a Renderable for a tag post list page.
func TagPostListPage(
	data *index.SiteData,
	tag *model.Tag,
	r *router.Router,
	resolver *bundle.Resolver,
) Renderable {
	url := r.TagPostListURL(tag)

	cssFiles, jsFiles := resolveAssets(resolver, []string{"core", "post-collection-js"}, nil)

	page := layout.PageData{
		Title:        fmt.Sprintf("Wpisy: %s", tag.Name),
		URL:          url,
		CanonicalURL: r.CanonicalURL(url),
		SiteName:     data.Config.Title,
		CSSFiles:     cssFiles,
		JSFiles:      jsFiles,
		NavStats:     navStatsFromIndex(data.NavStats, r, data.TagBySlug),
	}

	// Use English slug for JS filtering, Polish slug_pl in URL
	configJSON := fmt.Sprintf(`{"filterBy":"tag","filterValue":"%s"}`, tag.Slug) //nolint:gocritic // raw JSON template, %q would break output
	rawScript := `<script id="post-collection-config" type="application/json">` + configJSON + `</script>`

	return NewHTMLPage(url, page, views.AreaPostListContent(rawScript), true)
}

// TagGalleryPage creates a Renderable for a tag gallery page.
func TagGalleryPage(
	data *index.SiteData,
	tag *model.Tag,
	r *router.Router,
	resolver *bundle.Resolver,
) Renderable {
	url := r.TagGalleryURL(tag)

	cssFiles, jsFiles := resolveAssets(resolver, []string{"core"}, []string{"gallery"})

	page := layout.PageData{
		Title:        fmt.Sprintf("Galeria: %s", tag.Name),
		URL:          url,
		CanonicalURL: r.CanonicalURL(url),
		SiteName:     data.Config.Title,
		CSSFiles:     cssFiles,
		JSFiles:      jsFiles,
		NavStats:     navStatsFromIndex(data.NavStats, r, data.TagBySlug),
	}

	// Collect photos by photo tag slug
	photoCards := collectPhotosByTag(data, tag.Slug, r)

	return NewHTMLPage(url, page, views.AreaGalleryContent(photoCards), true)
}

// collectPhotosByTag collects photos that have the given photo tag slug.
func collectPhotosByTag(data *index.SiteData, tagSlug string, r *router.Router) []components.PhotoCardData {
	var cards []components.PhotoCardData
	for _, post := range data.Posts {
		if !post.IsFinished() {
			continue
		}
		for _, photo := range post.PublishedPhotos {
			if hasSlug(photo.TagSlugs, tagSlug) {
				cards = append(cards, components.PhotoCardData{
					JPEGSrc: r.ProcessedImageURL(post, photo.ImageFilename, "grid", "jpg"),
					AVIFSrc: r.ProcessedImageURL(post, photo.ImageFilename, "grid", "avif"),
					Alt:     photo.Desc,
				})
			}
		}
	}
	return cards
}

func hasSlug(slugs []string, target string) bool {
	for _, s := range slugs {
		if s == target {
			return true
		}
	}
	return false
}
