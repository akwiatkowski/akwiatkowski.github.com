// Package catalog loads site inputs (posts, photos, areas, config) and builds
// the lookup indexes and aggregated statistics used across the renderer.
// (Former internal/loader + internal/index, merged during the Crystal↔Go
// convergence to mirror Crystal's data_manager.)
package catalog

import (
	"odkrywajac/internal/model"
)

// SiteData holds all loaded data with pre-built indexes for fast lookups.
type SiteData struct {
	Posts       []*model.Post
	Tags        []model.Tag
	PhotoTags   []model.PhotoTag
	Areas       []*model.Area
	Config      model.SiteConfig
	RouteColors map[string]model.RouteColor
	Stations    []model.TrainStation
	Ideas       []model.Idea

	// Lookup indexes (internal maps, use methods for access)
	postsByTagSlug map[string][]*model.Post // tag slug → posts
	PostsByYear    map[int][]*model.Post    // year → posts
	postsByArea    map[string][]*model.Post // AreaMapKey → posts
	postBySlug     map[string]*model.Post   // post slug → post
	areaByKey      map[string]*model.Area   // AreaMapKey → area
	AreasByType    map[model.AreaType][]*model.Area
	AreasWithPosts map[model.AreaType][]*model.Area // areas that have at least one post
	TagBySlug      map[string]*model.Tag
	photoTagBySlug map[string]*model.PhotoTag

	NavStats NavStats
}

// NavStats holds aggregated navigation statistics.
type NavStats struct {
	BicycleDistance int
	BicycleTime     int
	BicycleCount    int
	HikeDistance    int
	HikeTime        int
	HikeCount       int
	// Self = bicycle + hike
	SelfDistance int
	SelfTime     int
}

// PostBySlug looks up a post by its slug.
func (sd *SiteData) PostBySlug(slug string) *model.Post {
	return sd.postBySlug[slug]
}

// PhotoTagBySlug returns a photo tag by its English slug.
func (sd *SiteData) PhotoTagBySlug(slug string) *model.PhotoTag {
	return sd.photoTagBySlug[slug]
}

// PostsForTag returns posts for a given tag slug.
func (sd *SiteData) PostsForTag(tagSlug string) []*model.Post {
	return sd.postsByTagSlug[tagSlug]
}

// FindArea looks up an area by type and slug.
func (sd *SiteData) FindArea(areaType model.AreaType, slug string) *model.Area {
	return sd.areaByKey[model.AreaMapKey(areaType, slug)]
}

// PostsForArea returns posts that reference an area.
func (sd *SiteData) PostsForArea(areaType model.AreaType, slug string) []*model.Post {
	return sd.postsByArea[model.AreaMapKey(areaType, slug)]
}

// FindAreaByMapKey looks up an area by its composite map key (e.g., "town:pobiedziska").
func (sd *SiteData) FindAreaByMapKey(key string) *model.Area {
	return sd.areaByKey[key]
}

// FindAreaByTypeSlug looks up an area using type string (e.g., "town") and slug.
func (sd *SiteData) FindAreaByTypeSlug(areaTypeSlug, slug string) *model.Area {
	at, ok := model.ParseAreaType(areaTypeSlug)
	if !ok {
		return nil
	}
	return sd.FindArea(at, slug)
}

// PostsForAreaByTypeSlug returns posts using type string (e.g., "town") and slug.
func (sd *SiteData) PostsForAreaByTypeSlug(areaTypeSlug, slug string) []*model.Post {
	at, ok := model.ParseAreaType(areaTypeSlug)
	if !ok {
		return nil
	}
	return sd.PostsForArea(at, slug)
}

// BuildSiteData constructs a SiteData with all indexes populated.
func BuildSiteData(
	posts []*model.Post,
	tags []model.Tag,
	photoTags []model.PhotoTag,
	areas []*model.Area,
	config model.SiteConfig,
	routeColors map[string]model.RouteColor,
	stations []model.TrainStation,
	ideas []model.Idea,
) *SiteData {
	sd := &SiteData{
		Posts:       posts,
		Tags:        tags,
		PhotoTags:   photoTags,
		Areas:       areas,
		Config:      config,
		RouteColors: routeColors,
		Stations:    stations,
		Ideas:       ideas,
	}

	sd.buildTagIndexes()
	sd.buildPostIndexes()
	sd.buildAreaIndexes()
	sd.computeNavStats()

	return sd
}

func (sd *SiteData) buildTagIndexes() {
	sd.TagBySlug = make(map[string]*model.Tag, len(sd.Tags))
	for i := range sd.Tags {
		sd.TagBySlug[sd.Tags[i].Slug] = &sd.Tags[i]
	}

	sd.photoTagBySlug = make(map[string]*model.PhotoTag, len(sd.PhotoTags))
	for i := range sd.PhotoTags {
		sd.photoTagBySlug[sd.PhotoTags[i].Slug] = &sd.PhotoTags[i]
	}
}

