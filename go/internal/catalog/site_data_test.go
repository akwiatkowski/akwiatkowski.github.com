package catalog

import (
	"testing"
	"time"

	"odkrywajac/internal/model"
)

func makePosts() []*model.Post {
	past := time.Date(2021, 8, 1, 0, 0, 0, 0, time.UTC)
	return []*model.Post{
		{
			Slug:      "2021-07-18-bicycle-trip",
			Date:      time.Date(2021, 7, 18, 0, 0, 0, 0, time.UTC),
			FinishedAt: &past,
			TagSlugs:  []string{"bicycle", "main"},
			TownSlugs: []string{"wielkopolskie", "pobiedziska"},
			LandSlugs: []string{},
			Distance:  69,
			TimeSpent: 8,
		},
		{
			Slug:      "2021-06-01-hike-trip",
			Date:      time.Date(2021, 6, 1, 0, 0, 0, 0, time.UTC),
			FinishedAt: &past,
			TagSlugs:  []string{"hike", "main"},
			TownSlugs: []string{"dolnoslaskie", "bystrzyca_klodzka"},
			LandSlugs: []string{"gory_bystrzyckie"},
			Distance:  15,
			TimeSpent: 7,
		},
		{
			Slug:     "2021-05-01-draft",
			Date:     time.Date(2021, 5, 1, 0, 0, 0, 0, time.UTC),
			TagSlugs: []string{"bicycle", "todo"},
			TownSlugs: []string{},
			LandSlugs: []string{},
			Distance: 30,
		},
	}
}

func makeTags() []model.Tag {
	return []model.Tag{
		{Slug: "bicycle", SlugPl: "rowerem", Name: "Rowerem", IsNav: true},
		{Slug: "hike", SlugPl: "pieszo", Name: "Pieszo", IsNav: true},
		{Slug: "main", SlugPl: "strona_glowna", Name: "Strona główna"},
		{Slug: "todo", SlugPl: "niedokonczone", Name: "Niedokończone"},
	}
}

func makeAreas() []*model.Area {
	return []*model.Area{
		{Slug: "pobiedziska", Name: "Pobiedziska", Type: model.AreaTypeTown,
			VoivodeshipSlug: "wielkopolskie"},
		{Slug: "bystrzyca_klodzka", Name: "Bystrzyca Kłodzka", Type: model.AreaTypeTown,
			VoivodeshipSlug: "dolnoslaskie"},
		{Slug: "wielkopolskie", Name: "Wielkopolskie", Type: model.AreaTypeVoivodeship},
		{Slug: "dolnoslaskie", Name: "Dolnośląskie", Type: model.AreaTypeVoivodeship},
		{Slug: "gory_bystrzyckie", Name: "Góry Bystrzyckie", Type: model.AreaTypeMesoRegion},
	}
}

func buildTestSiteData() *SiteData {
	return BuildSiteData(
		makePosts(), makeTags(), nil, makeAreas(),
		model.SiteConfig{Title: "Test"}, nil, nil, nil,
	)
}

func TestBuildSiteDataTagIndex(t *testing.T) {
	sd := buildTestSiteData()

	if sd.TagBySlug["bicycle"] == nil {
		t.Error("bicycle tag not found in index")
	}
	if sd.TagBySlug["bicycle"].Name != "Rowerem" {
		t.Errorf("bicycle name = %q", sd.TagBySlug["bicycle"].Name)
	}
}

func TestPostsForTag(t *testing.T) {
	sd := buildTestSiteData()

	bicyclePosts := sd.PostsForTag("bicycle")
	if len(bicyclePosts) != 2 { // bicycle-trip + draft
		t.Errorf("expected 2 bicycle posts, got %d", len(bicyclePosts))
	}

	hikePosts := sd.PostsForTag("hike")
	if len(hikePosts) != 1 {
		t.Errorf("expected 1 hike post, got %d", len(hikePosts))
	}
}

func TestPostsByYear(t *testing.T) {
	sd := buildTestSiteData()

	posts2021 := sd.PostsByYear[2021]
	if len(posts2021) != 3 {
		t.Errorf("expected 3 posts in 2021, got %d", len(posts2021))
	}
}

func TestFindArea(t *testing.T) {
	sd := buildTestSiteData()

	area := sd.FindArea(model.AreaTypeTown, "pobiedziska")
	if area == nil {
		t.Fatal("pobiedziska not found")
	}
	if area.Name != "Pobiedziska" {
		t.Errorf("Name = %q", area.Name)
	}

	// Not found
	if sd.FindArea(model.AreaTypeTown, "nonexistent") != nil {
		t.Error("should not find nonexistent area")
	}
}

