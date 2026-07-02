package catalog

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"odkrywajac/internal/service/exif"
	"odkrywajac/internal/model"

	"gopkg.in/yaml.v3"
)

func TestPopulatePublishedPhotos(t *testing.T) {
	// Create a temporary EXIF cache with one entry.
	cacheDir := t.TempDir()
	writeExifCache(t, cacheDir, "2022-12-18-test-post", []exifCacheEntry{
		{ImageFilename: "photo1.jpg", PostSlug: "2022-12-18-test-post", Lat: floatPtr(52.4), Lon: floatPtr(16.9)},
		{ImageFilename: "photo2.jpg", PostSlug: "2022-12-18-test-post", ISO: intPtr(400)},
	})

	exifCache := exif.NewCache(cacheDir)

	photoTags := []model.PhotoTag{
		{Slug: "good", Points: 5},
		{Slug: "best", Points: 10},
		{Slug: "gallery", Points: 2},
	}

	post := &model.Post{
		Slug:          "2022-12-18-test-post",
		Date:          mustParseDate("2022-12-18"),
		ImageFilename: "photo1.jpg",
		PublishedPhotoRefs: []model.PhotoRef{
			{Filename: "photo1.jpg", Caption: "A great photo", TagSlugs: []string{"best", "gallery"}},
			{Filename: "photo2.jpg", Caption: "Another photo", TagSlugs: []string{"good"}},
		},
	}

	// imagesDir not used for published photos when cache exists, but required by signature.
	PopulatePublishedPhotos([]*model.Post{post}, exifCache, photoTags, t.TempDir())

	if len(post.PublishedPhotos) != 2 {
		t.Fatalf("expected 2 published photos, got %d", len(post.PublishedPhotos))
	}

	// Check first photo
	p1 := post.PublishedPhotos[0]
	if p1.ImageFilename != "photo1.jpg" {
		t.Errorf("photo1 filename = %q", p1.ImageFilename)
	}
	if p1.PostSlug != "2022-12-18-test-post" {
		t.Errorf("photo1 post slug = %q", p1.PostSlug)
	}
	if p1.Points != 12 { // best(10) + gallery(2)
		t.Errorf("photo1 points = %d, want 12", p1.Points)
	}
	if !p1.IsHeader {
		t.Error("photo1 should be header (matches post.ImageFilename)")
	}
	if !p1.IsGallery {
		t.Error("photo1 should be gallery (has 'gallery' tag)")
	}
	if p1.Exif == nil {
		t.Error("photo1 should have EXIF data")
	} else if p1.Exif.Lat == nil || *p1.Exif.Lat != 52.4 {
		t.Errorf("photo1 lat = %v", p1.Exif.Lat)
	}

	// Check second photo
	p2 := post.PublishedPhotos[1]
	if p2.Points != 5 { // good(5)
		t.Errorf("photo2 points = %d, want 5", p2.Points)
	}
	if p2.IsHeader {
		t.Error("photo2 should not be header")
	}
	if !p2.IsGallery {
		t.Error("photo2 should be gallery ('good' tag qualifies)")
	}
}

func TestPopulatePublishedPhotosSkipsPostsWithNoRefs(t *testing.T) {
	cacheDir := t.TempDir()
	exifCache := exif.NewCache(cacheDir)

	post := &model.Post{Slug: "2022-01-01-empty", Date: mustParseDate("2022-01-01")}
	PopulatePublishedPhotos([]*model.Post{post}, exifCache, nil, t.TempDir())

	if len(post.PublishedPhotos) != 0 {
		t.Errorf("expected 0 photos, got %d", len(post.PublishedPhotos))
	}
}

