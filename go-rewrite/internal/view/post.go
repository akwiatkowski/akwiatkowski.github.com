package view

import (
	"encoding/json"
	"fmt"
	"sort"

	"odkrywajac/internal/bundle"
	"odkrywajac/internal/index"
	"odkrywajac/internal/markdown"
	"odkrywajac/internal/model"
	"odkrywajac/internal/router"
	"odkrywajac/internal/templates/components"
	"odkrywajac/internal/templates/layout"
	"odkrywajac/internal/templates/views"
)

// PostArticlePage creates a Renderable for a post article page.
func PostArticlePage(
	data *index.SiteData,
	post *model.Post,
	r *router.Router,
	resolver *bundle.Resolver,
) Renderable {
	url := r.PostURL(post)

	// Render markdown with custom extensions
	renderCtx := &markdown.RenderContext{
		Post:       post,
		PostLookup: data,
		URLBuilder: r,
	}
	renderedHTML, err := markdown.RenderPost(post.Content, renderCtx)
	if err != nil {
		renderedHTML = fmt.Sprintf("<p>Error rendering markdown: %s</p>", err)
	}

	// Build article data
	articleData := views.PostArticleData{
		RenderedMarkdown: renderedHTML,
		TagLinks:         buildTagLinks(data, post, r),
		AreaLinks:        buildAreaLinks(data, post, r),
	}

	// Gallery URL
	articleData.GalleryURL = r.PostGalleryURL(post)

	// Finished at
	if post.FinishedAt != nil {
		articleData.FinishedAtStr = post.FinishedAt.Format("2006-01-02")
	}

	// Prev/next posts
	prevPost, nextPost := findAdjacentPosts(data.Posts, post)
	if prevPost != nil {
		articleData.PrevPost = &views.PostPagerData{
			URL:          r.PostURL(prevPost),
			Title:        prevPost.Title,
			ThumbnailURL: postThumbnailURL(r, prevPost),
		}
	}
	if nextPost != nil {
		articleData.NextPost = &views.PostPagerData{
			URL:          r.PostURL(nextPost),
			Title:        nextPost.Title,
			ThumbnailURL: postThumbnailURL(r, nextPost),
		}
	}

	// Related posts
	articleData.RelatedPosts = buildRelatedPosts(data, post, r, 3)

	// Resolve assets
	cssFiles, jsFiles := resolveAssets(resolver, []string{"core"}, nil)

	// OG image
	var imageURL string
	if post.ImageFilename != "" {
		imageURL = r.CanonicalURL(r.ProcessedImageURL(post, post.ImageFilename, "card", "jpg"))
	}

	page := layout.PageData{
		Title:        post.Title,
		Subtitle:     post.Subtitle,
		Desc:         post.Desc,
		URL:          url,
		CanonicalURL: r.CanonicalURL(url),
		SiteName:     data.Config.Title,
		CSSFiles:     cssFiles,
		JSFiles:      jsFiles,
		ImageURL:     imageURL,
		NavStats:     navStatsFromIndex(data.NavStats, r, data.TagBySlug),
	}

	return NewHTMLPage(url, page, views.PostArticleContent(articleData), true)
}

// PostGalleryPage creates a Renderable for a post gallery page.
func PostGalleryPage(
	data *index.SiteData,
	post *model.Post,
	r *router.Router,
	resolver *bundle.Resolver,
) Renderable {
	url := r.PostGalleryURL(post)

	// Build gallery config JSON
	type galleryPhoto struct {
		JPEG    string `json:"jpeg"`
		AVIF    string `json:"avif"`
		GridJPEG string `json:"grid_jpeg"`
		GridAVIF string `json:"grid_avif"`
		Caption string `json:"caption"`
		Exif    string `json:"exif,omitempty"`
	}

	var photos []galleryPhoto
	for _, photo := range post.PublishedPhotos {
		photos = append(photos, galleryPhoto{
			JPEG:     r.ProcessedImageURL(post, photo.ImageFilename, "article", "jpg"),
			AVIF:     r.ProcessedImageURL(post, photo.ImageFilename, "article", "avif"),
			GridJPEG: r.ProcessedImageURL(post, photo.ImageFilename, "grid", "jpg"),
			GridAVIF: r.ProcessedImageURL(post, photo.ImageFilename, "grid", "avif"),
			Caption:  photo.Desc,
			Exif:     photo.ExifString(),
		})
	}

	configJSON, _ := json.Marshal(photos)
	rawScript := `<script id="gallery-config" type="application/json">` + string(configJSON) + `</script>`

	cssFiles, jsFiles := resolveAssets(resolver, []string{"core"}, []string{"gallery"})

	page := layout.PageData{
		Title:        fmt.Sprintf("Galeria: %s", post.Title),
		URL:          url,
		CanonicalURL: r.CanonicalURL(url),
		SiteName:     data.Config.Title,
		CSSFiles:     cssFiles,
		JSFiles:      jsFiles,
		NavStats:     navStatsFromIndex(data.NavStats, r, data.TagBySlug),
	}

	return NewHTMLPage(url, page, views.PostGalleryContent(rawScript), true)
}

