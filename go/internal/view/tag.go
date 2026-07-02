package view

import (
	"fmt"

	"odkrywajac/internal/service/bundle"
	"odkrywajac/internal/catalog"
	"odkrywajac/internal/model"
	"odkrywajac/internal/service/router"
	"odkrywajac/internal/view/template/layout"
	"odkrywajac/internal/view/template/views"
)

// TagPostListPage creates a Renderable for a tag post list page.
func TagPostListPage(
	data *catalog.SiteData,
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
// Uses the dynamic JS gallery with lightbox.
func TagGalleryPage(
	data *catalog.SiteData,
	tag *model.Tag,
	r *router.Router,
	resolver *bundle.Resolver,
) Renderable {
	url := r.TagGalleryURL(tag)
	allPhotos := allPublishedPhotos(data)
	photos := photosForTag(allPhotos, tag.Slug)
	title := fmt.Sprintf("Galeria: %s", tag.Name)
	return galleryPage(data, r, resolver, url, title, photos, true)
}
