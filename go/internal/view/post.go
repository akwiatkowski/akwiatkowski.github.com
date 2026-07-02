package view

import (
	"fmt"
	"sort"

	"odkrywajac/internal/service/bundle"
	"odkrywajac/internal/index"
	"odkrywajac/internal/content"
	"odkrywajac/internal/model"
	"odkrywajac/internal/service/router"
	"odkrywajac/internal/view/template/components"
	"odkrywajac/internal/view/template/layout"
	"odkrywajac/internal/view/template/views"
)

// polishWeekday returns the Polish name for a weekday.
var polishWeekdays = [...]string{
	"niedziela", "poniedziałek", "wtorek", "środa",
	"czwartek", "piątek", "sobota",
}

// PostArticlePage creates a Renderable for a post article page.
func PostArticlePage(
	data *index.SiteData,
	post *model.Post,
	r *router.Router,
	resolver *bundle.Resolver,
	release bool,
) Renderable {
	url := r.PostURL(post)

	// In the release TARGET, not-ready (todo/draft) posts keep their page shell
	// but ship no body and stay out of the sitemap — mirrors Crystal's
	// hide_not_finished behavior. In local they render fully.
	hideBody := release && !post.IsReady()

	// Render markdown with custom extensions
	var renderedHTML string
	if hideBody {
		renderedHTML = ""
	} else {
		renderCtx := &content.RenderContext{
			Post:       post,
			PostLookup: data,
			URLBuilder: r,
			TagLookup:  data,
		}
		var err error
		renderedHTML, err = content.RenderPost(post.Content, renderCtx)
		if err != nil {
			renderedHTML = fmt.Sprintf("<p>Error rendering markdown: %s</p>", err)
		}
	}

	// Hero header image
	var heroImageURL string
	if post.ImageFilename != "" {
		heroImageURL = r.PostImageURL(post, post.ImageFilename)
	}

	// Format date with Polish weekday: "2022-12-18 (niedziela)"
	dateStr := fmt.Sprintf("%s (%s)", post.Date.Format("2006-01-02"), polishWeekdays[post.Date.Weekday()])

	// Build article data
	articleData := views.PostArticleData{
		HeroImageURL:     heroImageURL,
		ImagePosition:    heroImagePosition(post.ImagePosition),
		Title:            post.Title,
		Subtitle:         post.Subtitle,
		DateStr:          dateStr,
		Author:           post.Author,
		RenderedMarkdown: renderedHTML,
		TagLinks:         buildTagLinks(data, post, r),
		AreaLinks:        buildAreaLinks(data, post, r),
	}

	// Gallery URL
	articleData.GalleryURL = r.PostGalleryURL(post)

	// SVG map and route stats
	if post.HasRoutes() {
		articleData.SvgMapURL = fmt.Sprintf("/mapa_zdjec/wpis/%s.svg", post.Slug)

		if cr, ok := post.RoutesCoordRange(); ok {
			center := cr.Center()
			zoom := 11
			articleData.MapLinks = []views.MapLink{
				{Name: "UMP", URL: fmt.Sprintf("https://mapa.ump.waw.pl/ump-www/?zoom=%d&lat=%f&lon=%f", zoom, center.Lat, center.Lon)},
				{Name: "OSM", URL: fmt.Sprintf("https://www.openstreetmap.org/#map=%d/%f/%f", zoom, center.Lat, center.Lon)},
				{Name: "Mapy.cz", URL: fmt.Sprintf("https://en.mapy.cz/zakladni?x=%f&y=%f&z=%d", center.Lon, center.Lat, zoom)},
				{Name: "Google", URL: fmt.Sprintf("https://www.google.pl/maps/@%f,%f,%dz", center.Lat, center.Lon, zoom)},
			}
		}
	}
	articleData.ActivityBadge = activityBadge(post)
	if post.Distance > 0 {
		articleData.DistanceStr = fmt.Sprintf("%d km", int(post.Distance))
	}
	if post.TimeSpent > 0 {
		articleData.TimeStr = fmt.Sprintf("%d h", int(post.TimeSpent))
	}
	if post.Temperature != nil {
		articleData.TemperatureStr = temperatureStr(*post.Temperature)
	}

	// Finished at
	if post.FinishedAt != nil {
		articleData.FinishedAtStr = post.FinishedAt.Format("2006-01-02")
	}

	// Prev/next posts
	prevPost, nextPost := findAdjacentPosts(data.Posts, post)
	if prevPost != nil {
		jpegURL, avifURL := postThumbnailURLs(r, prevPost)
		articleData.PrevPost = &views.PostPagerData{
			URL:              r.PostURL(prevPost),
			Title:            prevPost.Title,
			ThumbnailJPEGURL: jpegURL,
			ThumbnailAVIFURL: avifURL,
		}
	}
	if nextPost != nil {
		jpegURL, avifURL := postThumbnailURLs(r, nextPost)
		articleData.NextPost = &views.PostPagerData{
			URL:              r.PostURL(nextPost),
			Title:            nextPost.Title,
			ThumbnailJPEGURL: jpegURL,
			ThumbnailAVIFURL: avifURL,
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

	return NewHTMLPage(url, page, views.PostArticleContent(articleData), !hideBody)
}

// PostGalleryPage creates a Renderable for a post gallery page.
// Uses the dynamic JS gallery with lightbox.
func PostGalleryPage(
	data *index.SiteData,
	post *model.Post,
	r *router.Router,
	resolver *bundle.Resolver,
) Renderable {
	url := r.PostGalleryURL(post)
	title := fmt.Sprintf("Galeria: %s", post.Title)
	return galleryPage(data, r, resolver, url, title, post.PublishedPhotos, false)
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
		model.AreaTypeMesoRegion:  "Krainy",
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

// heroImagePosition returns the CSS background-position for a post's hero header.
// Defaults to "50% 50%" if not specified in the post's front matter.
func heroImagePosition(position string) string {
	if position == "" {
		return "50% 50%"
	}
	return position
}

// postThumbnailURLs returns the JPEG and AVIF thumbnail URLs for a post's header image.
func postThumbnailURLs(r *router.Router, post *model.Post) (jpegURL, avifURL string) {
	if post.ImageFilename == "" {
		return "", ""
	}
	return r.ProcessedImageURL(post, post.ImageFilename, "thumbnail", "jpg"),
		r.ProcessedImageURL(post, post.ImageFilename, "thumbnail", "avif")
}

// activityBadge returns an emoji badge for the post's activity type.
func activityBadge(post *model.Post) string {
	for _, slug := range post.TagSlugs {
		switch slug {
		case "bicycle":
			return "🚲 rowerem"
		case "hike":
			return "🥾 pieszo"
		}
	}
	return ""
}

// temperatureStr formats a temperature with an appropriate emoji.
func temperatureStr(temp int) string {
	emoji := "🌡️"
	if temp <= 0 {
		emoji = "❄️"
	} else if temp >= 25 {
		emoji = "☀️"
	}
	return fmt.Sprintf("%s %d °C", emoji, temp)
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
