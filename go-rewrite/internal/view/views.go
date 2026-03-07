package view

import (
	"odkrywajac/internal/bundle"
	"odkrywajac/internal/index"
	"odkrywajac/internal/model"
	"odkrywajac/internal/router"
)

// GenerateAllViews collects all Renderables from the site data.
// All views are independent since SiteData is frozen/immutable.
func GenerateAllViews(
	data *index.SiteData,
	r *router.Router,
	resolver *bundle.Resolver,
	polygonDir string,
	pagesDir string,
) []Renderable {
	var all []Renderable

	// Homepage
	all = append(all, HomepagePage(data, r, resolver))

	// Post pages: article and gallery for each finished post
	for _, post := range data.Posts {
		if !post.IsFinished() {
			continue
		}
		all = append(all,
			PostArticlePage(data, post, r, resolver),
			PostGalleryPage(data, post, r, resolver),
		)
	}

	// Area pages: show, post list, gallery for each area with posts
	for _, areaType := range model.AllAreaTypes() {
		areas := data.AreasWithPosts[areaType]
		for _, area := range areas {
			all = append(all,
				AreaShowPage(data, area, r, resolver, polygonDir),
				AreaPostListPage(data, area, r, resolver),
				AreaGalleryPage(data, area, r, resolver),
			)
		}
	}

	// Tag pages: post list and gallery for each tag
	for _, tag := range data.Tags {
		tag := tag // capture loop variable
		all = append(all,
			TagPostListPage(data, &tag, r, resolver),
		)
	}

	// Tag galleries for photo tags that have photos
	for _, photoTag := range data.PhotoTags {
		// Create a Tag-like reference for URL generation
		tag := &model.Tag{
			Slug:   photoTag.Slug,
			SlugPl: photoTag.SlugPl,
			Name:   photoTag.Title,
		}
		all = append(all, TagGalleryPage(data, tag, r, resolver))
	}

	// Tag redirects: /tag/<slug_pl>.html → /wpisy-dla/tagu/<slug_pl>.html
	for _, tag := range data.Tags {
		all = append(all, NewRedirectPage(
			r.TagShowURL(&tag),
			r.TagPostListURL(&tag),
			302,
		))
	}

	// JSON endpoints
	all = append(all,
		E2EJSON(data, r),
		HomepageJSON(data, r),
		MapJSON(data, r),
		PhotosJSON(data, r),
		PhotosMapJSON(data, r),
		TrainStationsJSON(data, r),
		PhotoGridJSON(data, r),
		IdeasJSON(r),
	)

	// Feeds
	all = append(all,
		RSSFeed(data, r),
		AtomFeed(data, r),
		RobotsTxt(r),
	)

	// Shell pages (JS-heavy with <div id="root">)
	all = append(all,
		RouteMapPage(data, r, resolver),
		PhotoMapPage(data, r, resolver),
		TimelinePage(data, r, resolver),
		ExifStatsPage(data, r, resolver),
		PhotoPlannerPage(data, r, resolver),
		TripIdeasPage(data, r, resolver),
	)

	// Static pages
	all = append(all,
		AboutPage(data, r, resolver, pagesDir),
		EnglishPage(data, r, resolver, pagesDir),
		MorePage(data, r, resolver),
	)

	// Index pages
	all = append(all,
		TownsIndexPage(data, r, resolver),
	)

	// Portfolio
	all = append(all,
		PortfolioPage(data, r, resolver),
	)

	// Sitemap must be generated last since it references all other sitemappable views
	all = append(all, Sitemap(all, r))

	return all
}