func (sd *SiteData) buildPostIndexes() {
	sd.postsByTagSlug = make(map[string][]*model.Post)
	sd.PostsByYear = make(map[int][]*model.Post)
	sd.postBySlug = make(map[string]*model.Post, len(sd.Posts))

	for _, post := range sd.Posts {
		sd.postBySlug[post.Slug] = post
		for _, tagSlug := range post.TagSlugs {
			sd.postsByTagSlug[tagSlug] = append(sd.postsByTagSlug[tagSlug], post)
		}
		sd.PostsByYear[post.Year()] = append(sd.PostsByYear[post.Year()], post)
	}
}

func (sd *SiteData) buildAreaIndexes() {
	sd.areaByKey = make(map[string]*model.Area, len(sd.Areas))
	sd.AreasByType = make(map[model.AreaType][]*model.Area)
	sd.postsByArea = make(map[string][]*model.Post)
	sd.AreasWithPosts = make(map[model.AreaType][]*model.Area)

	for _, area := range sd.Areas {
		sd.areaByKey[area.MapKey()] = area
		sd.AreasByType[area.Type] = append(sd.AreasByType[area.Type], area)
	}

	// Build postsByArea: area map key → posts that reference it
	// TownSlugs can reference towns or voivodeships; LandSlugs reference meso/macro regions
	for _, post := range sd.Posts {
		seen := make(map[string]bool)
		// Spatial coverage is the most precise source: exact per-type slugs the
		// route actually crossed (incl. counties and disambiguated towns that
		// frontmatter never lists). Frontmatter slugs below still count — some
		// posts have no route, and authors can tag areas beyond the GPS line.
		for areaType, slugs := range post.SpatialAreaSlugs {
			for _, slug := range slugs {
				key := model.AreaMapKey(areaType, slug)
				if _, exists := sd.areaByKey[key]; exists && !seen[key] {
					sd.postsByArea[key] = append(sd.postsByArea[key], post)
					seen[key] = true
				}
			}
		}
		for _, slug := range post.TownSlugs {
			for _, at := range model.AllAreaTypes() {
				key := model.AreaMapKey(at, slug)
				if _, exists := sd.areaByKey[key]; exists && !seen[key] {
					sd.postsByArea[key] = append(sd.postsByArea[key], post)
					seen[key] = true
				}
			}
		}
		for _, slug := range post.LandSlugs {
			for _, at := range []model.AreaType{model.AreaTypeMesoRegion, model.AreaTypeMacroRegion} {
				key := model.AreaMapKey(at, slug)
				if _, exists := sd.areaByKey[key]; exists && !seen[key] {
					sd.postsByArea[key] = append(sd.postsByArea[key], post)
					seen[key] = true
				}
			}
		}
		// ForeignSlugs create external areas on the fly
		for _, slug := range post.ForeignSlugs {
			key := model.AreaMapKey(model.AreaTypeExternal, slug)
			if !seen[key] {
				sd.postsByArea[key] = append(sd.postsByArea[key], post)
				seen[key] = true
			}
			// Auto-create external area entity if not yet known
			if _, exists := sd.areaByKey[key]; !exists {
				area := &model.Area{
					Slug: slug,
					Name: slug, // name = slug until config provides a display name
					Type: model.AreaTypeExternal,
				}
				sd.areaByKey[key] = area
				sd.Areas = append(sd.Areas, area)
				sd.AreasByType[model.AreaTypeExternal] = append(sd.AreasByType[model.AreaTypeExternal], area)
			}
		}
	}

	// Build AreasWithPosts
	areasWithPostsSet := make(map[string]bool)
	for key := range sd.postsByArea {
		areasWithPostsSet[key] = true
	}
	for _, area := range sd.Areas {
		if areasWithPostsSet[area.MapKey()] {
			sd.AreasWithPosts[area.Type] = append(sd.AreasWithPosts[area.Type], area)
		}
	}
}

func (sd *SiteData) computeNavStats() {
	for _, post := range sd.Posts {
		if !post.IsFinished() {
			continue
		}

		hasBicycle := containsSlug(post.TagSlugs, "bicycle")
		hasHike := containsSlug(post.TagSlugs, "hike")

		if hasBicycle {
			sd.NavStats.BicycleDistance += int(post.Distance)
			sd.NavStats.BicycleTime += int(post.TimeSpent)
			sd.NavStats.BicycleCount++
		}
		if hasHike {
			sd.NavStats.HikeDistance += int(post.Distance)
			sd.NavStats.HikeTime += int(post.TimeSpent)
			sd.NavStats.HikeCount++
		}
	}

	sd.NavStats.SelfDistance = sd.NavStats.BicycleDistance + sd.NavStats.HikeDistance
	sd.NavStats.SelfTime = sd.NavStats.BicycleTime + sd.NavStats.HikeTime
}

// VoivodeshipSlugsForPost returns the voivodeship slugs associated with a post.
// It checks the area index for which voivodeships have this post linked.
func (sd *SiteData) VoivodeshipSlugsForPost(post *model.Post) []string {
	var slugs []string
	for _, area := range sd.AreasByType[model.AreaTypeVoivodeship] {
		key := area.MapKey()
		for _, p := range sd.postsByArea[key] {
			if p == post {
				slugs = append(slugs, area.Slug)
				break
			}
		}
	}
	return slugs
}

func containsSlug(slugs []string, target string) bool {
	for _, s := range slugs {
		if s == target {
			return true
		}
	}
	return false
}