func TestPopulateAllPhotos(t *testing.T) {
	// Set up image directory with 3 files (2 published + 1 extra).
	imagesDir := t.TempDir()
	postImageDir := filepath.Join(imagesDir, "2022", "2022-12-18-test-post")
	if err := os.MkdirAll(postImageDir, 0o755); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"photo1.jpg", "photo2.jpg", "extra.jpg"} {
		if err := os.WriteFile(filepath.Join(postImageDir, name), []byte("fake"), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	// Set up EXIF cache.
	cacheDir := t.TempDir()
	writeExifCache(t, cacheDir, "2022-12-18-test-post", []exifCacheEntry{
		{ImageFilename: "photo1.jpg", PostSlug: "2022-12-18-test-post", Lat: floatPtr(52.0), Lon: floatPtr(17.0)},
		{ImageFilename: "extra.jpg", PostSlug: "2022-12-18-test-post", Lat: floatPtr(53.0), Lon: floatPtr(18.0)},
	})
	exifCache := exif.NewCache(cacheDir)

	// Pre-populate published photos.
	post := &model.Post{
		Slug: "2022-12-18-test-post",
		Date: mustParseDate("2022-12-18"),
		PublishedPhotos: []*model.Photo{
			{ImageFilename: "photo1.jpg", PostSlug: "2022-12-18-test-post", Desc: "Published 1", Points: 10},
			{ImageFilename: "photo2.jpg", PostSlug: "2022-12-18-test-post", Desc: "Published 2", Points: 5},
		},
	}

	PopulateAllPhotos([]*model.Post{post}, imagesDir, exifCache)

	if len(post.AllPhotos) != 3 {
		t.Fatalf("expected 3 all photos, got %d", len(post.AllPhotos))
	}

	// First two should be the published photos (with their original metadata).
	if post.AllPhotos[0].Desc != "Published 1" {
		t.Errorf("first photo desc = %q, want 'Published 1'", post.AllPhotos[0].Desc)
	}
	if post.AllPhotos[0].Points != 10 {
		t.Errorf("first photo points = %d, want 10", post.AllPhotos[0].Points)
	}

	// Third should be the extra photo from directory scan.
	extra := post.AllPhotos[2]
	if extra.ImageFilename != "extra.jpg" {
		t.Errorf("extra photo filename = %q", extra.ImageFilename)
	}
	if extra.Desc != "" {
		t.Errorf("extra photo should have empty desc, got %q", extra.Desc)
	}
	if extra.Exif == nil {
		t.Error("extra photo should have EXIF data from cache")
	} else if extra.Exif.Lat == nil || *extra.Exif.Lat != 53.0 {
		t.Errorf("extra photo lat = %v", extra.Exif.Lat)
	}
}

func TestPopulateAllPhotosNoDirectory(t *testing.T) {
	imagesDir := t.TempDir()
	cacheDir := t.TempDir()
	exifCache := exif.NewCache(cacheDir)

	post := &model.Post{
		Slug: "2022-01-01-no-images",
		Date: mustParseDate("2022-01-01"),
	}

	PopulateAllPhotos([]*model.Post{post}, imagesDir, exifCache)

	if post.AllPhotos != nil {
		t.Errorf("expected nil AllPhotos, got %d", len(post.AllPhotos))
	}
}

func TestPublishedPhotoByFilename(t *testing.T) {
	post := &model.Post{
		PublishedPhotos: []*model.Photo{
			{ImageFilename: "a.jpg", Desc: "A"},
			{ImageFilename: "b.jpg", Desc: "B"},
		},
	}

	found := post.PublishedPhotoByFilename("b.jpg")
	if found == nil || found.Desc != "B" {
		t.Errorf("expected to find photo B, got %v", found)
	}

	notFound := post.PublishedPhotoByFilename("c.jpg")
	if notFound != nil {
		t.Error("expected nil for missing photo")
	}
}

// --- test helpers ---

type exifCacheEntry struct {
	ImageFilename string   `yaml:"image_filename"`
	PostSlug      string   `yaml:"post_slug"`
	Lat           *float64 `yaml:"lat,omitempty"`
	Lon           *float64 `yaml:"lon,omitempty"`
	ISO           *int     `yaml:"iso,omitempty"`
}

func writeExifCache(t *testing.T, cacheDir, slug string, entries []exifCacheEntry) {
	t.Helper()
	data, err := yaml.Marshal(entries)
	if err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(cacheDir, slug+".yml")
	if err := os.WriteFile(path, append([]byte("---\n"), data...), 0o644); err != nil {
		t.Fatal(err)
	}
}

func floatPtr(f float64) *float64 { return &f }
func intPtr(i int) *int           { return &i }

func mustParseDate(s string) time.Time {
	t, err := time.Parse("2006-01-02", s)
	if err != nil {
		panic(err)
	}
	return t
}