// buildTagLinks creates tag links for a post.
func buildTagLinks(data *index.SiteData, post *model.Post, r *router.Router) []views.PostTagLink {
	var links []views.PostTagLink
	for _, tagSlug := range post.TagSlugs {
		tag := data.TagBySlug[tagSlug]
		if tag == nil {
			continue
		}
		links = append(links, views.PostTagLink{
			URL:  r.TagPostListURL(tag),
			Name: tag.Name,
		})
	}
	return links
}

// buildAreaLinks creates grouped area links for a post.
func buildAreaLinks(data *index.SiteData, post *model.Post, r *router.Router) []views.PostAreaGroup {
	type areaRef struct {
		areaType model.AreaType
		slug     string
	}

	// Collect area refs from post
	var refs []areaRef
	for _, slug := range post.TownSlugs {
		// TownSlugs can match towns or voivodeships
		for _, at := range model.AllAreaTypes() {
			if area := data.FindArea(at, slug); area != nil {
				refs = append(refs, areaRef{at, slug})
			}
		}
	}
	for _, slug := range post.LandSlugs {
		for _, at := range []model.AreaType{model.AreaTypeMesoRegion, model.AreaTypeMacroRegion} {
			if area := data.FindArea(at, slug); area != nil {
				refs = append(refs, areaRef{at, slug})
			}
		}
	}

	// Group by type
	grouped := make(map[model.AreaType][]views.PostAreaLink)
	for _, ref := range refs {
		area := data.FindArea(ref.areaType, ref.slug)
		if area == nil {
			continue
		}
		grouped[ref.areaType] = append(grouped[ref.areaType], views.PostAreaLink{
			URL:  r.AreaLinkURL(area),
			Name: area.Name,
		})
	}

	// Build ordered groups
	typeLabels := map[model.AreaType]string{
		model.AreaTypeTown:        "Gminy",
		model.AreaTypeCounty:      "Powiaty",
		model.AreaTypeVoivodeship: "Województwa",
		model.AreaTypeMesoRegion:  "Mezoregiony",
		model.AreaTypeMacroRegion: "Makroregiony",
	}

	var groups []views.PostAreaGroup
	for _, at := range model.AllAreaTypes() {
		if links, ok := grouped[at]; ok && len(links) > 0 {
			groups = append(groups, views.PostAreaGroup{
				Label: typeLabels[at],
				Areas: links,
			})
		}
	}

	return groups
}

// findAdjacentPosts finds the previous and next posts chronologically.
func findAdjacentPosts(posts []*model.Post, current *model.Post) (prev, next *model.Post) {
	// Posts should be sorted by date (newest first)
	sorted := make([]*model.Post, 0, len(posts))
	for _, p := range posts {
		if p.IsFinished() {
			sorted = append(sorted, p)
		}
	}
	sort.Slice(sorted, func(i, j int) bool {
		return sorted[i].Date.After(sorted[j].Date)
	})

	for i, p := range sorted {
		if p.Slug == current.Slug {
			if i > 0 {
				next = sorted[i-1] // newer post
			}
			if i < len(sorted)-1 {
				prev = sorted[i+1] // older post
			}
			break
		}
	}
	return
}

// postThumbnailURL returns the thumbnail URL for a post's header image.
func postThumbnailURL(r *router.Router, post *model.Post) string {
	if post.ImageFilename == "" {
		return ""
	}
	return r.ProcessedImageURL(post, post.ImageFilename, "thumbnail", "jpg")
}

// buildRelatedPosts finds related posts by shared areas/tags.
func buildRelatedPosts(data *index.SiteData, post *model.Post, r *router.Router, limit int) []components.PostCardData {
	// Score posts by shared attributes
	scores := make(map[string]int)

	for _, slug := range post.TownSlugs {
		for _, at := range model.AllAreaTypes() {
			for _, p := range data.PostsForArea(at, slug) {
				if p.Slug != post.Slug {
					scores[p.Slug] += 2
				}
			}
		}
	}
	for _, slug := range post.LandSlugs {
		for _, at := range []model.AreaType{model.AreaTypeMesoRegion, model.AreaTypeMacroRegion} {
			for _, p := range data.PostsForArea(at, slug) {
				if p.Slug != post.Slug {
					scores[p.Slug]++
				}
			}
		}
	}
	for _, tagSlug := range post.TagSlugs {
		for _, p := range data.PostsForTag(tagSlug) {
			if p.Slug != post.Slug {
				scores[p.Slug]++
			}
		}
	}

	// Sort by score descending
	type scoredPost struct {
		slug  string
		score int
	}
	var scored []scoredPost
	for slug, score := range scores {
		scored = append(scored, scoredPost{slug, score})
	}
	sort.Slice(scored, func(i, j int) bool {
		return scored[i].score > scored[j].score
	})

	// Take top N
	var cards []components.PostCardData
	for i, sp := range scored {
		if i >= limit {
			break
		}
		p := data.PostBySlug(sp.slug)
		if p == nil || !p.IsFinished() {
			continue
		}
		card := components.PostCardData{
			URL:   r.PostURL(p),
			Title: p.Title,
		}
		if p.ImageFilename != "" {
			card.Photo = &components.PhotoCardData{
				JPEGSrc: r.ProcessedImageURL(p, p.ImageFilename, "grid", "jpg"),
				AVIFSrc: r.ProcessedImageURL(p, p.ImageFilename, "grid", "avif"),
				Alt:     p.Title,
			}
		}
		cards = append(cards, card)
	}

	return cards
}