func TestFindAreaByTypeSlug(t *testing.T) {
	sd := buildTestSiteData()

	area := sd.FindAreaByTypeSlug("town", "pobiedziska")
	if area == nil {
		t.Fatal("pobiedziska not found via type slug")
	}

	// Invalid type
	if sd.FindAreaByTypeSlug("invalid", "pobiedziska") != nil {
		t.Error("should return nil for invalid type")
	}
}

func TestPostsForArea(t *testing.T) {
	sd := buildTestSiteData()

	// Town lookup
	townPosts := sd.PostsForArea(model.AreaTypeTown, "pobiedziska")
	if len(townPosts) != 1 {
		t.Errorf("expected 1 post for pobiedziska, got %d", len(townPosts))
	}

	// Voivodeship lookup (from TownSlugs containing "dolnoslaskie")
	voivPosts := sd.PostsForArea(model.AreaTypeVoivodeship, "dolnoslaskie")
	if len(voivPosts) != 1 {
		t.Errorf("expected 1 post for dolnoslaskie voivodeship, got %d", len(voivPosts))
	}

	// MesoRegion lookup (from LandSlugs)
	regionPosts := sd.PostsForArea(model.AreaTypeMesoRegion, "gory_bystrzyckie")
	if len(regionPosts) != 1 {
		t.Errorf("expected 1 post for gory_bystrzyckie, got %d", len(regionPosts))
	}
}

func TestAreasWithPosts(t *testing.T) {
	sd := buildTestSiteData()

	towns := sd.AreasWithPosts[model.AreaTypeTown]
	if len(towns) != 2 {
		t.Errorf("expected 2 towns with posts, got %d", len(towns))
	}

	voivs := sd.AreasWithPosts[model.AreaTypeVoivodeship]
	if len(voivs) != 2 {
		t.Errorf("expected 2 voivodeships with posts, got %d", len(voivs))
	}
}

func TestNavStats(t *testing.T) {
	sd := buildTestSiteData()

	// Only finished posts count
	if sd.NavStats.BicycleDistance != 69 {
		t.Errorf("BicycleDistance = %d, want 69 (draft should not count)", sd.NavStats.BicycleDistance)
	}
	if sd.NavStats.BicycleCount != 1 {
		t.Errorf("BicycleCount = %d, want 1", sd.NavStats.BicycleCount)
	}
	if sd.NavStats.HikeDistance != 15 {
		t.Errorf("HikeDistance = %d, want 15", sd.NavStats.HikeDistance)
	}
	if sd.NavStats.SelfDistance != 84 {
		t.Errorf("SelfDistance = %d, want 84", sd.NavStats.SelfDistance)
	}
}

func TestAreasByType(t *testing.T) {
	sd := buildTestSiteData()

	if len(sd.AreasByType[model.AreaTypeTown]) != 2 {
		t.Errorf("expected 2 towns, got %d", len(sd.AreasByType[model.AreaTypeTown]))
	}
	if len(sd.AreasByType[model.AreaTypeVoivodeship]) != 2 {
		t.Errorf("expected 2 voivodeships, got %d", len(sd.AreasByType[model.AreaTypeVoivodeship]))
	}
}

func TestVoivodeshipSlugsForPost(t *testing.T) {
	sd := buildTestSiteData()

	// bicycle-trip has TownSlugs=["wielkopolskie", "pobiedziska"], so voivodeship is wielkopolskie
	bicyclePost := sd.PostBySlug("2021-07-18-bicycle-trip")
	slugs := sd.VoivodeshipSlugsForPost(bicyclePost)
	if len(slugs) != 1 || slugs[0] != "wielkopolskie" {
		t.Errorf("VoivodeshipSlugsForPost(bicycle-trip) = %v, want [wielkopolskie]", slugs)
	}

	// hike-trip has TownSlugs=["dolnoslaskie", "bystrzyca_klodzka"], so voivodeship is dolnoslaskie
	hikePost := sd.PostBySlug("2021-06-01-hike-trip")
	slugs = sd.VoivodeshipSlugsForPost(hikePost)
	if len(slugs) != 1 || slugs[0] != "dolnoslaskie" {
		t.Errorf("VoivodeshipSlugsForPost(hike-trip) = %v, want [dolnoslaskie]", slugs)
	}

	// draft has no TownSlugs that match a voivodeship
	draftPost := sd.PostBySlug("2021-05-01-draft")
	slugs = sd.VoivodeshipSlugsForPost(draftPost)
	if len(slugs) != 0 {
		t.Errorf("VoivodeshipSlugsForPost(draft) = %v, want []", slugs)
	}
}
